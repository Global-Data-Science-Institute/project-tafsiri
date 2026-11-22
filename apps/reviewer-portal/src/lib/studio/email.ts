export type InvitationMessage = { id: string; email: string; token: string };
export async function deliverInvitation(
  invitation: InvitationMessage,
  config: {
    provider: string;
    origin: string;
    live: boolean;
    key?: string;
    from?: string;
  },
  transport: typeof fetch = fetch,
) {
  const origin = new URL(config.origin);
  if (
    origin.protocol !== "https:" &&
    !["127.0.0.1", "localhost"].includes(origin.hostname)
  )
    throw new Error("STUDIO_EMAIL_CONFIG");
  const link = new URL("/studio", origin.origin);
  link.searchParams.set("invite", invitation.token);
  if (config.provider === "mock")
    return { messageId: `mock-${invitation.id}`, previewLink: link.toString() };
  if (
    config.provider !== "resend" ||
    !config.live ||
    !config.key ||
    !config.from
  )
    throw new Error("STUDIO_EMAIL_DISABLED");
  const response = await transport("https://api.resend.com/emails", {
    method: "POST",
    signal: AbortSignal.timeout(15000),
    headers: {
      Authorization: `Bearer ${config.key}`,
      "Content-Type": "application/json",
      "Idempotency-Key": invitation.id,
    },
    body: JSON.stringify({
      from: config.from,
      to: [invitation.email],
      subject: "Your Tafsiri research workspace invitation",
      text: `You have been invited to a Tafsiri research workspace. Sign in with this email address and accept the invitation: ${link}\nThis link expires in seven days. A replacement invitation invalidates earlier links. If you did not expect this invitation, ignore it. No access is granted until acceptance.`,
    }),
  });
  if (!response.ok) throw new Error("STUDIO_EMAIL_FAILED");
  const body = await response.json();
  if (typeof body.id !== "string" || body.id.length > 200)
    throw new Error("STUDIO_EMAIL_FAILED");
  return { messageId: body.id as string };
}
