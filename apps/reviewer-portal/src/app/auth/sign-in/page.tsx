"use client";
import Link from "next/link";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { AuthShell } from "@/components/auth-shell";
import { createBrowserSupabase } from "@/lib/supabase/browser";

export default function SignIn() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [pending, setPending] = useState(false);
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    const password = (event.currentTarget.elements.namedItem("password") as HTMLInputElement).value;
    const { error } = await createBrowserSupabase().auth.signInWithPassword({ email, password });
    setPending(false);
    if (error) setMessage("We could not sign you in. Check your invitation and credentials.");
    else { router.replace("/reviewer/dashboard"); router.refresh(); }
  }
  return <AuthShell>
    <div className="auth-heading"><p className="eyebrow">Reviewer access</p><h1>Sign In</h1><p>Continue your independent linguistic review for Project Tafsiri.</p></div>
    <form onSubmit={submit} className="auth-form"><label htmlFor="email">Email</label><input id="email" type="email" autoComplete="email" required value={email} onChange={event => setEmail(event.target.value)} /><label htmlFor="password">Password</label><input id="password" name="password" type="password" autoComplete="current-password" required /><p role="alert">{message}</p><button disabled={pending}>{pending ? "Signing in…" : "Sign In"}</button></form>
    <p className="auth-help"><Link href="/auth/forgot-password">Forgot your password?</Link></p>
  </AuthShell>;
}
