# Multilingual compatibility and validation report 001

Date: 2026-11-19. Scope: architecture-only expansion from baseline `199a635`. Branch: `feature/tafsiri-multilingual-architecture`, based on existing `staging` to include the prior Migration 011 design. Review target is `staging`; no merge or deployment is authorized by this report.

## Deliverables and implemented change

Completed the [audit](multilingual-readiness-audit-001.md), [amendment](multilingual-architecture-amendment-001.md), seven [ADRs](../README.md), [Migration 011 review](migration-011-multilingual-sql-design-001.md), [portal design](multilingual-reviewer-portal-design-001.md), [Model Lab](tafsiri-model-lab-architecture-001.md), [Cloud specification](../architecture/tafsiri-cloud-commercial-architecture-001.md) and repeatable [onboarding gates](../language_inclusion_framework.md), including a paper-only Dholuo scenario. Updated vision, technical architecture, README and documentation navigation.

The implementation consists entirely of Markdown documentation. No application code, pipeline configuration, test implementation, SQL migration, source registry, frozen evaluation package or promotion review artifact changed. Existing Luhya behavior is preserved by leaving those executable/data surfaces intact. The new architecture is specified, not activated. No staging/production database writes, study activation, model training, commercial infrastructure or public API deployment occurred.

## Executed checks

| Check | Result and practical scope |
|---|---|
| `python -m pytest tests -q` | **143 passed**, including all discovered research regression tests. The Windows alias was inaccessible in the sandbox; execution outside the sandbox succeeded. |
| Portal `npm.cmd run typecheck` | **Passed**: Next route generation and TypeScript compilation. |
| Portal `npm.cmd run lint` | **Passed**. |
| Portal `npm.cmd test` | **28 passed across 8 files**, including auth/security, workflow, assignments, resume and Stage A tests. |
| Portal `npm.cmd run build` | **Passed**; compiled and generated routes with placeholder public Supabase URL/key overrides. No deployment. |
| Repository migration inventory vs staging `list_migrations` | **Matched eleven versions through Migration 010**. Read-only metadata inspection; not a full live schema/grant drift audit. |
| Staging column inspection | Confirmed registry/source/evidence/authority columns used by the design through read-only `information_schema`; no private content exported. |
| `git diff --check` | **Passed** for documentation changes. |
| Markdown navigation check | **101 local links checked across 19 changed/new Markdown files; zero broken targets**. |
| Protected implementation/data diff against baseline | **Empty** for `supabase`, `scripts`, `config`, `evaluation`, `artifacts`, `apps` and `tests`. |

Existing tests validate existing behavior only. They do not prove new multilingual authorization, dataset export gates, amended SQL triggers or commercial isolation: those are not implemented.

## Checks unavailable or intentionally deferred

- Local Docker is not running: `docker ps` failed because the Docker Desktop Linux engine pipe does not exist. SQL migration reset/smoke tests, atomic database integration and local database lint were not run. No hosted database was substituted for destructive local testing.
- Browser end-to-end tests were not run: the existing Playwright setup requires local Supabase/Docker and fixture setup. No live reviewers or studies were used for testing.
- Amended Migration 011 SQL is design fragments plus a complete table-by-table delta, not an executable migration; syntax/dependency/security validation of a full amended DDL remains future work. Historical September validation of the old design is not reused as a pass.
- Production database state, permissions and counts were not queried. Earlier deployment records remain historical; refresh them before any approved deployment.

## Compatibility and future acceptance matrix

| Requirement | Evidence in this change | Concrete future test / release gate |
|---|---|---|
| Stable Luhya identities and sources | Registry/source/migration files untouched; no data writes | Snapshot UUIDs, aliases, source/version/artifact hashes before/after a later migration; require exact equality |
| Existing rights remain authoritative | No source policy changes; eight existing use scopes retained in design | Source with UNKNOWN/expired MODEL_TRAINING denies export even when verified; no rights inference from acquisition |
| Assignments and authentication preserved | Portal untouched; baseline auth/security/workflow tests pass | Synthetic existing Luwanga reviewer completes onboarding, Stage A/B, resume and withdrawal with unchanged assignments |
| Language-specific scope | Explicit language-or-variety identity and per-side metadata specified | Parent-ambiguous variety accepted; both/neither lexical scope rejected; unsupported profile cannot fall back |
| Cross-language isolation | New qualification/RLS contract specified | Luwanga-only reviewer requests another-language item, draft and pipeline snapshot by UUID: deny server and DB |
| No evidence→canonical auto-promotion | No ingestion/promotion changes; separate gate retained | Import and human verification leave canonical counts unchanged until explicit scoped promotion |
| Immutable canonical semantics | Irreversible seal corrects weakness in historical proposed guard | Verify→dispute→edit/delete/clear seal all fail; new revision succeeds |
| No unapproved training export | Manifest and rights gate specified; no new exporter | Missing consent, rights or provenance excludes item and emits traceable reason; altered manifest rejected |
| No commercial use of research-only assets | Separate release/clearance interface specified | Research-only checkpoint, missing clearance, altered digest and revoked rollback target all rejected |
| Additive schema and legacy compatibility | No migration added or modified; nullable legacy concept extension proposed | Disposable DB: replay old migrations, apply future migration, assert unchanged old values/counts/grants and empty new tables |
| Reusable pipeline and evaluation | Existing runner/configuration and frozen evidence untouched | Old profile produces identical fixture output/hash; new profile uses same lineage stages without Luhya-only assumptions |
| Linguistic fidelity | No vocabulary or classifications invented | Same spellings and cognates retain separate identities; unresolved labels stay exact; no-equivalent cases remain uncertainty/preserve-and-explain policy |

Detailed SQL scenarios SQL-01–SQL-14 appear in the [SQL review](migration-011-multilingual-sql-design-001.md). Portal, Model Lab and Cloud documents provide their own negative authorization/rights cases. These are acceptance requirements, not executed test results.

## Review findings and next implementation steps

The original lexical model is reusable, but required language parenthood, unscoped definition/normalization text, default HUMAN provenance on legacy concepts, and status-only immutability guards need amendment. Registry classification and language-only scope need additive extensions; current aliases and dialect parent links cannot supply all semantics. Current portal expertise is partly self-reported and current evaluation items require a legacy dictionary row. Those are explicit dependencies before enabling another language.

Next: independently approve the design deltas; refresh schema/grant metadata; assemble and test complete 011 DDL on a disposable local stack; review an empty additive migration; implement scoped lexical promotion and authority before data admission. Follow with separately reviewed registry/profile/portal extensions. Dataset approval, model experiments and commercial release remain later gated work. No production quality or training results are claimed.

## Delivery controls

Use logical documentation commits and a draft PR against `staging`, which contains the baseline SQL design. Reviewers should resolve the SQL/security decisions before creating a migration. The PR must remain unmerged pending review. Git commits and publishing the requested draft do not authorize database deployment or production service changes.
