"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { createBrowserSupabase } from "@/lib/supabase/browser";
export default function UpdatePassword() {
  const [ready, setReady] = useState(false);
  const [valid, setValid] = useState(false);
  const [show, setShow] = useState(false);
  const [message, setMessage] = useState("");
  const [done, setDone] = useState(false);
  const [pending, setPending] = useState(false);
  useEffect(() => {
    let active = true;
    const invalidLink = new URLSearchParams(location.search).has("error");
    createBrowserSupabase().auth.getUser().then(({ data }) => {
      if (active) { setValid(!invalidLink && !!data.user); setReady(true); }
    });
    return () => { active = false; };
  }, []);
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const password = (form.elements.namedItem("password") as HTMLInputElement).value;
    const confirm = (form.elements.namedItem("confirm") as HTMLInputElement).value;
    if (password.length < 12) { setMessage("Use at least 12 characters."); return; }
    if (password !== confirm) { setMessage("The passwords do not match."); return; }
    setPending(true);
    const { data } = await createBrowserSupabase().auth.getUser();
    if (!data.user) { setValid(false); setPending(false); return; }
    const { error } = await createBrowserSupabase().auth.updateUser({ password });
    setPending(false);
    if (error) setMessage("Your password could not be changed. Request a new reset link and try again.");
    else { form.reset(); setDone(true); setMessage("Your password has been updated."); }
  }
  return <main className="shell auth-page"><div className="card auth-card"><p className="eyebrow">Project Tafsiri · Account security</p><h1>Set a New Password</h1>{!ready ? <p role="status">Checking your recovery link…</p> : !valid ? <div role="alert"><p>This link is invalid or has expired. Request a new password reset link.</p><Link href="/auth/forgot-password">Request a new link</Link></div> : done ? <div role="status"><p>{message}</p><Link className="button" href="/auth/sign-in">Continue to Sign In</Link></div> : <form onSubmit={submit}><label htmlFor="password">New password</label><input id="password" name="password" type={show ? "text" : "password"} minLength={12} autoComplete="new-password" aria-describedby="password-hint password-error" required /><p id="password-hint" className="muted">Use at least 12 characters.</p><label htmlFor="confirm">Confirm new password</label><input id="confirm" name="confirm" type={show ? "text" : "password"} minLength={12} autoComplete="new-password" aria-describedby="password-error" required /><label className="inline-control"><input type="checkbox" checked={show} onChange={event => setShow(event.target.checked)} /> Show passwords</label><p id="password-error" role="alert">{message}</p><button disabled={pending}>{pending ? "Changing…" : "Change Password"}</button></form>}</div></main>;
}
