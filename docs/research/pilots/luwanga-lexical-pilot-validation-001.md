# Luwanga lexical pilot validation 001

Preparation validation, 2026-11-19 local / 2026-11-20 UTC. The [readiness assessment](luwanga-lexical-pilot-readiness-001.md) reports empirical registry observations; software tests below use synthetic fixtures and establish no linguistic correctness, rights grant or human approval.

## Executed checks

| Check | Result |
|---|---|
| PR dependency state | #22/#23/#24 OPEN, targets recorded; full 012 implementation used as branch base |
| Hosted deployment metadata | Both environments through 20260928015644; 011 lexical table and 012 schema absent |
| Provenance preflight | Both environments: zero source entries/import batches; 12 artifacts, 110 evidence rows. Zero eligible unit lineage |
| Production scope/rights metadata | Exact Luwanga registry ID checked; Wanga mapping IN_REVIEW; 10 primary and 20 comparative verified evidence links; all seven screened resource leads fail rights/review combination |
| Production access metadata | Confirmed disabled RLS and public grants on 16 tables; six views lack invoker option; inspected source/evidence/role grants and relevant policies |
| Python baseline | `python -m pytest tests -q`: 156 passed, including 13 promotion CLI checks |
| Portal baseline | `npm.cmd test` in apps/reviewer-portal: 28 passed across 8 files |
| Manifest/dry-run contract | Read existing CLI, 011 constraints, 012 create/evidence/operation/digest/authority paths; no competing schema or validator introduced |
| Synthetic database rehearsal | `python tests/database/run_lexical_promotion_tests.py`: 102 promotion checks passed; 457 foundation assertions; seven post-012 smoke suites; Marlo atomic registration; four existing concurrency scenarios; all new functions/trigger bindings lint without warnings |

The existing synthetic harness uses only the fixed disposable `tafsiri-m012-validation-db` container. Its bootstrap reads schema-only Auth/history from the existing local stack; no hosted data are copied. Synthetic Luwanga labels/strings are software fixtures, never real candidate replicas or vocabulary. No eligible real record structure could be selected, so this is an infrastructure rehearsal only.

Rehearsal passed dry-run rollback and missing-approval reporting; separate approval with no canonical writes; exact-scope/independent authority and revocation; source verification, rights, lineage and digest rechecks; contradiction retention; atomic failure and idempotent execution; immutable history; and unchanged UNKNOWN training/commercial policies. It also rejected caller-forged identity, role reassignment, cross-scope expansion and a caller-owned deferred-trigger privilege trap. These are mechanical controls tested with invented data, not real permissions or review decisions.

Portal typecheck, lint and production build were not rerun for this documentation-only change; baseline tests were rerun as above. Full synthetic migration replay and failure rollback were rerun. No migration file or runtime code changed.

## Preflight reproduction

Use read-only database access to inspect latest `supabase_migrations.schema_migrations.version`, `to_regclass('public.lexemes')`, `to_regnamespace('lexical_governance')`, and counts of source_entries/source_import_batches/source_artifacts/linguistic_evidence. Resolve dialects by registry ID, then join linguistic_evidence_dialects to evidence/source_versions/sources and group by evidence_scope, role and verification_status. Do not select evidence text or reviewer identity to reproduce aggregate eligibility.

For each resource version in readiness, inspect current nonsuperseded source_rights and source_use_policies, effective/expiry windows, artifact links and source_dialect_mapping_assertions. Join entries to import batches and exact matching evidence locators only after rights clearance. Inspect pg_class RLS/options, has_table_privilege for anon/authenticated and pg_policies to reproduce the access triage. Queries must remain SELECT-only; current-state results can change and require a newly dated assessment.

## Untested and unresolved

No real manifest, source transcription, lexical identity/sense judgment, reviewer competence, independent human approval, production dry-run, deployment, real promotion, browser E2E or public API penetration test was performed. Actual artifact bytes were not reacquired/rehashed. No private research destination or retention policy was approved. Full hosted schema/grant drift, view-owner/RPC reachability, backups/recovery and security remediation remain future gates. The 22/23 advisor count is inherited evidence, not a freshly executed hosted advisor run.

No training/export/commercial service is present to validate downstream permission enforcement; the workflow must leave those rights independent. No confidential source text, reviewer identities, credentials or permission narratives are added to these public preparation documents. Existing frozen artifacts and applied migrations must remain byte/content unchanged in the final diff.

Recommendation: **BLOCKED — SECURITY OR DEPENDENCIES**, with additional rights, provenance and qualification blockers. Passing software tests cannot approve this pilot.
