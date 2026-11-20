import { defineConfig, devices } from "@playwright/test";
import { execSync } from "node:child_process";
import path from "node:path";
const root = path.resolve(__dirname, "../..");
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
  throw new Error("Refusing non-isolated Supabase environment");
const env = {
  NEXT_PUBLIC_SUPABASE_URL: status.API_URL,
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:
    status.PUBLISHABLE_KEY ?? status.ANON_KEY,
  SUPABASE_SECRET_KEY: status.SECRET_KEY ?? status.SERVICE_ROLE_KEY,
  DATA_STUDIO_ENABLED: "synthetic",
  STUDIO_EXTERNAL_AI_ENABLED: "false",
  NEXT_PUBLIC_APP_URL: "http://127.0.0.1:3014",
};
Object.assign(process.env, env);
export default defineConfig({
  testDir: "./e2e-studio",
  workers: 1,
  fullyParallel: false,
  timeout: 180000,
  retries: 0,
  reporter: "line",
  use: {
    baseURL: "http://127.0.0.1:3014",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  webServer: {
    command: `${process.platform === "win32" ? "npm.cmd" : "npm"} run dev -- --hostname 127.0.0.1 --port 3014`,
    url: "http://127.0.0.1:3014/studio",
    reuseExistingServer: false,
    env,
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
