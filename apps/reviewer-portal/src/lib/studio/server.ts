import "server-only";
import { createServerSupabase } from "@/lib/supabase/server";
export async function readLimited(
  request: Request,
  limit: number,
): Promise<ArrayBuffer> {
  if (Number(request.headers.get("content-length")) > limit)
    throw new Error("STUDIO_TOO_LARGE");
  const reader = request.body?.getReader();
  if (!reader) throw new Error("STUDIO_INVALID");
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      length += part.value.length;
      if (length > limit) {
        await reader.cancel();
        throw new Error("STUDIO_TOO_LARGE");
      }
      chunks.push(part.value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return bytes.buffer;
}
export async function studioContext(request?: Request) {
  if (process.env.DATA_STUDIO_ENABLED !== "synthetic")
    throw new Error("STUDIO_DISABLED");
  const expectedOrigin = process.env.NEXT_PUBLIC_APP_URL;
  if (
    request &&
    request.method !== "GET" &&
    (!expectedOrigin ||
      request.headers.get("origin") !== new URL(expectedOrigin).origin)
  )
    throw new Error("STUDIO_ORIGIN");
  const sb = await createServerSupabase();
  const { data, error } = await sb.auth.getUser();
  if (error || !data.user) throw new Error("STUDIO_AUTH");
  return { sb, user: data.user };
}
export function studioError(error: unknown) {
  const message = error instanceof Error ? error.message : "";
  const code = message.match(/STUDIO_[A-Z_]+/)?.[0] ?? "STUDIO_INVALID";
  const status =
    code === "STUDIO_DISABLED"
      ? 404
      : code === "STUDIO_AUTH"
        ? 401
        : code === "STUDIO_CONFLICT"
          ? 409
          : code === "STUDIO_LIMIT"
            ? 429
            : code === "STUDIO_TOO_LARGE"
              ? 413
              : 403;
  return Response.json(
    {
      error: code,
      message:
        "The request could not be completed. Check access, consent, required fields and the latest revision.",
    },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}
