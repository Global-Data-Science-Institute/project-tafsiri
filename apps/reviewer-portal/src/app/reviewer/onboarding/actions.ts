"use server";
import { revalidatePath } from "next/cache";
import { requireUser } from "@/lib/auth";
import { createAdminSupabase } from "@/lib/supabase/admin";
import { EXPERTISE_LEVELS, HE001_PARTICIPATION_VERSION, HE001_STUDY_KEY, LUWANGA_DIALECT_NAME } from "@/lib/study";

export type OnboardingResult = { ok:boolean; message:string };
export async function completeOnboarding(_:OnboardingResult, form:FormData):Promise<OnboardingResult> {
  const { user } = await requireUser();
  const level = String(form.get("expertise"));
  const native = form.get("nativeSpeaker") === "yes" ? true : form.get("nativeSpeaker") === "no" ? false : null;
  if (!EXPERTISE_LEVELS.includes(level as typeof EXPERTISE_LEVELS[number])) return {ok:false,message:"Choose your Luwanga experience level."};
  if (form.get("acknowledged") !== "yes") return {ok:false,message:"Please confirm the participation information."};
  const admin=createAdminSupabase();
  const {data:profile}=await admin.from("reviewer_profiles").select("id,is_active").eq("auth_user_id",user.id).maybeSingle();
  if(!profile) return {ok:false,message:"Your reviewer account has not been activated yet."};
  const {data:study}=await admin.from("evaluation_studies").select("id,dialect_id").eq("study_key",HE001_STUDY_KEY).maybeSingle();
  if(!study) return {ok:false,message:"This study is not available."};
  const {data:participation}=await admin.from("reviewer_study_participation").select("id,participation_status,participation_information_version,participation_acknowledged_at,onboarding_completed_at").eq("reviewer_id",profile.id).eq("study_id",study.id).maybeSingle();
  if(!participation) return {ok:false,message:"You are not currently enrolled in this study."};
  if(participation.participation_status!=="onboarding") return {ok:false,message:"This onboarding record can no longer be changed."};
  const {data:dialect}=await admin.from("dialects").select("id,name").eq("id",study.dialect_id).maybeSingle();
  if(!dialect || dialect.name.toLowerCase()!==LUWANGA_DIALECT_NAME.toLowerCase()) return {ok:false,message:"The study dialect could not be verified."};
  const {error:expertiseError}=await admin.from("reviewer_dialect_expertise").upsert({reviewer_id:profile.id,dialect_id:dialect.id,expertise_level:level,native_speaker:native,self_reported:true},{onConflict:"reviewer_id,dialect_id"});
  if(expertiseError) return {ok:false,message:"Dialect experience could not be saved."};
  if(!participation.participation_acknowledged_at){
    const {error}=await admin.from("reviewer_study_participation").update({participation_information_version:HE001_PARTICIPATION_VERSION}).eq("id",participation.id).is("participation_acknowledged_at",null);
    if(error) return {ok:false,message:"Participation acknowledgment could not be saved."};
  }
  if(!participation.onboarding_completed_at){
    const {error}=await admin.from("reviewer_study_participation").update({onboarding_completed_at:new Date(0).toISOString()}).eq("id",participation.id).is("onboarding_completed_at",null);
    if(error) return {ok:false,message:"Onboarding completion could not be saved."};
  }
  revalidatePath("/reviewer/onboarding");revalidatePath("/reviewer/dashboard");
  return {ok:true,message:"Your onboarding is complete and awaiting researcher approval."};
}
