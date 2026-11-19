# Multilingual Reviewer Portal extension design 001

Date: 2026-11-19. Status: proposed extension of `apps/reviewer-portal`; no code, study, invitation, assignment or permission changes.

## Existing contract

The portal already has reviewer profiles, `reviewer_dialect_expertise`, `reviewer_study_participation`, dialect-scoped `evaluation_studies`, assignments, annotations and adjudications. Migration 005 requires an active profile, active study participation and matching dialect expertise for reviewer assignment eligibility. Existing self-reported expertise does not establish independently verified authority.

`src/lib/auth.ts` revalidates users with `auth.getUser()` and research administrators through `app_metadata.tafsiri_role`. The admin client is server-only. `src/lib/study.ts` and onboarding target HE001/Luwanga; onboarding checks the selected study's actual dialect. Assignments remain preview-only in the portal. Preserve these restrictions until the future schema and authorization tests are ready.

## Proposed changes, in dependency order

| Surface | Extension | Compatibility boundary |
|---|---|---|
| Study configuration | Versioned profile resolved by immutable study ID/key, exact scope IDs, protocol version, expertise rubric, acknowledgment version and localized display text | Preserve `HUMAN_EVALUATION_001_LUWANGA` and `HE001-PARTICIPATION-V1`; never reinterpret an activated study or its frozen hashes |
| Qualification | Extend existing expertise with separately recorded administrator/expert decisions, evidence reference, scope, competence domain, validity interval, revocation and audit actor | Retain self-report as self-report; no automatic upgrades or cross-language grant |
| Language-only expertise | Add a language-target extension associated with the same reviewer profile, using typed FKs; no fabricated dialect | New scope capability requires a migration; not a UI-only flag |
| Study/item scope | Preserve required legacy study dialect; later additive scope associations enumerate each language/variety and role for new protocols | A multi-language item requires all applicable scopes or distinct explicitly bounded review tasks; no blanket multilingual role |
| Assignment eligibility | Require profile, participation, active assignment, approved qualification, study scope and permitted display rights | Database enforcement and server checks must agree; display filtering alone is insufficient |
| New evidence review units | Extend existing evaluation/review workflow to typed source-entry or sense-revision targets | Current `evaluation_items.dictionary_entry_id NOT NULL` is a real blocker; separately review compatibility migration before new target types |

Do not introduce a parallel reviewer identity or second application. Contributor canonical authority remains separate from reviewer profiles: any linkage requires explicit identity verification and grants, not email matching alone.

## Authorization contract

For a future new study, permit a reviewer operation only if all of the following hold:

```text
authenticated user owns active reviewer profile
AND owns eligible assignment for this exact item and study
AND study participation is active and not withdrawn
AND approved, unexpired, unrevoked qualification covers the task scopes
AND study protocol permits this operation at the current stage
AND source rights permit HUMAN_REVIEW and REVIEWER_DISPLAY
```

Language-family membership, an alias, similar spelling, a query parameter or user-editable metadata is never authority. A Luwanga reviewer receives no access to a Dholuo task without its separate qualification and assignment. Administrators can manage research workflows but do not become linguistic approvers automatically. Revocation is checked against current database state on each sensitive request; stale JWT claims cannot extend a revoked qualification.

Implement future RLS SELECT/UPDATE policies plus `WITH CHECK`, eligibility triggers and trusted server guards together. Cover item snapshots, drafts, annotations, pipeline snapshots, exports and direct API access. New tables default deny. Read authorization cannot rely only on the insertion-time assignment trigger: qualifications may expire after assignment. Use scoped, audited administrative functions only where needed and explicitly review their privileges; never solve access errors with an unrestricted security-definer function.

## Existing reviewer continuity

Do not alter active Luwanga assignments, acknowledgment versions or reviewer rows in this architecture phase. A later rollout must first produce an administrator-reviewed mapping of existing eligible participants to the new qualification model. Until that approved mapping and regression tests are complete, keep HE001 on its unchanged protocol; enable stricter new qualification requirements only for explicitly configured new studies. This compatibility path is restricted to the frozen HE001 study ID and existing assignments, not a fallback for arbitrary missing qualifications or new languages. Do not auto-backfill authority.

## Blinding, withdrawal and audit

Stage A sees source evidence and records independent judgments. Pipeline bucket/confidence/candidate suggestions remain unavailable, including direct snapshot requests. Stage A submission locks primary judgments before Stage B reveals the frozen pipeline snapshot. Stage B answers never rewrite Stage A. Resume order remains Stage B incomplete, Stage A draft, unstarted, then existing timestamp/ID tie-breakers.

Withdrawal remains study-specific, deactivates eligible active assignments and prevents further mutations. Preserve prior annotations and audit history subject to the study's consent/retention decision; no silent deletion. Revoking one qualification suspends affected tasks without cancelling unrelated valid studies. Avoid fetching private cross-language records into the browser and filtering afterward. Authenticated routes stay dynamic without shared response caches.

Add durable audit events for qualification grants/revocations, scope/protocol changes, activation, assignment decisions, stage transitions and withdrawal. Store actor, operation, target IDs, old/new state hashes, reason, timestamp and request correlation; never log full private source text or tokens. Existing workflow timestamps alone are not claimed to be a complete security audit log.

## Rollout and acceptance tests

No independently useful runtime change is needed for this design-only task. Relabeling Luwanga UI now would imply unsupported scope handling. Future work proceeds through additive schema/security review, configuration validation with the unchanged HE001 default, synthetic local tests, administrator review, then separately approved study activation.

| Test | Expected result |
|---|---|
| Existing HE001 reviewer signs in, resumes Stage A/B, submits and withdraws | Same behavior and records as before; no assignment or access loss during migration |
| Same reviewer requests another-language item/snapshot/draft by UUID or URL | Database and application deny; no data in response/logs |
| User self-reports native fluency or edits `user_metadata` | No activation, qualification approval or admin privilege |
| Revoked/expired qualification with an old active assignment/token | Read and write denied for affected tasks; unrelated study unaffected |
| Stage A user directly requests pipeline snapshot | Denied until valid Stage A lock transition |
| Reviewer spoofs timestamp, reviewer ID, study ID or dialect ID | Trusted server/DB rejects; no reassignment |
| Two concurrent stage submissions/withdrawal | Transactional guards preserve lock order and no post-withdrawal write |
| Admin assigns a task with unknown reviewer-display rights | Denied pending rights decision |
| Mixed-scope task has qualification for only one endpoint | Denied or split into explicitly scoped independent tasks |

These future scenarios are specifications, not passed tests. Current baseline check results are in the [validation report](multilingual-compatibility-validation-001.md).
