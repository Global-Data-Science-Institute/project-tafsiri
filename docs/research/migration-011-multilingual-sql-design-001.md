# Migration 011 multilingual SQL design review 001

Date: 2026-11-19. Status: design review completed; amended SQL implementation and independent database review pending. **Do not deploy.** No migration file or database changes are included.

## Baseline and disposition

The repository and read-only staging migration history end at logical Migration 010 (`20260928015644`). [SQL design 001](migration-011-canonical-lexical-core-sql-design-001.md) already specifies thirteen new tables and additive `concepts` columns. Its prior recommendation to implement applies to its historical scope. The multilingual review now requires the deltas below before implementation. Preserve that historical document and its September test result; neither constitutes validation of this amended design.

Existing UUID PKs/FKs, source-entry provenance, contributor identity, dialect aliases, optional `dialects.language_id`, existing concept columns and use-policy vocabulary were inspected. Migration filenames use CLI-generated timestamps. Before creating a migration, discover the installed CLI commands, run `supabase migration new <descriptive_name>`, and use its generated filename after confirming the remote history is still unchanged. No filename or deployment sequence is reserved by this document.

## Foundation boundary

Retain the thirteen-table lexical foundation. No new registry, source-language mapping, portal authority, candidate, dataset, model or serving tables belong in 011. Those need separate additive migrations. All new tables start empty, RLS-enabled and unavailable to `PUBLIC`, `anon`, and `authenticated`. There is no lexical promotion workflow yet; possession of administrative database access does not authorize populating the foundation.

The existing core remains `Lexeme → Form → Sense → Concept`; forms and senses both belong to lexemes (this is not a chain requiring every sense to belong to one spelling). No spelling column receives a global unique constraint.

## Table-by-table specification and delta

The full column lists and existing constraints in SQL design 001 are incorporated by reference, except where explicitly amended here. All new references use UUID FKs and `ON DELETE RESTRICT`; all timestamps use `timestamptz` unless preserving a legacy column.

