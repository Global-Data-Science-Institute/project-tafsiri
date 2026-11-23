# Hosted acceptance procedure and operational evidence checklist

Local S01?S03 remediation is documented in [remediation-001.md](remediation-001.md). Require independent review of the exact candidate, new migration and the S04?S07 deployment gates. Real scanning must use verified immutable CVD generations; altered mtimes and signed build expiry are mandatory negative cases.

Future execution only after explicit authorization and closure of synthetic preflight blockers. Operator and independent reviewer must use the exact resource IDs/commit/checksums in the approval ledger. Existing local scripts deliberately reject hosted URLs; **do not remove their safety guards** to run this plan. A hosted harness must be separately reviewed with a fixed new-project allowlist and disabled destructive resets.

## Fixture and evidence protocol

Use two institutions, `SYNTHETIC University A` and `SYNTHETIC University B`, sharing one approved registry language/variety ID. Do not add synthetic vocabulary to canonical tables. Ten accounts maximum: one expiring GDSI bootstrap operator, A admin/PI/researcher/contributor, B admin/PI/researcher/contributor, and one unrelated denial account. Create accounts through the future authorized Auth operator procedure using reserved `.example` addresses; confirm these test accounts directly, generate unique secrets, and transfer credentials through the approved private channel. No SMTP or invitation email delivery. GDSI may onboard metadata but must not see submissions.

Use unique `SYNTHETIC-<run-id>` markers, UTF-8 text including combining characters, a valid generated blank PDF, PCM WAV silence, and generated WebM silence as an unsupported-format rejection fixture. Include EICAR, hash mismatch, malformed structure, active/encrypted PDF and unsupported MIME fixtures. Never use real language material, existing datasets, names or microphone recordings. Record SHA-256 and size before upload. Generate any EICAR fixture only within the disposable test environment.

Every case records actor role, operation, expected/actual status, environment IDs, commit, time, sanitized request/receipt ID and reviewer initials. Keep tokens, cookies, credentials and private content out of public artifacts. Screenshots/traces can contain Auth state or private links: keep encrypted and expire them. Stop on any unexpected success across a denied boundary; preserve only minimal incident metadata and disable the candidate.

## Sequential acceptance cases

| Case | Actions | Required result / evidence |
|---|---|---|
| H00 Environment | Verify new refs, checksum manifest, protected exact URL/alias, no preview secrets, public/signup settings, private bucket | Existing research refs absent; anonymous candidate requests challenged; direct legacy API denied by approved remediation; record negative API tests independently of Vercel |
| H01 Onboarding | GDSI creates A/B invitations; mock delivery previews shared privately; accept using matching confirmed accounts | Wrong-email, expired, revoked, already-used and replaced tokens denied; replay does not resend; no email-provider network call |
| H02 Projects/campaigns | A/B select same registry ID, create separate projects and configurable campaigns | Same registry identity, separate ownership/content; metadata proposal is not canonical approval |
| H03 Collaboration | Invite researcher/contributor and explicit cross-institution collaborator to one project; remove project membership, then organization access separately | Only exact authorized project accessible; revoke every explicit project grant needed for full offboarding; last active org administrator protected |
| H04 Collection | Save/resume original text and upload clean text/PDF/PCM WAV under 5 MiB; attempt valid and malformed WebM as unsupported | Hashes match bytes; originals unchanged; submit requires fields and independent consent flags; all files unreadable before scan |
| H05 Real scanning | Run reviewed production-packaged scanner and stale/failed/updater cases | Clean -> CLEAN, EICAR -> INFECTED, mismatched hash/engine failure -> ERROR; no MOCK_CLEAN accepted as real scan evidence. Malformed/active/encrypted cases meet corrected policy; prove timeout/resource rejection and retry after recovery |
| H06 Assistance | Run deterministic mock, attempt external provider with UI and direct API | Mock suggestions MACHINE_GENERATED/UNVERIFIED; originals unchanged; external calls blocked globally even if project flag is toggled; direct begin RPC cannot itself transmit data |
| H07 Triage | Researcher requests clarification, contributor corrects and resubmits; PI accepts another item | Revision conflicts denied; acceptance is intake only; handoff remains PREPARED_BLOCKED; canonical/source/training counts unchanged |
| H08 Withdrawal | Start permitted work then withdraw contribution; attempt file read and stale completion | No new access/processing; stale completion does not restore results; record retained receipts distinctly from content |
| H09 Retention | Contributor requests deletion; unrelated user attempts approval; PI holds/releases/approves | Unauthorized approval denied, hold blocks, seven-day eligibility enforced; don't alter hosted clocks/eligibility to claim seven elapsed days. Schedule the approved test window accordingly; purge proves Storage removal before DB scrubbing and tombstones |
| H10 Isolation | Replay A identifiers as B, unrelated, GDSI and anonymous across state, command, delivery, scan/deletion/AI completion, direct tables/views and Storage | All forbidden operations denied; enumerate legacy paths and RPCs; no private marker in any public response |
| H11 Sessions/recovery | Keep old JWT, globally sign out, retry RPC and Storage; generate private one-use Auth recovery link; revoke membership | Old JWT denied before natural expiry; recovery restores identity only, no role elevation through editable metadata; replayed recovery token fails |
| H12 Backup/restore | Freeze writes, backup DB and all private object bytes/manifests, delete approved fixture, restore into new recovery target | Hash/count/schema/grants/RLS match; no public bucket; replay deletion tombstones, revoke restored sessions/invites; deleted content stays inaccessible. Record measured RPO/RTO; never restore over the main target |
| H13 Incident/rotation | Disable candidate/provider flags, stop worker, rotate worker/server/backup keys one at a time; try old/new keys from approved verifier | Old keys denied, new keys succeed only intended paths, no browser bundle secret; external processing remains off. Test alert routing and operator acknowledgement |
| H14 Rollback/failure | Stage incompatible app/config or failed migration only in recovery target, then restore compatible reviewed artifact | Database transaction failure leaves expected state/history; no partial migration marked complete; app rollback first disables Studio; no down-migration/drop of research tables |
| H15 Cleanup | Close all test sessions, remove only ledger-listed resources under approval scope, check billing | No existing project/domain changed; test services/secrets gone; metadata retained under agreed expiry; teardown independently witnessed |

