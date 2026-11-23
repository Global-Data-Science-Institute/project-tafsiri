// Actual local Auth/Storage/scan-worker integration. Refuses all hosted URLs.
import { createRequire } from "node:module";
import { execFileSync, execSync } from "node:child_process";
import { randomUUID, createHash } from "node:crypto";
import assert from "node:assert/strict";
import { scanOne } from "../../apps/reviewer-portal/src/lib/studio/scanner.mjs";
const require = createRequire(
  new URL("../../apps/reviewer-portal/package.json", import.meta.url),
);
const { createClient } = require("@supabase/supabase-js");
const cli =
  process.platform === "win32"
    ? ".\\node_modules\\.bin\\supabase.cmd"
    : "./node_modules/.bin/supabase";
const status = JSON.parse(
  execSync(`${cli} status --workdir .studio-local --output json`, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }),
);
assert.equal(status.API_URL, "http://127.0.0.1:55621");
const opts = { auth: { persistSession: false, autoRefreshToken: false } };
const admin = createClient(
  status.API_URL,
  status.SECRET_KEY ?? status.SERVICE_ROLE_KEY,
  opts,
);
const user = createClient(
  status.API_URL,
  status.PUBLISHABLE_KEY ?? status.ANON_KEY,
  opts,
);
const email = `scan-${randomUUID()}@synthetic.example`,
  password = `Synthetic-${randomUUID()}!`;
const created = await admin.auth.admin.createUser({
  email,
  password,
  email_confirm: true,
});
assert.equal(created.error, null);
assert.equal(
  (await user.auth.signInWithPassword({ email, password })).error,
  null,
);
const sql = (q) =>
  execFileSync(
    "docker",
    [
      "exec",
      "-i",
      "supabase_db_tafsiri-studio-synthetic",
      "psql",
      "-XqAt",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-v",
      "ON_ERROR_STOP=1",
    ],
    { input: q, encoding: "utf8" },
  ).trim();
sql(
  `INSERT INTO data_studio.platform_admins VALUES('${created.data.user.id}',now()+interval '1 hour')`,
);
async function command(operation, payload) {
  const r = await user.rpc("studio_command", {
    operation,
    payload,
    request_id: randomUUID(),
  });
  if (r.error) throw r.error;
  return r.data;
}
const invitation = await command("onboard", {
  name: "SYNTHETIC Scanner University",
  email,
});
await command("accept_invitation", { token: invitation.token });
const org = (await user.rpc("studio_state")).data.organizations[0].id;
const proposal = await command("propose_language", {
  org_id: org,
  name: "SYNTHETIC scanner scope",
  description: "Synthetic",
});
await command("process_language", {
  org_id: org,
  id: proposal.id,
  status: "COLLECTION_ALLOWED",
});
const project = await command("create_project", {
  org_id: org,
  title: "SYNTHETIC scanner test",
  proposal_id: proposal.id,
});
const campaign = await command("create_campaign", {
  project_id: project.id,
  title: "SYNTHETIC uploads",
  category: "DOCUMENT",
  template: [],
  target_count: 3,
});
const item = await command("save", {
  campaign_id: campaign.id,
  content: { text: "SYNTHETIC", source: "SYNTHETIC", method: "synthetic" },
  consent: {
    internal_research: true,
    human_review: true,
    external_ai: false,
    training: false,
    public_display: false,
    redistribution: false,
    commercial: false,
  },
});
const cases = [
  { name: "malformed-pdf", text: "%PDF-1.7\n%%EOF", mime: "application/pdf", expected: "ERROR" },
  { name: "malformed-wav", text: "RIFFxxxxWAVE", mime: "audio/wav", expected: "ERROR" },
  { name: "clean", text: "SYNTHETIC clean bytes", expected: "CLEAN" },
  {
    name: "eicar",
    text: "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*",
    expected: "INFECTED",
  },
  {
    name: "hash-mismatch",
    text: "SYNTHETIC mismatched bytes",
    expected: "ERROR",
  },
];
for (const c of cases) {
  const bytes = Buffer.from(c.text);
  c.upload = await command("upload_intent", {
    id: item.id,
    mime: c.mime ?? "text/plain",
    size_bytes: bytes.length,
    sha256:
      c.name === "hash-mismatch"
        ? "0".repeat(64)
        : createHash("sha256").update(bytes).digest("hex"),
  });
  assert.equal(
    (
      await user.storage
        .from("studio-quarantine")
        .upload(c.upload.object_path, bytes, { contentType: c.mime ?? "text/plain" })
    ).error,
    null,
  );
  assert.ok(
    (
      await user.storage
        .from("studio-quarantine")
        .download(c.upload.object_path)
    ).error,
    "unscanned object admitted",
  );
}
const scanner = async (bytes, mime) =>
  JSON.parse(
    execFileSync(
      "docker",
      [
        "exec",
        "-i",
        "tafsiri-clamav-runtime-001",
        "node",
        "/work/tests/studio/remediation-scanner.mjs",
        "--single",
      ],
      {
        input: JSON.stringify({
          bytes: Buffer.from(bytes).toString("base64"),
          mime,
        }),
        encoding: "utf8",
        timeout: 60000,
      },
    ),
  );
for (let i = 0; i < 25; i++) {
  const state = (await user.rpc("studio_state")).data;
  if (
    cases.every(
      (c) =>
        state.uploads.find((x) => x.id === c.upload.id).scan_state !==
        "PENDING",
    )
  )
    break;
  if (!(await scanOne(admin, { provider: "clamav" }, scanner))) break;
}
for (const c of cases) {
  const row = (await user.rpc("studio_state")).data.uploads.find(
    (x) => x.id === c.upload.id,
  );
  assert.equal(row.scan_state, c.expected, c.name);
  const download = await user.storage
    .from("studio-quarantine")
    .download(c.upload.object_path);
  assert.equal(Boolean(download.error), c.expected !== "CLEAN", c.name);
  console.log(
    JSON.stringify({
      case: c.name,
      state: row.scan_state,
      provider: row.scan_provider,
      version: row.scan_version,
    }),
  );
}
sql(
  `DELETE FROM data_studio.platform_admins WHERE user_id='${created.data.user.id}'`,
);
await user.auth.signOut({ scope: "global" });
console.log(
  "PASS real ClamAV worker: pending denial, clean admission, infected quarantine, hash error",
);
