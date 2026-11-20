# Migration 011 implementation report 001

Date: 2026-11-19 (migration filename generated in UTC on 2026-11-20).
Recommendation: **READY FOR REVIEW** of the empty foundation. **Not deployed.**

## Baseline and delivery

PR #22 was open and unmerged at implementation start. The implementation branch, `feature/tafsiri-migration-011-lexical-core`, starts at its head `a5b45af45b9279a197c9080e6648fc64adf4dde8`, which contains the multilingual amendment. `staging` was fetched and the existing eleven migrations through logical Migration 010 were inspected. PR #22 and all previously applied SQL files remain unchanged. The implementation PR targets `staging` and depends on the architecture decisions in #22; its initial diff therefore includes that unmerged documentation baseline.

Supabase CLI **2.114.0** generated [20261120001145_create_multilingual_canonical_lexical_core.sql](../../supabase/migrations/20261120001145_create_multilingual_canonical_lexical_core.sql) using the installed `migration new` command after inspecting its help. The timestamp was not invented. No staging or production SQL was executed during this assignment.

## Implemented schema

| New table | Responsibility |
|---|---|
| `lexemes` | Opaque identity with exactly one language or variety scope |
| `lexeme_dialects` | Reviewed variety assertions, with retirement and successor history |
| `lexeme_forms` | Representations, orthography versions, form roles and replacements |
| `form_normalizations` | Scoped, versioned interpretations anchored to exact source entries |
| `lexical_senses` | Stable meaning identities owned by a lexeme |
| `lexical_sense_revisions` | Versioned definitions, definition language/variety, category and cultural/grammatical context |
| `sense_dialects` | Sense-specific variety assertions |
| `sense_concepts` | Optional mappings; at most one current verified mapping per sense |
| `lexical_attestations` | One source-entry FK and exactly one typed canonical claim target |
| `lexical_linguistic_evidence` | Immutable typed associations to existing linguistic evidence |
| `lexical_relationships` | Explicit directional or symmetric lexeme relationships |
| `form_relationships` | Explicit directional or symmetric form relationships |
| `concept_revisions` | Language-scoped definitions of existing concept identities |

`concepts` receives nullable lifecycle, verification, origin, current revision, seal, creation/review attribution and retirement/successor metadata. Existing rows acquire no fabricated HUMAN provenance or verified status. Existing IDs, definitions, values, policies and table/default grants are preserved. The metadata must either remain wholly unclassified or provide all three lifecycle/verification/origin fields. A current revision uses a deferrable composite FK proving concept ownership.

No duplicate registry, review application, candidate workflow, ingestion engine, training dataset, model or serving layer was created. All thirteen tables are empty after migration. No data is seeded or backfilled.

## Reconciliation with the historical SQL

The historical SQL document remains unchanged. This implementation applies the [multilingual SQL amendment](migration-011-multilingual-sql-design-001.md) and resolves implementation details as follows:

- Lexemes use `language_id` XOR `identity_dialect_id`; a variety may have no parent language. Scope does not follow a language-family permission hierarchy.
- Both definition revision tables require language-or-variety scope. Sense revisions retain `source_category_label`; the existing broad category vocabulary does not impose noun classes.
- Forms support paired nonblank orthography key/version references. Normalization uniqueness includes language/variety scope and treats null scope columns consistently. The search index uses exact representation text, with no universal lowercase/casefold rule.
- Every verification-bearing new table, plus governed concepts, receives an irreversible server seal. Evidence associations have no independent verification state and are immutable from insertion.
- Existing concept metadata remains null unless explicitly adopted. `sealed_at` is also added to concepts so concept status downgrades cannot bypass protection.
- Scope/evidence association uniqueness applies to current rows, permitting retained superseded assertions. The parent field of any successor chain is immutable from insertion, even before verification; otherwise an unsealed successor could be reparented and invalidate a previously checked chain.
- Recorded retirement timestamps and successor choices cannot be rewritten. Superseded identity lifecycle cannot be reset to ACTIVE while retaining its successor.
- Service-role privileges are limited to SELECT/INSERT/UPDATE on new tables, replacing the historical blanket ALL grant. DELETE/TRUNCATE and direct function execution are revoked.

