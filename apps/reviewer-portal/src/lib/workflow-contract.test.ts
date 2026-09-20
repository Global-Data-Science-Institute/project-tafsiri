import{describe,expect,it}from"vitest";import fs from"node:fs";import path from"node:path";
const app=path.resolve(__dirname,"../app"),read=(p:string)=>fs.readFileSync(path.join(app,p),"utf8");
describe("portal workflow contracts",()=>{
 it("documents the Stage A lock warning",()=>expect(read("reviewer/review/[assignmentId]/page.tsx")).toContain("judgment is now locked"));
 it("renders completed work read-only",()=>expect(read("reviewer/review/[assignmentId]/page.tsx")).toContain("This record is read-only"));
 it("shows pending and withdrawn dashboard states",()=>{const s=read("reviewer/dashboard/page.tsx");expect(s).toContain("awaiting researcher approval");expect(s).toContain("Participation ended")});
 it("requires explicit withdrawal confirmation",()=>expect(read("admin/reviewers/[reviewerId]/participation-actions.tsx")).toContain("I understand and confirm"));
 it("never self-activates onboarding",()=>expect(read("reviewer/onboarding/actions.ts")).not.toContain('participation_status:"active"'));
});
