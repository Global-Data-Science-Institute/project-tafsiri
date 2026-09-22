import { NextResponse } from "next/server";
import { createServerSupabase } from "@/lib/supabase/server";
const decisions=["ACCEPT_SIMPLE","ACCEPT_VARIANT","SPLIT_SENSES","NEEDS_EXPERT"];
const optional=(value:unknown)=>typeof value==="string"&&value.trim()?value.trim():null;
export async function PUT(request:Request,{params}:{params:Promise<{assignmentId:string}>}){
 const sb=await createServerSupabase(),{data:{user}}=await sb.auth.getUser();if(!user)return NextResponse.json({message:"Sign in required."},{status:401});
 const{assignmentId}=await params,body=await request.json(),decision=String(body.decision??"");if(!decisions.includes(decision))return NextResponse.json({message:"Choose a linguistic judgment before saving."},{status:400});
 const payload={primary_decision:decision,reviewer_concept_label:optional(body.label),reviewer_definition:optional(body.definition),reviewer_notes:optional(body.notes)};
 const{data:existing}=await sb.from("review_annotations").select("id,annotation_status").eq("assignment_id",assignmentId).maybeSingle();
 if(existing?.annotation_status!==undefined&&existing.annotation_status!=="in_progress")return NextResponse.json({message:"This linguistic judgment is already locked."},{status:409});
 const result=existing?await sb.from("review_annotations").update(payload).eq("id",existing.id).eq("annotation_status","in_progress").select("updated_at").single():await sb.from("review_annotations").insert({...payload,assignment_id:assignmentId}).select("updated_at").single();
 if(result.error)return NextResponse.json({message:"Draft could not be saved."},{status:403});return NextResponse.json({savedAt:result.data.updated_at,version:body.version});
}
