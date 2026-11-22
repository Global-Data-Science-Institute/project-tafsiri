import { test, expect } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { execFileSync } from "node:child_process";
import { randomUUID, createHash } from "node:crypto";
import AxeBuilder from "@axe-core/playwright";
const origin = "http://127.0.0.1:3014";
const password = "Synthetic-RC-Only-2026!";
function sql(statement: string) {
  return execFileSync(
    "docker",
    [
      "exec",
      "-i",
      "supabase_db_tafsiri-studio-synthetic",
      "psql",
      "-XqAt",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-v",
      "ON_ERROR_STOP=1",
    ],
    { input: statement, encoding: "utf8" },
  ).trim();
}
async function command(
  client: SupabaseClient,
  operation: string,
  payload: object,
) {
  const r = await client.rpc("studio_command", {
    operation,
    payload,
    request_id: randomUUID(),
  });
  if (r.error) throw new Error(r.error.message);
  return r.data;
}
test("RC adversarial authorization, invitation delivery, scan admission, retention and session revocation", async ({
  page,
}) => {
  expect(process.env.NEXT_PUBLIC_SUPABASE_URL).toBe("http://127.0.0.1:55621");
  const admin = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SECRET_KEY!,
  );
  const users: Record<
    string,
    { id: string; email: string; client: SupabaseClient }
  > = {};
  for (const role of ["gdsi", "pi", "owner", "other"]) {
    const email = `rc-${role}-${randomUUID()}@synthetic.example`;
    const created = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    expect(created.error).toBeNull();
    const client = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
      { auth: { persistSession: false } },
    );
    expect(
      (await client.auth.signInWithPassword({ email, password })).error,
    ).toBeNull();
    users[role] = { id: created.data.user!.id, email, client };
  }
  const { gdsi, pi, owner, other } = users;
  sql(
    `INSERT INTO data_studio.platform_admins VALUES('${gdsi.id}',now()+interval '1 hour')`,
  );
  const invited = await command(gdsi.client, "onboard", {
    name: "SYNTHETIC RC University",
    email: pi.email,
  });
  await command(pi.client, "accept_invitation", { token: invited.token });
  const org = (await pi.client.rpc("studio_state")).data.organizations[0].id;
  const proposal = await command(pi.client, "propose_language", {
    org_id: org,
    name: "SYNTHETIC RC proposal",
    description: "Synthetic only",
  });
  await command(pi.client, "process_language", {
    org_id: org,
    id: proposal.id,
    status: "COLLECTION_ALLOWED",
  });
  const project = await command(pi.client, "create_project", {
    org_id: org,
    title: "SYNTHETIC RC project",
    proposal_id: proposal.id,
  });
  const campaign = await command(pi.client, "create_campaign", {
    project_id: project.id,
    title: "SYNTHETIC RC campaign",
    category: "DOCUMENT",
    template: [],
    target_count: 10,
  });
  const invite = await command(pi.client, "invite", {
    project_id: project.id,
    email: owner.email,
    role: "contributor",
  });
  await page.goto("/studio");
  await page.getByLabel("Email", { exact: true }).fill(pi.email);
  await page.getByLabel("Password", { exact: true }).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByRole("button", { name: "Sign out" })).toBeVisible();
  const deliveryRequest = randomUUID();
  const send = () =>
    page.request.post("/api/studio/invitations", {
      headers: { Origin: origin },
      data: { id: invite.id, request_id: deliveryRequest },
    });
  const sent = await send();
  expect(sent.ok()).toBeTruthy();
  const receipt = await sent.json();
  expect(receipt.state).toBe("MOCK_SENT");
  expect((await (await send()).json()).replayed).toBe(true);
  expect(
    (
      await owner.client.rpc("studio_command", {
        operation: "accept_invitation",
        payload: { token: invite.token },
        request_id: randomUUID(),
      })
    ).error,
  ).not.toBeNull();
  const currentToken = new URL(receipt.previewLink).searchParams.get("invite");
  expect(
    (
      await other.client.rpc("studio_command", {
        operation: "accept_invitation",
        payload: { token: currentToken },
        request_id: randomUUID(),
      })
    ).error,
  ).not.toBeNull();
  await command(owner.client, "accept_invitation", { token: currentToken });
  expect(
    (
      await owner.client.rpc("studio_command", {
        operation: "accept_invitation",
        payload: { token: currentToken },
        request_id: randomUUID(),
      })
    ).error,
  ).not.toBeNull();
  expect(
    (
      await other.client.rpc("studio_invitation_prepare", {
        invitation_id: invite.id,
        delivery_request: randomUUID(),
        email_provider: "mock",
      })
    ).error,
  ).not.toBeNull();
  expect(
    (
      await pi.client.rpc("studio_command", {
        operation: "revoke_member",
        payload: { org_id: org, id: pi.id },
        request_id: randomUUID(),
      })
    ).error?.message,
  ).toContain("LAST_ADMIN");
  expect(
    (
      await page.request.post("/api/studio/invitations", {
        headers: { Origin: "https://evil.invalid" },
        data: { id: invite.id, request_id: randomUUID() },
      })
    ).status(),
  ).toBe(403);
  const marker = `SYNTHETIC_PRIVATE_${randomUUID().replaceAll("-", "")}`;
  const consent = {
    internal_research: true,
    human_review: true,
    external_ai: false,
    training: false,
    public_display: false,
    redistribution: false,
    commercial: false,
  };
  const item = await command(owner.client, "save", {
    campaign_id: campaign.id,
    content: {
      text: marker,
      source: "Synthetic fixture",
      method: "Synthetic typing",
    },
    consent,
  });
  const uploadIds: string[] = [];
  for (const [text, wrongHash] of [
    ["SYNTHETIC clean file", false],
    ["EICAR-STANDARD-ANTIVIRUS-TEST-FILE", false],
    ["SYNTHETIC substituted bytes", true],
  ] as const) {
    const bytes = Buffer.from(text);
    const sha256 = createHash("sha256")
      .update(wrongHash ? "different" : bytes)
      .digest("hex");
    const upload = await command(owner.client, "upload_intent", {
      id: item.id,
      mime: "text/plain",
      size_bytes: bytes.length,
      sha256,
    });
    uploadIds.push(upload.id);
    expect(
      (
        await owner.client.storage
          .from("studio-quarantine")
          .upload(upload.object_path, bytes, { contentType: "text/plain" })
      ).error,
    ).toBeNull();
    expect(
      (
        await owner.client.storage
          .from("studio-quarantine")
          .download(upload.object_path)
      ).error,
    ).not.toBeNull();
    expect(
      (
        await other.client.storage
          .from("studio-quarantine")
          .download(upload.object_path)
      ).error,
    ).not.toBeNull();
    expect(
      (
        await owner.client.storage
          .from("studio-quarantine")
          .remove([upload.object_path])
      ).data ?? [],
    ).toHaveLength(0);
  }
  for (const rpc of ["studio_scan_claim", "studio_deletion_claim"])
    expect((await owner.client.rpc(rpc)).error).not.toBeNull();
  expect(
    (
      await owner.client.rpc("studio_scan_finish", {
        upload_id: uploadIds[0],
        lease: randomUUID(),
        verdict: "CLEAN",
        provider: "clamav",
        scanner_version: "forged",
        actual_hash: "0".repeat(64),
      })
    ).error,
  ).not.toBeNull();
  execFileSync(
    process.execPath,
    ["scripts/studio-worker.mjs", "scan", "--local"],
    { stdio: "pipe" },
  );
  const scanned = (await owner.client.rpc("studio_state")).data.uploads.filter(
    (x: { contribution_id: string }) => x.contribution_id === item.id,
  );
  expect(
    scanned.map((x: { scan_state: string }) => x.scan_state).sort(),
  ).toEqual(["ERROR", "INFECTED", "MOCK_CLEAN"]);
  const clean = scanned.find(
    (x: { scan_state: string }) => x.scan_state === "MOCK_CLEAN",
  );
  expect(
    (
      await owner.client.storage
        .from("studio-quarantine")
        .download(clean.object_path)
    ).error,
  ).toBeNull();
  expect(
    (
      await gdsi.client.storage
        .from("studio-quarantine")
        .download(clean.object_path)
    ).error,
  ).not.toBeNull();
  expect(
    (
      await admin.rpc("studio_scan_finish", {
        upload_id: clean.id,
        lease: randomUUID(),
        verdict: "CLEAN",
        provider: "clamav",
        scanner_version: "stale",
        actual_hash: clean.sha256,
      })
    ).error,
  ).not.toBeNull();
  // A public legacy path really is open in this fixture; prove it does not expose private Studio material.
  const anonymous = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
  const legacyMarker = `SYNTHETIC_PUBLIC_${randomUUID()}`;
  expect(
    (await anonymous.from("submissions").insert({ luhya_text: legacyMarker }))
      .error,
  ).toBeNull();
  expect(
    (
      await anonymous
        .from("submissions")
        .select("luhya_text")
        .eq("luhya_text", legacyMarker)
    ).data,
  ).toHaveLength(1);
  const legacy = [
    "bible_books",
    "bible_english_verses",
    "bible_luhya_verses",
    "dialect_aliases",
    "knowledge_base_entries",
    "luhya_dict",
    "luhya_dictionary",
    "luhya_kb",
    "luhya_proverbs",
    "pronoun_examples",
    "pronouns",
    "proverb_contributors",
    "proverbs",
    "submission_rate_limits",
    "suspicious_activity",
    "translations",
    "submissions",
    "word_details",
    "cultural_terms",
    "language_words",
    "pronoun_comparison",
    "pronoun_details",
    "dialect_comparisons",
  ];
  for (const client of [anonymous, other.client])
    for (const relation of legacy) {
      const r = await client.from(relation).select("*").limit(100);
      expect(JSON.stringify(r.data)).not.toContain(marker);
    }
  expect(
    (await other.client.rpc("studio_state")).data.contributions,
  ).toHaveLength(0);
  expect(
    (await other.client.schema("data_studio").from("contributions").select("*"))
      .error,
  ).not.toBeNull();
  // Preserve a successful machine suggestion to verify that retention erases it too.
  const run = await command(owner.client, "assist_begin", {
    id: item.id,
    provider: "mock",
    workflow: "quality",
  });
  expect(
    (
      await admin.rpc("studio_ai_finish", {
        run_id: run.id,
        output: { observations: [marker] },
        model_name: "synthetic",
        duration_ms: 1,
        failed: false,
      })
    ).error,
  ).toBeNull();
  await command(owner.client, "withdraw", {
    id: item.id,
    revision: item.revision,
    reason: "Synthetic withdrawal",
  });
  expect(
    (
      await owner.client.storage
        .from("studio-quarantine")
        .download(clean.object_path)
    ).error,
  ).not.toBeNull();
  await command(owner.client, "request_deletion", { id: item.id });
  expect(
    (
      await owner.client.rpc("studio_command", {
        operation: "approve_deletion",
        payload: { id: item.id },
        request_id: randomUUID(),
      })
    ).error,
  ).not.toBeNull();
  await command(pi.client, "retention_hold", {
    id: item.id,
    hold: true,
    reason: "Synthetic review hold",
  });
  expect(
    (
      await pi.client.rpc("studio_command", {
        operation: "approve_deletion",
        payload: { id: item.id },
        request_id: randomUUID(),
      })
    ).error,
  ).not.toBeNull();
  await command(pi.client, "retention_hold", {
    id: item.id,
    hold: false,
    reason: "Synthetic hold released",
  });
  await command(pi.client, "approve_deletion", { id: item.id });
  expect((await admin.rpc("studio_deletion_claim")).data).toBeNull();
  sql(
    `UPDATE data_studio.deletion_requests SET eligible_at=now()-interval '1 second' WHERE contribution_id='${item.id}'`,
  );
  const claim = (await admin.rpc("studio_deletion_claim")).data;
  expect(
    (
      await admin.rpc("studio_deletion_finish", {
        item_id: item.id,
        lease_id: claim.lease,
      })
    ).error?.message,
  ).toContain("STORAGE_REMAINS");
  sql(
    `UPDATE data_studio.deletion_requests SET lease_until=now()-interval '1 second' WHERE contribution_id='${item.id}'`,
  );
  execFileSync(
    process.execPath,
    ["scripts/studio-worker.mjs", "purge", "--local"],
    { stdio: "pipe" },
  );
  const retained = (await owner.client.rpc("studio_state")).data;
  expect(
    retained.deletions.find(
      (d: { contribution_id: string }) => d.contribution_id === item.id,
    ).state,
  ).toBe("PURGED");
  expect(JSON.stringify(retained)).not.toContain(marker);
  expect(
    sql(
      `SELECT count(*) FROM data_studio.requests WHERE body::text LIKE '%${marker}%' OR result::text LIKE '%${marker}%'`,
    ),
  ).toBe("0");
  expect(
    sql(
      `SELECT count(*) FROM storage.objects s JOIN data_studio.uploads u ON u.object_path=s.name WHERE u.contribution_id='${item.id}' AND s.bucket_id='studio-quarantine'`,
    ),
  ).toBe("0");
  expect(
    (
      await admin.rpc("studio_deletion_finish", {
        item_id: item.id,
        lease_id: claim.lease,
      })
    ).error,
  ).not.toBeNull();
  // Keep the JWT after deleting its session: direct Data API must refuse it, not just the web server.
  const session = (await owner.client.auth.getSession()).data.session!;
  const stale = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      global: { headers: { Authorization: `Bearer ${session.access_token}` } },
      auth: { persistSession: false },
    },
  );
  await owner.client.auth.signOut({ scope: "global" });
  expect((await stale.rpc("studio_state")).error?.message).toContain(
    "STUDIO_AUTH",
  );
  expect(
    (
      await stale.rpc("studio_command", {
        operation: "save",
        payload: {
          campaign_id: campaign.id,
          content: { text: marker },
          consent,
        },
        request_id: randomUUID(),
      })
    ).error,
  ).not.toBeNull();
  expect(
    (await stale.storage.from("studio-quarantine").download(clean.object_path))
      .error,
  ).not.toBeNull();
  // Recovery establishes identity but cannot restore a revoked membership or alter roles.
  const recovery = await admin.auth.admin.generateLink({
    type: "recovery",
    email: owner.email,
  });
  expect(recovery.error).toBeNull();
  const recovered = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    { auth: { persistSession: false } },
  );
  expect(
    (
      await recovered.auth.verifyOtp({
        token_hash: recovery.data.properties!.hashed_token,
        type: "recovery",
      })
    ).error,
  ).toBeNull();
  await command(pi.client, "revoke_member", {
    project_id: project.id,
    id: owner.id,
  });
  expect((await recovered.rpc("studio_state")).data.projects).toHaveLength(0);
  expect(
    (
      await recovered.auth.updateUser({
        data: { role: "admin", tafsiri_role: "research_admin" },
      })
    ).error,
  ).toBeNull();
  expect((await recovered.rpc("studio_state")).data.platform_admin).toBe(false);
  await page.reload();
  await page
    .getByRole("button", { name: "administration", exact: true })
    .click();
  for (const width of [390, 1440]) {
    await page.setViewportSize({ width, height: 900 });
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
    expect(
      (await new AxeBuilder({ page }).analyze()).violations.filter((v) =>
        ["critical", "serious"].includes(v.impact ?? ""),
      ),
    ).toEqual([]);
  }
  await page.screenshot({
    path: "../../.studio-local/rc-administration.png",
    fullPage: true,
  });
});
