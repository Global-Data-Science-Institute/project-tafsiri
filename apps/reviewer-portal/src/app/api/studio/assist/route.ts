import { readLimited, studioContext, studioError } from "@/lib/studio/server";
import { createAdminSupabase } from "@/lib/supabase/admin";
import { runAssistant } from "@/lib/studio/assistant";
export async function POST(request: Request) {
  try {
    const { sb } = await studioContext(request);
    const raw = new TextDecoder("utf-8", { fatal: true }).decode(
      await readLimited(request, 2000),
    );
    const body = JSON.parse(raw);
    if (!["mock", "openai"].includes(body.provider))
      throw new Error("STUDIO_PROVIDER");
    if (
      body.provider === "openai" &&
      process.env.STUDIO_EXTERNAL_AI_ENABLED !== "true"
    )
      throw new Error("STUDIO_PROVIDER");
    const admin = createAdminSupabase(); // Only completion RPC; no contributor-controlled admin query.
    const { data: run, error } = await sb.rpc("studio_command", {
      operation: "assist_begin",
      payload: {
        id: body.id,
        provider: body.provider,
        workflow: body.workflow,
      },
      request_id: body.request_id,
    });
    if (error) throw new Error(error.message);
    if (run.replayed)
      return Response.json(run, { headers: { "Cache-Control": "no-store" } });
    const start = Date.now();
    let output,
      model =
        body.provider === "mock"
          ? "deterministic-studio-1"
          : (process.env.STUDIO_OPENAI_MODEL ?? "unconfigured"),
      failed = false;
    try {
      const result = await runAssistant(body.provider, run, {
        key: process.env.OPENAI_API_KEY,
        model: process.env.STUDIO_OPENAI_MODEL,
        externalEnabled: process.env.STUDIO_EXTERNAL_AI_ENABLED === "true",
      });
      output = result.output;
      model = result.model;
    } catch {
      output = {
        error:
          "Assistance unavailable. Original material is unchanged; request human input.",
      };
      failed = true;
    }
    const { data, error: finishError } = await admin.rpc("studio_ai_finish", {
      run_id: run.id,
      output,
      model_name: model,
      duration_ms: Date.now() - start,
      failed,
    });
    if (finishError) throw new Error(finishError.message);
    return Response.json(data, {
      status: failed ? 422 : 200,
      headers: { "Cache-Control": "no-store" },
    });
  } catch (error) {
    return studioError(error);
  }
}
