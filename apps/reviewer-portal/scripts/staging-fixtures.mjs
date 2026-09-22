import { createClient } from "@supabase/supabase-js";
import { randomBytes } from "node:crypto";
import { writeFile } from "node:fs/promises";

const PRODUCTION_REF = "ydkookidvipqrwuilqeu";
const STAGING_REF = "gfhdwmqefotkljrltfnx";
const mode = process.argv[2] ?? "seed";
const credentialsPath = process.argv[3];
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const secret = process.env.SUPABASE_SECRET_KEY;
if (!url || !secret) throw new Error("Staging Supabase environment is incomplete.");
const ref = new URL(url).hostname.split(".")[0];
if (ref === PRODUCTION_REF) throw new Error("Refusing known production Supabase project.");
if (ref !== STAGING_REF) throw new Error(`Refusing unapproved Supabase project ref: ${ref}`);
const sb = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });

const ids = {
  language: "5a000000-0000-4000-8000-000000000001",
  dialect: "5a000000-0000-4000-8000-000000000002",
  study: "5a000000-0000-4000-8000-000000000003",
  profileA: "5a000000-0000-4000-8000-000000000010",
  profileB: "5a000000-0000-4000-8000-000000000011",
  participationA: "5a000000-0000-4000-8000-000000000020",
  participationB: "5a000000-0000-4000-8000-000000000021",
  entries: Array.from({ length: 5 }, (_, i) => `5a000000-0000-4000-8000-00000000020${i + 1}`),
  items: Array.from({ length: 5 }, (_, i) => `5a000000-0000-4000-8000-00000000010${i + 1}`),
};
const must = async (promise, label) => { const { data, error } = await promise; if (error) throw new Error(`${label}: ${error.message}`); return data; };

