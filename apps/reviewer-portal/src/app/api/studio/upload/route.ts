import { createHash } from "node:crypto";
import { readLimited, studioContext, studioError } from "@/lib/studio/server";
import { MAX_UPLOAD, validateUpload } from "@/lib/studio/files";
export async function POST(request: Request) {
  try {
    const { sb } = await studioContext(request);
    const body = await readLimited(request, MAX_UPLOAD + 20000);
    const form = await new Response(body, {
      headers: { "Content-Type": request.headers.get("content-type") ?? "" },
    }).formData();
    const file = form.get("file");
    if (!(file instanceof File) || file.size > MAX_UPLOAD)
      throw new Error("STUDIO_INVALID");
    const bytes = new Uint8Array(await file.arrayBuffer());
    validateUpload(bytes, file.type);
    const digest = createHash("sha256").update(bytes).digest("hex");
    const { data, error } = await sb.rpc("studio_command", {
      operation: "upload_intent",
      request_id: form.get("request_id"),
      payload: {
        id: form.get("id"),
        mime: file.type,
        size_bytes: bytes.length,
        sha256: digest,
      },
    });
    if (error) throw new Error(error.message);
    let upload = data;
    if (data.replayed) {
      const { data: current, error: stateError } = await sb.rpc("studio_state");
      upload = current?.uploads.find((x: { id: string }) => x.id === data.id);
      if (stateError || !upload || upload.sha256 !== digest)
        throw new Error("STUDIO_DENIED");
    }
    const { error: uploadError } = await sb.storage
      .from("studio-quarantine")
      .upload(upload.object_path, bytes, {
        contentType: file.type,
        upsert: false,
      });
    if (uploadError) {
      // A retry may find the original object. Confirm integrity rather than overwriting it.
      const existing = await sb.storage
        .from("studio-quarantine")
        .download(upload.object_path);
      if (
        existing.error ||
        !existing.data ||
        createHash("sha256")
          .update(new Uint8Array(await existing.data.arrayBuffer()))
          .digest("hex") !== digest
      )
        throw new Error("STUDIO_UPLOAD_FAILED");
    }
    return Response.json(
      { id: upload.id, state: "QUARANTINED" },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch (error) {
    return studioError(error);
  }
}
export async function GET(request: Request) {
  try {
    const { sb } = await studioContext();
    const { data, error } = await sb.rpc("studio_state");
    if (error) throw new Error(error.message);
    const id = new URL(request.url).searchParams.get("id");
    const upload = data.uploads.find((u: { id: string }) => u.id === id);
    if (!upload) throw new Error("STUDIO_DENIED");
    const { data: blob, error: readError } = await sb.storage
      .from("studio-quarantine")
      .download(upload.object_path);
    if (readError || !blob) throw new Error("STUDIO_DENIED");
    return new Response(blob, {
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Disposition":
          'attachment; filename="quarantined-contribution"',
        "X-Content-Type-Options": "nosniff",
        "Cache-Control": "no-store",
      },
    });
  } catch (error) {
    return studioError(error);
  }
}
