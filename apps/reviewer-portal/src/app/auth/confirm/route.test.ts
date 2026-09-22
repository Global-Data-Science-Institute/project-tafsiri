import { beforeEach, describe, expect, it, vi } from "vitest";
const verify = vi.fn();
vi.mock("@/lib/supabase/server", () => ({ createServerSupabase: async () => ({ auth: { verifyOtp: verify } }) }));
import { GET } from "./route";

describe("recovery confirmation", () => {
  beforeEach(() => verify.mockReset());
  it("verifies a recovery hash and removes it from the destination", async () => {
    verify.mockResolvedValueOnce({ error: null });
    const response = await GET(new Request("https://portal.test/auth/confirm?token_hash=one-time-secret&type=recovery&next=/auth/update-password"));
    expect(verify).toHaveBeenCalledWith({ token_hash: "one-time-secret", type: "recovery" });
    expect(response.status).toBe(303);
    expect(response.headers.get("location")).toBe("https://portal.test/auth/update-password");
    expect(response.headers.get("cache-control")).toBe("no-store");
  });
  it("rejects an invalid or expired hash without exposing it", async () => {
    verify.mockResolvedValueOnce({ error: { message: "expired" } });
    const response = await GET(new Request("https://portal.test/auth/confirm?token_hash=expired-secret&type=recovery"));
    expect(response.headers.get("location")).toBe("https://portal.test/auth/update-password?error=invalid_link");
    expect(response.headers.get("location")).not.toContain("expired-secret");
  });
  it("rejects missing hashes, unsupported types, and unsafe next URLs before verification", async () => {
    for (const query of ["type=recovery", "token_hash=abc&type=signup", "token_hash=abc&type=recovery&next=https://evil.test", "token_hash=abc&type=recovery&next=//evil.test"]) {
      const response = await GET(new Request(`https://portal.test/auth/confirm?${query}`));
      expect(response.headers.get("location")).toBe("https://portal.test/auth/update-password?error=invalid_link");
    }
    expect(verify).not.toHaveBeenCalled();
  });
});