async function seed() {
  if (!credentialsPath) throw new Error("A local credential output path is required.");
  const existing = await must(sb.from("evaluation_studies").select("id").eq("study_key", "STAGING_PORTAL_SMOKE_001").maybeSingle(), "fixture check");
  if (existing) throw new Error("Fixture study already exists; refusing duplicate seed.");
  const users = {};
  const credentials = {};
  for (const [key, code] of [["admin", "STG-ADMIN-001"], ["reviewerA", "STG-LUW-R001"], ["reviewerB", "STG-LUW-R002"]]) {
    const password = `Stg-${randomBytes(18).toString("base64url")}!9a`;
    const email = `${code.toLowerCase()}@example.invalid`;
    const data = await must(sb.auth.admin.createUser({ email, password, email_confirm: true, app_metadata: key === "admin" ? { tafsiri_role: "research_admin" } : {} }), `create ${code}`);
    users[key] = data.user.id;
    credentials[key] = { email, password };
  }
  await must(sb.from("languages").insert({ id: ids.language, name: "Staging Luhya", iso_code: "stg-luy" }), "language");
  await must(sb.from("dialects").insert({ id: ids.dialect, name: "Luwanga", language_id: ids.language, description: "Synthetic staging-only fixture" }), "dialect");
  await must(sb.from("dictionary_entries").insert(ids.entries.map((id, i) => ({ id, dialect_id: ids.dialect, word: `stg-luw-word-${i + 1}`, word_normalized: `stg-luw-word-${i + 1}`, english_definition: `Synthetic staging definition ${i + 1}`, part_of_speech: i === 4 ? "verb" : "noun", noun_class: i === 4 ? null : "staging" }))), "dictionary entries");
  await must(sb.from("reviewer_profiles").insert([
    { id: ids.profileA, auth_user_id: users.reviewerA, reviewer_code: "STG-LUW-R001", display_name: "Staging Reviewer A" },
    { id: ids.profileB, auth_user_id: users.reviewerB, reviewer_code: "STG-LUW-R002", display_name: "Staging Reviewer B" },
  ]), "reviewer profiles");
  await must(sb.from("evaluation_studies").insert({ id: ids.study, study_key: "STAGING_PORTAL_SMOKE_001", title: "Staging Portal Smoke 001", description: "Disposable synthetic hosted verification study", dialect_id: ids.dialect, pipeline_version: "staging-smoke-001", evidence_schema_version: "staging-smoke-001", configuration_hash: "staging-only-configuration", source_artifact_hash: "staging-only-source" }), "study");
  await must(sb.from("evaluation_items").insert(ids.items.map((id, i) => ({ id, study_id: ids.study, item_number: i + 1, dictionary_entry_id: ids.entries[i], source_snapshot: { word: `stg-luw-word-${i + 1}`, english_definition: `Synthetic staging definition ${i + 1}`, part_of_speech: i === 4 ? "verb" : "noun", noun_class: i === 4 ? null : "staging", other_definitions_for_form: [] }, source_hash: `staging-source-${i + 1}`, sampling_group: i === 4 ? "targeted_edge" : `bucket_${String.fromCharCode(65 + (i % 3))}` }))), "items");
  await must(sb.from("evaluation_item_pipeline_snapshots").insert(ids.items.map((id, i) => ({ evaluation_item_id: id, pipeline_snapshot: { bucket: String.fromCharCode(65 + (i % 3)), mapping_status: "candidate", ambiguity_action: "review", heuristic_confidence: 0.61 + i / 20, heuristic_flags: ["STAGING_ONLY"], ambiguity_indicators: [], reason_codes: ["STAGING_SMOKE"] }, pipeline_hash: `staging-pipeline-${i + 1}` }))), "snapshots");
  await must(sb.from("evaluation_studies").update({ study_status: "active" }).eq("id", ids.study), "activate study");
  await must(sb.from("reviewer_study_participation").insert([
    { id: ids.participationA, reviewer_id: ids.profileA, study_id: ids.study },
    { id: ids.participationB, reviewer_id: ids.profileB, study_id: ids.study },
  ]), "participation");
  await must(sb.from("reviewer_dialect_expertise").insert({ reviewer_id: ids.profileB, dialect_id: ids.dialect, expertise_level: "fluent", native_speaker: false }), "reviewer B expertise");
  await must(sb.from("reviewer_study_participation").update({ participation_information_version: "STAGING-SMOKE-V1" }).eq("id", ids.participationB), "reviewer B acknowledgment");
  await must(sb.from("reviewer_study_participation").update({ onboarding_completed_at: new Date(0).toISOString() }).eq("id", ids.participationB), "reviewer B onboarding");
  await must(sb.from("reviewer_study_participation").update({ participation_status: "active" }).eq("id", ids.participationB), "reviewer B activation");
  await must(sb.from("review_assignments").insert({ evaluation_item_id: ids.items[4], reviewer_id: ids.profileB }), "reviewer B isolation assignment");
  await writeFile(credentialsPath, JSON.stringify(credentials), { encoding: "utf8", mode: 0o600 });
  console.log(JSON.stringify({ project_ref: ref, study_key: "STAGING_PORTAL_SMOKE_001", study_id: ids.study, counts: { auth_users: 3, reviewer_profiles: 2, evaluation_items: 5, pipeline_snapshots: 5, assignments: 1 }, reviewer_codes: ["STG-LUW-R001", "STG-LUW-R002"], credentials_file_written: true }, null, 2));
}

async function assignReviewerA() {
  const participation = await must(sb.from("reviewer_study_participation").select("participation_status").eq("id", ids.participationA).single(), "Reviewer A participation");
  if (participation.participation_status !== "active") throw new Error("Reviewer A must be activated through the portal first.");
  const existing = await must(sb.from("review_assignments").select("id").eq("reviewer_id", ids.profileA), "Reviewer A assignment check");
  if (existing.length) throw new Error("Reviewer A assignments already exist; refusing duplicate assignment.");
  await must(sb.from("review_assignments").insert(ids.items.slice(0, 4).map(evaluation_item_id => ({ evaluation_item_id, reviewer_id: ids.profileA }))), "Reviewer A assignments");
  console.log(JSON.stringify({ project_ref: ref, reviewer_code: "STG-LUW-R001", assignments_created: 4 }, null, 2));
}

if (mode === "seed") await seed();
else if (mode === "assign-reviewer-a") await assignReviewerA();
else throw new Error(`Unknown mode: ${mode}`);
