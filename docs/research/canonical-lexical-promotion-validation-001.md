# Canonical lexical promotion validation 001

Validation date: 2026-11-20 UTC (2026-11-19 local).

Recommendation: **READY FOR INDEPENDENT REVIEW**, not authorized for deployment or real linguistic promotion.

## Dependency and hosted compatibility checks

Branch: `feature/tafsiri-canonical-lexical-promotion`, based on the complete PR #23 head `b700283b03937185c091bad7edf3d22183660e09`. PRs [#22](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/22) and [#23](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/23) were both OPEN with no merge timestamp. The draft promotion PR targets `feature/tafsiri-migration-011-lexical-core`. Required integration order: #22 → #23 → promotion PR. Neither dependency was modified or merged.

Read-only Supabase queries inspected `supabase_migrations.schema_migrations` and canonical/role relation existence in Project Tafsiri Staging and Project Tafsiri. Both histories contain the same eleven repository migrations through `20260928015644`; both have `contributor_roles`, and neither has `lexemes`. Thus Migration 011 and this migration are absent from both hosted databases. No migration-history divergence was observed in this check. It was not a complete hosted column/constraint/grant diff; refresh that full drift check before any separately approved deployment.

No staging/production database write, database deployment, real-data backfill, model training, commercial implementation or automatic merge occurred.

## Implementation delivered

- [Architecture and contracts](canonical-lexical-promotion-architecture-001.md).
- CLI-generated [Migration 012](../../supabase/migrations/20261120005801_create_canonical_lexical_promotion_governance.sql).
- [Dry-run-first Python/psql interface](../../scripts/lexical_promotion/promote.py).
- [Disposable database integration suite](../../tests/database/run_lexical_promotion_tests.py).
- [CLI transaction/quoting tests](../../tests/lexical_promotion/test_cli.py).
- Updated [CI](../../.github/workflows/ci.yml), documentation indexes, and the existing 011 security test's version-aware service-write expectations.

The migration adds five private governance tables, one private schema, one inert researcher group role, ten private functions and one invoker-only public concept-boundary trigger function. No canonical table is duplicated. All thirteen 011 tables remain; service INSERT/UPDATE is revoked across all thirteen. Eleven existing lexical tables have supported policy-001 operations. Global concept revision/creation and form-normalization workflows are explicitly deferred and inaccessible through the new API.

## Local environment and reproducibility

All database mutations/tests ran in the disposable container `tafsiri-m012-validation-db`, using cached Supabase PostgreSQL image `public.ecr.aws/supabase/postgres:17.6.1.155` (PostgreSQL 17.6). The existing local Supabase database supplied only Auth and migration-ledger schema definitions, never research data, users, sessions or tokens. The existing 011 harness performs the bootstrap and historical replay. The final container had a temporary loopback-only port at `127.0.0.1:55439` for read-only CLI advisors; it is not a hosted database.

The runner accepts no connection URL and refuses a target already containing `public.languages`. Its human names, rights, qualifications, vocabulary, definitions and scopes are explicitly synthetic. Dedicated fixture logins connect through actual PostgreSQL authentication. Superuser session switching is used only inside rolled-back fault-injection fixtures; the production interface never accepts a switched actor argument.

The installed project CLI is 2.114.0. The migration was generated using its `migration new` command, after inspecting existing files and command help. No historical migration was edited. CLI advisor invocation uses `--db-url` for the disposable localhost database; the CLI's generic message “Connecting to remote database” does not describe a hosted operation here. SSL was disabled only on that loopback connection because the disposable image has no TLS listener.

## Executed results

| Check | Actual result |
|---|---|
| New database harness | **101 named checks passed**; includes seven post-012 regression-suite completion checks |
| Migration replay | Eleven historical files, then 011 and 012 successfully applied to a fresh isolated database |
| Migration 012 failure atomicity | Deliberate late failure removed the entire new schema and group role; subsequent clean application passed |
| Migration 011 rollback/compatibility | Existing failure injection, explicit rollback and legacy-data/schema/privilege checks passed |
| Canonical foundation SQL | **457 assertions passed** before 012; the same suite passed after permission hardening with expected denial of service writes |
| Existing database smoke suites | All seven passed after 012: portal, source provenance, evidence, scholarly source type, rule governance, artifact provenance and lexical core |
| Existing registration integration | Marlo atomic registration passed before and after 012 |
| New concurrent execution tests | Real authenticated sessions: duplicate execution waits and returns original outputs; conflicting proposals produce one commit and one fully rolled-back failure |
| Existing concurrency regressions | All **four** 011 scenarios passed after 012: mapping uniqueness, current-pointer serialization, cycle rejection and isolation rejection |
| New function lint | All private functions and every new trigger binding passed `plpgsql_check` with **zero errors and warnings** |
| All Python regressions | `python -m pytest tests -q`: **156 passed** (143 existing + 13 CLI tests) |
| Reviewer Portal | **28 tests passed** across eight files; typecheck, lint and production build passed |
| Supabase advisors | Executed locally; legacy findings described below; no warning/error names a new governance object |

CI now runs all discovered Python tests, preserving the existing portal/database jobs and adding a fresh-container promotion test step. The PR's GitHub checks provide the separate hosted-runner replay result; local results above do not imply a hosted database deployment.

## What the synthetic checks establish

