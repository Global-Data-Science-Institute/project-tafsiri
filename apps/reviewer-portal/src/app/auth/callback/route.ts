import { NextResponse } from "next/server";
import { createServerSupabase } from "@/lib/supabase/server";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const tokenHash = url.searchParams.get("token_hash");
  const type = url.searchParams.get("type");
  const recovery = type === "recovery" || url.searchParams.get("next") === "/auth/update-password";
  const failure = new URL(recovery ? "/auth/update-password?error=invalid_link" : "/auth/sign-in?error=invalid_callback", url.origin);
  const supabase = await createServerSupabase();
  // Supabase's default confirmation URL returns a PKCE code. Custom email
  // templates may instead link here with a token hash and its OTP type.
  const result = code
    ? await supabase.auth.exchangeCodeForSession(code)
    : tokenHash && (type === "recovery" || type === "invite")
      ? await supabase.auth.verifyOtp({ token_hash: tokenHash, type })
      : null;
  if (!result || result.error) return NextResponse.redirect(failure);
  // Only known internal routes are accepted as destinations.
  return NextResponse.redirect(new URL(recovery ? "/auth/update-password" : "/reviewer/onboarding", url.origin));
}
