export type ResumeRow = { id:string; assigned_at:string; review_annotations?: { annotation_status:string }[] | { annotation_status:string } | null };
export function resumeAssignment(rows: ResumeRow[]) {
  const rank = (row:ResumeRow) => {
    const nested = Array.isArray(row.review_annotations) ? row.review_annotations[0] : row.review_annotations;
    if (nested?.annotation_status === "primary_submitted") return 0;
    if (nested?.annotation_status === "in_progress") return 1;
    if (!nested) return 2;
    return 3;
  };
  return [...rows].sort((a,b)=>rank(a)-rank(b)||a.assigned_at.localeCompare(b.assigned_at)||a.id.localeCompare(b.id))[0] ?? null;
}
