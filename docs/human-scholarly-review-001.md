# Human Scholarly Review 001

Dr. Moody Amakobe reviewed all 110 records in Linguistic Evidence Extraction 001 against their cited source locations and accepted them. The completed decision package is frozen by checksums in `extraction_001_human_review.json`.

Verification records that each extraction accurately reflects its scholarly source. It does not promote the evidence to an executable or canonical Tafsiri rule. The original `MACHINE_GENERATED` provenance and `LLM_ASSISTED` extraction method remain unchanged.

## Artifacts

- `artifacts/linguistic_evidence/extraction_001_human_review.json`
- `artifacts/linguistic_evidence/extraction_001_review_completed.csv`
- `artifacts/linguistic_evidence/extraction_001.jsonl`, retained unchanged as the reviewed evidence identity

## Commands

```powershell
python -m scripts.linguistic_evidence.apply_human_review --validate
python -m scripts.linguistic_evidence.apply_human_review --dry-run --project-ref PROJECT_REF
python -m scripts.linguistic_evidence.apply_human_review --execute --project-ref PROJECT_REF --confirm-project-ref PROJECT_REF
```

The utility requires exactly the 110 Extraction 001 keys and validates parent content, dialect links, notation rows, and G2P children before updating anything. Its write guard permits contributor insertion and updates to the three evidence review fields only: `verification_status`, `reviewed_by`, and `reviewed_at`.

Contributor resolution first compares normalized email and then normalized exact name. Duplicate or conflicting identities stop execution. A repeated review run reuses the contributor and all verified evidence rows.
