# Multilingual platform foundation 001

Implementation for independent review; no deployment, research-data ingestion, model training or commercial activation. Branch `feature/tafsiri-multilingual-platform-foundation` is based on pilot documentation commit `646ef40`, which includes full 012 implementation `fa986c8`. At inspection, PRs [22](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/22), [23](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/23), [24](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/24) and [25](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/25) were OPEN. Targets remain staging, staging, #23's branch and #24's branch respectively. This PR stacks on #25; no dependency was modified or merged.

## Registry extension

Installed Supabase CLI generated [Migration 013](../../supabase/migrations/20261120021023_multilingual_platform_foundation.sql). Existing `languages.id`, `dialects.id`, names, codes, aliases and parent links remain intact. There are no seed identities or automatic backfills. New `language_registry.profiles` rows extend exactly one existing language XOR variety, unique per identity. The extension UUID identifies metadata; it is not a replacement language ID.

Nine restricted tables reuse the existing contributor, source and linguistic-evidence foundations:

| Table | Responsibility |
|---|---|
| profiles | Approved community name and registration/research lifecycle for an existing identity |
| names_codes | Alternative/community names and codes with standard/version, evidence and review status |
| classifications | Explicit two-endpoint relationship assertions, including disputed and unrelated classifications |
| orthographies | Versioned exact-scope writing-system, script-standard/version, direction and normalization metadata |
| capabilities | Independently approved, finite, revocable dataset/model-evaluation/model/commercial capabilities |
| configurations | Immutable profile-key/version, orthography and canonical-JSON content digest approvals; revocable |
| access_grants | Finite, revocable individual-login access to one exact profile |
| source_scopes | Located document/evidence/headword/gloss/example/commentary/reference scope assertions |
| events | Append-only owner-attributed before/after audit of registry changes |

Names and codes never imply identity equivalence or linguistic relationship. Existing `dialect_aliases` remain legacy lookup data and are not an authorization source. New language-level names and reviewed code metadata cannot fit that dialect-only table; the assertion extension does not copy or replace its rows. `dialects.language_id` stays a compatibility association, not an access hierarchy. Classification evidence can disagree without rewriting identity or granting access.

Registry lifecycle supports REGISTERED, RESEARCH_ENABLED, SUSPENDED and RETIRED. Unlike the earlier conceptual draft's pre-approval states, this implementation creates a profile only after owner-reviewed registration; proposed/disputed research assertions remain in their respective tables. Identity and semantic assertion fields are immutable. Explicit status/review transitions and lifecycle decisions are audited; old values are retained. New interpretations use new assertion rows. Capability/configuration/access approvals allow only one-way revocation. Deletes and truncates are denied by triggers, except that a privileged administrator can ultimately change controls.

Registration and research enablement do not imply DATASET_ELIGIBLE, MODEL_EVALUATION_ELIGIBLE, MODEL_AVAILABLE or COMMERCIALLY_AVAILABLE. Each capability requires its own approval, reviewer, validity and revocation record; lookup never derives later stages from earlier ones. Suspended/non-research profiles expose no available capabilities. A capability record is an approval reference, not implementation of a dataset exporter/model registry or commercial service; downstream consumers must validate the exact governed release and rights separately.

## Access and internal contracts

The private schema is not a new public API. All nine tables have RLS, no client policies, and revoked PUBLIC/anon/authenticated/service/research-reader table privileges. No ordinary role can write registry data. Reviewed operator mutations are the initial governance boundary; an operator UI and finer-grained curator authority remain future work. Access membership and grants are provisioned separately, never seeded by this migration.

The NOLOGIN `tafsiri_registry_reader` group receives only schema usage and two narrow SECURITY DEFINER entry functions with empty search paths and fully qualified references:

- `lookup(kind, identity)` checks session_user's unexpired, unrevoked exact-profile grant and returns approved names/codes, lifecycle, verified orthographies, classification-uncertainty flag and independent available capabilities. Unknown and unauthorized identities receive the same denial. No source text, evidence/permission narrative, reviewer UUID or cross-scope classification endpoint is returned.
- `resolve_configuration(kind, identity, key, version)` uses the same authorization, requires research enablement and a verified matching orthography, and returns the exact approved digest/version. No latest-version or Luwanga fallback.

