# Partner Release Candidate 001: validation and decision

Date: 2026-11-22. Outcome: **BLOCKED — SECURITY OR OPERATIONAL READINESS**. The implementation is available for code and controlled-staging-plan review; this is not authorization to deploy or use authentic institutional data.

Baseline: [PR #28](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/28), commit `83f0b3312bedeeafcf3a5bac18b5aa62455a80a0`, branch `feature/tafsiri-data-studio`. Its Studio, portal, research and database CI jobs passed. The reviewed open stack includes PRs #22–#28: #22/#23 target staging, #24–#28 build on the preceding architecture work. This RC uses branch `feature/tafsiri-partner-rc-001` and targets #28's branch. No existing PR was merged. Canonical review CSVs, evidence artifacts and research datasets were not changed.

## Implemented changes

Migration `20261122072133_partner_release_candidate_001.sql` extends the inspected private Studio schema. It adds scan receipts/leases, retention requests/holds, invitation delivery receipts and active-session checks. All 17 private Studio tables have RLS and deny direct table access to anon, authenticated and service roles. Guarded public entrypoints delegate to private baseline implementations; only the service role can complete scans, deletion, email delivery or AI runs. A revoked Auth session cannot continue with a cached JWT. AI completion also checks the initiating session. Worker leases and session IDs are withheld from workspace state.

Attachments require scan admission before reads; workers recheck the original hash and size. Error/timeout/missing signatures fail closed, expired leases are retryable, and withdrawn content is inaccessible. ClamAV is integrated through an absolute binary path with constrained process arguments; the deterministic local mock is explicitly labeled MOCK_CLEAN. No extraction, transcription, source registration or canonical promotion is added. Retention requires contributor request after withdrawal, PI approval, seven-day synthetic delay and no hold. Storage deletion must complete before private content copies are scrubbed. Hash and rights receipts remain.

Invitations support configurable mock/Resend delivery, explicit resend/token rotation, delivery receipts and quotas, email-bound acceptance, expiry, replay protection and revocation. Provider idempotency uses the delivery UUID. No live email provider was provisioned or contacted. Existing account recovery is linked from Studio; membership removal survives identity recovery. Last-organization-admin removal is blocked. UI labels distinguish original contributor material, awaiting human review, accepted intake and machine-generated unverified suggestions.

External AI remains disabled by default. OpenAI structured-response handling was exercised with injected synthetic transports, including throttling, refusal, incomplete/malformed output and transport failure. This is adapter-contract validation, not a live model/provider certification. Project permission and applicable contribution consent are tested at the real database/API boundary. `store:false` is not a retention agreement. No model training occurred.

The synthetic staging template, runtime environment guard, worker guard, metadata-only error logs, local database/Storage recovery scripts, [onboarding guide](partner-onboarding-guide-001.md) and [deployment runbook](../operations/partner-release-runbook-001.md) complete the reviewable operational package. Branch deployment is disabled. The environment guard refuses existing staging/production project refs and ordinary Vercel previews.

## Independent boundary validation

The new `e2e-studio/partner-release.spec.ts` drives real local Auth, Data API, Storage, application routes and database functions rather than mocking authorization. It is independent of UI-only permission checks; it was authored and run by the implementing agent, **not an independent human security audit**. A second reviewer must accept the evidence before deployment.

| Boundary | Executed evidence |
|---|---|
| Tenancy and roles | Existing two-institution journey shares registry identity while denying cross-institution and contributor access; separate RC user has empty private state and cannot directly query the private schema; editable user metadata does not grant authority |
| Session and CSRF | Real Auth global sign-out followed by reuse of the old JWT denies state, mutation and private file access; wrong Origin rejected; recovery does not recreate revoked membership |
| Invitations | Mock route delivery, same-request replay, old-token rejection after rotation, wrong-email rejection, one-time acceptance, unauthorized delivery and last-admin removal denied; baseline covers expiry/revocation |
| File admission | Direct Storage uploads remain unreadable pending scan; clean mock admitted, EICAR marker quarantined, wrong hash ERROR; ordinary clients cannot forge worker receipts or delete objects; GDSI cannot download institution files |
| Retention | Contributor cannot approve, hold blocks approval, pre-seven-day claim returns no work, finish refuses remaining Storage objects, stale lease rejected; final purge removes Storage and content from contribution/AI/idempotency copies |
| AI | Baseline project/consent/revision/revocation checks plus provider failure contracts; originals stay separate; no source/lexeme ingestion |
| Legacy paths | Positive control anonymously inserts and reads a SYNTHETIC_PUBLIC marker through `public.submissions`; anon and unrelated user query 23 named legacy tables/views without receiving the private Studio marker |
| Usability | Desktop 1440px and mobile 390px administration views have no horizontal overflow and no serious/critical Axe findings; baseline journey covers collection, triage and collaboration with accessibility assertions |

The legacy test queries up to 100 rows per relation in a small synthetic database. It proves the tested fixture paths, not exhaustive hosted reachability or every privileged export. The earlier 16 non-RLS legacy tables, six definer views, permissive submissions policies and broad service capabilities remain documented exposure risks. Public submissions was demonstrated as an actual unsafe HTTP path, not dismissed as historical. Studio does not copy private content into those relations; handoff remains PREPARED_BLOCKED. **Deployment into existing shared staging/production is blocked** until legacy consumer contracts and remediation or stronger isolation are independently accepted.

## Executed regression evidence

Local isolated stack: `tafsiri-studio-synthetic`, API 55621, database 55622. Original local stack and hosted data were not modified. Clean reset replayed every migration including the RC migration before running Reviewer Portal tests.

- Python research suite: **189 passed**.
- Frontend unit suite: **50 passed**, including environment, email, scanner and AI failure contracts.
- Studio browser suite: **2 full scenarios passed** (existing two-institution journey plus RC adversarial test).
- Existing Reviewer Portal browser suite: **8 passed** after clean migration replay.
- Existing database smoke files: **7 passed**; **51 direct private-table denials** across 17 tables and three roles; anonymous/missing identity/forged AI completion denied; bucket private; no automatic canonical/source ingestion.
- SQL lint for public and data_studio: **no schema errors**.
- Type checking, ESLint and production build passed for the implementation; final CI is authoritative for the committed revision.
- Database restore into a newly created disposable local database: passed record counts, content checksum, RLS, grants and private bucket checks. The initial postgres-role restore correctly failed on ownership; the rehearsal uses local supabase_admin to preserve ownership rather than dropping grants.
- Storage restore into a new private local bucket: **6 objects** copied through a local archive, all checksum matches and anonymous reads denied. Source objects unchanged. Scripts are included in CI after Studio acceptance.

CI also runs the existing lexical migration failure/replay/concurrency, atomic Marlo registration, governed promotion, multilingual foundation and full database lint suites. The draft PR checks must be green before review approval; baseline PR #28 success is not a substitute for RC CI.

## Remaining release gates and limitations

1. Actual ClamAV engine/current-signature detection and resource-limit tests have not run. Mock admission and stub exit-code tests are not malware certification. Until the real worker is independently exercised, attachment admission on hosted staging remains blocked.
2. Existing legacy exposure remains. Runtime guards protect against accidental use of known shared refs but are not a replacement for security-owner approval, least-privilege credentials or a full service/export audit. The new synthetic target and exact URL protection have not been provisioned or verified.
3. Hosted database-plus-Storage recovery, tombstone replay, key rotation, alert routing, on-call ownership and RPO/RTO have not been rehearsed. Local restore success establishes a repeatable test, not hosted disaster-recovery readiness.
4. Email delivery/provider credentials, sender verification, bounce handling and hosted Auth recovery are unvalidated. Mock sends nothing; SENT only indicates provider acceptance. No real messages or OpenAI calls were sent.
5. Seven-day retention is a synthetic policy. Institutional consent/rights agreements, retained identity/receipt justification, backup expiry and legal-hold procedures need approval. PURGING does not accept a new hold; operators must stop the worker for escalation.
6. Workspace state loads scoped records without pagination; the baseline serializes commands using a global advisory lock. Files are capped at 5 MB and workers process 25 jobs per invocation. Browser journeys are functional checks, not load/SLO tests. Large institutions, concurrent upload volume, memory pressure and queue latency need measurement before scale claims.
7. Automated Axe/viewport checks do not replace manual keyboard, screen-reader and nontechnical partner usability review. No real participant recruitment or onboarding occurred. Reviewer Portal's existing minor logo/smooth-scroll console warnings remain.

Next decision: review this draft implementation and approve a narrowly scoped, separate synthetic-environment/scanner/operations validation plan. Actual deployment requires separate authorization after the applicable security and operational gates are satisfied. Authentic university data remains blocked regardless of synthetic success.

References used for adapter review: [ClamAV scanning](https://docs.clamav.net/manual/Usage/Scanning.html), [Resend email API](https://resend.com/docs/api-reference/emails/send-email), [Supabase sessions](https://supabase.com/docs/guides/auth/sessions), [OpenAI structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs). See also [legacy security triage](../security/legacy-advisor-triage-001.md).
