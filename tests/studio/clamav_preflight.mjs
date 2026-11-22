// Run only in the disposable, network-disabled scanner container; no credentials.
import { scanBytes } from "../../apps/reviewer-portal/src/lib/studio/scanner.mjs";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdir, writeFile, utimes, readFile } from "node:fs/promises";
import assert from "node:assert/strict";
const execute = promisify(execFile);
const binary = "/opt/clamav147/usr/local/bin/clamscan";
const config = { provider: "clamav", binary, database: "/var/lib/clamav" };
const encode = (s) => new TextEncoder().encode(s);
if (process.argv.includes("--single")) {
  let input = "";
  for await (const chunk of process.stdin) input += chunk;
  const { bytes, mime } = JSON.parse(input);
  console.log(
    JSON.stringify(await scanBytes(Buffer.from(bytes, "base64"), mime, config)),
  );
} else {
  const results = [];
  async function check(name, bytes, mime, expected, options = config, runner) {
    const start = Date.now();
    let result;
    try {
      result = await scanBytes(bytes, mime, options, runner);
    } catch (e) {
      result = { verdict: "ERROR", reason: e.message };
    }
    results.push({ name, expected, ...result, elapsed_ms: Date.now() - start });
    console.log(JSON.stringify(results.at(-1)));
    if (expected) assert.equal(result.verdict, expected, name);
  }
  const text = encode("SYNTHETIC scanner acceptance only\n");
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] >>",
  ];
  let pdf = "%PDF-1.7\n",
    offsets = [0];
  for (const [i, object] of objects.entries()) {
    offsets.push(pdf.length);
    pdf += `${i + 1} 0 obj\n${object}\nendobj\n`;
  }
  const xref = pdf.length;
  pdf += `xref\n0 4\n0000000000 65535 f \n${offsets
    .slice(1)
    .map((n) => `${String(n).padStart(10, "0")} 00000 n \n`)
    .join("")}trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  const wav = Buffer.alloc(1644);
  wav.write("RIFF");
  wav.writeUInt32LE(1636, 4);
  wav.write("WAVEfmt ", 8);
  wav.writeUInt32LE(16, 16);
  wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(8000, 24);
  wav.writeUInt32LE(16000, 28);
  wav.writeUInt16LE(2, 32);
  wav.writeUInt16LE(16, 34);
  wav.write("data", 36);
  wav.writeUInt32LE(1600, 40);
  // EICAR is the standard harmless antivirus test string, generated only inside the container.
  const eicar = encode(
    "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*",
  );
  await check("clean-text", text, "text/plain", "CLEAN");
  await check("clean-pdf", encode(pdf), "application/pdf", "CLEAN");
  await check("clean-wav", wav, "audio/wav", "CLEAN");
  await check("eicar", eicar, "text/plain", "INFECTED");
  await check("unsupported", text, "application/octet-stream", "INFECTED");
  await check("malformed-magic", encode("MZ"), "application/pdf", "INFECTED");
  await check(
    "active-pdf",
    encode("%PDF-1.7 /JavaScript %%EOF"),
    "application/pdf",
    "INFECTED",
  );
  await check(
    "encrypted-pdf",
    encode("%PDF-1.7 /Encrypt %%EOF"),
    "application/pdf",
    "INFECTED",
  );
  await check("oversized", Buffer.alloc(5242881), "text/plain", "ERROR");
  await check(
    "structurally-invalid-pdf",
    encode("%PDF-1.7\n%%EOF"),
    "application/pdf",
    null,
  );
  await check(
    "structurally-invalid-wav",
    encode("RIFFxxxxWAVE"),
    "audio/wav",
    null,
  );
  await mkdir("/tmp/stale", { recursive: true });
  await writeFile("/tmp/stale/daily.cvd", "fixture");
  await utimes("/tmp/stale/daily.cvd", 1, 1);
  await check("stale-signatures", text, "text/plain", "ERROR", {
    ...config,
    database: "/tmp/stale",
  });
  await check("missing-engine", text, "text/plain", "ERROR", {
    ...config,
    binary: "/nonexistent/clamscan",
  });
  // Kill the actual engine during scan startup with an injected 1ms transport deadline.
  await check(
    "real-engine-timeout",
    text,
    "text/plain",
    "ERROR",
    config,
    (file, args, options) =>
      execute(file, args, {
        ...options,
        timeout: args.includes("--version") ? 5000 : 1,
      }),
  );
  // Production 45s deadline against a deliberately hung executable, version call delegates to real engine.
  await check(
    "production-timeout-45s",
    text,
    "text/plain",
    "ERROR",
    config,
    (file, args, options) =>
      args.includes("--version")
        ? execute(file, args, options)
        : execute("/bin/sleep", ["60"], options),
  );
  assert.ok(
    results.at(-1).elapsed_ms >= 44000,
    "Production timeout must actually elapse",
  );
  await writeFile("/tmp/limit.bin", Buffer.alloc(7 * 1024 * 1024, 65));
  let limitCode = 0;
  try {
    await execute(
      binary,
      [
        "--database=/var/lib/clamav",
        "--alert-exceeds-max=yes",
        "--max-filesize=6M",
        "--no-summary",
        "/tmp/limit.bin",
      ],
      { timeout: 45000 },
    );
  } catch (e) {
    limitCode = e.code;
  }
  results.push({ name: "engine-file-limit-6MiB", exit_code: limitCode });
  assert.equal(limitCode, 1);
  const engine = (
    await execute(binary, ["--version", "--database=/var/lib/clamav"])
  ).stdout.trim();
  const metadata = (
    await execute("/usr/bin/sigtool", ["--info", "/var/lib/clamav/daily.cvd"])
  ).stdout;
  const report = {
    at: new Date().toISOString(),
    engine,
    signature_metadata: metadata,
    limits: {
      memory_bytes: await readFile("/sys/fs/cgroup/memory.max", "utf8"),
      cpus: await readFile("/sys/fs/cgroup/cpu.max", "utf8"),
      pids: await readFile("/sys/fs/cgroup/pids.max", "utf8"),
    },
    results,
  };
  await writeFile("/tmp/clamav-results.json", JSON.stringify(report, null, 2));
  console.log("REPORT /tmp/clamav-results.json");
}
