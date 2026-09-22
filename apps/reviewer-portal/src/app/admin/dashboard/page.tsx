import { requireAdmin } from "@/lib/auth";
import { HE001_STUDY_KEY } from "@/lib/study";
export default async function AdminDashboard(){
 const{sb}=await requireAdmin();
 const{data:study}=await sb.from("evaluation_studies").select("id,title,study_status").eq("study_key",HE001_STUDY_KEY).maybeSingle();
 if(!study)return <main className="shell"><div className="card">Study unavailable.</div></main>;
 const[{data:items=[]},{data:assignments=[]},{count:reviewers},{count:done}]=await Promise.all([
  sb.from("evaluation_items").select("id").eq("study_id",study.id),
  sb.from("review_assignments").select("evaluation_item_id,assignment_status,reviewer_id,evaluation_items!inner(study_id)").eq("evaluation_items.study_id",study.id),
  sb.from("reviewer_study_participation").select("*",{count:"exact",head:true}).eq("study_id",study.id).eq("participation_status","active"),
  sb.from("review_annotations").select("*,review_assignments!inner(evaluation_items!inner(study_id))",{count:"exact",head:true}).eq("annotation_status","submitted").eq("review_assignments.evaluation_items.study_id",study.id)
 ]);
 const target=3,counts=new Map<string,number>();for(const a of assignments??[])counts.set(a.evaluation_item_id,(counts.get(a.evaluation_item_id)??0)+1);
 const atTarget=(items??[]).filter(i=>(counts.get(i.id)??0)>=target).length,zero=(items??[]).filter(i=>!counts.get(i.id)).length,below=(items?.length??0)-atTarget;
 const metrics=[["Items",items?.length??0],["Active reviewers",reviewers??0],["Assignments",assignments?.length??0],["Completed reviews",done??0],["Items at target",atTarget],["Items below target",below],["Items with zero assignments",zero]];
 return <main className="shell"><p className="eyebrow">Research operations · {study.study_status}</p><h1>{study.title}</h1><div className="grid">{metrics.map(([label,value])=><div className="card metric" key={label}><span>{label}</span><strong>{value}</strong></div>)}</div><div className="card"><h2>Coverage target</h2><p>{target} independent reviews per item · 450 assignments planned</p></div></main>
}
