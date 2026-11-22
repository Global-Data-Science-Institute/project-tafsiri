import { readLimited, studioContext, studioError } from "@/lib/studio/server";
import { createAdminSupabase } from "@/lib/supabase/admin";
import { deliverInvitation } from "@/lib/studio/email";
export async function POST(request: Request) {
  try {
    const { sb } = await studioContext(request);
    const body = JSON.parse(
      new TextDecoder().decode(await readLimited(request, 2000)),
    );
    const provider = process.env.STUDIO_EMAIL_PROVIDER ?? "mock";
    if (
      !["mock", "resend"].includes(provider) ||
      (provider === "resend" &&
        process.env.STUDIO_EMAIL_LIVE_ENABLED !== "true")
    )
      throw new Error("STUDIO_EMAIL_DISABLED");
    const { data: invitation, error } = await sb.rpc(
      "studio_invitation_prepare",
      {
        invitation_id: body.id,
        delivery_request: body.request_id,
        email_provider: provider,
      },
    );
    if (error) throw new Error(error.message);
    if (invitation.replayed)
      return Response.json(invitation, {
        headers: { "Cache-Control": "no-store" },
      });
    let sent,
      succeeded = false;
    try {
      sent = await deliverInvitation(invitation, {
        provider,
        origin: process.env.NEXT_PUBLIC_APP_URL!,
        live: process.env.STUDIO_EMAIL_LIVE_ENABLED === "true",
        key: process.env.STUDIO_EMAIL_API_KEY,
        from: process.env.STUDIO_EMAIL_FROM,
      });
      succeeded = true;
    } catch {
      /* Persist only a bounded status; never provider bodies or invitation secrets. */
    }
    const { data, error: finishError } = await createAdminSupabase().rpc(
      "studio_invitation_finish",
      {
        delivery_id: invitation.id,
        succeeded,
        message_id: sent?.messageId ?? null,
      },
    );
    if (finishError) throw new Error(finishError.message);
    return Response.json(
      {
        ...data,
        ...(provider === "mock" && data.state === "MOCK_SENT"
          ? { previewLink: sent?.previewLink }
          : {}),
      },
      {
        status: succeeded ? 200 : 502,
        headers: {
          "Cache-Control": "no-store",
          "Referrer-Policy": "no-referrer",
        },
      },
    );
  } catch (error) {
    return studioError(error);
  }
}