| Table | Retained identity and fields | Required multilingual/security amendment |
|---|---|---|
| `lexemes` | UUID PK, unique opaque `lexeme_key`, lifecycle/verification/origin, creator/reviewer/time, current lemma, supersession | Replace required `language_id` with nullable `language_id` FK and nullable `identity_dialect_id` FK; exactly one required. Add irreversible `sealed_at` timestamp. Identity endpoints and keys immutable from insertion. |
| `lexeme_dialects` | UUID, lexeme/dialect FKs, role, provenance, verification and review | Scope assertion, never an automatic language classification. Freeze endpoint/role after first verification; preserve supersession history rather than overwriting verified membership. Add `sealed_at`, `superseded_at`, `superseded_by` self-FK with paired fields and non-self check. |
| `lexeme_forms` | UUID, unique `form_key`, lexeme FK, text, system, role, optional dialect, status and replacement | Add nullable `orthography_key text`, `orthography_version text`, paired nonblank check; key/version reference is a versioned external research specification until a registry FK exists. Add `sealed_at`; freeze text, system, role, dialect, orthography and parent after sealing. |
| `lexical_senses` | UUID, unique `sense_key`, lexeme FK, lifecycle/status/current revision | Parent/key immutable; add `sealed_at`; do not inherit broader scope from a similar sense. |
| `lexical_sense_revisions` | UUID, sense FK, positive revision number, definition/category/register/domain/restrictions/cultural context/usage/reason | Add nullable `definition_language_id` and `definition_dialect_id` FKs, exactly one required on new rows; add nullable `source_category_label text` to preserve analysis outside broad POS categories; add `sealed_at`. |
| `sense_dialects` | UUID, sense/dialect FKs, role/status/provenance/review | Add `sealed_at` and supersession pair as for lexeme scope; a `CONTRASTS_WITH` row is not positive scope membership. |
| `concepts` (existing) | Every current column and key retained | New lifecycle, verification and provenance columns must be nullable with no default for legacy rows. Null means not evaluated by the core, not HUMAN/PROVISIONAL classification. New core writes supply explicit values. Optional current revision pointer and reviewer fields remain additive. |
| `concept_revisions` | UUID, concept FK, revision number, definition/domain/subdomain/notes/reason/origin/status | Add definition language/variety XOR fields as on sense revisions; add `sealed_at`. A definition language does not determine the languages to which the concept applies. |
| `sense_concepts` | UUID, sense/concept FKs, mapping status, provenance/review/confidence/rationale/supersession | Add `sealed_at`; freeze endpoints and rationale on first verification. At most one current verified concept per sense; culturally specific or partial correspondences can stay candidate/disputed with no forced match. |
| `form_normalizations` | UUID, unique key, source-entry FK, optional form FK, normalized text, policy version, method, rationale, review | Add nullable `scope_language_id`, `scope_dialect_id` FKs, exactly one required; add `sealed_at`. Extend tuple uniqueness to include scope; text-only normalization cannot lose language scope. Unresolved source labels remain evidence until normalization scope is reviewed. |
| `lexical_relationships` | UUID, source/target lexeme FKs, relationship type, provenance/review/rationale/supersession | Add `sealed_at`; cross-language links allowed as separately reviewed claims. No inferred same-lexeme or translation equivalence. Sense-level relations remain deferred. |
| `form_relationships` | UUID, source/target form FKs, type/provenance/review/rationale/supersession | Add `sealed_at`; retain symmetric ordering and directional borrowing/derivation; freeze semantics when sealed. |
| `lexical_attestations` | UUID, unique key, source-entry FK, exactly one of six typed target FKs, claim/evidence role/value/provenance/review | Add `sealed_at`; freeze source, target, claim and quoted value. Target scope is derived through its FK; original source scope can remain unresolved and is not silently replaced. |
| `lexical_linguistic_evidence` | UUID, evidence FK, exactly one lexeme/form/sense-revision target, evidence role, notes | Preserve typed uniqueness. Make target/evidence/role immutable from insertion; removal/correction requires a superseding association, so add nullable `superseded_at` and self-FK `superseded_by`. |

All new stable keys use nonblank checks and unique indexes. No keys derive from glosses or spellings. Orthography references in 011 are descriptive specifications only; unresolved or unapproved orthography versions cannot be accepted for a later promotion. A full orthography catalog belongs in the registry extension.

## Scope SQL patterns (design fragments, not runnable migration)

```sql
-- In the proposed CREATE TABLE lexemes:
language_id uuid REFERENCES public.languages(id) ON DELETE RESTRICT,
identity_dialect_id uuid REFERENCES public.dialects(id) ON DELETE RESTRICT,
CONSTRAINT lexemes_identity_scope_check
  CHECK (num_nonnulls(language_id, identity_dialect_id) = 1)

-- In both proposed revision tables:
definition_language_id uuid REFERENCES public.languages(id) ON DELETE RESTRICT,
definition_dialect_id uuid REFERENCES public.dialects(id) ON DELETE RESTRICT,
CONSTRAINT definition_scope_check
  CHECK (num_nonnulls(definition_language_id, definition_dialect_id) = 1)

-- In form_normalizations (replaces the previous tuple uniqueness):
UNIQUE NULLS NOT DISTINCT
  (source_entry_id, scope_language_id, scope_dialect_id,
   normalization_policy_version, normalized_text)
```

A variety-scoped lexeme is valid even when its variety's `language_id` is null or contested. A language-scoped lexeme with dialect forms needs positive reviewed scope assertions before promotion; comparing against the legacy parent FK alone is insufficient. 011 can enforce typed referential integrity and XOR locally; the later promotion workflow must validate linguistic scope, source rights and qualified authority. It must not claim those semantic gates are implemented by a CHECK constraint.

