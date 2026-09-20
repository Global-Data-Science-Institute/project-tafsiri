import { defineConfig, devices } from "@playwright/test";
import { execSync } from "node:child_process";
import path from "node:path";
const root=path.resolve(__dirname,"../..");
const status=JSON.parse(execSync("npx.cmd supabase status -o json",{cwd:root,encoding:"utf8"}));
const env={NEXT_PUBLIC_SUPABASE_URL:status.API_URL,NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:status.PUBLISHABLE_KEY,SUPABASE_SECRET_KEY:status.SECRET_KEY,NEXT_PUBLIC_APP_URL:"http://127.0.0.1:3000",TAFSIRI_INVITATION_MODE:"mock"};
Object.assign(process.env,env);
export default defineConfig({testDir:"./e2e",fullyParallel:false,workers:1,retries:0,timeout:45000,reporter:"line",globalSetup:"./e2e/global-setup.ts",globalTeardown:"./e2e/global-teardown.ts",use:{baseURL:"http://127.0.0.1:3000",trace:"retain-on-failure",screenshot:"only-on-failure"},webServer:{command:"npm.cmd run dev -- --hostname 127.0.0.1 --port 3000",url:"http://127.0.0.1:3000",reuseExistingServer:false,env},projects:[{name:"chromium",use:{...devices["Desktop Chrome"]}}]});
