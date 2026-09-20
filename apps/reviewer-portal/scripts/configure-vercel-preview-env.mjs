import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const values = Object.fromEntries(readFileSync(".env.local", "utf8").split(/\r?\n/).flatMap(line => {
  const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
  if (!match) return [];
  return [[match[1], match[2].trim().replace(/^['"]|['"]$/g, "")]];
}));
const preview = {
  NEXT_PUBLIC_SUPABASE_URL: values.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: values.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  SUPABASE_SECRET_KEY: values.SUPABASE_SECRET_KEY,
  TAFSIRI_INVITATION_MODE: "mock",
  TAFSIRI_STUDY_KEY: "STAGING_PORTAL_SMOKE_001",
  NEXT_PUBLIC_APP_URL: "https://tafsiri-reviewer-portal-staging.vercel.app",
};
for (const [name, value] of Object.entries(preview)) {
  if (!value) throw new Error(`Missing ${name}`);
  const result = spawnSync("npx.cmd", ["vercel", "env", "add", name, "preview", "--force"], {
    input: Buffer.from(value, "utf8"), stdio: ["pipe", "inherit", "inherit"], shell: true,
  });
  if (result.error) throw result.error;
  if (result.status) process.exit(result.status ?? 1);
}
console.log("Preview variables replaced using UTF-8 byte input; values not displayed.");