Retain `(id,parent_id)` unique constraints and deferrable composite FKs for lexeme→current form, sense→current revision and concept→current revision. Foreign keys prove ownership, not acceptance; setting a current pointer requires a sealed, verified child in the future governed write transaction. The same transaction locks affected parent rows to prevent concurrent conflicting pointer updates.

## Verification, lifecycle and immutability

Retain lexical lifecycle `PROVISIONAL`, `ACTIVE`, `DISPUTED`, `DEPRECATED`, `SUPERSEDED`, separately from verification `UNVERIFIED`, `IN_REVIEW`, `VERIFIED`, `REJECTED`, `DISPUTED`. Mapping statuses retain `CANDIDATE`. Canonical activation requires approval; merely setting a verification field must not activate a record. Forms retain their existing replacement/deprecation model.

The historical guard only tests `OLD.verification_status='VERIFIED'`. Replace it with per-table invoker triggers using an irreversible seal:

1. On insertion in a verified state or first transition to verified, set `sealed_at` to server time; reject caller-supplied seal manipulation. Require reviewer and timestamp and, when implemented, promotion authorization.
2. Once sealed, never clear or alter the seal, origin, key, identity, source/target, language scope or semantic content. Check the old seal even when the old status is disputed/rejected. A downgrade then edit must fail.
3. Permit only explicitly enumerated governance transitions, current-pointer changes and paired supersession fields, with attributed audit events. Retain original reviewer attribution after disputes; amend the old review-pair CHECK so it does not demand that sealed rows erase their review history.
4. Deny DELETE on canonical/history rows through triggers and privileges; TRUNCATE is not granted to application roles. Changes create a replacement form, new revision or superseding assertion. Database-owner emergency powers are operationally restricted and audited.
5. Revocation/dispute never destroys evidence. `superseded_by` cannot self-reference; deferred validation prevents supersession cycles and enforces same-parent revision lineage where applicable.

Trigger implementation must explicitly enumerate protected fields for each table, including the new scope/definition language fields. Do not reuse one record-shaped trigger branch that accidentally accesses columns absent from another table. Audit storage for lexical approval is a later dependency; 011 remains empty until that workflow exists.

## Concepts compatibility

Adding `NOT NULL DEFAULT 'HUMAN'` to old concepts would assign unsupported provenance to historical rows. The amended migration uses nullable new metadata, with CHECK constraints that allow the all-unclassified legacy state but require complete metadata whenever a core current revision is set. Existing definitions and counts remain byte-for-byte unchanged. Legacy readers continue using `definition_en`; new readers use the revision pointer if present. Future promotion transactions explicitly maintain compatibility snapshots only when an approved English definition exists; they must not overwrite `definition_en` with another language. Snapshot synchronization policy is a release blocker for future writes, not a reason to change old rows now.

## Indexes and constraint review

Retain all existing proposed unique keys, positive revision numbers, confidence range `[0,1]`, non-self relationship checks, exact-one attestation target checks and the partial unique index for a current verified sense→concept mapping. Symmetric endpoints use ordered UUIDs; directional borrowing preserves orientation.

Add `(identity_dialect_id,lifecycle_status)` on lexemes alongside `(language_id,lifecycle_status)`. Add definition-language/variety indexes when revision retrieval needs them, and scope-leading normalization indexes. Preserve indexes on each attestation target, both relationship endpoints, source-entry links and current/replacement pointers. Check all referencing FKs for useful leading-column coverage without duplicating existing composite/unique indexes. Nonunique representation search is a derived lookup and must always filter scope; casefolded search equality never means lexical identity. Query plans and performance targets require real local synthetic measurements later, not invented scale claims.

## RLS, grants and administrative boundary

Enable RLS on every new public table before any grants. Revoke client/PUBLIC table access and default function execution; create no read policies, public RPCs or portal access. Unlike the old blanket `GRANT ALL`, grant the trusted service role only the operations needed after the empty foundation is approved; do not grant DELETE/TRUNCATE. Service-role credentials bypass RLS, so invoker integrity triggers and server authorization remain necessary. New functions use explicit qualified names, empty `search_path`, and no `SECURITY DEFINER` mutation convenience.

