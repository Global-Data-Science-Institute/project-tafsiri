# Multilingual architecture amendment 001

Date: 2026-11-19. Status: approved direction from the project brief; implementation details proposed for review. No new language, database object, dataset or service is activated.

## Scope and authority

Tafsiri becomes a multilingual African-language research platform with Luhya as its first reference implementation and primary focus. This amendment extends the [existing lexical architecture](canonical-lexical-core-architecture-001.md), informed by the [repository audit](multilingual-readiness-audit-001.md). Historical research decisions remain intact. Where the old SQL design conflicts with this amendment, use the [multilingual SQL design review](migration-011-multilingual-sql-design-001.md) before implementation.

## One research pipeline

```mermaid
flowchart LR
  S[Registered source] --> V[Version and exact artifacts]
  V --> I[Governed import]
  I --> E[Located evidence]
  E --> H[Human verification]
  H --> C[Separate canonical promotion]
  C --> D[Approved versioned datasets]
  D --> Q[Independent evaluation]
  Q --> M[Future research models]
  M --> R[Separate release and rights approval]
  R --> P[Future commercial artifact boundary]
```

Arrows denote review gates, not automatic transitions. Existing registration, evidence and promotion tools remain responsible for their current stages. Language configuration selects parser/normalization/review policy; it never bypasses provenance or authorization.

## Identity registry: extend existing identities

Retain `languages.id` and `dialects.id`. The internal table name `dialects` does not impose a sociolinguistic hierarchy: the product may call these varieties. Existing `dialects.language_id` remains a compatibility association, not definitive classification or an authorization inheritance tree.

Proposed additions, in a later registry migration:

| Extension | Contract |
|---|---|
| Language/variety metadata | One extension row per existing identity; immutable project key, community-preferred label, lifecycle and governance reference; no duplicated identity registry |
| Names and codes | Alternate/community/historical names and code-system/version/value assertions with source, review and validity interval; reuse `dialect_aliases` for existing lookup; do not infer equivalence from an alias |
| Classification assertions | Typed language/variety endpoints, relationship, evidence, rationale, certainty, status, reviewer, dates and supersession; multiple competing parents allowed |
| Orthography profiles | Stable key plus immutable version, exact language or variety scope, writing-system codes where verified, normalization policy, evidence and reviewer; multiple scripts/orthographies may coexist |
| Language-only source/evidence scope | Extend existing mention/mapping and evidence mechanisms with language targets; never create an artificial variety simply to satisfy a dialect FK |

Use separate language/dialect FKs with exactly-one-target checks on new assertion endpoints, rather than an unconstrained polymorphic UUID. Project keys are opaque and independent of spelling/classification; standardized codes are optional and require evidence. `languages.iso_code` remains unchanged as legacy metadata. An unrecognized code is not silently minted as ISO. Public catalog labels are a reviewed projection; private classification evidence stays protected.

Registry lifecycle is `PROPOSED → UNDER_REVIEW → RESEARCH_ENABLED`, with `SUSPENDED` or `RETIRED` possible through attributed decisions. A registry lifecycle never means translation support. Dataset, model and commercial eligibility are separately approved capabilities. Existing Luhya identities receive no automatic lifecycle backfill in this phase.

## Assertion scope

An assertion must identify a language, a variety, multiple explicitly enumerated targets, or an unresolved source mention. Null never means all languages. Source-level scope describes contents, not the scope of every entry. Multilingual dictionaries retain headword, gloss, example and commentary scopes separately; mixed-language passages can have multiple located assertions.

Unresolved source labels remain exact text in `source_entries.raw_dialect_label` and `source_variety_mentions`. Existing verified mapping assertions remain valid. A future language-target extension must preserve those rows and their dialect FKs. A reviewed mapping is a new assertion, never an edit to original source text. Language classification disagreement need not block evidence preservation; it does block unsupported canonical generalizations and access inference.

## Linguistic separation

`Lexeme → Form → Sense → Concept` remains the core. A lexical identity belongs to one explicitly chosen language OR variety scope; a variety can remain parent-ambiguous. Forms and senses may narrow scope only through reviewed assertions. A lexeme cannot acquire another language merely because a string matches. Homographs, cognates and borrowing retain separate identities.

Definitions and glosses record their own language, independently of the lexical object's scope. Concepts are optional shared semantic identities, not English definitions. Mapping two senses to one concept does not authorize treating them as interchangeable translations. Cultural context, register, grammatical constraints and partial equivalence remain visible. Cross-language semantic relationships require review covering both endpoints; disagreement stays disputed.

Morphological, phonological and orthographic variation reuse located linguistic evidence and typed form relationships. No mandatory noun-class, Bantu grammar or English POS assumption is added to the core. Preserve source categories alongside reviewed broad categories; `OTHER`/`UNKNOWN` remains possible. Idioms, proverbs and multiword expressions retain source evidence pending a separate expression extension to the same pipeline. Do not squeeze a proverb into a single-word lexeme or implement an expression engine now.

## Configuration contract for the existing runner

Future configuration should extend `scripts/candidate_generation/config.py` and its existing config hash with a versioned profile containing:

- Exact environment-local language/variety IDs and a portable project key resolved through an explicit environment mapping; no name-based fallback for new profiles.
- Headword, gloss and example language scopes; orthography/version; source adapter and source-version/artifact allowlist.
- Normalization and tokenizer versions, source POS mappings, optional morphology features, contextual markers and calibrated confidence rules.
- Review protocol/version, eligibility scopes, rights policy version and unresolved-label behavior.

Keep the current `pipeline_001.json`, concept registry, marker configuration and frozen evaluation bytes untouched. The existing NFKC/casefold function is a research matching heuristic, not universal orthographic truth. A new profile must not strip meaningful tone or merge distinct strings. Disabled noun-class evidence must not produce the same confidence interpretation without calibration. Unsupported profiles fail closed rather than falling back to Luwanga. Different adapters can feed the same entry/evidence contracts; they do not create another pipeline.

## Governance and deployment boundaries

Human verification, canonical approval, dataset approval, model evaluation and commercial clearance are distinct decisions with actors, scope, evidence hashes and policy versions. Machine origin remains recorded after review. New canonical tables begin empty and deny client access; the Reviewer Portal retains its current study. New review studies require independently tested database authority and blinding rules.

The Model Lab consumes explicitly approved dataset snapshots. Tafsiri Cloud consumes only approved versioned release artifacts, with separate credentials, storage and deployment authority. Neither receives privileged research database access. Feedback enters existing governed intake only with consent; it is not training truth.

## Decision records and acceptance

The seven [multilingual ADRs](../architecture/decisions/adr-multilingual-001-single-pipeline.md) cover pipeline reuse, identity, dialect preservation, semantics, reviewer authority, model/data governance and research/commercial separation. The [onboarding framework](../language_inclusion_framework.md) and [validation matrix](multilingual-compatibility-validation-001.md) define acceptance gates. Hypothetical Dholuo onboarding tests architecture only; it creates no data or support claim.
