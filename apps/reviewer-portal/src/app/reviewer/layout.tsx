import Image from "next/image";
import Link from "next/link";
import { reviewerContext } from "@/lib/auth";
import SignOut from "./sign-out";
export const dynamic = "force-dynamic";
export default async function Layout({ children }: { children: React.ReactNode }) {
  const { profile } = await reviewerContext();
  if (!profile) return <main className="shell"><div className="card"><h1>Reviewer access pending</h1><p>Your authenticated account does not yet have an active reviewer profile.</p></div></main>;
  return <><header className="shell nav"><Link className="brand" href="/reviewer/dashboard"><Image src="/gdsi-logo.svg" alt="Global Data Science Institute" width="250" height="52" /><span>Project Tafsiri</span></Link><nav aria-label="Reviewer navigation"><Link href="/reviewer/dashboard">Dashboard</Link><Link href="/reviewer/instructions">Instructions</Link><Link href="/reviewer/profile">Profile</Link><SignOut /></nav></header>{children}</>;
}
