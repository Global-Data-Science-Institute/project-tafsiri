"use client";
import Link from "next/link";
import { useState } from "react";
import { useRouter } from "next/navigation";
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
  return <main className="shell auth-page"><div className="card auth-card"><p className="eyebrow">GDSI · Project Tafsiri</p><h1>Language Reviewer Portal</h1><p>Help strengthen digital resources for Luhya languages through independent linguistic review.</p><form onSubmit={submit}><label htmlFor="email">Email</label><input id="email" type="email" autoComplete="email" required value={email} onChange={event => setEmail(event.target.value)} /><label htmlFor="password">Password</label><input id="password" name="password" type="password" autoComplete="current-password" required /><p role="alert">{message}</p><button disabled={pending}>{pending ? "Signing in…" : "Sign In"}</button></form><p><Link href="/auth/forgot-password">Forgot your password?</Link></p><p className="muted">Project Tafsiri is a research initiative of the Global Data Science Institute.</p></div></main>;
}
