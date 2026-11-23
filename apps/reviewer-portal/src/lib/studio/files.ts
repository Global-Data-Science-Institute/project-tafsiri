export const MAX_UPLOAD = 5 * 1024 * 1024;
export function validateUpload(bytes: Uint8Array, mime: string) {
  if (!bytes.length || bytes.length > MAX_UPLOAD)
    throw new Error("Choose a file between 1 byte and 5 MB.");
  const head = new TextDecoder().decode(bytes.slice(0, 12));
  if (mime === "text/plain") {
    const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    if (text.includes("\0")) throw new Error("Invalid text file.");
  } else if (mime === "application/pdf") {
    if (
      !head.startsWith("%PDF-") ||
      !new TextDecoder().decode(bytes.slice(-1024)).includes("%%EOF")
    )
      throw new Error("Invalid PDF header or end marker.");
  } else if (mime === "audio/wav") {
    if (!head.startsWith("RIFF") || head.slice(8, 12) !== "WAVE")
      throw new Error("Invalid WAV header.");
  } else if (mime === "audio/webm") {
    if (![0x1a, 0x45, 0xdf, 0xa3].every((v, i) => bytes[i] === v))
      throw new Error("Invalid WebM header.");
  } else throw new Error("Use UTF-8 text, PDF, WAV or WebM.");
  // Preliminary type identification only. Structural validation and malware
  // scanning happen in the isolated worker; this function never admits a file.
}
