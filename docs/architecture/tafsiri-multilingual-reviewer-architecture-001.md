# Tafsiri multilingual Reviewer Portal architecture 001

Status: planned extension of `apps/reviewer-portal`, not another portal. Read with the [implemented foundation's integration contract](../research/multilingual-reviewer-integration-contract-001.md) and [reference architecture](tafsiri-platform-reference-architecture-001.md).

## Compatibility and data model

Preserve HUMAN_EVALUATION_001_LUWANGA, HE001-PARTICIPATION-V1, current assignments, dictionary targets and frozen pipeline suggestions. Stage A remains blinded and immutable after submission; Stage B reveals only its authorized frozen suggestions. Participation withdrawal remains study-specific. Do not backfill qualification from self-reported native/fluent/advanced/familiar expertise.

The future additive schema design extends current profiles, studies, participation, assignments, annotations and adjudications. All schema implementation will use new versioned migrations after schema inspection.

| Entity | Proposed relationship and invariant |
|---|---|
| Expertise claim | Reviewer, exact language XOR variety, proficiency, evidence reference and claim time; self-report only |
| Qualification | Reviewer, exact scope, task/protocol version, issuing authority, evidence digest, valid interval and irreversible revocation; approval independent of claim |
| Identity binding | Audited explicit Auth subject-to-reviewer binding; any contributor linkage separately verified; email matching never grants canonical authority |
| Study configuration version | Immutable scope set, registry profile digests, per-side orthography, protocol, participation text/version, allowed target types, stage disclosure and export policy |
| Study target | Typed association to legacy dictionary entry, source entry, evidence or canonical revision using constrained FKs; exactly one target; immutable content snapshot hash |
| Assignment | Reviewer, target, study version and stage, current qualification references; unique active allocation; authorization rechecked on every action |
| Review and adjudication | Append-only submitted observations, protocol rubric/version, attribution, stage and snapshot hash; adjudication links all disagreements without erasing reviews |
| Access/audit event | Actor, action, resource, policy decision, timestamp, request ID; no private text in general logs |

`evaluation_items.dictionary_entry_id` is currently required. New target types need an additive association and a compatibility adapter for legacy items, not fake dictionary rows or silently nullable identity semantics. Multi-scope tasks require qualification covering every relevant endpoint. A study may offer several independently scoped task streams without requiring all reviewers to qualify for every stream.

## Authorization and gateway

The server derives the reviewer from validated Auth identity, then checks active profile, active participation, current task-specific qualifications, exact assignment, frozen study/configuration, source HUMAN_REVIEW and REVIEWER_DISPLAY permissions, and stage visibility. Enforce the same conditions at database and route boundaries, including drafts, resume, exports and direct UUID access. Shared language parentage, aliases and classification assertions never expand rights.

013 authenticates individual database `session_user`; Supabase Auth does not supply that identity. Design a narrow server-side registry projection gateway with its own reviewed delegation records: authenticated subject, study, permitted exact profiles, operation, expiry and audit. A future migration must define its least-privilege function/role contract and trusted identity verification. Do not impersonate an individual with `SET ROLE`, caller-provided UUIDs, postgres or a service-role bypass. Existing direct-login RPCs remain unchanged until a separately reviewed gateway exists. This unresolved implementation boundary blocks activation, not architecture completion.

Administrators manage studies, invitations and assignments but acquire no linguistic approval authority. Qualification issuers cannot approve themselves. Researchers receive project-approved deidentified results, not reviewer private profiles or blinded data ahead of protocol release. Canonical proposers and approvers continue through 012's separate contributor authority and independence checks; annotations do not execute promotion.

## Application modules and proposed internal API

Reuse existing onboarding, study, assignment, review/draft and admin modules. Add scope-aware expertise claims, qualification administration, study configuration management, typed target loading, protocol rendering, adjudication and audited researcher exports. Shared authorization functions must be invoked by server reads and writes, not just navigation guards.

| Proposed route | Input/output | Enforcement and errors |
|---|---|---|
| GET `/research/v1/studies` | Current user → eligible study metadata | Auth plus participation; never list unauthorized content |
| GET `/research/v1/assignments/{id}` | Assignment → stage-filtered target and version | Exact user/study/scope; 404 for inaccessible resources |
| PUT `/research/v1/assignments/{id}/draft` | Rubric answers, expected revision → draft revision | CSRF/session checks, schema, assignment, optimistic concurrency; 409 stale |
| POST `/research/v1/assignments/{id}/submit` | Draft revision and idempotency key → sealed submission | Recheck current rights and qualification transactionally; 422 invalid rubric |
| POST `/research/v1/qualifications` | Signed-off evidence, task/scope/validity → decision reference | Designated issuer only; no self-approval |
| POST `/research/v1/adjudications` | Review IDs, resolution/rationale → immutable decision | Qualified independent adjudicator; unresolved disagreement retained |
| POST `/research/v1/exports` | Approved project/study/protocol → export job ID | Researcher scope and export rights; separate from training export |

These are future route contracts. No runtime paths are added here. Use request IDs and immutable protocol versions; idempotent retries bind exact bodies. Revocation denies subsequent access even if a draft exists; preserve the audit according to approved retention, rather than silently deleting submitted results.

## Protocol, experience and stages

Protocol versions define prompts, scoring scales, allowed abstention, conflict disclosure, stage disclosure, assignment randomization seed and adjudication escalation. Disagreement is a research result; do not average it into canonical acceptance. An adjudicator can resolve, request more review or preserve disputed status. Studies lock their protocol before assignment.

Interface locale is independent of reviewed language. Use reviewed labels, Unicode-preserving input, registry direction/script metadata, accessible keyboard/focus support and explicit orthography selection. Untranslated UI labels may use a disclosed fallback interface language, never a fabricated linguistic translation or silent target-variety fallback. Low-bandwidth drafts need privacy-conscious expiry; do not cache protected evidence indefinitely on shared devices.

Stage 1 adds qualification and typed-target schema with HE001 regression coverage. Stage 2 adds the reviewed gateway and exact-scope authorization. Stage 3 adds multilingual protocols, UX and administration using synthetic studies. Stage 4 permits separately approved real studies. Tests must cover cross-user/language/assignment direct-route denial, expired qualification, display-right revocation, blinding, concurrent submit, withdrawal, inaccessible exports and preserved HE001 behavior. Recruitment and real study activation are outside this task.
