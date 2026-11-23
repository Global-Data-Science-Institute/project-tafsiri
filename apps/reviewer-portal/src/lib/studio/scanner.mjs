import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { validateFormat, AdmissionError } from "./file-validation.mjs";
import { verifySignatures } from "./signatures.mjs";
const execute = promisify(execFile);

export async function scanBytes(bytes, mime, config, runner = execute) {
  if (config.provider === "mock" && !config.synthetic) throw new Error("Mock scanning is synthetic only");
  const dir = await mkdtemp(path.join(tmpdir(), "tafsiri-scan-"));
  let version = "admission-2";
  try {
    if (!bytes.length || bytes.length > 5242880) throw new AdmissionError("PROCESSING_LIMIT");
    const file = path.join(dir, "quarantine.bin");
    await writeFile(file, bytes, { mode: 0o600 });
    await validateFormat(bytes, mime, file, config, runner);
    if (config.provider === "mock") {
      const infected = new TextDecoder().decode(bytes).includes("EICAR-STANDARD-ANTIVIRUS-TEST-FILE");
      return { verdict: infected ? "INFECTED" : "CLEAN", code: infected ? "MALWARE_DETECTED" : "MOCK_CLEAN", version: "synthetic-mock-2" };
    }
    if (config.provider !== "clamav") throw new AdmissionError("SCANNER_UNAVAILABLE");
    const verified = await verifySignatures(config, runner);
    const daily = verified.signatures.find(s => s.name === "daily.cvd");
    version = `ClamAV ${verified.engine};daily=${daily.version};built=${daily.build};VERIFIED;admission-2`;
    const args = ["--no-summary", "--alert-exceeds-max=yes", "--max-filesize=6M", "--max-scansize=20M",
      "--max-recursion=8", "--max-files=100", ...verified.signatures.map(s => `--database=${path.join(verified.database, s.name)}`), file];
    try {
      await runner(config.binary, args, { timeout: 45000, maxBuffer: 8192, windowsHide: true });
      return { verdict: "CLEAN", code: "ADMITTED", version, ...verified };
    } catch (error) {
      return { verdict: error.code === 1 ? "INFECTED" : "ERROR",
        code: error.code === 1 ? "MALWARE_DETECTED" : error.killed ? "SCANNER_TIMEOUT" : "SCANNER_UNAVAILABLE", version };
    }
  } catch (error) {
    return { verdict: "ERROR", code: error instanceof AdmissionError ? error.code : "SCANNER_UNAVAILABLE", version };
  } finally {
    if (path.dirname(path.resolve(dir)) !== path.resolve(tmpdir()) || !path.basename(dir).startsWith("tafsiri-scan-"))
      throw new Error("Unexpected scanner temporary path");
    await rm(dir, { recursive: true, force: true });
  }
}
export async function scanOne(client, config, scanner = scanBytes) {
  const { data: item, error } = await client.rpc("studio_scan_claim");
  if (error) throw error;
  if (!item) return false;
  let result = { verdict: "ERROR", version: "scanner-unavailable" },
    hash = null;
  try {
    const { data, error: downloadError } = await client.storage
      .from("studio-quarantine")
      .download(item.object_path);
    if (downloadError || !data) throw new Error("Storage unavailable");
    const bytes = new Uint8Array(await data.arrayBuffer());
    const { createHash } = await import("node:crypto");
    hash = createHash("sha256").update(bytes).digest("hex");
    if (hash === item.sha256 && bytes.length === item.size_bytes)
      result = await scanner(bytes, item.mime, config);
  } catch {
    /* Record a retryable error without storing object contents or provider output. */
  }
  const finished = await client.rpc("studio_scan_finish", {
    upload_id: item.id,
    lease: item.scan_lease,
    verdict: result.verdict,
    provider: config.provider,
    scanner_version: `${result.version};${result.code ?? "SCANNER_UNAVAILABLE"}`.slice(0, 200),
    actual_hash: hash,
  });
  if (finished.error) throw finished.error;
  return true;
}

export async function purgeOne(client) {
  const { data: item, error } = await client.rpc("studio_deletion_claim");
  if (error) throw error;
  if (!item) return false;
  if (item.paths.length) {
    const removed = await client.storage
      .from("studio-quarantine")
      .remove(item.paths);
    if (removed.error)
      throw new Error("Storage deletion failed; lease will expire for retry");
  }
  const finished = await client.rpc("studio_deletion_finish", {
    item_id: item.contribution_id,
    lease_id: item.lease,
  });
  if (finished.error) throw finished.error;
  return true;
}
