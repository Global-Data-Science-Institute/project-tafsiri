# Linguistic Evidence Extraction 001

This bounded pilot contains 110 paraphrased scholarly observations from the 11 approved full-text sources. Every record is `UNVERIFIED`, has `MACHINE_GENERATED` provenance, and uses the `LLM_ASSISTED` extraction method. These records are evidence for later scholarly review; they are not canonical linguistic rules.

## Artifacts

- `artifacts/linguistic_evidence/extraction_001.jsonl` is the deterministic write input.
- `artifacts/linguistic_evidence/extraction_001_manifest.json` records retrieval metadata, SHA-256 checksums, page counts, availability, and per-source counts. Downloaded publications are excluded from Git.
- `artifacts/linguistic_evidence/extraction_001_review.csv` is the human review worksheet.

The pilot stores no publication examples or interlinear tiers. It creates no inferred relationships between claims. This minimizes copied text and avoids unsupported display rights.

## Validation and import

```powershell
python -m scripts.linguistic_evidence.register_evidence --validate
python -m scripts.linguistic_evidence.register_evidence --dry-run --project-ref PROJECT_REF
python -m scripts.linguistic_evidence.register_evidence --execute --project-ref PROJECT_REF --confirm-project-ref PROJECT_REF
```

Set `SUPABASE_URL` and either `SUPABASE_SERVICE_ROLE_KEY` or `SUPABASE_SECRET_KEY`. The URL must contain the declared project reference. Execution requires the matching confirmation reference.

The importer completes source, version, evidence-type, dialect, and literal-variety resolution before its first write. Its write guard permits only the seven Migration 007 evidence tables. Existing evidence is identified by source version, locator, evidence type, and normalized summary. Exact matches are reused; managed-field differences stop as conflicts.

## Review guidance

Reviewers should compare each paraphrase and notation against its locator, assess the dialect link, and record a decision and notes in the CSV. Promotion to `VERIFIED` requires a separate scholarly workflow with reviewer identity and timestamp. Provenance remains machine generated after review.
