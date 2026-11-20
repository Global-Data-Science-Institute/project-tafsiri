# Multilingual pipeline configuration contract 001

Implemented in the existing `scripts/candidate_generation` package. Default `load_config(config/candidate_generation)` retains the original PipelineConfig, curated keys, contextual markers and canonical hash. Existing Luwanga behavior remains opt-out of the new mode; no historical JSON/config/evaluation artifact is rewritten.

## Version 1 profile

Every key is required; unknown keys, malformed UUIDs, unsupported versions/options and empty allowlists raise explicit errors. `target` may be null only when there is no identified gloss. The immutable LanguageProfile stores serialized content and returns copies, so caller mutations cannot silently change its hash.

| Field | Contract |
|---|---|
| contract_version, key, version | Contract 1, explicit profile key, positive integer version |
| source, target | Exact `{kind: language or variety, id: UUID}`; no name, code, alias or parent inference |
| adapter | SOURCE_ENTRY_SNAPSHOT_V1 only |
| orthography | Exact registered orthography UUID and version |
| normalization | PRESERVE or NFC; no implicit casefold, compatibility normalization or tone stripping |
| tokenization | NONE or WHITESPACE_V1, explicitly selected |
| morphology | NONE; unsupported language analyzers fail rather than producing Bantu assumptions |
| features | CONSERVATIVE_V1; supplied-form/gloss repetition and review flags only |
| source_versions, artifacts | Nonempty unique UUID allowlists |
| rights_policy_reference | Required provenance reference, never interpreted as a grant |
| review_protocol | Explicit protocol/version reference |
| evaluation | Explicit protocol and SYNTHETIC or RESEARCH split; real CLI mode is blocked |

The configuration digest is SHA-256 of UTF-8 JSON with sorted keys, compact separators and unescaped Unicode. This is distinct from the 012 PostgreSQL evidence digest. Changing any configuration field changes the digest and requires a new registry configuration approval/version. `RegistryClient.resolve` verifies the exact digest and orthography against authorized DB results. The synthetic offline CLI validates structure only and makes no registry-approval claim.

## Existing source contract, new snapshot adapter

The input envelope is `{contract_version: 1, records: [...]}`. Each record references existing source_id, source_version_id, artifact_id, SHA-256, import_batch_id, source_entry_id and source_locator. It preserves original_form/original_gloss, exact headword_scope and gloss_scope, reviewed scope_assertion_ids, rights_policy_reference and an explicit synthetic boolean. It does not fabricate dictionary_entry IDs for source entries. Example/commentary scopes remain in the source assertion layer; this conservative lexical adapter consumes headword and gloss only.

Validation checks IDs, duplicates, allowlists, exact scopes, policy-reference equality, required original text/digest and synthetic labeling. It does not authenticate files or prove rights: a trusted private exporter must later verify those references against current registry/evidence/rights records. Never feed untrusted self-declared snapshots into an approval workflow. Generation revalidates records against the supplied profile, preventing reuse of records loaded under a different scope.

The same CorpusIndex accepts a profile normalizer; each run has one exact source and target scope. It preserves distinct entries with identical forms and different glosses and flags them for review. All new-profile candidates have zero uncalibrated confidence, `needs_review`, no concept suggestions and no asserted semantic equivalence. Tokenization and normalization outputs are analysis fields; original text stays intact. English-specific POS, noun-class, sense-splitting and curated-key heuristics are not applied.

Scoped exports use evidence schema `pipeline-scoped-evidence-v1`, source_entry_id and proposed_gloss. Legacy exports keep dictionary_entry_id and proposed_definition_en. CorpusIndex's internal compatibility property for glosses is not an assertion that the language is English. The same summary and CSV/JSONL export mechanisms handle both schemas. No alternative research runner or ingestion system exists.

## Synthetic execution

Four profile/snapshot pairs in `tests/fixtures/multilingual` represent two unrelated language configurations and two variety configurations; every record is explicitly SYNTHETIC. Additional SQL fixtures cover a language without varieties, disputed classification, multiple orthographies and a multilingual source. None is vocabulary or an approved research dataset.

```text
python -m scripts.candidate_generation.cli --dry-run --language-profile tests/fixtures/multilingual/synthetic_language_a_profile.json --input-snapshot tests/fixtures/multilingual/synthetic_language_a_snapshot.json --output-dir artifacts/synthetic_multilingual_run
```

Use a new private/local output directory for each run. Profile mode rejects overwrite requests and historical candidate/evaluation output locations. With no profile, an input snapshot is rejected rather than falling back to Luwanga. RESEARCH split is representable for validation/registry resolution but rejected by the CLI pending a separately authorized private adapter. No backend/database writes, canonical promotion or training are performed.

Future extensions must introduce explicit versioned adapters/features with tests and reviewed rights/scope enforcement. Unsupported configurations must remain errors; a code or similar spelling never selects a language automatically.
