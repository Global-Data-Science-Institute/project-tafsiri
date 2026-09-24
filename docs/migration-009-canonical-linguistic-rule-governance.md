# Migration 009: Canonical Linguistic Rule & Promotion Governance Foundation

Migration `20260924035424_create_canonical_linguistic_rule_governance.sql` implements the approved governance foundation. It creates no canonical rules, revisions, promotions, promotion outputs, supersessions, or contributor-role assignments.

## Implemented foundation

- Separate governed canonical rule and contributor-role taxonomies
- Stable rule identity and immutable numbered semantic revisions
- Explicit revision-level dialect links and typed conditions
- Traceable rule-revision links to scholarly evidence
- Explicit promotion actions, lifecycle, approval/application separation, risk class, authority policy, checksums, and idempotency keys
- Foreign-key-safe typed promotion outputs
- Rule supersession supporting replacement, refinement, split, and merge histories
- Scoped, time-bounded contributor authority assignments
- Validation for verified supporting evidence, active dialect scope, revision immutability, and supersession cycles
- RLS and deny-by-default client privileges on all new governance tables

`PROTO_LANGUAGE` is deferred as a canonical scope. Verified reconstructed evidence may remain in the evidence layer. Canonical scopes in this foundation are `DIALECT`, `MULTI_DIALECT`, and `FAMILY_GENERALIZATION`.

## Transactional application decision

Migration 009 does not add a promotion-application RPC. The first promotion pilot must establish a deterministic proposal payload for dialect links, evidence roles, and conditions before a privileged atomic function is safe to freeze. The schema supplies uniqueness, state, evidence, scope, history, and output constraints needed by that later transaction.

No `SECURITY DEFINER` function is introduced. The four validation trigger functions use an empty search path, are unavailable to `PUBLIC`, `anon`, and `authenticated`, and are granted only to `service_role`.

## Verification

The rollback-only smoke test is `tests/database/canonical_linguistic_rule_governance_smoke.sql`. It covers taxonomy, identity, revision history, dialect scope, evidence roles, promotion state, outputs, supersession, authority, RLS, grants, and helper-function security.

Both staging and production dry runs report Migration 009 as the only pending migration. Neither environment was modified during implementation verification.
