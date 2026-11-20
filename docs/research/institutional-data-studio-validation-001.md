# Institutional Data Studio — synthetic acceptance evidence

Implementation branch: `feature/tafsiri-data-studio`, based on PR #27 (`4c3253f`). This report concerns the isolated local synthetic environment only. The original local stack and hosted databases were not migrated. No partner material or live external AI request was used.

## Implemented acceptance journeys

The browser suite uses four independent authenticated sessions and real local Supabase Auth, PostgreSQL and private Storage. It creates two synthetic universities with independent administrators and private contributions against one shared language identity. Institution onboarding and invitation acceptance, language proposals without registry creation, project/campaign setup, contributor drafts and resumption, Unicode preservation, configurable questions, text and WAV uploads, mock assistance, submission, triage, acceptance for intake, correction requests and withdrawal are exercised through browser UI and authenticated HTTP calls.

Authorization assertions cover email-bound and expired invitations; missing scope and role escalation; contributor ownership; cross-organization API, direct PostgREST and Storage denial; GDSI metadata-only visibility; explicit cross-institution project sharing and revocation; CSRF rejection; optimistic revision conflicts; idempotent command/upload retries; and invitation tokens absent from stored request payloads/results. A contributor can propose a language within their project's institution but not an unrelated institution.

AI checks cover unsupported providers, the server external-processing switch, project and item consent, current access/revision rechecks on completion, revoked permission cancelling a pending result, forged completion denial, per-actor quota, and unchanged original content. Optional OpenAI request formatting is tested with a stub transport, never the live provider. Suggestions retain MACHINE_GENERATED/UNVERIFIED provenance. Neither intake acceptance nor prepared handoff creates source entries, lexemes, training permission or canonical approval.

The Studio browser journey checks a 390-pixel viewport and zero serious/critical Axe violations on the exercised screen. This is targeted automated accessibility evidence, not a full manual accessibility audit. WAV upload is tested; physical microphone capture and every supported browser/device require independent acceptance testing.

## Executed checks

| Check | Local result |
| --- | --- |
| Python regression suite | 189 passed |
| Frontend unit tests | 36 passed across 9 files |
| TypeScript and ESLint | Passed |
| Existing SQL smoke suites | 7 passed |
| Direct private table reads | 42 denials: 14 tables × anon/authenticated/service_role |
| Anonymous/missing identity, forged AI completion, private bucket | Passed |
| Public and Data Studio schema lint | No errors |
| Studio multi-session browser journey | 1 comprehensive scenario passed, including visible correction history |
| Existing reviewer browser regressions | 8 passed |
| Production compilation | Passed with synthetic local configuration |
| Updated relative documentation links | Passed |

## Reviewer compatibility fixes

The existing reviewer suite exposed insufficient contrast in shared teal links against the paper background; the shared token and footer link were darkened. It also exposed a pre-existing Strict Mode effect replay bug that left autosave showing “Saving” after persistence. The mounted flag is now restored when the effect starts, with a dedicated unit regression. The Stage B browser test now waits for navigation to the next assignment and inspects the assignment actually visited; it previously allowed an early database read and assumed fixture insertion order was review order. Reviewer judgment, blinding and submission authority are unchanged.

The anonymous admin-API regression disables redirect following so it checks the authorization redirect itself rather than the final sign-in page's HTTP 200. Withdrawal assertions use the persisted participation status because the completed action form is removed after revalidation.

## Explicit limits and real-partner blockers

- Handoff is PREPARED_BLOCKED. Source/artifact registration, signed export, qualified reviewer task creation and downstream ingestion require separately authorized integration. Existing provenance and canonical systems are preserved, not duplicated.
- Raw PDF extraction/OCR and audio transcription are deferred. The assistant works on contributor-supplied text; document files remain private quarantine objects. Optional OpenAI is implemented but has no live-provider acceptance result.
- Upload signatures, MIME/size limits and private authorization are implemented. Malware scanning and quarantine admission are not; file metadata is never trusted as evidence certification.
- Invitation links are delivered manually. Production email, verified identity/onboarding operations, credential custody, retention/deletion, incident response, backup/restore and capacity/pagination require acceptance. Global write serialization is deliberately bounded to this synthetic MVP.
- Organization and explicit project memberships are independent grants. Revoking one does not revoke another; administrators must revoke all applicable grants to remove all access. GDSI oversight does not grant access to private project content.
- Legacy security findings remain a launch gate. The new private schema denies direct table access to anon, authenticated and service_role; privileged completion uses one narrow RPC, but server-key custody and the wider legacy deployment require independent review.
- Real institutions require approved data-use agreements and consent wording, independent DB/API/storage security acceptance and explicit deployment authorization. External AI additionally requires approved provider/location/retention terms. `store:false` alone does not satisfy those requirements.

See [local setup and walkthrough](institutional-data-studio-setup-001.md) for repeatable commands, synthetic accounts and operator boundaries.

Local completion state: **PARTNER PLATFORM MVP — READY FOR INDEPENDENT ACCEPTANCE TESTING**. This is not production approval; the gates above remain mandatory before authentic partner material is collected.
