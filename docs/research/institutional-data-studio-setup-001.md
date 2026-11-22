# Institutional Data Studio: local operator and acceptance setup

This MVP is restricted to synthetic data. No hosted migration or deployment is authorized. The stopped task left architecture commit `08a5e4f` and an empty CLI-generated migration; the institutional implementation reuses both on `feature/tafsiri-data-studio`, based on PR #27 (`4c3253f`). Migration `20261120032711_data_studio_private_intake.sql` adds the private institutional boundary without altering canonical tables.

## Isolated local environment

Prerequisites: Docker, Node/npm, Python and the repository's installed Supabase CLI. From the repository root:

```powershell
npm ci
python tests/studio/prepare_local.py
.\node_modules\.bin\supabase.cmd start --workdir .studio-local
```

The helper copies versioned migrations and prepares ignored `.studio-local/supabase/config.toml` with project ID `tafsiri-studio-synthetic`, API port 55621, DB port 55622 and isolated Auth/Storage. Existing `project-tafsiri` containers on 54621/54622 are untouched. No remote project is linked. Existing data seeds are disabled. Email authentication is enabled only in this copied synthetic configuration. Never reuse the fixture accounts/password outside this environment.

From `apps/reviewer-portal`:

```powershell
npm ci
node scripts/studio-local.mjs seed
node scripts/studio-local.mjs serve
```

Open `http://127.0.0.1:3014/studio`. The helper obtains local credentials in memory and refuses a different API URL; it does not modify existing environment files. Three synthetic users are available with password `Synthetic-Only-Studio-2026!`:

- `gdsi@studio.synthetic.example`: partner onboarding metadata only.
- `university-a@studio.synthetic.example`: first synthetic institution administrator.
- `university-b@studio.synthetic.example`: second synthetic institution administrator.

Both institutions select the same synthetic registry identity but have separate projects, campaigns and private drafts. GDSI cannot inspect either institution's drafts. No real language vocabulary is included. The seed helper is repeatable and leaves existing fixture drafts unchanged.

## Acceptance walkthrough

Use separate browser profiles/private windows for each account. As GDSI, open **GDSI oversight**, create a new synthetic partner invitation and copy its private link. RC 001 adds configurable mock/Resend invitation delivery; mock is the default and sends nothing. Use the send/resend control to issue a replacement link. Live delivery needs separate authorization. Sign in with the invited verified email, accept the invitation and complete the organization profile. Institution users perform all subsequent work in the UI; they need no database access.

In **Administration**, propose a language with no corpus and allow collection planning. This does not create a registry identity. Create a project using that proposal or a shared existing language/variety. Invite project collaborators with contributor/researcher/PI roles; an invitation to a different institution shares only that project. Create a campaign, choose a category and add optional/required template questions without changing code.

In **Collect**, save/resume a Unicode draft, select independent permitted uses and upload a synthetic text/PDF/WAV/WebM file (5 MB maximum). Run `node scripts/studio-worker.mjs scan --local` to exercise synthetic mock admission before downloads. Browser audio recording is available when MediaRecorder/WebM and microphone permission are supported; uploads remain the fallback. Submit after required metadata and internal research/human-review consent. Use deterministic assistance and observe MACHINE_GENERATED/UNVERIFIED labels and unchanged originals.

Researchers/PIs triage in **Intake**, request clarification, reject or accept for research intake. Acceptance creates no canonical or training approval. Preparing handoff yields PREPARED_BLOCKED: authorized source registration, private export and qualified reviewer task integration are pending. Contributors can request correction or withdraw; withdrawal stops new AI/attachment access and invalidates the prepared handoff. RC 001 adds contributor deletion requests, PI approval/holds, a seven-day synthetic retention delay and an operator-run purge that scrubs content copies after Storage deletion. See the release runbook for retained receipts and backup handling.

## Configuration and optional AI

Application routes require `DATA_STUDIO_ENABLED=synthetic` and the RC environment guard. Local use is restricted to port 55621; hosted use requires a new approved synthetic project and rejects existing staging/production and preview environments. `NEXT_PUBLIC_APP_URL` must match the browser origin, and public Supabase URL/key must point to the intended isolated environment. Authentication requires a verified user and exact memberships. The server's `SUPABASE_SECRET_KEY` is used for AI completion and invitation-delivery completion RPCs; it must never be exposed to clients. Before real use, assess replacing this broad key with a dedicated completion identity and approve key custody.

Mock assistance runs without external network access. OpenAI is implemented but opt-in: `STUDIO_EXTERNAL_AI_ENABLED=true`, server-only `OPENAI_API_KEY`, an explicitly chosen `STUDIO_OPENAI_MODEL`, project external-AI enablement and contribution consent are all required. No model name is assumed, no live call was used for tests, and no key is provisioned. The adapter processes supplied text only; raw document OCR/parsing and audio transcription are deferred. `store:false` does not establish zero retention or data-use permission. Provider-region/retention arrangements must be reviewed before any real material is sent.

## Repeatable validation

From the repository root, run Python regressions and isolated SQL checks:

```powershell
python -m pytest tests -q
python tests/studio/database_checks.py
.\node_modules\.bin\supabase.cmd db lint --local --workdir .studio-local --schema public,data_studio --level error --fail-on error
```

From `apps/reviewer-portal`:

```powershell
npm run typecheck
npm run lint
npm test
npx playwright install chromium
npx playwright test --config playwright.studio.config.ts
npx playwright test --config playwright.studio-reviewer.config.ts
npm run build
```

The Studio browser suite creates fresh synthetic users and verifies real Auth/API/DB/Storage behavior, not mocked persistence. The reviewer regression configuration runs the existing eight browser tests with a guarded local fixture reset. **That reviewer suite resets the isolated Studio database before and after tests**, so run the demo seed again afterward. It never resets the original stack. CI runs the same isolated Studio job alongside existing regression jobs.

To stop only this stack, run `supabase stop --workdir .studio-local` using the installed CLI from the repository root. The default preserves its local backup. Do not use a linked/hosted reset. The branch-specific Vercel configuration disables automatic deployment for `feature/tafsiri-data-studio`; merging and any future deployment remain separate approvals.

## Real-partner gates

Required before onboarding authentic material: independent database/API/storage authorization review; approved organization agreements and data-use/consent text; upload scanning/quarantine admission; retention/deletion and incident procedures; workload/access limits and pagination for scale; credential isolation; production Auth/email/invitation delivery configuration; backup/restore verification; legacy exposure assessment or proven isolation; and explicit environment deployment approval. Optional external AI adds provider, location, retention and rights approval. Signed ingestion/export and qualified review handoff remain independent future integrations. Synthetic success authorizes none of these steps.

RC 001 supersedes the MVP scanning, invitation and retention limitations above. See [validation](partner-release-validation-001.md), [partner onboarding](partner-onboarding-guide-001.md), and [operations/deployment gates](../operations/partner-release-runbook-001.md).
