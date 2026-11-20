import { readLimited, studioContext, studioError } from "@/lib/studio/server";
export async function GET() {
  try {
    const { sb } = await studioContext();
    const { data, error } = await sb.rpc("studio_state");
    if (error) throw new Error(error.message);
    return Response.json(data, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    return studioError(error);
  }
}
export async function POST(request: Request) {
  try {
    const { sb } = await studioContext(request);
    const raw = new TextDecoder("utf-8", { fatal: true }).decode(
      await readLimited(request, 65000),
    );
    if (raw.length > 65000) throw new Error("STUDIO_INVALID");
    const body = JSON.parse(raw);
    if (body.operation === "assist_begin") throw new Error("STUDIO_OPERATION");
    const { data, error } = await sb.rpc("studio_command", {
      operation: body.operation,
      payload: body.payload,
      request_id: body.request_id,
    });
    if (error) throw new Error(error.message);
    return Response.json(data, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    return studioError(error);
  }
}
