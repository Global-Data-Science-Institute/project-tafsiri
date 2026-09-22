"use client";
import { useState } from "react";
import { createBrowserSupabase } from "@/lib/supabase/browser";
export default function SecurityForm() {
  const [message, setMessage] = useState("");
  const [show, setShow] = useState(false);
  const [pending, setPending] = useState(false);
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const current = (form.elements.namedItem("current") as HTMLInputElement).value;
    const password = (form.elements.namedItem("password") as HTMLInputElement).value;
    const confirm = (form.elements.namedItem("confirm") as HTMLInputElement).value;
    if (password.length < 12) { setMessage("Use at least 12 characters."); return; }
    if (password !== confirm) { setMessage("The new passwords do not match."); return; }
    setPending(true);
    const supabase = createBrowserSupabase();
    const { data: userResult } = await supabase.auth.getUser();
    if (!userResult.user?.email) { setMessage("Your session has expired. Sign in again."); setPending(false); return; }
    const { error: checkError } = await supabase.auth.signInWithPassword({ email: userResult.user.email, password: current });
    if (checkError) { setMessage("Current password is incorrect."); setPending(false); return; }
    const { error } = await supabase.auth.updateUser({ password });
    setPending(false);
    setMessage(error ? "Password could not be changed. Please try again." : "Your password has been updated.");
    if (!error) form.reset();
  }
  return <section className="card"><h2>Security</h2><h3>Change Password</h3><form onSubmit={submit}><label htmlFor="current">Current password</label><input id="current" name="current" type={show ? "text" : "password"} autoComplete="current-password" required /><label htmlFor="password">New password</label><input id="password" name="password" type={show ? "text" : "password"} minLength={12} autoComplete="new-password" required /><p className="muted">Use at least 12 characters.</p><label htmlFor="confirm">Confirm new password</label><input id="confirm" name="confirm" type={show ? "text" : "password"} minLength={12} autoComplete="new-password" required /><label className="inline-control"><input type="checkbox" checked={show} onChange={event => setShow(event.target.checked)} /> Show passwords</label><p role="status" aria-live="polite">{message}</p><button disabled={pending}>{pending ? "Changing…" : "Change Password"}</button></form></section>;
}
