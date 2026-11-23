import { describe, it, expect } from "vitest";
import { validateWav, validateFormat } from "./file-validation.mjs";
import { wav, pdf } from "../../../../../tests/studio/scanner-fixtures.mjs";

describe("structural admission", () => {
  it("accepts bounded PCM silence", () => expect(() => validateWav(wav())).not.toThrow());
  it.each([0, 1, 11, 12, 43, 100, 1643])("rejects truncation at %s", n => {
    expect(() => validateWav(wav().subarray(0,n))).toThrow("INVALID_FORMAT");
  });
  it.each([[4,1],[16,100000],[24,0],[28,1],[40,0],[40,1601]])("rejects invalid size/metadata %s", (offset,value) => {
    const bytes = wav(); bytes.writeUInt32LE(value,offset);
    expect(() => validateWav(bytes)).toThrow();
  });
  it("rejects missing/duplicate format and data chunks", () => {
    const missing = wav(); missing.write("JUNK",12);
    expect(() => validateWav(missing)).toThrow("UNSUPPORTED_FORMAT");
    const duplicate = Buffer.concat([wav(),wav().subarray(12)]);duplicate.writeUInt32LE(duplicate.length-8,4);
    expect(() => validateWav(duplicate)).toThrow();
  });
  it("does not admit WebM from an EBML header", async () => {
    await expect(validateFormat(Buffer.from([26,69,223,163]),"audio/webm","/tmp/file",{},()=>{})).rejects.toThrow("UNSUPPORTED_FORMAT");
  });
  it("does not treat parser warnings, overflow or invalid output as success", async () => {
    for (const error of [{code:3},{code:"ERR_CHILD_PROCESS_STDIO_MAXBUFFER"},{signal:"SIGSEGV"}]) {
      await expect(validateFormat(pdf(),"application/pdf","/tmp/file",{qpdf:"/usr/bin/qpdf"},async()=>{throw error;})).rejects.toThrow("INVALID_FORMAT");
    }
  });
});