Individual database-login grants use the established direct-session approach; a caller UUID, session setting, self-report or JWT claim cannot supply identity. A future service gateway needs its own reviewed user-to-scope delegation contract. Do not use shared owner/service credentials or reuse a dropped login name without revoking old grants. SQL owner/superuser control remains an explicit trust boundary.

[RegistryClient](../../scripts/candidate_generation/registry.py) is a transport-neutral internal Python client. A host supplies an authenticated `query_one(sql, parameters)` connection adapter returning decoded JSON. Parameters are bound, never interpolated. Methods implement lookup, orthographies, independent capabilities and profile resolution. Resolution validates the document, independently checks target access, verifies the source orthography and matches the exact approved content digest. No network server, credentials, public translation endpoint or alternate pipeline is introduced.

## Language-aware evidence

Existing source/version/artifact/import/entry/evidence IDs remain authoritative. `source_scopes` preserves each literal label and component locator; optional entry and evidence references are constrained to the same version. Entry linkage includes the existing import batch through a composite FK. Multiple located scope assertions support multilingual documents and separate headword/gloss/example/commentary languages. REFERENCE scopes state a reference, not semantic equivalence. UNRESOLVED labels cannot carry canonical identity; reviewed mappings are new assertions, never replacement source text.

The existing linguistic_evidence scope CHECK is widened to LANGUAGE and MULTILINGUAL while preserving all four historical values. New evidence types require explicit EVIDENCE component assertions at transaction commit: one language for LANGUAGE, at least two explicit identities for MULTILINGUAL; VERIFIED evidence requires VERIFIED scopes. Deferred validation permits evidence and scope insertion in one transaction. Evidence-parent locks and READ COMMITTED checks serialize scope edits; disputed scope cannot leave a verified record unsupported. A curator can atomically dispute the evidence and its scope instead. Raw source labels, existing dialect links, source rights and use policies are unchanged.

Promotion policy LEXICAL_PROMOTION_001 does not hash this extension. A fail-closed trigger blocks new/updated proposals involving new evidence types or any source version carrying new source-scope assertions. The conservative version-level boundary prevents document assertions from being ignored. A SHARE lock protects against concurrent scope insertion during proposal changes. Existing proposals/sources without new scopes retain the tested 012 path. This is an intentional limitation until a separately reviewed policy binds all new scopes, contradictions and authority into its digest; adding a new scope can therefore block a pending legacy proposal. No new scope automatically authorizes canonical promotion.

## Single pipeline and configuration

See [the configuration contract](multilingual-pipeline-configuration-001.md). Existing candidate_generation indexing, generation entry point, summary and export functions are reused. The default Luwanga loader, historical configuration hash, frozen evaluation artifacts and old candidate schema remain unchanged. An opt-in versioned profile selects conservative, language-neutral analysis and an explicit source-entry snapshot adapter. New profiles cannot reach the old name-based extractor or English gloss heuristics by fallback.

Synthetic CLI execution is implemented. A production private exporter that checks current source rights, reviewed scope assertions and snapshot custody is deliberately not implemented or authorized here; real-data profile CLI execution fails explicitly. This keeps software generalization separate from deferred language research. Registered configurations are not permission grants.

## Security, validation and next work

See [security priorities](../security/multilingual-foundation-hardening-plan-001.md), [portal integration](multilingual-reviewer-integration-contract-001.md) and [validation results](multilingual-platform-validation-001.md). No existing portal route, reviewer record, study, permission or source corpus is changed.

Next development milestone: independently review the registry/operator authority and hardening migrations, then implement a rights-aware private source-entry exporter plus a versioned multilingual promotion-policy extension. Separately implement study-scoped portal qualification enforcement. Language-specific corpus research, deployment, model training and commercial release each remain distinct authorized milestones.
