# Multilingual Reviewer Portal integration contract 001

Next implementation contract; existing app behavior remains unchanged. Inspected `src/lib/study.ts`, assignment generation, existing portal tests, [reviewer design](multilingual-reviewer-portal-design-001.md) and the existing study/participation schema. The current HE001 default remains HUMAN_EVALUATION_001_LUWANGA with HE001-PARTICIPATION-V1. No another-language study is activated by Migration 013.

The independently testable registry/profile interfaces are implemented in the backend Python package and database. No unused browser selector or permissive service-key bridge is added: the portal's Supabase Auth identity cannot become an individual database session_user. Implementing that bridge requires a separately reviewed authorization design. Current portal typecheck/lint/tests/build validate that this milestone preserves the app.

## Next additive study contract

Persist an exact study identity scope, approved configuration key/version/digest, orthography version, review protocol and permitted target types. Existing HE001 rows keep their frozen dialect configuration and assignments; no automatic qualification backfill. New language-only studies must not invent a variety to satisfy the current dialect-specific model. Existing evaluation_items.dictionary_entry_id remains a blocker to arbitrary lexical evidence targets; introduce an additive typed-target design with compatibility tests in that future migration.

For every assignment/read/draft/annotation/snapshot/export, enforce all of:

1. Active authenticated reviewer profile and active study participation.
2. Approved task-specific qualification covering the exact language/variety, with current validity and revocation checks.
3. An eligible assignment to this reviewer and item, whose immutable study configuration matches the approved registry digest.
4. Explicit HUMAN_REVIEW and REVIEWER_DISPLAY permission for each source, and study-stage authorization.
5. Independent research authorization; canonical approval remains a separate contributor-role qualification and proposer/approver independence check.

Self-reported native/fluent/advanced/familiar proficiency remains an onboarding claim, not authority. A classification, shared parent, alias or model capability grants no additional assignment scope. Administrative participation management does not confer linguistic competence. No grant is inferred from registry registration or RESEARCH_ENABLED.

Implement a server-only scoped registry gateway with a reviewed mapping from authenticated reviewer/study to exact registry access. Do not expose DB reader credentials to a browser, call as postgres or use caller-provided contributor IDs as authority. The current direct-DB registry client is not that gateway. Keep permission narratives, source text and reviewer identities out of catalog responses and shared caches.

## Acceptance tests for the next PR

Preserve existing HE001 sign-in/resume, Stage A blinding, Stage B frozen suggestions, save/submit, consent and withdrawal. Add same-user cross-language UUID/URL/direct-API denial; exact study/item configuration mismatch; missing/expired/revoked qualification; disputed classification without scope inheritance; inactive participation; source-display revocation; administrative versus canonical authority separation; and no browser/service key exposure. Test SQL RLS and server routes together, not only UI filtering. Ensure another-language denial does not revoke an unrelated valid HE001 assignment.

Deferred: qualification issuance UI, identity linkage, scoped gateway, typed study targets, new study activation, human recruitment and real review data. These are authorization prerequisites, not defects to bypass for backward compatibility.
