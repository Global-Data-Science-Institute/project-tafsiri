import Image from "next/image";
import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
export const dynamic = "force-dynamic";
export default async function Layout({ children }: { children: React.ReactNode }) {
  await requireAdmin();
  return <><header className="shell nav"><Link className="brand" href="/admin/dashboard"><Image src="/gdsi-logo.svg" alt="Global Data Science Institute" width="250" height="52" /><span>Research administration</span></Link><nav aria-label="Administration navigation"><Link href="/admin/dashboard">Overview</Link><Link href="/admin/reviewers">Reviewers</Link><Link href="/admin/assignments">Assignments</Link></nav></header>{children}</>;
}
