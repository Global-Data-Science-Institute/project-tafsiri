import { execSync } from "node:child_process";
import path from "node:path";
export function resetLocalDatabase() {
  const isolated = process.env.TAFSIRI_E2E_ISOLATED_STUDIO === "true";
  if (
    !isolated &&
    process.env.NEXT_PUBLIC_SUPABASE_URL === "http://127.0.0.1:55621"
  )
    throw new Error("Isolated URL requires isolated reset mode");
  if (
    isolated &&
    process.env.NEXT_PUBLIC_SUPABASE_URL !== "http://127.0.0.1:55621"
  )
    throw new Error("Refusing non-isolated fixture reset");
  const npx = process.platform === "win32" ? "npx.cmd" : "npx";
  execSync(
    `${npx} supabase db reset --local${isolated ? " --workdir .studio-local" : ""}`,
    { cwd: path.resolve(__dirname, "../../.."), stdio: "inherit" },
  );
}
