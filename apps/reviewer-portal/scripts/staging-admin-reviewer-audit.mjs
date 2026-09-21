import { createClient } from "@supabase/supabase-js";

const stagingRef = "gfhdwmqefotkljrltfnx";
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SECRET_KEY;
if (!url || !key || new URL(url).hostname !== `${stagingRef}.supabase.co`) {
  throw new Error("Refusing to inspect any project other than Project Tafsiri Staging.");
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
  admins.push(...result.users.filter(user => user.app_metadata?.tafsiri_role === "research_admin")
    .map(user => ({ id: user.id, email: user.email ?? null })));
  if (result.users.length < 100) break;
}
const studies = await must(db.from("evaluation_studies").select("id,study_key,study_status,dialect_id").eq("study_key", "STAGING_PORTAL_SMOKE_001"), "staging QA study");
const codeOwner = await must(db.from("reviewer_profiles").select("id,auth_user_id,reviewer_code").eq("reviewer_code", "STG-ADMIN-R001"), "staging QA code availability");
const dialects = studies.length ? await must(db.from("dialects").select("id,name").eq("id", studies[0].dialect_id), "study dialect") : [];
const profiles = admins.length ? await must(db.from("reviewer_profiles").select("id,auth_user_id,reviewer_code,is_active").in("auth_user_id", admins.map(a => a.id)), "admin reviewer profiles") : [];
const profileIds = profiles.map(p => p.id);
const participation = profileIds.length ? await must(db.from("reviewer_study_participation").select("reviewer_id,study_id,participation_status,participation_information_version,onboarding_completed_at,participation_acknowledged_at").in("reviewer_id", profileIds), "admin participation") : [];
const expertise = profileIds.length ? await must(db.from("reviewer_dialect_expertise").select("reviewer_id,dialect_id,expertise_level,native_speaker,self_reported,notes").in("reviewer_id", profileIds), "admin expertise") : [];
const itemCount = studies.length ? await must(db.from("evaluation_items").select("id", { count: "exact" }).eq("study_id", studies[0].id), "staging items") : null;
const items = studies.length ? await must(db.from("evaluation_items").select("id,item_number,source_hash").eq("study_id", studies[0].id).order("item_number"), "staging items") : [];
const assignments = items.length ? await must(db.from("review_assignments").select("evaluation_item_id,reviewer_id,assignment_role,assignment_status").in("evaluation_item_id", items.map(item => item.id)), "staging assignments") : [];
const studyVersions = studies.length ? await must(db.from("reviewer_study_participation").select("participation_information_version,participation_status").eq("study_id", studies[0].id), "staging participation versions") : [];
console.log(JSON.stringify({ project_ref: stagingRef, admins, profiles, codeOwner, studies, dialects, participation, expertise, staging_item_count: itemCount?.length ?? 0, items, assignments, studyVersions }, null, 2));
