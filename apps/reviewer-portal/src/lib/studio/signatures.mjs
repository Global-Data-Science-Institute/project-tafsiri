import { realpath, readdir, open, lstat } from "node:fs/promises";
import path from "node:path";
import { AdmissionError } from "./file-validation.mjs";

// Reviewed engine profile. Unknown versions require explicit compatibility review.
const engines = { "1.4.7": 217 };
export async function verifySignatures(config, runner, now = Date.now()) {
  const fail = () => { throw new AdmissionError("SIGNATURE_VERIFICATION_FAILURE"); };
  try {
    if (!path.isAbsolute(config.sigtool ?? "") || !path.isAbsolute(config.database ?? "") ||
        !path.isAbsolute(config.binary ?? "") || !Number.isFinite(config.maxSignatureAgeHours) ||
        config.maxSignatureAgeHours <= 0 || config.maxSignatureAgeHours > 48) fail();
    // Resolve the atomic current symlink ONCE. Updaters never modify generations.
    const database = await realpath(config.database);
    const names = await readdir(database);
    const files = ["main.cvd", "daily.cvd", "bytecode.cvd"];
    if (names.some(n => ![...files, "freshclam.dat", "mirrors.dat"].includes(n)) ||
        files.some(n => !names.includes(n))) fail();
    const options = { timeout: 45000, maxBuffer: 8192, windowsHide: true, env: { ...process.env, LC_ALL: "C", TZ: "UTC" } };
    let engine;
    try { engine = (await runner(config.binary, ["--version"], options)).stdout; }
    catch (error) { throw new AdmissionError(error.killed ? "SCANNER_TIMEOUT" : "SCANNER_UNAVAILABLE"); }
    const version = /^ClamAV (\d+\.\d+\.\d+)(?:\/|\s|$)/.exec(engine)?.[1];
    if (!engines[version]) fail();
    const tool = await runner(config.sigtool, ["--version"], options);
    if (!tool.stdout.startsWith(`ClamAV ${version}`)) fail();
    const metadata = [];
    for (const name of files) {
      const file = path.join(database, name), s = await lstat(file);
      if (!s.isFile() || s.size < 512 || s.size > 256 * 1024 * 1024) fail();
      // sigtool calls cl_cvdverify: cryptographic verification PLUS comparison
      // of the outer header with the signed internal .info and payload hashes.
      // CLD/CUD and detached-signature 1.5 formats are deliberately unsupported.
      const { stdout } = await runner(config.sigtool, ["--info", file], options);
      if (!/^Verification OK\.$/m.test(stdout)) fail();
      const handle = await open(file, "r");
      const header = Buffer.alloc(512);
      try { if ((await handle.read(header, 0, 512, 0)).bytesRead !== 512) fail(); }
      finally { await handle.close(); }
      const parts = header.toString("ascii").trim().split(":");
      const build = Number(parts[8]), revision = Number(parts[2]), level = Number(parts[4]);
      if (parts[0] !== "ClamAV-VDB" || !Number.isSafeInteger(build) || build <= 0 ||
          !Number.isSafeInteger(revision) || revision <= 0 || !Number.isSafeInteger(level) || level > engines[version] ||
          build * 1000 > now + 300000) fail();
      if (name === "daily.cvd" && now - build * 1000 > config.maxSignatureAgeHours * 3600000) fail();
      metadata.push({ name, version: revision, build: new Date(build * 1000).toISOString(), functionality: level });
    }
    return { database, engine: version, signatures: metadata, updateStatus: "VERIFIED" };
  } catch (error) {
    if (error instanceof AdmissionError) throw error;
    fail();
  }
}
