export function assertStudioEnvironment(
  env: Record<string, string | undefined> = process.env,
) {
  if (env.DATA_STUDIO_ENABLED !== "synthetic")
    throw new Error("STUDIO_DISABLED");
  const url = env.NEXT_PUBLIC_SUPABASE_URL;
  if (url === "http://127.0.0.1:55621" && !env.VERCEL) return;
  const ref = env.STUDIO_APPROVED_PROJECT_REF;
  if (
    !ref ||
    ["gfhdwmqefotkljrltfnx", "ydkookidvipqrwuilqeu"].includes(ref) ||
    url !== `https://${ref}.supabase.co` ||
    env.STUDIO_ENVIRONMENT !== "synthetic-staging" ||
    env.VERCEL_ENV === "preview"
  )
    throw new Error("STUDIO_ENVIRONMENT");
}