The valid Luwanga-scope fixture is explicitly invented software data. Additional cases establish:

- Exact dialect and language authority, operation-specific permission checks, independent approval, finite qualification validity, revocation and existing research-role checks. A dialect qualification cannot authorize its parent language. A separate language qualification succeeds only after independent provisioning.
- No anonymous/authenticated/service invocation, no direct researcher table access, no caller-forged login identity, no self-expansion of authority, and no direct service canonical write/adoption. Private outputs and audit narratives stay inaccessible to ordinary users. A caller-owned deferred-trigger trap cannot execute under the definer's privileges.
- Required current human verification, exact entry/evidence/artifact lineage, registered artifact status, known source rights, explicit research/review use permissions, literal source-label resolution and compatible primary evidence scope. Revoking rights/authority or changing the reviewed evidence invalidates execution.
- Retained conflicting attestations and recorded contradiction assessment; omitted known contrary evidence fails submission. Historical and borrowed forms retain their supplied spelling. A missing-equivalent fixture preserves `ORIGINAL_TECHNICAL_TERM`; the engine generates no translation or vocabulary.
- Identical strings remain distinct lexical identities, including in two independently authorized varieties. Multiple senses coexist. A revised meaning creates a new sealed revision and an expected-state pointer change while preserving the old meaning. A competing stale revision rolls back its newly inserted row. Governed dialect assertions and lexical/form relationships execute; cross-scope relationships fail closed.
- Approval alone creates no canonical records. Dry-run rolls back all simulated records and outputs and reports missing approvals. Failed dry-run still reports the proposed operation/evidence plan alongside the blocking conflict. Late failures leave no partial canonical/output records, and committed failures retain audit events. Rejected, withdrawn and disputed proposals remain auditable.
- Executed retries are idempotent. Canonical approval changes neither MODEL_TRAINING nor COMMERCIAL_API policies; both remain UNKNOWN in the fixture. No exporter or commercial service exists to be exercised, and no downstream eligibility claim is made.

Development failures were resolved, not suppressed: peer-authentication fixture setup was changed to real dedicated TCP logins; SQL JSON/operator precedence was corrected; historical/borrowed fixtures no longer try to install a non-lemma as the current lemma; the generic history trigger now uses JSON fields instead of nonexistent table-specific attributes; permission fixture effective times are safely in the past; and database startup readiness is polled before replay. Assertions check intended messages/SQLSTATEs rather than accepting arbitrary exceptions. The final complete suite passed.

## Advisor findings and security limits

The local Supabase security/performance advisor returned **22 ERROR and 23 WARN entries** at WARN-or-higher level. They refer to existing public-schema objects/policy patterns, not objects added by 012:

| Existing pattern | Findings |
|---|---:|
| RLS disabled on legacy public tables | 16 ERROR |
| Legacy views with definer behavior | 6 ERROR |
| Overlapping permissive policies on languages/dialects | 18 WARN entries across database roles |
| Per-row Auth RLS initialization | 3 WARN |
| vector extension in public | 1 WARN |
| Unrestricted legacy submissions INSERT policy | 1 WARN |

The six views are `word_details`, `cultural_terms`, `language_words`, `pronoun_comparison`, `pronoun_details` and `dialect_comparisons`. The sixteen tables are `bible_books`, `bible_english_verses`, `bible_luhya_verses`, `dialect_aliases`, `knowledge_base_entries`, `luhya_dict`, `luhya_dictionary`, `luhya_kb`, `luhya_proverbs`, `pronoun_examples`, `pronouns`, `proverb_contributors`, `proverbs`, `submission_rate_limits`, `suspicious_activity` and `translations`. Their definitions precede this change. Report counts for overlapping policies include roles present in the synthetic environment; these are not a claim that a hosted advisor will produce identical counts.

No blanket “security clean” claim is made. These legacy findings require a separately reviewed access-hardening decision before treating the whole database as deployment-ready. Changing their grants or public behavior is outside this lexical promotion change. New governance security is supported by actual denial tests and private-schema ACL/RLS checks, not solely by the advisor's object coverage.

Owner/superuser bypass remains unavoidable. Private function code is owner-controlled. A rolled-back/disconnected outer transaction cannot preserve a failure audit row. The first policy serializes promotions and locks evidence/rights tables, so it is not validated for large-volume concurrent intake. Language evidence has no native language-ID field in the historical evidence model; exact language scope requires the recorded independent assessment described in the architecture. Browser E2E, hosted user flows, credential provisioning, production-scale performance, real linguistic validity and real rights clearance were not tested or claimed.

## Remaining gates and next milestone

1. Independently review the SQL security-definer boundary, exact-scope policy, broad locking and deployment impact; resolve the legacy advisor findings through an explicit access review.
2. Integrate dependencies in order, refresh full hosted schema/grant/history drift and backup/recovery checks, and obtain explicit staging deployment approval. This work authorizes no database deployment.
3. Approve a bounded real-data research pilot separately: documented research/review rights, frozen source/artifact/evidence references, independently verified reviewer competence, owner-issued scoped authority, explicit contradiction decisions and per-proposal approval.

Recommended next research milestone: prepare that bounded lexical pilot protocol and its qualification/rights evidence packet for review. Do not begin real-data promotion, model training or commercial serving on the strength of these synthetic results.
