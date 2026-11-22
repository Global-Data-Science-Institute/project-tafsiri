import { describe, it, expect, vi } from "vitest";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { scanBytes, scanOne, purgeOne } from "./scanner.mjs";
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
      ).toBe("INFECTED");
  });
  it("maps engine infection and failure distinctly and requires fresh signatures", async () => {
    const dir = await mkdtemp(path.join(tmpdir(), "tafsiri-scan-test-"));
    try {
      const config = {
        provider: "clamav",
        binary: path.join(dir, "clamscan"),
        database: dir,
      };
      await expect(scanBytes(bytes, "text/plain", config)).rejects.toThrow(
        "signatures",
      );
      await writeFile(
        path.join(dir, "daily.cvd"),
        "SYNTHETIC signature fixture",
      );
      for (const [code, verdict] of [
        [0, "CLEAN"],
        [1, "INFECTED"],
        [2, "ERROR"],
      ]) {
        const runner = vi
          .fn()
          .mockResolvedValueOnce({ stdout: "ClamAV synthetic/fixture" });
        if (code) runner.mockRejectedValueOnce({ code });
        else runner.mockResolvedValueOnce({ stdout: "OK" });
        expect(
          (await scanBytes(bytes, "text/plain", config, runner)).verdict,
        ).toBe(verdict);
        expect(runner.mock.calls[1][1]).toContain("--alert-exceeds-max=yes");
      }
    } finally {
      if (path.dirname(path.resolve(dir)) !== path.resolve(tmpdir()))
        throw new Error("Unexpected temp path");
      await rm(dir, { recursive: true, force: true });
    }
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
