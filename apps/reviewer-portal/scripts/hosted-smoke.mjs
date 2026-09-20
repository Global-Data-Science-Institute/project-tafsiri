import { chromium } from "playwright";
import AxeBuilder from "@axe-core/playwright";
import { createClient } from "@supabase/supabase-js";
import { readFile } from "node:fs/promises";

const baseURL = process.env.HOSTED_BASE_URL;
const bypass = process.env.VERCEL_PROTECTION_BYPASS;
const credentialsPath = process.env.STAGING_CREDENTIALS_PATH;
if (!baseURL || !bypass || !credentialsPath) throw new Error("Hosted smoke environment is incomplete.");
const credentials = JSON.parse(await readFile(credentialsPath, "utf8"));
const sb = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SECRET_KEY, { auth: { persistSession: false } });
const ids = { profileA: "5a000000-0000-4000-8000-000000000010", profileB: "5a000000-0000-4000-8000-000000000011", participationA: "5a000000-0000-4000-8000-000000000020", items: Array.from({ length: 5 }, (_, i) => `5a000000-0000-4000-8000-00000000010${i + 1}`) };
const results = {};
const must = async (promise, label) => { const { data, error } = await promise; if (error) throw new Error(`${label}: ${error.message}`); return data; };
const assert = (condition, message) => { if (!condition) throw new Error(message); };
const seriousAxe = async page => (await new AxeBuilder({ page }).analyze()).violations.filter(v => ["critical", "serious"].includes(v.impact));

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ baseURL });
const page = await context.newPage();
const establishProtectionCookie = async () => {
  await context.setExtraHTTPHeaders({ "x-vercel-protection-bypass": bypass });
  await page.goto(`/?x-vercel-set-bypass-cookie=true`);
  await context.setExtraHTTPHeaders({});
};
await establishProtectionCookie();
const login = async account => {
  await page.goto("/auth/sign-in");
  await page.getByLabel("Email").fill(credentials[account].email);
  await page.getByLabel("Password").fill(credentials[account].password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await page.waitForURL(/\/(reviewer|admin|pending-access)/, { timeout: 20000 });
};
const freshSession = async account => { await context.clearCookies(); await establishProtectionCookie(); await login(account); };

try {
  await page.goto("/auth/sign-in");
  const signInAxe = await seriousAxe(page);
  await login("reviewerA");
  await page.goto("/reviewer/onboarding");
  const onboardingAxe = await seriousAxe(page);
  for (let step = 0; step < 12; step++) {
    if (await page.getByRole("heading", { name: "Onboarding complete" }).count()) break;
    const heading = await page.getByRole("heading", { level: 1 }).innerText();
    if (heading === "Language & dialect experience") { await page.getByLabel(/How would you describe/).selectOption("advanced"); await page.getByLabel("No").check(); }
    if (heading === "Acknowledgment") await page.getByLabel(/I have read participation/).check();
    const finish = page.getByRole("button", { name: /Save & finish/ });
    if (await finish.count()) { await finish.click(); break; }
    await page.getByRole("button", { name: "Save & continue" }).click();
  }
  await page.getByRole("heading", { name: "Onboarding complete" }).waitFor();
  const participation = await must(sb.from("reviewer_study_participation").select("participation_status,participation_information_version,participation_acknowledged_at,onboarding_completed_at").eq("id", ids.participationA).single(), "onboarding verification");
  const expertise = await must(sb.from("reviewer_dialect_expertise").select("expertise_level,native_speaker").eq("reviewer_id", ids.profileA).single(), "expertise verification");
  assert(["onboarding", "active"].includes(participation.participation_status) && participation.participation_acknowledged_at && participation.onboarding_completed_at && expertise.expertise_level === "advanced", "Onboarding evidence mismatch");
  results.onboarding = "PASS";

  await freshSession("admin");
  await page.goto(`/admin/reviewers/${ids.profileA}`);
  const activate = page.getByRole("button", { name: "Activate Reviewer" });
  if (await activate.count()) { await activate.click(); await page.waitForTimeout(1500); }
  const active = await must(sb.from("reviewer_study_participation").select("participation_status").eq("id", ids.participationA).single(), "activation verification");
  assert(active.participation_status === "active", "Reviewer A was not activated");
  const currentAssignments = await must(sb.from("review_assignments").select("id").eq("reviewer_id", ids.profileA), "Reviewer A assignment check");
  if (!currentAssignments.length) await must(sb.from("review_assignments").insert(ids.items.slice(0, 4).map(evaluation_item_id => ({ evaluation_item_id, reviewer_id: ids.profileA }))), "Reviewer A staging assignments");
  results.admin_activation = "PASS";

  await freshSession("reviewerA");
  const adminResponse = await page.goto("/admin");
  assert((adminResponse?.status() ?? 500) >= 300 || !(await page.locator("body").innerText()).includes("Tafsiri Research Admin"), "Reviewer reached admin UI");
  const inviteResponse = await page.request.post(`${baseURL}/api/admin/invitations`, { headers: { "x-vercel-protection-bypass": bypass }, data: { email: "nobody@example.invalid", reviewerCode: "LUW-R999", studyKey: "STAGING_PORTAL_SMOKE_001" } });
  assert(inviteResponse.status() >= 300, "Reviewer invoked admin invitation endpoint");
  results.admin_isolation = "PASS";

  const bAssignment = await must(sb.from("review_assignments").select("id").eq("reviewer_id", ids.profileB).single(), "Reviewer B assignment");
  const crossResponse = await page.goto(`/reviewer/review/${bAssignment.id}`);
  const crossBody = (await page.locator("body").innerText()).toLowerCase();
  assert(crossResponse?.status() === 404 || crossBody.includes("could not be found") || crossBody.includes("not found"), "Reviewer B data was exposed");
  results.cross_reviewer_isolation = "PASS";

  await page.goto("/reviewer/dashboard");
  const continueLink = page.getByRole("link", { name: "Continue review" });
  const stageBExisting = await must(sb.from("review_annotations").select("assignment_id").eq("annotation_status", "primary_submitted").in("assignment_id", (await must(sb.from("review_assignments").select("id").eq("reviewer_id", ids.profileA), "Reviewer A assignments for resume")).map(row => row.id)).maybeSingle(), "Stage B resume lookup");
  if (stageBExisting) assert((await continueLink.getAttribute("href"))?.endsWith(stageBExisting.assignment_id), "Dashboard did not prioritize Stage B incomplete assignment");
  await continueLink.click();
  await page.waitForURL(/\/reviewer\/review\//);
  let stageAAxe = [];
  if (await page.getByRole("button", { name: "Submit Linguistic Judgment" }).count()) {
    assert(!(await page.locator("body").innerText()).includes("Preliminary classification"), "Pipeline revealed before Stage A");
    assert(!(await page.locator("body").innerText()).includes("STAGING_ONLY"), "Pipeline payload leaked before Stage A");
    stageAAxe = await seriousAxe(page);
    await page.getByLabel(/One clear meaning/).check();
    await page.getByLabel(/Suggested concept label/).fill("Synthetic test concept");
    await page.getByText(/Saved(?: at)?/).waitFor({ timeout: 20000 });
    await page.getByRole("button", { name: "Submit Linguistic Judgment" }).click();
    await page.getByText("Your original judgment is now locked").waitFor();
  }
  assert((await page.locator("body").innerText()).includes("Preliminary classification"), "Pipeline did not reveal after Stage A");
  const stageBUrl = page.url();
  await freshSession("reviewerA");
  await page.goto("/reviewer/dashboard");
  await page.getByRole("link", { name: "Continue review" }).click();
  await page.waitForURL(/\/reviewer\/review\//);
  assert(new URL(page.url()).pathname === new URL(stageBUrl).pathname, "Resume did not prioritize Stage B incomplete assignment");
  results.resume = "PASS";
  await page.locator('select[name="bucket"]').selectOption("YES");
  await page.locator('select[name="ambiguity"]').selectOption("YES");
  await page.getByRole("button", { name: "Submit final review" }).click();
  const submittedId = new URL(stageBUrl).pathname.split("/").pop();
  let submitted;
  for (let attempt = 0; attempt < 20; attempt++) {
    submitted = await must(sb.from("review_annotations").select("annotation_status,primary_submitted_at,pipeline_revealed_at,submitted_at,review_assignments!inner(assignment_status,completed_at)").eq("assignment_id", submittedId).single(), "review submission verification");
    if (submitted.annotation_status === "submitted" && submitted.review_assignments.assignment_status === "completed") break;
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  assert(submitted.annotation_status === "submitted" && submitted.submitted_at && submitted.review_assignments.assignment_status === "completed", "Final submission/assignment state mismatch");
  results.review_flow = "PASS"; results.pipeline_blinding = "PASS";

  results.accessibility = [...signInAxe, ...onboardingAxe, ...stageAAxe].length === 0 ? "PASS" : "FAIL";
  const assignment = await must(sb.from("review_assignments").select("id").eq("reviewer_id", ids.profileA).eq("assignment_status", "active").limit(1).single(), "responsive assignment");
  await page.goto(`/reviewer/review/${assignment.id}`);
  if (!stageAAxe.length) stageAAxe = await seriousAxe(page);
  for (const width of [375, 1280]) { await page.setViewportSize({ width, height: 900 }); await page.goto(`/reviewer/review/${assignment.id}`); const overflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth); assert(!overflow, `Horizontal overflow at ${width}px`); assert(await page.getByRole("button", { name: "Submit Linguistic Judgment" }).isVisible(), `Submit inaccessible at ${width}px`); }
  results.accessibility = [...signInAxe, ...onboardingAxe, ...stageAAxe].length === 0 ? "PASS" : "FAIL";
  results.responsive = "PASS";

  const publicKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const forbidden = [process.env.SUPABASE_SECRET_KEY, "postgresql://", "service_role", "Auth Admin token"].filter(Boolean);
  const resources = await page.evaluate(() => performance.getEntriesByType("resource").map(e => e.name).filter(n => /\.js(?:\?|$)/.test(n)));
  let hostedText = await page.content();
  for (const resource of resources.slice(0, 100)) { const response = await context.request.get(resource, { headers: { "x-vercel-protection-bypass": bypass } }); if (response.ok()) hostedText += await response.text(); }
  assert(forbidden.every(value => !hostedText.includes(value)), "Privileged secret marker found client-side");
  assert(!process.env.SUPABASE_SECRET_KEY.startsWith("NEXT_PUBLIC_"), "Invalid secret variable name");
  results.secret_audit = "PASS";
  console.log(JSON.stringify({ results, accessibility: { critical_or_serious: [...signInAxe, ...onboardingAxe, ...stageAAxe].length }, responsive_widths: [375, 1280], public_publishable_key_expected_client_side: Boolean(publicKey) }, null, 2));
} finally { await browser.close(); }
