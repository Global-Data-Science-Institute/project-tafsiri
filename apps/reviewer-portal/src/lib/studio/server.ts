import "server-only";
import { assertStudioEnvironment } from "./environment";
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
  assertStudioEnvironment();
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
  const requestId = crypto.randomUUID();
  console.warn(
    JSON.stringify({ event: "studio_request_rejected", code, requestId }),
  );
  const messages: Record<string, string> = {
    STUDIO_AUTH: "Your session has ended. Sign in again to continue.",
    STUDIO_CONFLICT:
      "This record changed or this request was already completed. Refresh and try again.",
    STUDIO_REQUIRED: "Complete the required fields before submitting.",
    STUDIO_CONSENT:
      "This action needs the contributor's applicable permission and project authorization.",
    STUDIO_LAST_ADMIN:
      "Invite and activate another organization administrator before removing the last administrator.",
    STUDIO_WITHDRAW_FIRST:
      "Withdraw this contribution before requesting retained-data deletion.",
    STUDIO_LIMIT: "The request limit has been reached. Please try again later.",
    STUDIO_ENVIRONMENT:
      "This environment has not been approved for the synthetic release candidate.",
  };
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
      requestId,
      message:
        messages[code] ??
        "The request could not be completed. Check access, consent, required fields and the latest revision.",
    },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}
