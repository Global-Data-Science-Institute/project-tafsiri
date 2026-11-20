# Luwanga evidence packet and manifest specification 001

Version 1; preparatory specification only. Zero real packets/manifests generated because [eligibility gates](luwanga-lexical-pilot-readiness-001.md) fail. This is a packaging contract around Migration 012, not a new ingestion or evidence pipeline.

## Private packet envelope

One immutable version per proposed lexical unit, stored only in an approved access-controlled research location. The following fields describe a non-executable envelope; do not submit this envelope to the CLI.

| Field | Required content |
|---|---|
| packet_id, packet_version, supersedes_packet | Stable opaque identity, positive integer version, prior version reference or explicit none |
| unit_key, proposal_id, policy_version | Opaque unit; real proposal UUID when prepared; LEXICAL_PROMOTION_001 |
| source_references[] | source ID, source-version ID, artifact ID and exact SHA-256, import-batch ID, source-entry ID, evidence ID and exact locator |
| source_fidelity | Original form and gloss privately preserved verbatim; editorial interpretation separate; qualified verification decision/time and private attribution reference |
| scope | Exact Luwanga dialect ID; literal source label; verified mapping assertion ID; evidence scope/primary links; no competing primary dialect |
| claims[] | Identity/form/sense decision, justification, alternative readings and claim-level attestation targets |
| evidence_roles[] | SUPPORTS, CONTRADICTS, QUALIFIES or HISTORICAL_SUPPORT for each evidence reference; explicit known-conflict search and uncertainty statement |
| permissions[] | Current rights ID/status and policy IDs/decisions, effective/expiry dates, private authorization reference; separate permissions for actual display/research/review activities |
| qualification_refs[] | Private independent competence, role, exact-scope authority and validity references; author/approver independence decision |
| manifest | Exact immutable Migration 012 proposal document described below |
| evidence_snapshot, evidence_digest | Server-returned snapshot/digest when available; absent and explicitly NOT_SUBMITTED before an authorized submission |
| custody | Private storage reference, access owner/list, retention/withdrawal decision and permitted publication scope |

Do not record a fake digest or human decision to make a packet complete. Missing prerequisites remain explicit missing fields and block submission. A byte hash of a stored packet may be used for custody, labeled separately; it is not the 012 evidence-set digest. Store changed packets as new versions; preserve prior versions and reasons.

## Existing executable manifest contract

Use [promote.py](../../../scripts/lexical_promotion/promote.py) and [Migration 012](../../../supabase/migrations/20261120005801_create_canonical_lexical_promotion_governance.sql). The database is the authoritative structural and relational validator; the CLI parses JSON and constructs transactions, not a standalone JSON Schema validator.

Required top-level fields: UUID `id`; unique nonempty `idempotency_key`; `proposal_type` CREATE/REVISE/ASSERT/DISPUTE; positive `proposal_version`; `policy_version` exactly LEXICAL_PROMOTION_001; `dialect_id` exactly the verified Luwanga registry UUID and no language identity; valid `provenance_origin` from the existing 011 constraint; explicit `contradiction_statement`; nonempty `evidence` and ordered `operations` (1–100). Do not place packet-envelope fields or qualifications into operation data as if they were canonical columns.

Every evidence item has existing UUIDs `source_entry_id`, `evidence_id`, `artifact_id` and a permitted evidence role. Entry and evidence must share source version and exact locator. Import checksum/algorithm must match a non-quarantined registered artifact linked to that version. Supporting evidence must be current human VERIFIED. Known contrary/alternative neighbors must be included and classified; absence of registered relations does not prove absence of linguistic disagreement.

Each operation contains `table`, `action`, `data` with a stable UUID, and `expected` where required. Insert parents before children. Supported insert tables are lexemes, lexeme_forms, lexical_senses, lexical_sense_revisions, lexeme_dialects, sense_dialects, sense_concepts, lexical_relationships, form_relationships, lexical_attestations and lexical_linguistic_evidence. `set_current` permits only lemma/revision pointers and requires the exact old value, including JSON null. `dispute` supports lexemes, lexical_senses and sense_concepts with expected old status. Check all remaining column names/types and enums against 011; do not infer them from an older design document.

Provide supporting claim-level attestations for every primary inserted claim and an attestation for every disclosed source, including contrary evidence. Identity is never inferred from spelling or gloss equality. Preserve the source spelling; no normalization operation is available under policy 001. Historical/borrowed forms must not be installed as current lemmas unless separately represented as valid LEMMA records. Cross-scope relationships, new global concepts, concept revisions and identity merging are outside this policy. The executor supplies verification, attribution, timestamps, provenance and lifecycle fields; do not supply managed fields.

## Digest and freeze

012 hashes PostgreSQL JSONB text serialized as UTF-8 with SHA-256:

```sql
encode(extensions.digest(convert_to(
  jsonb_build_object('policy', p.policy_version,
                    'manifest', p.manifest,
                    'evidence', snap)::text,
  'UTF8'), 'sha256'), 'hex')
```

`snap` is the server's existing evidence snapshot: source/version, entry, batch, artifact and links, scopes, variety mentions, current rights/research policies, mappings and evidence relations. Preserve evidence/operation array order. A Python sorted-JSON hash or whole-file checksum is not interchangeable with this digest. Inspect and archive the server-produced digest; no client may substitute one. REVIEWER_DISPLAY and other activity-specific permissions need their own operational recheck: the 012 research digest does not implement every downstream use-policy gate.

Submission freezes snapshot/digest. Independent approval must bind the exact digest, `source_fidelity_confirmed: true`, nonempty `scope_assessment` and `contradiction_assessment`. Revalidation on execution must match the reviewed evidence and authorization snapshot. Any evidence or authority change requires investigation and, where invalidated, a new proposal/review rather than silent rehashing.

## Rehearsal interface

Future authorized private preview only:

```text
python scripts/lexical_promotion/promote.py --manifest PRIVATE_MANIFEST_PATH
```

Default action is dry_run. `inspect` and dry_run always end with ROLLBACK, including temporary proposal creation, even if `--commit` is supplied. A dry-run may acquire locks and consume sequence values; it is not a production no-impact guarantee. Missing approvals and conflicts must be inspected; a successful rehearsal is not approval. Other state-changing actions require explicit `--commit`. No real-data CLI call was made in this preparation. Credentials belong in separately provisioned individual libpq configuration; never a shared service identity or GitHub file.

The [validation report](luwanga-lexical-pilot-validation-001.md) distinguishes synthetic manifest/transaction validation from the unavailable real evidence packet. Synthetic fixtures remain in the existing test harness and are never labeled authentic Luwanga.
