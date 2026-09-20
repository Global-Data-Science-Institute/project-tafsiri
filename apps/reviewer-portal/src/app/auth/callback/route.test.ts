import { describe, expect, it, vi } from "vitest";
const exchange = vi.fn();
const verify = vi.fn();
vi.mock("@/lib/supabase/server", () => ({ createServerSupabase: async () => ({ auth: { exchangeCodeForSession: exchange, verifyOtp: verify } }) }));
import { GET } from "./route";
describe("auth callback", () => {
  it("rejects missing recovery state with a friendly destination", async () => {
    const response = await GET(new Request("https://portal.test/auth/callback?type=recovery"));
    expect(response.headers.get("location")).toBe("https://portal.test/auth/update-password?error=invalid_link");
  });
  it("exchanges a recovery code and ignores unsafe next destinations", async () => {
    exchange.mockResolvedValueOnce({ error: null });
    const response = await GET(new Request("https://portal.test/auth/callback?code=one&next=//evil.test"));
    expect(exchange).toHaveBeenCalledWith("one");
    expect(response.headers.get("location")).toBe("https://portal.test/reviewer/onboarding");
  });
  it("verifies a recovery token hash", async () => {
    verify.mockResolvedValueOnce({ error: null });
    const response = await GET(new Request("https://portal.test/auth/callback?token_hash=secret&type=recovery"));
    expect(verify).toHaveBeenCalledWith({ token_hash: "secret", type: "recovery" });
    expect(response.headers.get("location")).toBe("https://portal.test/auth/update-password");
  });
});
