import { describe, expect, it } from "vitest";
import { assertStudioEnvironment } from "./environment";
describe("synthetic environment boundary", () => {
  const approved = {
    DATA_STUDIO_ENABLED: "synthetic",
    NEXT_PUBLIC_SUPABASE_URL: "https://synthetic-new-project.supabase.co",
    STUDIO_APPROVED_PROJECT_REF: "synthetic-new-project",
    STUDIO_ENVIRONMENT: "synthetic-staging",
  };
  it("defaults to disabled", () => {
    expect(() => assertStudioEnvironment({})).toThrow("STUDIO_DISABLED");
  });
  it("accepts only the isolated local port without hosted configuration", () => {
    expect(() =>
      assertStudioEnvironment({
        DATA_STUDIO_ENABLED: "synthetic",
        NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:55621",
      }),
    ).not.toThrow();
    expect(() =>
      assertStudioEnvironment({
        DATA_STUDIO_ENABLED: "synthetic",
        NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54621",
      }),
    ).toThrow();
  });
  it("rejects existing research environments even when marked approved", () => {
    for (const ref of ["gfhdwmqefotkljrltfnx", "ydkookidvipqrwuilqeu"])
      expect(() =>
        assertStudioEnvironment({
          ...approved,
          STUDIO_APPROVED_PROJECT_REF: ref,
          NEXT_PUBLIC_SUPABASE_URL: `https://${ref}.supabase.co`,
        }),
      ).toThrow("STUDIO_ENVIRONMENT");
  });
  it("requires matching project and explicit environment and rejects previews", () => {
    expect(() => assertStudioEnvironment(approved)).not.toThrow();
    for (const override of [
      { VERCEL_ENV: "preview" },
      { STUDIO_ENVIRONMENT: "production" },
      { STUDIO_APPROVED_PROJECT_REF: "other" },
      { STUDIO_APPROVED_PROJECT_REF: "" },
    ])
      expect(() =>
        assertStudioEnvironment({ ...approved, ...override }),
      ).toThrow("STUDIO_ENVIRONMENT");
  });
});
