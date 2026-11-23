import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { activateSignatures } from "../src/lib/studio/signature-update.mjs";

// No database/service credentials belong in the updater environment.
try {
  const result = await activateSignatures(process.env.STUDIO_SIGNATURE_ROOT, {
    binary: process.env.STUDIO_CLAMSCAN_PATH,
    sigtool: process.env.STUDIO_SIGTOOL_PATH,
    freshclam: process.env.STUDIO_FRESHCLAM_PATH,
    maxSignatureAgeHours: Number(process.env.STUDIO_SIGNATURE_MAX_AGE_HOURS),
  }, promisify(execFile));
  console.log(JSON.stringify(result));
} catch {
  console.error(JSON.stringify({ updateStatus: "FAILED", code: "SIGNATURE_VERIFICATION_FAILURE" }));
  process.exitCode = 1;
}
