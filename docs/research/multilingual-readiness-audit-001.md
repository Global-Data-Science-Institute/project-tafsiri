# Multilingual readiness audit 001

Date: 2026-11-19. Baseline: `199a635` on local `staging`. Scope: repository and read-only staging metadata. No production database inspection or writes were performed. Architecture proposals below are not deployed capabilities.

## Evidence and migration state

Inspected the root README, vision, technical architecture, inclusion framework, canonical lexical architecture and existing Migration 011 SQL design, portal README and authorization/onboarding code, all migration responsibilities, candidate configuration/extraction/normalization, evaluation documentation, CI, and database smoke-test inventory.

The repository has eleven timestamped migration files ending in `20260928015644_create_source_artifact_foundation.sql` (logical Migration 010). Supabase MCP `list_migrations` for **Project Tafsiri Staging** returned the same eleven versions on this date. Logical numbers are documentation labels, not filename prefixes. Migration 011 has no SQL migration file. Its existing design is `migration-011-canonical-lexical-core-sql-design-001.md`; its September local SQL validation is historical, not validation of this amendment.

Read-only staging `information_schema.columns` inspection confirmed `languages`, `dialects`, `dialect_aliases`, `source_entries`, `source_dialect_mapping_assertions`, `source_use_policies`, `linguistic_evidence`, `linguistic_evidence_dialects`, and `contributor_roles` columns. No source content, reviewer identities, or credentials were extracted. Repository constraints remain the basis for the detailed design; migration-list equality alone is not a full live-schema drift audit. Production alignment and counts in earlier documents remain historical observations.

## Reuse and required changes

| Existing surface | Verified repository behavior | Multilingual requirement |
|---|---|---|
| `languages(id,name,iso_code)` | UUID identity; nullable, unique ISO code | Retain IDs; add governed names, lifecycle and external-code assertions without requiring a code |
| `dialects(id,name,description,language_id)` and `dialect_aliases` | Nullable single language FK; aliases for lookup | Retain IDs and names; classification needs evidence-backed many-to-many assertions, not automatic parent inheritance |
| `config/dialects/canonical_dialect_registry_001.json` | Explicit Luhya environment/name policy, includes both Wanga and Luwanga | Preserve this reference configuration; never collapse those identities or treat `General / Not sure` as a real pan-Luhya lexicon |
| Migrations 006 and 010 | Sources, versions, rights, use policies, entries, artifact hashes/acquisitions and import lineage | Reuse one provenance chain; permit multiple language assertions per version/entry |
| Migration 007 | Raw `source_variety_mentions`, scoped evidence, dialect links, notation, examples, relations | Retain unresolved literal labels; add language-only scope without inventing dialects |
| Migration 009 | Canonical rules, revisions, evidence, promotions and bounded contributor authority | Preserve rule governance; lexical approval remains a separately specified operation in the same pipeline |
| Existing lexical proposal | Thirteen proposed tables; existing concepts reused | Amend identity scope, text language, normalization, and irreversible verification guards before implementation |
| Portal Migrations 003–005 | Dialect-scoped studies, expertise, assignments, participation, two-stage annotations | Extend qualification evidence and study scope; retain every existing assignment and blinded stage |
| Candidate generation | `extract.py` selects `name=eq.Luwanga`; English gloss heuristics and noun-class feature; NFKC/casefold normalization | Future versioned language profiles in the same runner; current hashes and default behavior stay frozen |
| Evaluation | Frozen snapshots, manifests and human-review packages | Future manifests include per-side language/variety, orthography and split provenance |

`source_variety_mentions` permits many literal labels per source version and an unresolved state. Its candidate FK targets dialects only. `source_dialect_mapping_assertions` requires a canonical dialect; therefore it cannot represent an unresolved mapping or a language-only mapping today. Do not pretend either limitation is already solved.

## Dependencies and compatibility risks

The baseline also contains `dictionary_entries`, `luhya_dict`, `luhya_dictionary`, Bible tables, translations, knowledge tables, noun classes and English definitions. They are legacy/application surfaces, not canonical lexical truth. Renaming these or changing their semantics would break candidate generation and evaluation foreign keys. `evaluation_items.dictionary_entry_id` is required today; reviewing new canonical evidence cannot be enabled just by relabeling the UI.

`apps/reviewer-portal/src/lib/study.ts` defaults to `HUMAN_EVALUATION_001_LUWANGA`. Onboarding explicitly checks the Luwanga dialect name before writing self-reported expertise. `TAFSIRI_STUDY_KEY` alone is not a multilingual authorization mechanism. Migration 005's eligibility trigger joins active profile, active study participation and matching dialect expertise. Qualification verification and coverage of multiple item scopes require future database enforcement.

`languages.iso_code` uniqueness and global dialect alias naming can conflict with contested classifications or homonymous names. Add scoped assertions; do not relax existing constraints or rewrite references opportunistically. UUIDs remain authoritative within an environment. Environment-specific fixtures must not assume equal UUIDs across staging and production.

## Security and governance risks

- Broad legacy public-read policies exist on language, dialect and some legacy lexical tables. New restricted metadata must not be added to those public rows without exposure review; use private extension tables and explicit projection contracts.
- Portal `requireUser()` calls `auth.getUser()`; `requireAdmin()` checks trusted `app_metadata.tafsiri_role` before constructing the server-only privileged client. Keep this boundary. Privileged operations still require object/study scope checks because service credentials bypass RLS.
- Self-reported expertise is not approved linguistic authority. Contributor rule roles and reviewer profiles are different identities/workflows; neither implies the other.
- Source policy decisions are `ALLOWED`, `DISALLOWED`, `REVIEW_REQUIRED`, `UNKNOWN`, separately for eight use scopes. Neither source receipt nor human review licenses training or commercial service.
- Verified-at-time guards in the old SQL design can be bypassed by downgrading status before editing. This is a design defect to fix before executing Migration 011, not a deployed vulnerability in nonexistent lexical tables.
- No production training/export approval gate is implemented by this work. Future gates must fail closed on missing, expired, conflicting, or unsuitable rights.

## Components held unchanged

All applied migrations, source records/configurations, dialect registry, frozen evaluation artifacts, promotion pilot review CSV, registration scripts, portal code/authentication, study permissions and assignments remain unchanged. No new ingestion, reviewer application, model runner or public API is introduced. No Luhya data is backfilled.

## Implementation sequence and blockers

1. Accept the multilingual amendment and ADRs as design direction; preserve historical proposals.
2. Review the Migration 011 delta and resolve its identity/immutability issues; regenerate and test the complete SQL locally before any migration file is proposed.
3. Design additive registry/source-scope extensions and qualification enforcement as separately reviewed migrations. Do not bundle permission changes into the empty lexical foundation.
4. Version the existing runner's language profiles and portal study configuration only after database scope contracts exist. Require byte-identical legacy outputs for the unchanged profile.
5. Approve a small Luwanga lexical pilot, then rights-cleared dataset/evaluation research. Consider another language only through the onboarding gates.
6. Implement model experiments and commercial handoff only when research evidence and independent approvals justify them.

See [validation report](multilingual-compatibility-validation-001.md) for executed checks and limitations. Unresolved dependencies are design approval, complete schema/grant drift verification before implementation, local database test availability, explicit rights decisions, and language-specific expert approval. None blocks the documentation milestones.
