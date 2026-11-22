import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, writeFile, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
const execute = promisify(execFile);

// The mock is explicitly not malware protection. Only synthetic acceptance may use it.
export async function scanBytes(bytes, mime, config, runner = execute) {
  if (!bytes.length || bytes.length > 5242880)
    return { verdict: "ERROR", version: "format-1" };
  const text = new TextDecoder().decode(bytes);
  const valid =
    mime === "text/plain"
      ? !text.includes("\0") &&
        (() => {
          try {
            new TextDecoder("utf-8", { fatal: true }).decode(bytes);
            return true;
          } catch {
            return false;
          }
        })()
      : mime === "application/pdf"
        ? text.startsWith("%PDF-") && text.slice(-1024).includes("%%EOF")
        : mime === "audio/wav"
          ? text.startsWith("RIFF") && text.slice(8, 12) === "WAVE"
          : mime === "audio/webm" &&
            [0x1a, 0x45, 0xdf, 0xa3].every((v, i) => bytes[i] === v);
  if (
    !valid ||
    (mime === "application/pdf" &&
      /\/(JavaScript|JS|Launch|EmbeddedFile|Encrypt)\b/.test(text))
  )
    return { verdict: "INFECTED", version: "format-policy-1" };
  if (config.provider === "mock") {
    if (!config.synthetic) throw new Error("Mock scanning is synthetic only");
    return {
      verdict: text.includes("EICAR-STANDARD-ANTIVIRUS-TEST-FILE")
        ? "INFECTED"
        : "CLEAN",
      version: "synthetic-mock-1",
    };
  }
  if (
    config.provider !== "clamav" ||
    !path.isAbsolute(config.binary ?? "") ||
    !path.isAbsolute(config.database ?? "")
  )
    throw new Error("Scanner configuration missing");
  // Refuse stale or missing daily signatures, even if the engine itself starts.
  let fresh = false;
  for (const name of ["daily.cvd", "daily.cld"]) {
    try {
      const s = await stat(path.join(config.database, name));
      if (Date.now() - s.mtimeMs < 48 * 3600000 && s.size > 0) fresh = true;
    } catch {
      /* fail closed */
    }
  }
  if (!fresh) throw new Error("Scanner signatures are missing or stale");
  const dir = await mkdtemp(path.join(tmpdir(), "tafsiri-scan-"));
  try {
    const file = path.join(dir, "quarantine.bin");
    await writeFile(file, bytes, { mode: 0o600 });
    const { stdout: version } = await runner(
      config.binary,
      ["--version", `--database=${config.database}`],
      { timeout: 5000, maxBuffer: 4096, windowsHide: true },
    );
    const args = [
      "--no-summary",
      "--alert-exceeds-max=yes",
      "--max-filesize=6M",
      "--max-scansize=20M",
      "--max-recursion=8",
      "--max-files=100",
      `--database=${config.database}`,
      file,
    ];
    try {
      await runner(config.binary, args, {
        timeout: 45000,
        maxBuffer: 8192,
        windowsHide: true,
      });
      return { verdict: "CLEAN", version: version.trim().slice(0, 200) };
    } catch (error) {
      return {
        verdict: error.code === 1 ? "INFECTED" : "ERROR",
        version: version.trim().slice(0, 200),
      };
    }
  } finally {
    if (
      path.dirname(path.resolve(dir)) !== path.resolve(tmpdir()) ||
      !path.basename(dir).startsWith("tafsiri-scan-")
    )
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
    scanner_version: result.version,
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
