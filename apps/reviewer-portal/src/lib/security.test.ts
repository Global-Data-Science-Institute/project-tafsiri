import { describe, expect, it } from "vitest";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(__dirname, "..");
function files(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry =>
    entry.isDirectory() ? files(path.join(dir, entry.name)) : [path.join(dir, entry.name)]);
}
const appFiles = files(root).filter(file => /\.(ts|tsx)$/.test(file) && !file.endsWith(".test.ts"));

describe("security boundary", () => {
  const source = appFiles.map(file => fs.readFileSync(file, "utf8")).join("\n");
  it("does not embed credentials", () => {
    expect(source).not.toMatch(/eyJ[a-zA-Z0-9_-]{20,}/);
    expect(source).not.toContain("TAFSIRI_DATABASE_URL");
  });
  it("keeps Auth Admin server-side", () => {
    for (const file of appFiles.filter(file => fs.readFileSync(file, "utf8").includes('"use client"')))
      expect(fs.readFileSync(file, "utf8")).not.toContain("auth.admin");
  });
  it("guards invitation endpoint", () => {
    expect(fs.readFileSync(path.join(root, "app/api/admin/invitations/route.ts"), "utf8")).toContain("requireAdmin()");
  });
  it("does not preload Pipeline evidence", () => {
    const page = fs.readFileSync(path.join(root, "app/reviewer/review/[assignmentId]/page.tsx"), "utf8");
    expect(page.indexOf("if (annotation?.primary_submitted_at)")).toBeLessThan(page.indexOf('from("evaluation_item_pipeline_snapshots")'));
  });
});
