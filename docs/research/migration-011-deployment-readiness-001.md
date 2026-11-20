# Migration 011 deployment-readiness checklist 001

Date: 2026-11-19. Recommendation: **READY FOR REVIEW** of the empty foundation; **not approved for deployment**. No staging or production database writes have occurred.

Migration: [20261120001145_create_multilingual_canonical_lexical_core.sql](../../supabase/migrations/20261120001145_create_multilingual_canonical_lexical_core.sql).

The [implementation report](migration-011-implementation-report-001.md) is the detailed evidence and limitations record. PR #22 was unmerged when this implementation branch was created; review that dependency before merging the implementation into staging.

## Completed local acceptance criteria

- [x] CLI-generated timestamped migration; all earlier migration files unchanged.
- [x] Thirteen foundation tables; additive nullable concepts metadata; no registry duplication, seed or backfill.
- [x] Clean replay of every historical migration followed by 011 on disposable Supabase PostgreSQL 17.6.
- [x] Failure injection and explicit rollback leave no partial schema/data/privilege change.
- [x] Existing synthetic language/dialect IDs, source/version/rights records and concept values preserved.
- [x] Existing column definitions, constraints, policies, table grants and default grants preserved.
- [x] All thirteen new tables verified empty immediately after migration.
- [x] Exactly-one identity/definition/normalization scope; parentless variety identities and homographs supported.
- [x] Sealing resists status downgrade, semantic/provenance changes, seal tampering and deletion.
- [x] Composite current ownership, directional/symmetric relationships, successor parentage and cycles tested.
- [x] RLS enabled; no anon/authenticated grants or policies on new tables; no definer function or new view exposure.
- [x] Actual service-role writes respect sealing; service-role DELETE/TRUNCATE denied on new tables.
- [x] 457 SQL assertions and four concurrent/isolation scenarios pass.
- [x] All six existing database smoke suites and the source-registration atomic integration pass.
- [x] New PL/pgSQL trigger bindings lint without errors or warnings.
- [x] 143 Python research tests, 28 portal tests, portal typecheck, lint and build pass.

These results establish local structural readiness for review. They do not validate an unimplemented lexical promotion workflow, training exporter or commercial service. SQL-07/13 linguistic approval and SQL-14 downstream approval gates remain later implementation work, as described in the report.

## Required before an authorized staging deployment

- [ ] Independent architecture/database/security review accepts the schema and trigger contracts, including service-role and operator limitations.
- [ ] Resolve PR #22's dependency and review the implementation PR's final diff against the intended staging head; no automatic merge.
- [ ] Check CI results on that exact commit, including normal CLI clean reset, database lint and the new replay/concurrency job.
- [ ] Refresh read-only staging migration history, schema, roles, default grants, concepts exposure and existing views/functions; verify no drift from the reviewed baseline through Migration 010.
- [ ] Confirm the exact staging project identity; inspect the installed CLI's documented deployment command and dry-run options. Do not infer environment from a saved link alone.
- [ ] Confirm the pending plan contains only the reviewed 011 migration and no seed, role, destructive, data-population or unrelated changes.
- [ ] Record predeployment schema/grant snapshot, source/language/dialect/concept/reviewer counts and relevant immutable data digests.
- [ ] Confirm backup and tested recovery procedure, deployment owner and maintenance/lock tolerance for the additive ALTER TABLE on concepts.
- [ ] Obtain explicit staging deployment approval for the exact commit and migration checksum.

Only after those gates may a separately authorized operator apply the migration transactionally to staging. This task stops before that action.

## Staging post-application acceptance (not executed)

- [ ] Exactly one 011 history entry; no duplicate/partial migration objects.
- [ ] Thirteen new tables exist and all have zero rows; no imported lexical data or automatic canonicalization.
- [ ] Preexisting data digests/counts and grants match the predeployment snapshot; old concepts remain unclassified by new metadata.
- [ ] Verify RLS, policies, effective grants, function execution and absence of unexpected views/RPCs using read-only catalog checks.
- [ ] Run read-only lint/advisory inspection; investigate new warnings rather than accepting them by default.
- [ ] Check current Reviewer Portal authentication, assignments, blinded stages, resume and withdrawal under an approved non-destructive staging test plan.
- [ ] Record results and obtain a separate decision for production. Staging success does not authorize production deployment.

## Recovery

Migration application must be atomic. A failure before commit should leave the old schema intact; confirm history and catalog state before retrying. Do not repeatedly push after an unexplained failure.

After a committed migration, restrict new callers and prepare a reviewed forward corrective migration. Do not drop canonical tables or rewrite applied migration files. If restoration is needed, use the approved backup/restore procedure and preserve audit evidence. Local tests use synthetic rollback transactions and disposable containers; never run their destructive setup, fixture cleanup or concurrency scripts against hosted environments.

## Data-admission and service blockers

Even after an empty foundation is deployed, real lexical writes require a separate scoped authority/promotion/audit implementation. Existing public concepts metadata must not be mistaken for a private audit store. Current-pointer ownership does not establish verified linguistic acceptance. Training requires explicit current source-use permission and approved manifests; commercial release requires its separate clearance. These are data/service blockers, not features supplied by Migration 011.