Opaque keys, exactly-one targets, UUID FKs with RESTRICT, positive revision numbers, review attribution, confidence bounds, symmetric endpoint ordering, non-self links and indexes are implemented. Current form/revision ownership uses composite deferrable FKs added after both tables exist. Homographs and identical forms across languages/varieties remain valid separate records.

## Sealing, graph integrity and concurrency

Three `SECURITY INVOKER` trigger functions use an empty search path and schema-qualified dynamic SQL. The row guard reads JSONB records with explicit per-table identity and mutation contracts. It checks configured fields exist and never references a field that is absent from a table. After sealing it compares the complete row minus the small permitted governance-field list; newly added columns are protected by default.

The server sets `sealed_at` on a verified insert or first verification transition. Callers cannot supply, change or clear it. Status downgrades retain both the seal and original review attribution. Semantic content, provenance, keys, scope and parentage remain immutable; corrections require a new revision, replacement form or successor assertion. DELETE and TRUNCATE are rejected for new canonical history, including unsealed rows. Unclassified legacy concepts retain ordinary DELETE behavior; adopted concepts are protected. Concepts TRUNCATE is protected because it could erase governed history.

Successor updates acquire a relation-scoped transaction advisory lock. A deferred constraint trigger checks the final transaction graph for cycles and matching parent/scope. The selected successor cannot later change. Graph edits support READ COMMITTED and SERIALIZABLE; REPEATABLE READ graph edits fail closed because acquiring a lock does not refresh its snapshot. Multiple graph edits should use a stable relation order and retry ordinary deadlock/serialization failures. This foundation does not promise lock-free writes.

The partial unique index serializes competing verified mappings. Ordinary parent UPDATE row locks serialize current-pointer changes. The pointer contract guarantees ownership, not optimistic version checking: two valid pointer changes serialize and the last successful update wins. A future approval workflow must add expected-revision checks when its governance requires them.

## Security boundary and limitations

All thirteen new public tables have RLS enabled, no client policies and no grants to PUBLIC, anon or authenticated. Existing broad public-schema default grants are explicitly revoked on the new tables, including inherited defaults to service_role, before the limited administrative grants are added. No view, public RPC or security-definer function is introduced. Trigger functions cannot be called directly by clients or service_role; PostgreSQL invokes them through the table triggers.

The service role bypasses RLS, but ordinary service-role DML still fires the integrity triggers. It can create/update draft or verified rows if used by trusted code; these structural checks do **not** implement qualified lexical approval. Lexical promotion, authority, evidence-set approval and durable approval audit remain separate future work. Do not load real canonical data until that workflow is implemented and approved.

`concepts` was already publicly readable. Its existing table-level SELECT grants also cover the additive compatibility metadata. This migration does not claim that metadata is private. Private revision text stays in the inaccessible `concept_revisions` table; private audit narratives must not be placed on the compatibility row. Revisit column-level exposure before admitting governed concept data. No reviewer profile details are added to concepts; attribution references use the existing contributor identity.

Database owners/superusers can alter tables, disable triggers or change grants. The migration cannot defend against such administrative powers. Backup, operator separation and administrative audit remain operational controls. It also does not implement linguistic scope approval, training export decisions or commercial clearance.

## Validation environment and reproducibility

Docker was initially stopped and was started locally. The installed CLI attempted to download a newer PostgreSQL image for an isolated stack, but image registries returned EOF errors. No hosted environment was substituted. Validation used a fresh disposable container named `tafsiri-m011-validation-db` from the cached Supabase image `public.ecr.aws/supabase/postgres:17.6.1.155`, PostgreSQL **17.6**, with no host ports.

The image includes only the initial Auth schema. The replay harness copies the **schema only** of Auth and CLI migration history from the existing local Supabase container, with no user records, tokens or credentials. It enables the real `pg_net` extension required by the historical baseline, then replays all eleven repository migrations and records a history entry only after each succeeds. Migration 011 executes in a transaction. Synthetic legacy fixture rows test compatibility before being removed by their exact fixture IDs. The existing local Tafsiri database is read-only throughout this process.

