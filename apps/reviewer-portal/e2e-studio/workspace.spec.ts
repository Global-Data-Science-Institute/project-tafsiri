import { test, expect, type Page } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import AxeBuilder from "@axe-core/playwright";
const origin = "http://127.0.0.1:3014";
const password = "Synthetic-Only-Studio-2026!";
const suffix = randomUUID().slice(0, 8);
const accounts: Record<string, { email: string; id: string }> = {};
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
async function login(page: Page, who: string) {
  await page.goto("/studio");
  await page.getByLabel("Email", { exact: true }).fill(accounts[who].email);
  await page.getByLabel("Password", { exact: true }).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByRole("button", { name: "Sign out" })).toBeVisible();
}
async function cmd(
  page: Page,
  operation: string,
  payload: Record<string, unknown>,
  request_id = randomUUID(),
  expected = 200,
) {
  const response = await page.request.post("/api/studio", {
    headers: { Origin: origin },
    data: { operation, payload, request_id },
  });
  const result = await response.json();
  expect(response.status(), JSON.stringify(result)).toBe(expected);
  return result;
}
async function state(page: Page) {
  const r = await page.request.get("/api/studio");
  expect(r.ok()).toBeTruthy();
  return r.json();
}
function section(page: Page, heading: string) {
  return page
    .locator("section")
    .filter({ has: page.getByRole("heading", { name: heading, exact: true }) })
    .first();
}
test.beforeAll(async () => {
  if (process.env.NEXT_PUBLIC_SUPABASE_URL !== "http://127.0.0.1:55621")
    throw new Error("Local synthetic fixtures only");
  const admin = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SECRET_KEY!,
  );
  for (const who of ["gdsi", "a", "b", "contributor"]) {
    const email = `${who}-${suffix}@synthetic.example`;
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    if (error) throw error;
    accounts[who] = { email, id: data.user.id };
  }
  sql(
    `INSERT INTO data_studio.platform_admins VALUES('${accounts.gdsi.id}',now()+interval '1 day');`,
  );
});
test("two institutions: onboarding, collection, isolated uploads, AI, triage and revocable collaboration", async ({
  browser,
}) => {
  const contexts = await Promise.all([
    browser.newContext(),
    browser.newContext(),
    browser.newContext(),
    browser.newContext(),
  ]);
  const [g, a, b, contributor] = await Promise.all(
    contexts.map((c) => c.newPage()),
  );
  await login(g, "gdsi");
  await login(a, "a");
  await login(b, "b");
  await login(contributor, "contributor");
  await g.getByRole("button", { name: "GDSI oversight", exact: true }).click();
  const onboard = section(g, "Invite a partner institution");
  await onboard
    .getByLabel("Institution name")
    .fill(`SYNTHETIC University A ${suffix}`);
  await onboard
    .getByLabel("Institution administrator email")
    .fill(accounts.a.email);
  await onboard
    .getByRole("button", { name: "Create partner invitation" })
    .click();
  const link = g.getByLabel("Invitation link");
  await expect(link).toHaveValue(/invite=/);
  const invitationA = new URL(await link.inputValue()).searchParams.get(
    "invite",
  )!;
  await a.getByLabel("Invitation token").fill(invitationA);
  await a.getByRole("button", { name: "Join workspace" }).click();
  await expect(
    a.getByRole("combobox", { name: "Organization", exact: true }),
  ).toContainText("University A");
  const onboardB = await cmd(g, "onboard", {
    name: `SYNTHETIC University B ${suffix}`,
    email: accounts.b.email,
  });
  await cmd(
    a,
    "accept_invitation",
    { token: onboardB.token },
    randomUUID(),
    403,
  ); // Email-bound invitation.
  await cmd(b, "accept_invitation", { token: onboardB.token });
  const orgA = (await state(a)).organizations[0].id,
    orgB = (await state(b)).organizations[0].id;
  await a.getByRole("button", { name: "administration", exact: true }).click();
  const proposal = section(a, "Propose a language");
  await proposal
    .getByLabel("Community language name")
    .fill(`SYNTHETIC New Language ${suffix}`);
  await proposal
    .getByLabel("Scope and community context")
    .fill("SYNTHETIC community; no existing corpus");
  await proposal
    .getByRole("button", { name: "Submit language proposal" })
    .click();
  await a.getByRole("button", { name: "Allow collection planning" }).click();
  const newProposal = (await state(a)).proposals[0];
  expect(
    sql(
      `SELECT count(*) FROM public.languages WHERE name='SYNTHETIC New Language ${suffix}'`,
    ),
  ).toBe("0");
  const projectForm = section(a, "Create research project");
  await projectForm
    .getByLabel("Project title")
    .fill("SYNTHETIC collection project");
  await projectForm
    .getByLabel("Language or variety")
    .selectOption(`proposal:${newProposal.id}`);
  await projectForm
    .getByRole("button", { name: "Create project", exact: true })
    .click();
  await expect(section(a, "Create collection campaign")).toBeVisible();
  const projectA = (await state(a)).projects[0].id;
  // Both independent universities also select one shared existing identity; no duplicate registry.
  const sharedLanguage = randomUUID();
  sql(
    `INSERT INTO public.languages(id,name) VALUES('${sharedLanguage}','SYNTHETIC Shared Language ${suffix}')`,
  );
  const sharedProjectA = await cmd(a, "create_project", {
    org_id: orgA,
    title: "SYNTHETIC Shared Scope A",
    language_id: sharedLanguage,
  });
  const projectB = (
    await cmd(b, "create_project", {
      org_id: orgB,
      title: "SYNTHETIC Shared Scope B",
      language_id: sharedLanguage,
    })
  ).id;
  const campaignForm = section(a, "Create collection campaign");
  await campaignForm
    .getByLabel("Campaign title")
    .fill("SYNTHETIC vocabulary campaign");
  await campaignForm
    .getByLabel("Additional questions, one per line")
    .fill("Usage setting");
  await campaignForm
    .getByRole("button", { name: "Create campaign", exact: true })
    .click();
  await expect.poll(async () => (await state(a)).campaigns.length).toBe(1);
  const campaignA = (await state(a)).campaigns[0].id;
  const campaignB = (
    await cmd(b, "create_campaign", {
      project_id: projectB,
      title: "SYNTHETIC B campaign",
      category: "WORD",
      template: [],
      target_count: 10,
    })
  ).id;
  const consent = {
    internal_research: true,
    human_review: true,
    training: false,
    public_display: false,
    redistribution: false,
    commercial: false,
    external_ai: false,
  };
  const content = {
    text: "SYNTHETIC PRIVATE B",
    source: "synthetic fixture",
    method: "synthetic typing",
  };
  await cmd(b, "save", { campaign_id: campaignB, content, consent });
  const sharedCampaignA = await cmd(a, "create_campaign", {
    project_id: sharedProjectA.id,
    title: "SYNTHETIC A shared scope campaign",
    category: "WORD",
    template: [],
    target_count: 10,
  });
  const sharedPrivateA = await cmd(a, "save", {
    campaign_id: sharedCampaignA.id,
    content: { ...content, text: "SYNTHETIC PRIVATE A SAME LANGUAGE" },
    consent,
  });
  expect(
    (await state(b)).contributions.some(
      (c: { id: string }) => c.id === sharedPrivateA.id,
    ),
  ).toBeFalsy();
  const invitation = await cmd(a, "invite", {
    project_id: projectA,
    email: accounts.contributor.email,
    role: "contributor",
  });
  await cmd(contributor, "accept_invitation", { token: invitation.token });
  const contributorProposal = await cmd(contributor, "propose_language", {
    org_id: orgA,
    name: "SYNTHETIC contributor proposal",
    description: "Synthetic community scope for human assessment",
  });
  expect(
    (await state(contributor)).proposals.some(
      (p: { id: string }) => p.id === contributorProposal.id,
    ),
  ).toBe(true);
  await cmd(
    contributor,
    "propose_language",
    {
      org_id: orgB,
      name: "SYNTHETIC unauthorized proposal",
      description: "Denied",
    },
    randomUUID(),
    403,
  );
  await contributor.reload();
  await contributor
    .getByRole("button", { name: "collect", exact: true })
    .click();
  const form = section(contributor, "New contribution");
  await form
    .getByLabel("Original text or recording description")
    .fill("SYNTHETIC α é original");
  await form.getByLabel("Source and provenance").fill("SYNTHETIC source");
  await form.getByLabel("Collection method").fill("Synthetic fixture typing");
  await form
    .getByLabel("Usage setting (required to submit)")
    .fill("SYNTHETIC setting");
  await form.getByLabel("Internal research", { exact: true }).check();
  await form.getByLabel("Human review", { exact: true }).check();
  await form.getByRole("button", { name: "Save draft" }).click();
  await expect(
    contributor.getByRole("heading", { name: "Resume contribution" }),
  ).toBeVisible();
  let item = (await state(contributor)).contributions[0];
  expect(item.owner_id).toBe(accounts.contributor.id);
  expect(item.content.text).toBe("SYNTHETIC α é original");
  const card = contributor.getByTestId(`contribution-${item.id}`);
  await card.getByLabel("Upload original file").setInputFiles({
    name: "synthetic.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("SYNTHETIC original document α"),
  });
  await card
    .getByRole("button", { name: "Upload to private quarantine" })
    .click();
  await expect(card.getByText(/PENDING/)).toBeVisible();
  const pendingUpload = (await state(contributor)).uploads[0];
  expect(
    (
      await contributor.request.get(`/api/studio/upload?id=${pendingUpload.id}`)
    ).status(),
  ).toBe(403);
  execFileSync(
    process.execPath,
    ["scripts/studio-worker.mjs", "scan", "--local"],
    { stdio: "pipe" },
  );
  await contributor.reload();
  await contributor
    .getByRole("button", { name: "intake", exact: true })
    .click();
  await expect(
    card.getByRole("link", { name: "Download original" }),
  ).toBeVisible();
  const upload = (await state(contributor)).uploads[0];
  expect(
    (await contributor.request.get(`/api/studio/upload?id=${upload.id}`)).ok(),
  ).toBeTruthy();
  expect(
    (await b.request.get(`/api/studio/upload?id=${upload.id}`)).status(),
  ).toBe(403);
  expect(
    (await g.request.get(`/api/studio/upload?id=${upload.id}`)).status(),
  ).toBe(403);
  const invalidFile = await contributor.request.post("/api/studio/upload", {
    headers: { Origin: origin },
    multipart: {
      id: item.id,
      request_id: randomUUID(),
      file: {
        name: "bad.pdf",
        mimeType: "application/pdf",
        buffer: Buffer.from("NOT A PDF"),
      },
    },
  });
  expect(invalidFile.status()).toBe(403);
  const wav = Buffer.alloc(44);
  wav.write("RIFF");
  wav.writeUInt32LE(36, 4);
  wav.write("WAVE", 8);
  const uploadRequest = randomUUID();
  const audioUpload = () =>
    contributor.request.post("/api/studio/upload", {
      headers: { Origin: origin },
      multipart: {
        id: item.id,
        request_id: uploadRequest,
        file: { name: "synthetic.wav", mimeType: "audio/wav", buffer: wav },
      },
    });
  const firstAudio = await audioUpload();
  expect(firstAudio.ok()).toBeTruthy();
  const repeatedAudio = await audioUpload();
  expect(repeatedAudio.ok()).toBeTruthy();
  expect((await repeatedAudio.json()).id).toBe((await firstAudio.json()).id);
  await card.getByText("AI research assistance", { exact: true }).click();
  await card.getByRole("button", { name: "Request assistance" }).click();
  await expect(card.getByText("MACHINE_GENERATED · UNVERIFIED")).toBeVisible();
  expect((await state(contributor)).contributions[0].content.text).toBe(
    item.content.text,
  );
  expect(
    (
      await contributor.request.post("/api/studio/assist", {
        headers: { Origin: origin },
        data: {
          id: item.id,
          provider: "unsupported",
          workflow: "quality",
          request_id: randomUUID(),
        },
      })
    ).status(),
  ).toBe(403);
  expect(
    (
      await contributor.request.post("/api/studio/assist", {
        headers: { Origin: origin },
        data: {
          id: item.id,
          provider: "openai",
          workflow: "quality",
          request_id: randomUUID(),
        },
      })
    ).status(),
  ).toBe(403);
  await card.getByRole("button", { name: "Submit for intake" }).click();
  await expect(card.getByText("SUBMITTED", { exact: true })).toBeVisible();
  item = (await state(contributor)).contributions[0];
  await cmd(
    b,
    "withdraw",
    { id: item.id, revision: item.revision },
    randomUUID(),
    403,
  );
  await cmd(g, "prepare_handoff", { id: item.id }, randomUUID(), 403);
  expect((await state(g)).contributions).toEqual([]);
  expect(
    (await state(b)).contributions.every(
      (c: { id: string }) => c.id !== item.id,
    ),
  ).toBeTruthy();
  await a.reload();
  await a.getByRole("button", { name: "intake", exact: true }).click();
  const reviewCard = a.getByTestId(`contribution-${item.id}`);
  await reviewCard
    .getByLabel("Correction, withdrawal or intake decision reason")
    .fill("SYNTHETIC administrative review, not linguistic verification");
  await reviewCard.getByRole("button", { name: "Mark triaged" }).click();
  await reviewCard
    .getByRole("button", { name: "Accept for research intake" })
    .click();
  await reviewCard
    .getByRole("button", { name: "Prepare governed handoff" })
    .click();
  await expect(reviewCard.getByText(/PREPARED_BLOCKED/)).toBeVisible();
  const handoff = (await state(a)).handoffs[0];
  expect(handoff.packet.training_approved).toBe(false);
  expect(handoff.packet.canonical_approved).toBe(false);
  expect(handoff.packet.reviewer_handoff).toBe(
    "BLOCKED_PENDING_AUTHORIZED_INTEGRATION",
  );
  expect(sql("SELECT count(*) FROM public.lexemes")).toBe("0");
  expect(sql("SELECT count(*) FROM public.source_entries")).toBe("0");
  // Explicit cross-institution collaboration is revocable and does not share other projects.
  const sharedInvite = await cmd(a, "invite", {
    project_id: projectA,
    email: accounts.b.email,
    role: "researcher",
  });
  await cmd(b, "accept_invitation", { token: sharedInvite.token });
  expect(
    (await state(b)).contributions.some(
      (c: { id: string }) => c.id === item.id,
    ),
  ).toBeTruthy();
  await cmd(a, "revoke_member", { project_id: projectA, id: accounts.b.id });
  expect(
    (await state(b)).contributions.some(
      (c: { id: string }) => c.id === item.id,
    ),
  ).toBeFalsy();
  item = (await state(contributor)).contributions[0];
  await cmd(contributor, "correction", {
    id: item.id,
    reason: "SYNTHETIC correction requested",
  });
  await contributor.reload();
  await contributor
    .getByRole("button", { name: "intake", exact: true })
    .click();
  await expect(
    contributor.getByText("SYNTHETIC correction requested", { exact: false }),
  ).toBeVisible();
  await cmd(contributor, "withdraw", {
    id: item.id,
    revision: item.revision,
    reason: "SYNTHETIC withdrawal",
  });
  expect(
    (
      await contributor.request.get(`/api/studio/upload?id=${upload.id}`)
    ).status(),
  ).toBe(403);
  expect((await state(a)).handoffs[0].state).toBe("WITHDRAWN");
  // Retry integrity and forged identities: the authenticated actor always owns the new draft.
  const requestId = randomUUID(),
    body = {
      campaign_id: campaignA,
      content: { ...content, text: "SYNTHETIC retry" },
      consent,
      owner_id: accounts.b.id,
    };
  const saved = await cmd(contributor, "save", body, requestId);
  const retry = await cmd(contributor, "save", body, requestId);
  expect(retry.replayed).toBe(true);
  expect(saved.owner_id).toBe(accounts.contributor.id);
  await cmd(contributor, "save", { ...body, content }, requestId, 409);
  await cmd(
    contributor,
    "submit",
    { id: saved.id, revision: 999 },
    randomUUID(),
    409,
  );
  await cmd(
    contributor,
    "create_project",
    { org_id: orgA, title: "forged", language_id: sharedLanguage },
    randomUUID(),
    403,
  );
  await cmd(
    a,
    "create_project",
    { org_id: orgA, title: "missing scope" },
    randomUUID(),
    403,
  );
  // CSRF and direct PostgREST/Storage bypass checks use the same real Auth token.
  expect(
    (
      await contributor.request.post("/api/studio", {
        headers: { Origin: "https://untrusted.example" },
        data: {
          operation: "withdraw",
          payload: { id: saved.id, revision: 1 },
          request_id: randomUUID(),
        },
      })
    ).status(),
  ).toBe(403);
  const direct = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
  await direct.auth.signInWithPassword({ email: accounts.b.email, password });
  expect(
    (
      await direct.rpc("studio_command", {
        operation: "prepare_handoff",
        payload: { id: saved.id },
        request_id: randomUUID(),
      })
    ).error,
  ).toBeTruthy();
  expect(
    (
      await direct.storage
        .from("studio-quarantine")
        .download(upload.object_path)
    ).error,
  ).toBeTruthy();
  expect(
    (
      await direct.rpc("studio_ai_finish", {
        run_id: (await state(a)).ai_runs[0].id,
        output: { verified: true },
        model_name: "forged",
        duration_ms: 1,
      })
    ).error,
  ).toBeTruthy();
  const ownClient = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
  await ownClient.auth.signInWithPassword({
    email: accounts.contributor.email,
    password,
  });
  await cmd(a, "project_settings", { project_id: projectA, external_ai: true });
  expect(
    (
      await ownClient.rpc("studio_command", {
        operation: "assist_begin",
        payload: { id: saved.id, provider: "openai", workflow: "quality" },
        request_id: randomUUID(),
      })
    ).error?.message,
  ).toContain("STUDIO_CONSENT");
  const permitted = await cmd(contributor, "save", {
    ...body,
    id: saved.id,
    revision: 1,
    consent: { ...consent, external_ai: true },
  });
  const authorized = await ownClient.rpc("studio_command", {
    operation: "assist_begin",
    payload: { id: permitted.id, provider: "openai", workflow: "quality" },
    request_id: randomUUID(),
  });
  expect(authorized.error).toBeNull();
  await cmd(a, "project_settings", {
    project_id: projectA,
    external_ai: false,
  });
  const service = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SECRET_KEY!,
  );
  const cancelled = await service.rpc("studio_ai_finish", {
    run_id: authorized.data.id,
    output: { observations: [] },
    model_name: "synthetic-no-network",
    duration_ms: 0,
  });
  expect(cancelled.data.state).toBe("CANCELLED");
  let limitReached = false;
  for (let i = 0; i < 22; i++) {
    const result = await ownClient.rpc("studio_command", {
      operation: "assist_begin",
      payload: { id: saved.id, provider: "mock", workflow: "quality" },
      request_id: randomUUID(),
    });
    if (result.error) {
      expect(result.error.message).toContain("STUDIO_LIMIT");
      limitReached = true;
      break;
    }
  }
  expect(limitReached).toBeTruthy();
  const noConsent = await cmd(contributor, "save", {
    campaign_id: campaignA,
    content: { ...content, question_1: "SYNTHETIC" },
    consent: { ...consent, human_review: false },
  });
  await cmd(
    contributor,
    "submit",
    { id: noConsent.id, revision: 1 },
    randomUUID(),
    403,
  );
  const expiredInvite = await cmd(a, "invite", {
    project_id: projectA,
    email: accounts.b.email,
    role: "contributor",
  });
  sql(
    `UPDATE data_studio.invitations SET expires_at=now()-interval '1 second' WHERE id='${expiredInvite.id}'`,
  );
  await cmd(
    b,
    "accept_invitation",
    { token: expiredInvite.token },
    randomUUID(),
    403,
  );
  expect(
    sql(
      `SELECT snapshot->'contribution'->'content'->>'text' FROM data_studio.events WHERE contribution_id='${item.id}' AND action='submit'`,
    ),
  ).toBe("SYNTHETIC α é original");
  expect(
    sql(
      "SELECT bool_and(relrowsecurity) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='data_studio' AND c.relkind='r'",
    ),
  ).toBe("t");
  expect(
    sql(
      "SELECT count(*) FROM information_schema.role_table_grants WHERE table_schema='data_studio' AND grantee IN ('anon','authenticated','service_role','PUBLIC')",
    ),
  ).toBe("0");
  expect(
    sql(
      "SELECT count(*) FROM data_studio.requests WHERE body->'payload' ? 'token' OR result ? 'token'",
    ),
  ).toBe("0");
  await a.setViewportSize({ width: 390, height: 844 });
  await a.getByRole("button", { name: "overview", exact: true }).click();
  expect(
    await a.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
  ).toBeTruthy();
  const accessibility = await new AxeBuilder({ page: a }).analyze();
  expect(
    accessibility.violations.filter((v) =>
      ["critical", "serious"].includes(v.impact ?? ""),
    ),
  ).toEqual([]);
  for (const context of contexts) await context.close();
});
