import Link from "next/link";
import { notFound } from "next/navigation";
import { reviewerContext } from "@/lib/auth";
import { submitStageB } from "../actions";
import StageAForm from "./stage-a-form";

export default async function ReviewPage({ params }: { params: Promise<{ assignmentId: string }> }) {
  const { assignmentId } = await params;
  const { sb } = await reviewerContext();
  const { data: assignment } = await sb.from("review_assignments")
    .select("id,evaluation_item_id,assignment_status").eq("id", assignmentId).maybeSingle();
  if (!assignment) notFound();

  const { data: item } = await sb.from("evaluation_items")
    .select("id,item_number,source_snapshot").eq("id", assignment.evaluation_item_id).single();
  if (!item) notFound();
  const { data: annotation } = await sb.from("review_annotations")
    .select("*").eq("assignment_id", assignment.id).maybeSingle();
  const stage = annotation?.annotation_status ?? "in_progress";

  let pipeline: Record<string, unknown> | null = null;
  if (annotation?.primary_submitted_at) {
    const { data } = await sb.from("evaluation_item_pipeline_snapshots")
      .select("pipeline_snapshot").eq("evaluation_item_id", item.id).maybeSingle();
    pipeline = data?.pipeline_snapshot as Record<string, unknown> | null;
  }
  const source = item.source_snapshot as Record<string, unknown>;
  const otherDefinitions = Array.isArray(source.other_definitions_for_form)
    ? source.other_definitions_for_form as string[] : [];
  const ambiguity = Array.isArray(pipeline?.ambiguity_indicators)
    && pipeline.ambiguity_indicators.length > 0;

  return <main className="shell">
    <p className="eyebrow">Record {item.item_number} Â· {stage.replaceAll("_", " ")}</p>
    <div className="progress"><span style={{ width: `${Math.min(100, item.item_number / 150 * 100)}%` }} /></div>
    <section className="card">
      <p className="eyebrow">Linguistic information</p><h1>{String(source.word ?? "")}</h1>
      <h2>{String(source.english_definition ?? "")}</h2>
      <p>Part of speech: {String(source.part_of_speech ?? "â€”")} Â· Noun class: {String(source.noun_class ?? "â€”")}</p>
      {otherDefinitions.length > 0 && <div className="warning"><strong>Other frozen definitions for this form</strong>
        <ul>{otherDefinitions.map(value => <li key={value}>{value}</li>)}</ul></div>}
    </section>

    {stage === "in_progress" && <StageAForm assignmentId={assignment.id} initial={{decision:annotation?.primary_decision??"",label:annotation?.reviewer_concept_label??"",definition:annotation?.reviewer_definition??"",notes:annotation?.reviewer_notes??""}}/>}

    {stage === "primary_submitted" && pipeline && <form action={submitStageB} className="card">
      <input type="hidden" name="assignment" value={assignment.id} /><p className="eyebrow">Compare with Tafsiri</p>
      <h2>Your original judgment is now locked</h2><p>Tafsiri made this preliminary rule-based assessment before your review.</p>
      <div className="warning">Preliminary classification: <strong>{String(pipeline.bucket ?? "")}</strong><br />
        Ambiguity detected: <strong>{ambiguity ? "Yes" : "No"}</strong></div>
      <details><summary>Advanced technical details</summary><p>Rule-based review score: {String(pipeline.heuristic_confidence ?? "")} (not a probability)</p></details>
      <label htmlFor="bucket">Was Tafsiri&apos;s classification reasonable?</label><select id="bucket" name="bucket" required defaultValue=""><option value="" disabled>Select</option><option>YES</option><option>NO</option><option>UNSURE</option></select>
      <label htmlFor="ambiguity">Was Tafsiri correct about ambiguity?</label><select id="ambiguity" name="ambiguity" required defaultValue=""><option value="" disabled>Select</option><option>YES</option><option>NO</option><option>UNSURE</option></select>
      <button>Submit final review</button>
    </form>}
    {stage === "submitted" && <div className="card"><h2>Review complete</h2><p>This record is read-only. Thank you for your careful judgment.</p><dl><dt>Decision</dt><dd>{annotation?.primary_decision}</dd>{annotation?.reviewer_concept_label&&<><dt>Concept label</dt><dd>{annotation.reviewer_concept_label}</dd></>}{annotation?.reviewer_definition&&<><dt>Preferred definition</dt><dd>{annotation.reviewer_definition}</dd></>}<dt>Pipeline classification reasonable</dt><dd>{annotation?.pipeline_bucket_correct}</dd><dt>Ambiguity assessment correct</dt><dd>{annotation?.pipeline_ambiguity_correct}</dd></dl><Link className="button" href="/reviewer/dashboard">Return to dashboard</Link></div>}
  </main>;
}
