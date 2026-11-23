import { createClient } from "@supabase/supabase-js";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { scanOne, purgeOne } from "../src/lib/studio/scanner.mjs";
const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../..",
);
const local = process.argv.includes("--local");
let url = process.env.STUDIO_WORKER_SUPABASE_URL,
  key = process.env.STUDIO_WORKER_SECRET;
if (local) {
  const cli =
    process.platform === "win32"
      ? ".\\node_modules\\.bin\\supabase.cmd"
      : "./node_modules/.bin/supabase";
  const s = JSON.parse(
    execSync(`${cli} status --workdir .studio-local --output json`, {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }),
  );
  if (s.API_URL !== "http://127.0.0.1:55621")
    throw new Error("Wrong isolated environment");
  url = s.API_URL;
  key = s.SECRET_KEY ?? s.SERVICE_ROLE_KEY;
} else if (
  process.env.STUDIO_WORKER_AUTHORIZED !== "synthetic-staging-approved" ||
  !process.env.STUDIO_APPROVED_PROJECT_REF ||
  ["gfhdwmqefotkljrltfnx", "ydkookidvipqrwuilqeu"].includes(
    process.env.STUDIO_APPROVED_PROJECT_REF,
  ) ||
  url !== `https://${process.env.STUDIO_APPROVED_PROJECT_REF}.supabase.co` ||
  process.env.STUDIO_ENVIRONMENT !== "synthetic-staging" ||
  process.env.VERCEL_ENV === "preview"
)
  throw new Error("Worker environment is not approved");
if (!url || !key) throw new Error("Worker credentials missing");
const client = createClient(url, key, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const config = {
  provider: local ? "mock" : "clamav",
  synthetic: local,
  binary: process.env.STUDIO_CLAMSCAN_PATH,
  database: process.env.STUDIO_CLAMAV_DATABASE,
  sigtool: process.env.STUDIO_SIGTOOL_PATH,
  qpdf: process.env.STUDIO_QPDF_PATH,
  maxSignatureAgeHours: Number(process.env.STUDIO_SIGNATURE_MAX_AGE_HOURS),
};
const mode = process.argv[2];
if (!["scan", "purge"].includes(mode))
  throw new Error("Use studio-worker.mjs scan|purge [--local]");
let count = 0;
while (
  count < 25 &&
  (await (mode === "scan" ? scanOne(client, config) : purgeOne(client)))
)
  count++;
console.log(
  JSON.stringify({
    worker: mode,
    processed: count,
    environment: local ? "local-synthetic" : "approved-synthetic-staging",
  }),
);