Test entry points:

- [Rollback-only smoke/security suite](../../tests/database/canonical_lexical_core_smoke.sql)
- [Clean replay, failure injection and compatibility harness](../../tests/database/run_lexical_core_replay_tests.py)
- [Two-session concurrency tests](../../tests/database/run_lexical_core_concurrency_tests.py)
- [Updated CI workflow](../../.github/workflows/ci.yml)

The replay script intentionally refuses a database already containing `public.languages`. Provision a fresh dedicated container from the local stack's cached image before running it. It accepts no remote connection URL. The concurrency script commits synthetic fixtures for visibility between sessions; discard them with the dedicated container afterward, not by weakening canonical deletion guards.

## Executed results

| Check | Result |
|---|---|
| Historical migration replay | Eleven files passed on a fresh PostgreSQL/Supabase database |
| Failed migration atomicity | Deliberate division-by-zero after DDL rolled back the whole migration; no residual table/column/data/grant change |
| Explicit migration rollback | Passed; baseline snapshot identical |
| Successful additive migration | Passed; old values, IDs, columns, constraints, policies and grants preserved; new concept metadata null |
| New SQL suite | **457 assertions passed**, including thirteen empty-table checks, all sealed record types, ownership, scopes, successor chains and role security |
| Concurrency | **Four scenarios passed**: mapping uniqueness, parent-pointer serialization, concurrent cycle rejection, unsupported isolation rejection |
| Existing database suites | All six passed, including portal participation/blinding/withdrawal and source/evidence/rule/artifact regressions |
| Existing source-registration atomic integration | Passed against the isolated migrated database |
| PL/pgSQL validation | No errors or warnings for any new trigger binding via `plpgsql_check` |
| Python research regression | **143 passed** |
| Reviewer Portal | **28 tests passed**; typecheck, lint and build passed |

Harness-development failures were corrected: invalid JSON in one mutation fixture, a catalog character-type cast, schema ownership during Auth bootstrap, and legacy smoke assumptions about globally empty rights tables. The final suites require the intended SQLSTATE, not just any error. None of those failures was suppressed or treated as a pass. The missing CLI history prerequisite for the existing atomic test was reconciled using its actual local schema and replayed migration records.

## SQL-01 through SQL-14 coverage

SQL-01–06 and SQL-09–12 directly test identity, separation, ownership, sealing, definition language, normalization, relationships, security, compatibility and atomic replay. SQL-08 uses actual concurrent sessions, not a sequential duplicate-only simulation. SQL-13 checks cycles for all ten successor-bearing tables and races, with same-parent integrity and reparenting prevention.

For SQL-07 and SQL-13, the foundation proves evidence and human verification do not automatically create lexemes and that unresolved source labels remain unchanged. Linguistic approval of compatible scope is a **future promotion-workflow requirement**, not an implemented CHECK constraint. SQL-14 proves canonical verification does not change source rights or introduce an export/serving capability. A real training-export or commercial-rights denial test remains deferred because those systems do not exist. No test-only approval engine was invented to claim otherwise.

## Remaining gates and recommendation

**READY FOR REVIEW** of an empty, local-validated foundation. Staging and production deployment remain unperformed and require explicit approval. Before staging: resolve independent database/security review, refresh hosted schema/grants/history drift checks, confirm backup/recovery and ensure only this migration is pending. See the [deployment-readiness checklist](migration-011-deployment-readiness-001.md).

Production deployment, real lexical data admission, reviewer access, linguistic promotion, approved training exports and commercial serving are not authorized by these local results. Browser E2E and hosted user-flow testing were not run; the existing portal unit/security and SQL workflow regressions passed. Full CLI-managed stack startup was blocked by image downloads; transactional PostgreSQL replay and direct PL/pgSQL lint succeeded using the cached Supabase runtime. CI additionally runs its normal clean Supabase reset and lint when the PR is opened.
