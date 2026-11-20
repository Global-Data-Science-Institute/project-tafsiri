import base from "./playwright.studio.config";
import { defineConfig } from "@playwright/test";
process.env.TAFSIRI_E2E_ISOLATED_STUDIO = "true";
export default defineConfig({
  ...base,
  testDir: "./e2e",
  globalSetup: "./e2e/global-setup.ts",
  globalTeardown: "./e2e/global-teardown.ts",
});
