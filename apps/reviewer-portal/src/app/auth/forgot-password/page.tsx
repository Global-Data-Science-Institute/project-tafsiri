"use client";
import Link from "next/link";
import { useState } from "react";
import { createBrowserSupabase } from "@/lib/supabase/browser";
export default function ForgotPassword() {
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [pending, setPending] = useState(false);
  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setPending(true);
    const redirectTo = `${location.origin}/auth/callback?next=%2Fauth%2Fupdate-password`;
    await createBrowserSupabase().auth.resetPasswordForEmail(email, { redirectTo });
    setPending(false);
    setMessage("If an account exists for that email address, a password reset link has been sent.");
  }
  return <main className="shell auth-page"><div className="card auth-card"><p className="eyebrow">Project Tafsiri · Account recovery</p><h1>Reset your password</h1><p>Enter the email address for your reviewer account.</p><form onSubmit={submit}><label htmlFor="recovery-email">Email</label><input id="recovery-email" type="email" autoComplete="email" required value={email} onChange={event => setEmail(event.target.value)} /><button disabled={pending}>{pending ? "Sending…" : "Send reset link"}</button><p role="status" aria-live="polite">{message}</p></form><Link href="/auth/sign-in">Return to sign in</Link></div></main>;
}
