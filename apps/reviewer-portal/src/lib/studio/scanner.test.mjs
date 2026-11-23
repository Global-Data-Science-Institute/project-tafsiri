import { describe, it, expect, vi } from "vitest";
import { scanBytes, scanOne, purgeOne } from "./scanner.mjs";
import * as signatures from "./signatures.mjs";
const bytes = new TextEncoder().encode("SYNTHETIC plain evidence");
describe("quarantine admission", () => {
  it("labels mock results and refuses mock use for nonsynthetic data", async () => {
    expect(
      (
        await scanBytes(bytes, "text/plain", {
          provider: "mock",
          synthetic: true,
        })
      ).verdict,
    ).toBe("CLEAN");
    await expect(
      scanBytes(bytes, "text/plain", { provider: "mock", synthetic: false }),
    ).rejects.toThrow();
    expect(
      (
        await scanBytes(
          new TextEncoder().encode("EICAR-STANDARD-ANTIVIRUS-TEST-FILE"),
          "text/plain",
          { provider: "mock", synthetic: true },
        )
      ).verdict,
    ).toBe("INFECTED");
  });
  it("rejects unsupported, malformed, active and encrypted PDF uploads", async () => {
    for (const [content, mime] of [
      ["MZ", "application/pdf"],
      ["SYNTHETIC", "application/octet-stream"],
      ["%PDF-1.7 /JavaScript %%EOF", "application/pdf"],
      ["%PDF-1.7 /Encrypt %%EOF", "application/pdf"],
    ])
      expect(
        (
          await scanBytes(new TextEncoder().encode(content), mime, {
            provider: "mock",
            synthetic: true,
          })
        ).verdict,
      ).toBe("ERROR");
  });
  it("fails closed on missing signatures even with a configured engine", async () => {
    const result = await scanBytes(bytes, "text/plain", { provider: "clamav", binary: "/missing", database: "/missing", sigtool: "/missing", maxSignatureAgeHours: 48 });
    expect(result.verdict).toBe("ERROR");
    expect(result.code).toBe("SIGNATURE_VERIFICATION_FAILURE");
  });
  it("preserves engine exit mappings after independently verified signatures", async () => {
    const verification = vi.spyOn(signatures, "verifySignatures").mockResolvedValue({
      database: "/synthetic-signatures", engine: "1.4.7", updateStatus: "VERIFIED",
      signatures: [{ name: "daily.cvd", version: 1, build: "2026-11-22T00:00:00.000Z" }],
    });
    try {
      for (const [code, verdict, internal] of [[0,"CLEAN","ADMITTED"],[1,"INFECTED","MALWARE_DETECTED"],[2,"ERROR","SCANNER_UNAVAILABLE"]]) {
        const runner = vi.fn(async () => { if (code) throw { code }; return { stdout: "OK" }; });
        const result = await scanBytes(bytes,"text/plain",{provider:"clamav",binary:"/synthetic-engine"},runner);
        expect(result.verdict).toBe(verdict); expect(result.code).toBe(internal);
        expect(runner.mock.calls[0][1]).toContain("--alert-exceeds-max=yes");
        expect(runner.mock.calls[0][2].timeout).toBe(45000);
      }
    } finally { verification.mockRestore(); }
  });
  it("records scan error after storage failure without admitting a file", async () => {
    const rpc = vi
      .fn()
      .mockResolvedValueOnce({
        data: { id: "synthetic", scan_lease: "lease", object_path: "opaque" },
      })
      .mockResolvedValueOnce({ data: {} });
    const client = {
      rpc,
      storage: {
        from: () => ({
          download: async () => ({ error: new Error("offline") }),
        }),
      },
    };
    expect(await scanOne(client, { provider: "mock", synthetic: true })).toBe(
      true,
    );
    expect(rpc.mock.calls[1][1].verdict).toBe("ERROR");
  });
  it("never acknowledges purge after a failed storage removal", async () => {
    const rpc = vi.fn().mockResolvedValueOnce({
      data: {
        paths: ["opaque"],
        contribution_id: "synthetic",
        lease: "lease",
      },
    });
    await expect(
      purgeOne({
        rpc,
        storage: {
          from: () => ({
            remove: async () => ({ error: new Error("offline") }),
          }),
        },
      }),
    ).rejects.toThrow("Storage deletion failed");
    expect(rpc).toHaveBeenCalledTimes(1);
  });
});
