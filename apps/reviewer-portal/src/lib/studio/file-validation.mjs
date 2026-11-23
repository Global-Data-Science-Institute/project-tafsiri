import path from "node:path";

export class AdmissionError extends Error {
  constructor(code) { super(code); this.code = code; }
}
const fail = (code = "INVALID_FORMAT") => { throw new AdmissionError(code); };

// A deliberately narrow PCM profile, not a general multimedia decoder.
export function validateWav(input) {
  const b = Buffer.from(input);
  if (b.length < 44 || b.toString("ascii", 0, 4) !== "RIFF" ||
      b.toString("ascii", 8, 12) !== "WAVE" || b.readUInt32LE(4) !== b.length - 8) fail();
  let offset = 12, fmt, data;
  while (offset < b.length) {
    if (offset + 8 > b.length) fail();
    const name = b.toString("ascii", offset, offset + 4), size = b.readUInt32LE(offset + 4);
    const start = offset + 8, end = start + size;
    if (end + (size % 2) > b.length) fail();
    if (name === "fmt ") {
      if (fmt || size !== 16) fail("UNSUPPORTED_FORMAT");
      fmt = b.subarray(start, end);
    } else if (name === "data") {
      if (data !== undefined || !fmt || !size) fail();
      data = size;
    } else fail("UNSUPPORTED_FORMAT"); // No unvalidated metadata/embedded payload chunks.
    offset = end + (size % 2);
  }
  if (!fmt || !data) fail();
  const encoding = fmt.readUInt16LE(0), channels = fmt.readUInt16LE(2), rate = fmt.readUInt32LE(4);
  const byteRate = fmt.readUInt32LE(8), alignment = fmt.readUInt16LE(12), bits = fmt.readUInt16LE(14);
  if (encoding !== 1 || ![1, 2].includes(channels) || ![8, 16, 24, 32].includes(bits)) fail("UNSUPPORTED_FORMAT");
  if (rate < 8000 || rate > 96000 || alignment !== channels * bits / 8 ||
      byteRate !== rate * alignment || data % alignment || data / byteRate > 300) fail();
}

export async function validateFormat(bytes, mime, file, config, runner) {
  if (!bytes.length || bytes.length > 5242880) fail("PROCESSING_LIMIT");
  if (mime === "text/plain") {
    try { if (new TextDecoder("utf-8", { fatal: true }).decode(bytes).includes("\0")) fail(); }
    catch { fail(); }
    return;
  }
  if (mime === "audio/wav") return validateWav(bytes);
  // EBML magic is not sufficient. WebM stays quarantined until a validator is reviewed.
  if (mime !== "application/pdf") fail("UNSUPPORTED_FORMAT");
  if (!Buffer.from(bytes).subarray(0, 5).equals(Buffer.from("%PDF-"))) fail();
  if (!path.isAbsolute(config.qpdf ?? "")) fail("PARSER_UNAVAILABLE");
  const options = { timeout: 10000, maxBuffer: 8 * 1024 * 1024, windowsHide: true };
  let doc;
  try {
    // Warnings (exit 3), repair attempts, crashes and timeouts all fail closed.
    await runner(config.qpdf, ["--check", file], options);
    const { stdout } = await runner(config.qpdf, ["--json=2", "--json-stream-data=none", file], options);
    doc = JSON.parse(stdout);
  } catch (e) {
    fail(e.killed ? "PARSER_TIMEOUT" : e.code === "ENOENT" ? "PARSER_UNAVAILABLE" : "INVALID_FORMAT");
  }
  if (doc.encrypt?.encrypted) fail("UNSUPPORTED_FORMAT");
  if (!Array.isArray(doc.pages) || !doc.pages.length || doc.pages.length > 100 ||
      doc.qpdf?.[0]?.jsonversion !== 2 || !doc.qpdf[1] || Object.keys(doc.qpdf[1]).length > 10000) fail();
  // qpdf decodes escaped names and exposes indirect/unreferenced objects. Reject
  // all actions, annotations, forms, attachments and external stream references.
  const denied = new Set(["/AA", "/A", "/OpenAction", "/AcroForm", "/Annots", "/JavaScript", "/JS",
    "/Launch", "/EmbeddedFile", "/EmbeddedFiles", "/EF", "/Filespec", "/RichMedia", "/XFA",
    "/Encrypt", "/URI", "/SubmitForm", "/ImportData", "/GoToR", "/GoToE", "/Sound", "/Movie",
    "/Rendition", "/3D", "/Collection", "/F", "/FFilter", "/FDecodeParms", "/Action",
    "/GoTo", "/Named", "/SetOCGState", "/Trans", "/Thread", "/Hide", "/ResetForm", "/GoTo3DView", "/PresSteps"]);
  const pending = [doc.qpdf[1]];
  let count = 0;
  while (pending.length) {
    const value = pending.pop();
    if (++count > 100000) fail("PROCESSING_LIMIT");
    if (typeof value === "string" && denied.has(value)) fail("UNSUPPORTED_FORMAT");
    if (value && typeof value === "object") {
      for (const [key, item] of Object.entries(value)) {
        if (denied.has(key)) fail("UNSUPPORTED_FORMAT");
        pending.push(item);
      }
    }
  }
}
