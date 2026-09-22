"use client";
import Link from "next/link";
import { useState } from "react";
import { AuthShell } from "@/components/auth-shell";
import { createBrowserSupabase } from "@/lib/supabase/browser";

export default function ForgotPassword() {
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [pending, setPending] = useState(false);
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    const redirectTo = `${process.env.NEXT_PUBLIC_APP_URL || location.origin}/auth/confirm`;
    await createBrowserSupabase().auth.resetPasswordForEmail(email, { redirectTo });
    setPending(false);
    setMessage("If an account exists for that email address, password reset instructions have been sent.");
  }
  return <AuthShell>
    <div className="auth-heading"><p className="eyebrow">Account recovery</p><h1>Reset your password</h1><p>Enter the email address for your reviewer account. We will send instructions if an account exists.</p></div>
    <form onSubmit={submit} className="auth-form"><label htmlFor="recovery-email">Email</label><input id="recovery-email" type="email" autoComplete="email" required value={email} onChange={event => setEmail(event.target.value)} /><button disabled={pending}>{pending ? "Sending…" : "Send reset link"}</button><p role="status" aria-live="polite">{message}</p></form>
    <p className="auth-help"><Link href="/auth/sign-in">Return to Sign In</Link></p>
  </AuthShell>;
}
