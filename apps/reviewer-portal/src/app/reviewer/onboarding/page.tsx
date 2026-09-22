import { reviewerContext } from "@/lib/auth";
import { HE001_STUDY_KEY } from "@/lib/study";
import OnboardingWizard from "./wizard";
import { createAdminSupabase } from "@/lib/supabase/admin";
export default async function OnboardingPage(){
  const{profile}=await reviewerContext();
  if(!profile)return <main className="shell"><div className="card"><h1>Reviewer access pending</h1><p>Your reviewer account has not been activated yet.</p></div></main>;
  const trusted=createAdminSupabase();
  const{data:study}=await trusted.from("evaluation_studies").select("id").eq("study_key",HE001_STUDY_KEY).maybeSingle();
  const{data:participation}=study?await trusted.from("reviewer_study_participation").select("participation_status,participation_information_version,participation_acknowledged_at,onboarding_completed_at").eq("reviewer_id",profile.id).eq("study_id",study.id).maybeSingle():{data:null};
  const{data:expertise}=await trusted.from("reviewer_dialect_expertise").select("expertise_level,native_speaker,dialects(name)").eq("reviewer_id",profile.id).maybeSingle();
  if(!participation)return <main className="shell"><div className="card">You are not currently enrolled in this study.</div></main>;
  if(participation.onboarding_completed_at)return <main className="shell"><div className="card"><h1>Onboarding complete</h1><p>{participation.participation_status==="onboarding"?"Your onboarding is complete and awaiting researcher approval.":"Your participation information has been recorded."}</p></div></main>;
  const resumeStep=participation.participation_acknowledged_at?8:expertise?4:0;
  return <OnboardingWizard initialStep={resumeStep} initialExpertise={expertise?.expertise_level??""} initialNative={expertise?.native_speaker??null}/>;
}
