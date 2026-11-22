import { describe, it, expect, vi } from "vitest";
import { deliverInvitation } from "./email";
const invitation = {
  id: "synthetic-delivery",
  email: "invitee@synthetic.example",
  token: "synthetic-token",
};
describe("institutional email adapter", () => {
  it("previews mock delivery without network access", async () => {
    const transport = vi.fn();
    const result = await deliverInvitation(
      invitation,
      { provider: "mock", origin: "http://127.0.0.1:3014", live: false },
      transport,
    );
    expect(result.previewLink).toContain("invite=synthetic-token");
    expect(transport).not.toHaveBeenCalled();
  });
  it("fails closed without explicit live authorization", async () => {
    const transport = vi.fn();
    await expect(
      deliverInvitation(
        invitation,
        {
          provider: "resend",
          origin: "https://synthetic.example",
          live: false,
          key: "synthetic",
          from: "noreply@synthetic.example",
        },
        transport,
      ),
    ).rejects.toThrow("DISABLED");
    expect(transport).not.toHaveBeenCalled();
  });
  it("binds recipient and idempotency key, without copying source material", async () => {
    const transport = vi
      .fn()
      .mockResolvedValue(Response.json({ id: "synthetic-provider-id" }));
    await deliverInvitation(
      invitation,
      {
        provider: "resend",
        origin: "https://synthetic.example",
        live: true,
        key: "synthetic",
        from: "noreply@synthetic.example",
      },
      transport,
    );
    const options = transport.mock.calls[0][1];
    expect(options.headers["Idempotency-Key"]).toBe(invitation.id);
    expect(JSON.parse(options.body).to).toEqual([invitation.email]);
    expect(options.signal).toBeInstanceOf(AbortSignal);
  });
  it("does not return provider error bodies or accept malformed success", async () => {
    for (const response of [
      new Response("sensitive provider body", { status: 429 }),
      Response.json({}),
    ]) {
      await expect(
        deliverInvitation(
          invitation,
          {
            provider: "resend",
            origin: "https://synthetic.example",
            live: true,
            key: "synthetic",
            from: "noreply@synthetic.example",
          },
          vi.fn().mockResolvedValue(response),
        ),
      ).rejects.toThrow("STUDIO_EMAIL_FAILED");
    }
  });
});
