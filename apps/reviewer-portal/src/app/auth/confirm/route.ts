import { NextResponse } from "next/server";
import { createServerSupabase } from "@/lib/supabase/server";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const tokenHash = url.searchParams.get("token_hash");
  const type = url.searchParams.get("type");
  const next = url.searchParams.get("next");
  const destination = new URL("/auth/update-password", url.origin);
  const failure = new URL("/auth/update-password?error=invalid_link", url.origin);

  // Recovery is the only OTP type this endpoint needs. Ignore arbitrary next URLs.
  if (!tokenHash || type !== "recovery" || (next && next !== "/auth/update-password")) {
    return NextResponse.redirect(failure, { status: 303, headers: { "Cache-Control": "no-store", "Referrer-Policy": "no-referrer" } });
  }

  const supabase = await createServerSupabase();
  const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: "recovery" });
  return NextResponse.redirect(error ? failure : destination, {
    status: 303,
    headers: { "Cache-Control": "no-store", "Referrer-Policy": "no-referrer" },
  });
}
