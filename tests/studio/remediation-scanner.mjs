// Real executables, synthetic files, no network or service credentials.
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdir, copyFile, writeFile, readFile, utimes, realpath, readdir } from "node:fs/promises";
import { scanBytes } from "../../apps/reviewer-portal/src/lib/studio/scanner.mjs";
import { verifySignatures } from "../../apps/reviewer-portal/src/lib/studio/signatures.mjs";
import { activateSignatures } from "../../apps/reviewer-portal/src/lib/studio/signature-update.mjs";
import { pdf, wav } from "./scanner-fixtures.mjs";
const execute = promisify(execFile);
const config = { provider: "clamav", binary: "/opt/clamav147/usr/local/bin/clamscan", sigtool: "/opt/clamav147/usr/local/bin/sigtool", database: "/var/lib/clamav", qpdf: "/usr/bin/qpdf", maxSignatureAgeHours: 48 };
if (process.argv.includes("--single")) {
  let input = ""; for await (const chunk of process.stdin) input += chunk;
  const { bytes, mime } = JSON.parse(input);
  console.log(JSON.stringify(await scanBytes(Buffer.from(bytes, "base64"), mime, config)));
} else {
  const results = [];
  async function check(name, bytes, mime, verdict, code, settings = config, runner = execute) {
    const start = Date.now(), result = await scanBytes(bytes, mime, settings, runner);
    assert.equal(result.verdict, verdict, name); if (code) assert.equal(result.code, code, name);
    if (name === "scanner-timeout") assert.ok(Date.now() - start >= 44000);
    if (name === "parser-timeout") assert.ok(Date.now() - start >= 9000);
    results.push({ name, verdict: result.verdict, code: result.code, elapsed_ms: Date.now() - start });
    console.log(JSON.stringify(results.at(-1)));
  }
  const text = Buffer.from("SYNTHETIC harmless text");
  await check("clean-text", text, "text/plain", "CLEAN", "ADMITTED");
  await check("valid-pdf", pdf(), "application/pdf", "CLEAN", "ADMITTED");
  await check("valid-wav", wav(), "audio/wav", "CLEAN", "ADMITTED");
  await check("original-invalid-pdf", Buffer.from("%PDF-1.7\n%%EOF"), "application/pdf", "ERROR", "INVALID_FORMAT");
  await check("original-invalid-wav", Buffer.from("RIFFxxxxWAVE"), "audio/wav", "ERROR", "INVALID_FORMAT");
  await check("truncated-pdf", pdf().subarray(0, 90), "application/pdf", "ERROR", "INVALID_FORMAT");
  await check("encoded-active-pdf", pdf("/Open#41ction << /S /Java#53cript /JS (test) >>"), "application/pdf", "ERROR", "UNSUPPORTED_FORMAT");
  await check("indirect-action", pdf("/OpenAction 3 0 R"), "application/pdf", "ERROR", "UNSUPPORTED_FORMAT");
  await writeFile("/tmp/plain.pdf", pdf());
  await execute(config.qpdf, ["--encrypt", "", "synthetic-owner", "256", "--", "/tmp/plain.pdf", "/tmp/encrypted.pdf"]);
  await check("encrypted-pdf", await readFile("/tmp/encrypted.pdf"), "application/pdf", "ERROR", "UNSUPPORTED_FORMAT");
  const badEncoding = wav(); badEncoding.writeUInt16LE(3, 20);
  await check("unsupported-wave-encoding", badEncoding, "audio/wav", "ERROR", "UNSUPPORTED_FORMAT");
  const badSize = wav(); badSize.writeUInt32LE(999999, 40);
  await check("wav-chunk-overrun", badSize, "audio/wav", "ERROR", "INVALID_FORMAT");
  const badRate = wav(); badRate.writeUInt32LE(1, 28);
  await check("wav-byte-rate", badRate, "audio/wav", "ERROR", "INVALID_FORMAT");
  const longWav = Buffer.alloc(300 * 8000 + 8000 + 44); wav().copy(longWav, 0, 0, 44);
  longWav.writeUInt32LE(longWav.length - 8, 4); longWav.writeUInt32LE(longWav.length - 44, 40);
  longWav.writeUInt32LE(8000, 28); longWav.writeUInt16LE(1, 32); longWav.writeUInt16LE(8, 34);
  await check("wav-duration", longWav, "audio/wav", "ERROR", "INVALID_FORMAT");
  await check("webm-magic-only", Buffer.from([0x1a,0x45,0xdf,0xa3]), "audio/webm", "ERROR", "UNSUPPORTED_FORMAT");
  await execute("/usr/bin/ffmpeg", ["-nostdin", "-v", "error", "-f", "lavfi", "-i", "anullsrc=r=8000:cl=mono", "-t", "0.1", "-c:a", "libopus", "/tmp/valid.webm"]);
  await check("valid-webm-unsupported", await readFile("/tmp/valid.webm"), "audio/webm", "ERROR", "UNSUPPORTED_FORMAT");
  await check("oversized", Buffer.alloc(5242881), "text/plain", "ERROR", "PROCESSING_LIMIT");
  const eicar = Buffer.from("X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*");
  await check("eicar", eicar, "text/plain", "INFECTED", "MALWARE_DETECTED");
  await writeFile("/tmp/limit.bin", Buffer.alloc(7 * 1024 * 1024,65));
  await assert.rejects(execute(config.binary,[`--database=${config.database}`,"--alert-exceeds-max=yes","--max-filesize=6M","--no-summary","/tmp/limit.bin"],{timeout:45000}), e => e.code === 1);
  results.push({name:"engine-file-limit-6MiB",exit_code:1});
  await check("parser-timeout", pdf(), "application/pdf", "ERROR", "PARSER_TIMEOUT", config,
    (f,a,o) => f === config.qpdf ? execute("/bin/sleep", ["60"], o) : execute(f,a,o));
  await check("parser-crash", pdf(), "application/pdf", "ERROR", "INVALID_FORMAT", config,
    (f,a,o) => f === config.qpdf ? execute("/bin/false", [], o) : execute(f,a,o));
  await check("scanner-timeout", text, "text/plain", "ERROR", "SCANNER_TIMEOUT", config,
    (f,a,o) => a.includes("--no-summary") ? execute("/bin/sleep", ["60"], o) : execute(f,a,o));
  await check("missing-engine", text, "text/plain", "ERROR", "SCANNER_UNAVAILABLE", { ...config, binary: "/absent" });
  const metadata = await verifySignatures(config, execute);
  async function copied(dir) {
    await mkdir(dir, {recursive:true});
    for (const name of ["main.cvd","daily.cvd","bytecode.cvd"]) await copyFile(`${config.database}/${name}`, `${dir}/${name}`);
  }
  await copied("/tmp/copied");
  await utimes("/tmp/copied/daily.cvd", new Date(), new Date());
  // Advance only the verifier's injected test clock, never the signed bytes or host clock.
  // A copied valid database with fresh mtime must expire at authenticated build + 49h.
  const expiredAt = Date.parse(metadata.signatures.find(s => s.name === "daily.cvd").build) + 49 * 3600000;
  await assert.rejects(verifySignatures({ ...config, database: "/tmp/copied" }, execute, expiredAt), /SIGNATURE_VERIFICATION_FAILURE/);
  results.push({ name: "old-valid-new-mtime", verdict: "ERROR", code: "SIGNATURE_VERIFICATION_FAILURE", test_clock: new Date(expiredAt).toISOString() });
  const header = await readFile("/tmp/copied/daily.cvd");
  const parts = header.subarray(0,512).toString().trim().split(":"); parts[8] = String(Math.floor(Date.now()/1000));
  header.fill(32, 0, 512); header.write(parts.join(":"),0,"ascii"); await writeFile("/tmp/copied/daily.cvd",header);
  await check("forged-header-time", text, "text/plain", "ERROR", "SIGNATURE_VERIFICATION_FAILURE", { ...config, database: "/tmp/copied" });
  await copyFile(`${config.database}/daily.cvd`, "/tmp/copied/daily.cvd");
  const badSignature = await readFile("/tmp/copied/daily.cvd");
  const badParts = badSignature.subarray(0,512).toString().trim().split(":"); badParts[6] = "A";
  badSignature.fill(32,0,512);badSignature.write(badParts.join(":"),0,"ascii");await writeFile("/tmp/copied/daily.cvd",badSignature);
  await check("unverifiable-signature", text, "text/plain", "ERROR", "SIGNATURE_VERIFICATION_FAILURE", { ...config, database: "/tmp/copied" });
  await writeFile("/tmp/copied/daily.cvd", "corrupted");
  await check("corrupted", text, "text/plain", "ERROR", "SIGNATURE_VERIFICATION_FAILURE", { ...config, database: "/tmp/copied" });
  await check("missing-db", text, "text/plain", "ERROR", "SIGNATURE_VERIFICATION_FAILURE", { ...config, database: "/missing" });
  await copied("/tmp/copied"); await writeFile("/tmp/copied/daily.cld", "unsupported");
  await check("unsupported-cld", text, "text/plain", "ERROR", "SIGNATURE_VERIFICATION_FAILURE", { ...config, database: "/tmp/copied" });
  await check("unknown-engine-version", text, "text/plain", "ERROR", "SIGNATURE_VERIFICATION_FAILURE", config,
    (f,a,o) => a.includes("--version") ? Promise.resolve({stdout:"ClamAV 0.1.0"}) : execute(f,a,o));
  const root = "/tmp/generations";
  await activateSignatures(root, config, execute, copied);
  const previous = await realpath(`${root}/current`);
  await assert.rejects(activateSignatures(root, config, execute, async stage => { await writeFile(`${stage}/daily.cvd`,"partial"); throw new Error("interrupted"); }));
  assert.equal(await realpath(`${root}/current`), previous);
  await activateSignatures(root, config, execute, copied);
  assert.notEqual(await realpath(`${root}/current`), previous);
  await check("restart-after-atomic-update", text, "text/plain", "CLEAN", "ADMITTED", { ...config, database: `${root}/current` });
  const restarted = await execute(process.execPath,["--input-type=module","-e",`import {scanBytes} from '/work/apps/reviewer-portal/src/lib/studio/scanner.mjs'; console.log(JSON.stringify(await scanBytes(Buffer.from('SYNTHETIC restart'),'text/plain',${JSON.stringify({...config,database:`${root}/current`})})));`],{timeout:60000});
  assert.equal(JSON.parse(restarted.stdout).verdict,"CLEAN");
  results.push({name:"fresh-worker-process",verdict:"CLEAN"});
  await Promise.all([check("concurrent-pdf", pdf(), "application/pdf", "CLEAN", "ADMITTED"), check("concurrent-wav", wav(), "audio/wav", "CLEAN", "ADMITTED")]);
  assert.equal((await readdir("/tmp")).filter(n=>n.startsWith("tafsiri-scan-")).length, 0);
  await writeFile("/tmp/remediation-results.json", JSON.stringify({ at:new Date().toISOString(), metadata, qpdf:(await execute(config.qpdf,["--version"])).stdout.trim(), updater: "interruption preserved old generation; successful atomic switch; restart verified", results },null,2));
}
