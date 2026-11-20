// Synthetic-only operator helper. Never accepts a hosted database URL.
import { execSync, execFileSync, spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
const app = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const root = path.resolve(app, "../..");
const cli =
  process.platform === "win32"
    ? ".\\node_modules\\.bin\\supabase.cmd"
    : "./node_modules/.bin/supabase";
const status = JSON.parse(
  execSync(`${cli} status --workdir .studio-local --output json`, {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }),
);
if (status.API_URL !== "http://127.0.0.1:55621")
  throw new Error("Only the isolated synthetic stack is allowed");
const env = {
  ...process.env,
  NEXT_PUBLIC_SUPABASE_URL: status.API_URL,
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:
    status.PUBLISHABLE_KEY ?? status.ANON_KEY,
  SUPABASE_SECRET_KEY: status.SECRET_KEY ?? status.SERVICE_ROLE_KEY,
  NEXT_PUBLIC_APP_URL: "http://127.0.0.1:3014",
  DATA_STUDIO_ENABLED: "synthetic",
  STUDIO_EXTERNAL_AI_ENABLED: "false",
};
if (process.argv[2] === "serve") {
  const child = spawn(
    process.platform === "win32" ? "npm.cmd" : "npm",
    ["run", "dev", "--", "--hostname", "127.0.0.1", "--port", "3014"],
    {
      cwd: app,
      env,
      stdio: "inherit",
      shell: process.platform === "win32",
      windowsHide: true,
    },
  );
  child.on("exit", (code) => process.exit(code ?? 1));
} else if (process.argv[2] === "seed") {
  const admin = createClient(status.API_URL, env.SUPABASE_SECRET_KEY, {
    auth: { persistSession: false },
  });
  const password = "Synthetic-Only-Studio-2026!";
  const users = {};
  const clients = {};
  const { data: existing, error: listError } = await admin.auth.admin.listUsers(
    { perPage: 1000 },
  );
  if (listError) throw listError;
  for (const name of ["gdsi", "university-a", "university-b"]) {
    const email = `${name}@studio.synthetic.example`;
    let user = existing.users.find((u) => u.email === email);
    if (!user) {
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });
      if (error) throw error;
      user = data.user;
    }
    users[name] = user.id;
    const client = createClient(
      status.API_URL,
      env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
      { auth: { persistSession: false } },
    );
    const { error } = await client.auth.signInWithPassword({ email, password });
    if (error) throw error;
    clients[name] = client;
  }
  const sql = (text) =>
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
      { input: text, encoding: "utf8" },
    );
  sql(
    `INSERT INTO data_studio.platform_admins VALUES('${users.gdsi}',now()+interval '7 days') ON CONFLICT(user_id) DO UPDATE SET expires_at=EXCLUDED.expires_at;`,
  );
  const language = "14000000-0000-4000-8000-000000000001";
  sql(
    `INSERT INTO public.languages(id,name) VALUES('${language}','SYNTHETIC Shared Demonstration Language') ON CONFLICT(id) DO NOTHING;`,
  );
  async function cmd(client, operation, payload) {
    const { data, error } = await client.rpc("studio_command", {
      operation,
      payload,
      request_id: randomUUID(),
    });
    if (error) throw error;
    return data;
  }
  async function state(client) {
    const { data, error } = await client.rpc("studio_state");
    if (error) throw error;
    return data;
  }
  for (const name of ["university-a", "university-b"]) {
    const client = clients[name];
    let s = await state(client);
    if (!s.organizations.length) {
      const invitation = await cmd(clients.gdsi, "onboard", {
        name: `SYNTHETIC ${name.toUpperCase()}`,
        email: `${name}@studio.synthetic.example`,
      });
      await cmd(client, "accept_invitation", { token: invitation.token });
      s = await state(client);
    }
    let project = s.projects[0];
    if (!project)
      project = await cmd(client, "create_project", {
        org_id: s.organizations[0].id,
        title: "SYNTHETIC shared-language research",
        language_id: language,
      });
    let campaign = s.campaigns[0];
    if (!campaign)
      campaign = await cmd(client, "create_campaign", {
        project_id: project.id,
        title: "SYNTHETIC vocabulary collection",
        category: "WORD",
        template: [
          { key: "usage_setting", label: "Usage setting", required: false },
        ],
        target_count: 20,
      });
    if (!s.contributions.length)
      await cmd(client, "save", {
        campaign_id: campaign.id,
        content: {
          text: `SYNTHETIC private example for ${name}`,
          source: "Synthetic demonstration fixture",
          method: "Fixture construction",
          context: "Not authentic language material",
        },
        consent: {
          internal_research: true,
          human_review: true,
          training: false,
          public_display: false,
          redistribution: false,
          commercial: false,
          external_ai: false,
        },
      });
  }
  console.log(
    "Synthetic demo prepared. Local URL: http://127.0.0.1:3014/studio",
  );
  console.log(
    "Accounts: gdsi@studio.synthetic.example, university-a@studio.synthetic.example, university-b@studio.synthetic.example",
  );
  console.log("Synthetic-only password: Synthetic-Only-Studio-2026!");
} else throw new Error("Use: node scripts/studio-local.mjs seed|serve");
