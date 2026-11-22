import { describe, expect, it, vi } from "vitest";
import { mockAssist, runAssistant, validateSuggestions } from "./assistant";
import { validateUpload } from "./files";
const input = {
  content: {
    text: "SYNTHETIC α tone",
    source: "SYNTHETIC source",
    method: "synthetic typing",
  },
  workflow: "vocabulary",
  duplicate_count: 1,
};
describe("Studio assistant boundary", () => {
  it("fails closed on provider throttling, refusal, truncated output and transport errors", async () => {
    const config = {
      externalEnabled: true,
      key: "synthetic",
      model: "synthetic",
    };
    for (const response of [
      new Response("provider error", { status: 429 }),
      Response.json({ status: "incomplete", output: [] }),
      Response.json({
        status: "completed",
        output: [
          { content: [{ type: "refusal", refusal: "synthetic refusal" }] },
        ],
      }),
      new Response("not json"),
    ]) {
      await expect(
        runAssistant(
          "openai",
          input,
          config,
          vi.fn().mockResolvedValue(response),
        ),
      ).rejects.toThrow();
    }
    await expect(
      runAssistant(
        "openai",
        input,
        config,
        vi.fn().mockRejectedValue(new Error("timeout")),
      ),
    ).rejects.toThrow("timeout");
  });
  it("preserves original evidence and reports uncertainty and missing fields", () => {
    const before = JSON.stringify(input);
    const output = mockAssist(input);
    expect(output.candidates).toEqual([input.content.text]);
    expect(output.questions).toContain("Can you provide context?");
    expect(output.uncertainty).toContain("No translation");
    expect(JSON.stringify(input)).toBe(before);
  });
  it("does not fabricate audio transcripts", () =>
    expect(mockAssist({ ...input, workflow: "audio" }).uncertainty).toContain(
      "not supported",
    ));
  it("rejects unknown providers and unconfigured external calls without network access", async () => {
    const transport = vi.fn();
    await expect(
      runAssistant("other", input, { externalEnabled: true }, transport),
    ).rejects.toThrow("Unsupported provider");
    await expect(
      runAssistant("openai", input, { externalEnabled: false }, transport),
    ).rejects.toThrow("not configured");
    expect(transport).not.toHaveBeenCalled();
  });
  it("uses bounded nonstored structured Responses requests and literal candidates", async () => {
    const output = mockAssist(input);
    const transport = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          status: "completed",
          output: [
            {
              content: [{ type: "output_text", text: JSON.stringify(output) }],
            },
          ],
        }),
      ),
    );
    await runAssistant(
      "openai",
      input,
      {
        externalEnabled: true,
        key: "synthetic-test-key",
        model: "synthetic-model",
      },
      transport,
    );
    const body = JSON.parse(transport.mock.calls[0][1].body);
    expect(body.store).toBe(false);
    expect(body.max_output_tokens).toBe(1200);
    expect(body.text.format.type).toBe("json_schema");
  });
  it("rejects invented candidates and malformed/refused output", async () => {
    const transport = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          status: "completed",
          output: [
            {
              content: [
                {
                  type: "output_text",
                  text: JSON.stringify({
                    ...mockAssist(input),
                    candidates: ["invented lexical answer"],
                  }),
                },
              ],
            },
          ],
        }),
      ),
    );
    await expect(
      runAssistant(
        "openai",
        input,
        { externalEnabled: true, key: "test", model: "test" },
        transport,
      ),
    ).rejects.toThrow("Unsupported candidate");
    expect(() =>
      validateSuggestions({ ...mockAssist(input), verified: true }),
    ).toThrow();
  });
});
describe("quarantine format checks", () => {
  it("accepts Unicode text without normalization", () =>
    expect(() =>
      validateUpload(new TextEncoder().encode("SYNTHETIC é"), "text/plain"),
    ).not.toThrow());
  it("rejects malformed documents, executables, oversized and empty files", () => {
    for (const [bytes, mime] of [
      [new Uint8Array(), "text/plain"],
      [new TextEncoder().encode("MZ.exe"), "application/pdf"],
      [new Uint8Array(5242881), "audio/wav"],
      [new Uint8Array([0xff]), "text/plain"],
      [new Uint8Array([1]), "text/html"],
    ] as const)
      expect(() => validateUpload(bytes, mime)).toThrow();
  });
});
