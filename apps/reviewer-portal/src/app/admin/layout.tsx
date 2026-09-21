import Image from "next/image";
import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
export const dynamic = "force-dynamic";
export default async function Layout({ children }: { children: React.ReactNode }) {
  const { sb, user } = await requireAdmin();
  const { data: reviewerProfile } = await sb.from("reviewer_profiles").select("id").eq("auth_user_id", user.id).eq("is_active", true).maybeSingle();
  return <><header className="shell nav"><Link className="brand" href="/admin/dashboard"><Image src="/gdsi-logo.svg" alt="Global Data Science Institute" width="250" height="52" /><span>Research administration</span></Link><nav aria-label="Administration navigation"><Link href="/admin/dashboard">Admin Dashboard</Link>{reviewerProfile && <Link href="/reviewer/dashboard">Reviewer Dashboard</Link>}<Link href="/admin/reviewers">Reviewers</Link><Link href="/admin/assignments">Assignments</Link></nav></header>{children}</>;
}
