import { reviewerContext } from "@/lib/auth";
import SecurityForm from "./security-form";
export default async function Page() {
  const { sb, profile } = await reviewerContext();
  const { data: expertise = [] } = await sb.from("reviewer_dialect_expertise").select("expertise_level,native_speaker,dialects(name)");
  return <main className="shell"><p className="eyebrow">Reviewer area · Account</p><h1>Reviewer profile</h1><div className="card"><p>Reviewer code: <strong>{profile?.reviewer_code}</strong></p><p>Display name: {profile?.display_name || "Not provided"}</p><h2>Dialect experience</h2>{expertise?.map((entry: any, index) => <p key={index}>{entry.dialects?.name}: {entry.expertise_level}</p>)}</div><SecurityForm /></main>;
}