Do not alter existing concepts or portal RLS/grants as a side effect. Existing privileges on concepts require a column-level review before adding restricted metadata; keep private audit/authority evidence out of that compatibility table. Test roles directly, including client access through views/functions. Supabase guidance: [RLS and grants](https://supabase.com/docs/guides/database/postgres/row-level-security). Current [changelog](https://supabase.com/changelog.md) was consulted; no CLI upgrade or hosted operation is part of this design.

## Future implementation order

1. Refresh live schema/grants/trigger inventory and migration parity; resolve this review's blockers.
2. Assemble complete amended DDL: additive concept columns, revisions, lexemes/scope, forms, senses, relationships, attestations; add circular pointers after children.
3. Add guards, indexes, comments, explicit privileges and RLS in the same transaction. No source or lexical seed data and no historical backfill.
4. Validate on a disposable local database with synthetic fixtures, including current portal/database smoke suites. Record schema diff, counts, grants, advisors and query plans.
5. Only then create the timestamped migration and submit it for independent review. Staging/production application requires explicit approval outside this task.

## Required tests (specified, not executed)

| ID | Synthetic scenario | Expected result |
|---|---|---|
| SQL-01 | Language-only and parent-ambiguous variety-only lexemes; both/neither scope | First two accepted; both/neither rejected |
| SQL-02 | Identical spelling across languages, varieties and two homographs within one variety | Separate form/lexeme IDs accepted; no automatic mapping |
| SQL-03 | Foreign current form/revision from another parent | Composite FK rejects at transaction end |
| SQL-04 | Verify then dispute/downgrade then edit scope/text/origin; clear seal; DELETE | All semantic mutation/deletion attempts rejected; replacement revision accepted |
| SQL-05 | Definition in a different language from its lexeme; missing definition scope | Explicit differing language accepted; missing scope rejected |
| SQL-06 | Same source entry/policy/text normalized under two scopes | Both retained; exact same scoped tuple duplicate rejected |
| SQL-07 | Unresolved source label and two contradictory attestations | Source unchanged; attestations retained; unsupported canonical scope promotion denied later |
| SQL-08 | Two concurrent verified concept mappings/current revision changes | Partial uniqueness/row locks prevent conflicting current results |
| SQL-09 | Symmetric reversed duplicate, self-link, directional borrowing | Reversed/self rejected; direction preserved |
| SQL-10 | Anonymous, authenticated reviewer, unrelated reviewer and function/view access | No access to any new core table; existing portal behavior unchanged |
| SQL-11 | Preexisting legacy concept lacking provenance | Old bytes unchanged; new metadata null; not implicitly canonical or training eligible |
| SQL-12 | Rollback entire DDL or fail halfway; successful empty migration | No residual partial schema on failure; all thirteen new tables empty on success |
| SQL-13 | Supersession cycle; form/sense claims outside reviewed scope | Cycle rejected; later promotion rejects incompatible scope |
| SQL-14 | Missing/expired MODEL_TRAINING or COMMERCIAL_API permission | Later dataset/release gate denies, even with verified canonical objects |

## Recovery and remaining decisions

Use transactional local rehearsal and predeployment backups. If a future empty foundation needs rollback, disable new callers/grants and issue a forward corrective migration. Once any governed data exists, preserve it and recover with a reviewed forward migration or verified backup restore; do not drop tables or run destructive down migrations. Rehearse restore on disposable local infrastructure only.

Before executable SQL: review the variety-only identity change, nullable legacy concept metadata, sealing/audit transition rules, orthography reference policy and privilege inventory. Before admitting lexical data: implement scoped authority, approvals, atomic promotion/output audit and rights traversal. Before publishing datasets/services: implement the independent gates in the Model Lab and Cloud specifications. This document completes architectural review, not human approval or database validation of future SQL.