No automated script may perform hosted H00–H15 under this assignment. The current hosted environment does not exist. The approval must include the seven-day deletion observation window or explicitly leave that case pending; accelerated local fixtures cannot establish elapsed hosted retention.

## Operational readiness matrix

| Control | Local evidence | Still required in future environment |
|---|---|---|
| Real scanner/fail-closed transitions | 1.4.7 matrix and actual DB/Storage worker harness | Review corrected S01/S02 evidence and unsupported WebM policy; hostile corpus, final production packaging and pinned image provenance |
| Scheduling | Bounded worker and lease expiry tested; non-overlap schedule specified | Install supervisor/timers; kill/restart worker; prove no overlapping file processing or lost receipts |
| Queue/alerts | DB receipts and metadata-only logs exist | Add heartbeat/age monitor; inject >threshold backlog, failed scan, stale signature; prove alert receipt and acknowledgement |
| Auth/invitation recovery | Existing browser suite covers expired/replaced tokens and identity recovery after revocation | Exact redirect allowlist, protected callback, no-email operator recovery and rate-limit tests |
| Error/cache handling | API no-store and sanitized errors reviewed/tested | Inspect CDN response/cache behavior, query-token redaction, document referrer policy and logs; no secret-bearing traces |
| DB backup integrity | Disposable DB restore checks counts/content checksum/grants/RLS/private bucket | Provider restore ownership/roles, consistent snapshot, measured RPO/RTO |
| Storage consistency | Seven local objects restored by checksum with anonymous denial in this run | Backup store custody/encryption, deletion tombstone replay, restore completeness across DB/object snapshot |
| Credential rotation | Environment guards and old-user-session denial tested; local service-key rotation not simulated | Real service/server/backup key revocation, old key HTTP denial, worker restart/cutover; do not confuse Auth logout with service-key rotation |
| App rollback | Build passes; no new application logic in this packet | Protected deployment rollback/alias routing and incompatible-schema refusal on candidate |
| Migration failure | Existing database CI includes failure/replay/concurrency tests; manifest verifies unchanged baseline | Target-specific dry run, deliberate failure in recovery target, history verification and forward-fix rehearsal |
| Cleanup | Disposable scanner containers/image cleanup; guarded local reviewer resets | Authorized deletion of only new IDs plus billing/secret verification |

Approval requires named owners for every future step. Findings marked as blockers cannot be waived by checking a box without a recorded security-owner disposition and revised test expectation. Real-partner rights, dialect governance, participant consent, retention agreements and model-training approval remain outside this synthetic acceptance plan.
