import { createClient } from "@supabase/supabase-js";

if (process.argv[2] !== "--apply") throw new Error("Run with --apply only after reviewing the staging audit.");
const ref = "gfhdwmqefotkljrltfnx";
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SECRET_KEY;
if (!url || !key || new URL(url).hostname !== `${ref}.supabase.co`) {
  throw new Error("Refusing to write to any project other than Project Tafsiri Staging.");
}
const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
const must = async (promise, label) => {
  const { data, error } = await promise;
  if (error) throw new Error(`${label}: ${error.message}`);
  return data;
};

const admins = [];
for (let page = 1; ; page++) {
  const result = await must(db.auth.admin.listUsers({ page, perPage: 100 }), "list staging Auth users");
  admins.push(...result.users.filter(user => user.app_metadata?.tafsiri_role === "research_admin"));
  if (result.users.length < 100) break;
}
if (admins.length !== 1) throw new Error(`Expected exactly one staging research_admin; found ${admins.length}.`);
const admin = admins[0];
const study = await must(db.from("evaluation_studies").select("id,study_key,study_status,dialect_id").eq("study_key", "STAGING_PORTAL_SMOKE_001").single(), "QA study");
if (study.study_status !== "active") throw new Error("The staging QA study is not active.");
const dialect = await must(db.from("dialects").select("id,name").eq("id", study.dialect_id).single(), "QA study dialect");
if (dialect.name !== "Luwanga") throw new Error("The staging QA study is not Luwanga.");
const item = await must(db.from("evaluation_items").select("id,study_id,item_number,source_hash").eq("study_id", study.id).eq("item_number", 2).single(), "synthetic QA item");
if (item.source_hash !== "staging-source-2") throw new Error("Refusing an item without the expected synthetic staging source hash.");

const proposedCode = "STG-ADMIN-R001";
const codeOwner = await must(db.from("reviewer_profiles").select("id,auth_user_id").eq("reviewer_code", proposedCode).maybeSingle(), "QA reviewer code");
let profile = await must(db.from("reviewer_profiles").select("id,auth_user_id,reviewer_code,is_active").eq("auth_user_id", admin.id).maybeSingle(), "admin reviewer profile");
if (codeOwner && codeOwner.auth_user_id !== admin.id) throw new Error("The QA reviewer code belongs to another Auth user.");
const changes = [];
if (!profile) {
  profile = await must(db.from("reviewer_profiles").insert({ auth_user_id: admin.id, reviewer_code: proposedCode, display_name: "Staging Admin QA Reviewer", notes: "Staging-only administrative portal QA account", is_active: true }).select("id,auth_user_id,reviewer_code,is_active").single(), "create admin reviewer profile");
  changes.push("reviewer profile created");
} else if (!profile.is_active) {
  profile = await must(db.from("reviewer_profiles").update({ is_active: true }).eq("id", profile.id).select("id,auth_user_id,reviewer_code,is_active").single(), "activate admin reviewer profile");
  changes.push("reviewer profile activated");
}

const expertise = await must(db.from("reviewer_dialect_expertise").select("id,expertise_level,self_reported").eq("reviewer_id", profile.id).eq("dialect_id", dialect.id).maybeSingle(), "QA dialect expertise");
if (!expertise) {
  await must(db.from("reviewer_dialect_expertise").insert({ reviewer_id: profile.id, dialect_id: dialect.id, expertise_level: "familiar", native_speaker: false, self_reported: false, notes: "Staging QA reviewer access - administrative test account" }), "create QA dialect expertise");
  changes.push("familiar non-self-reported Luwanga QA expertise created");
}

let participation = await must(db.from("reviewer_study_participation").select("id,participation_status,participation_information_version,participation_acknowledged_at,onboarding_completed_at").eq("reviewer_id", profile.id).eq("study_id", study.id).maybeSingle(), "QA study participation");
if (!participation) {
  participation = await must(db.from("reviewer_study_participation").insert({ reviewer_id: profile.id, study_id: study.id }).select("id,participation_status,participation_information_version,participation_acknowledged_at,onboarding_completed_at").single(), "create QA study participation");
  changes.push("QA study participation created");
}
if (participation.participation_status === "onboarding") {
  if (!participation.participation_acknowledged_at) {
    participation = await must(db.from("reviewer_study_participation").update({ participation_information_version: "STAGING-SMOKE-V1" }).eq("id", participation.id).select("id,participation_status,participation_information_version,participation_acknowledged_at,onboarding_completed_at").single(), "record staging QA information acknowledgment");
    changes.push("staging QA participation information recorded");
  }
  if (!participation.onboarding_completed_at) {
    participation = await must(db.from("reviewer_study_participation").update({ onboarding_completed_at: new Date(0).toISOString() }).eq("id", participation.id).select("id,participation_status,participation_information_version,participation_acknowledged_at,onboarding_completed_at").single(), "complete trusted QA onboarding");
    changes.push("trusted QA onboarding completed");
  }
  participation = await must(db.from("reviewer_study_participation").update({ participation_status: "active" }).eq("id", participation.id).select("id,participation_status,participation_information_version,participation_acknowledged_at,onboarding_completed_at").single(), "activate QA participation");
  changes.push("QA participation activated");
}
if (participation.participation_status !== "active") throw new Error(`QA participation cannot be used in status ${participation.participation_status}.`);

let assignment = await must(db.from("review_assignments").select("id,assignment_status").eq("reviewer_id", profile.id).eq("evaluation_item_id", item.id).maybeSingle(), "QA assignment");
if (!assignment) {
  assignment = await must(db.from("review_assignments").insert({ reviewer_id: profile.id, evaluation_item_id: item.id, assignment_role: "reviewer" }).select("id,assignment_status").single(), "assign synthetic QA item");
  changes.push("one synthetic QA item assigned");
}
const finalUser = await must(db.auth.admin.getUserById(admin.id), "verify admin Auth metadata");
if (finalUser.user.app_metadata?.tafsiri_role !== "research_admin") throw new Error("Admin role verification failed.");
console.log(JSON.stringify({ project_ref: ref, auth_user_id: admin.id, email: admin.email, admin_role: "research_admin", reviewer_profile_id: profile.id, reviewer_code: profile.reviewer_code, participation_status: participation.participation_status, study_key: study.study_key, assignment_id: assignment.id, assignment_status: assignment.assignment_status, changes }, null, 2));
