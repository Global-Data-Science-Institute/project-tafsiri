"use client";
import { useRouter } from "next/navigation";
import { createBrowserSupabase } from "@/lib/supabase/browser";
export default function SignOut() {
  const router = useRouter();
  return <button className="nav-button" onClick={async () => { await createBrowserSupabase().auth.signOut(); router.replace("/auth/sign-in"); router.refresh(); }}>Sign Out</button>;
}
