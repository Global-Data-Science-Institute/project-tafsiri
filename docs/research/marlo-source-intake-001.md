# Michael Marlo Source Intake 001

## Outcome

**ACTION REQUIRED.** The repository-safe inventory is complete for the ten files currently supplied, including one exact duplicate. Three expected files are absent: `WangaDictionary09012008.pdf`, `Appleby1943dictionary.pdf`, and `Tura.xlsx`. Source registration and imports should wait until the missing artifacts and rights questions are resolved.

No staging or production database writes were made. Original PDFs and workbooks remain outside version control. The machine-readable record is `config/sources/marlo_source_intake_001.json`.

## Provenance and rights

Professor Michael R. Marlo directly supplied the materials after contacting Dr. Moody Amakobe about possible Project Tafsiri collaboration. This supports direct-provider acquisition provenance. The exact email date is unavailable in the retained repository-safe metadata, and the correspondence itself is not stored in Git.

Direct provision does not establish an open license. New materials remain `UNKNOWN` for rights status. Review is required before internal processing or reviewer display, and explicit clarification is needed for public display, redistribution, model training, publication, and commercial use.

## Inventory findings

| Work or dataset | Files | Finding | Parser readiness |
|---|---:|---|---|
| Bukusu-English dictionary, draft 2008-09-01 | 1 | Existing source and version; supplied binary differs from the previously reconciled binary | Partial |
| *Luragoli-English Vocabulary* (Friends Africa Mission Press, 1940) | 1 | New historical intellectual work; OCR text layer is noisy | Ready with OCR and manual review |
| *Amang’ana go Lulimi lwo Lulogooli* (Ndanyi & Ndanyi, 2005) | 5 unique parts + 1 duplicate | One new intellectual work, five ordered scan components, 141 unique pages; Part 5 copy is byte-for-byte identical | Ready with OCR and manual review |
| Luyia comparative dictionary workbook | 1 | New dataset; 5,152 aligned data rows | Ready |
| Idakho comparative workbook | 1 | New dataset; 4,626 meaningful rows and 5 blank rows | Partial pending column clarification |
| Wanga dictionary, Appleby 1943 dictionary, Tura workbook | 0 of 3 | Expected but missing | Not ready |

The Luyia workbook columns are source-provided cross-variety correspondences. They are not canonical equivalence or verified same-sense claims. `Idakho_1` and `Idakho_2` remain separate because their intended distinction is undocumented.

## Dialect handling

All reported labels are preserved verbatim. Bukusu/Lubukusu and Wanga/Luwanga have existing registry context. Luragoli, Logoori, and Lulogooli may map to Maragoli, but this remains a candidate requiring expert confirmation. Tura/Lutura remains unresolved. No generalized Luhya vocabulary or blended dialect mapping was created.

## Artifact model decision

Add a versioned `source_artifacts` migration before registering these files. The current import-batch entity represents processing executions and should not also serve as immutable file identity. A distinct artifact record is needed because this intake includes multiple files for one intellectual work, an exact duplicate, a newly acquired binary for an existing source version, structured workbooks, and files that may be reprocessed by different parsers.

An artifact should carry the checksum, byte size, media type, acquisition provenance, component order, duplicate relationship, and private archive locator. Import batches can then reference an artifact without conflating file identity with an execution.

## Locator conventions

- Spreadsheet: `artifact:{artifact_key}/sheet:{sheet_name}/row:{one_based_row}/column:{column_name}`
- PDF: `artifact:{artifact_key}/part:{component_sequence}/pdf-page:{one_based_pdf_page}/printed-page:{printed_page_or_unknown}/entry:{sequence_on_page}`

## Lineage and cross-reference evidence

The Luyia workbook explicitly contains Appleby, Kisa, Tsotso, Wanga, and Bukusu columns. The Idakho workbook explicitly contains Appleby 1943 and Luwanga alongside its two Idakho columns. These are recorded as source cross-references only. They do not prove that the workbooks derive every value from those publications or that aligned cells are synonymous. The missing Tura workbook prevents assessment of its Appleby, Luwanga, and `cuts` relationships. The Bukusu and Wanga dictionaries remain existing registered intellectual works; a new acquisition channel alone does not create a source version.

## Private archive recommendation

Store original files in an access-controlled private research archive outside the public repository. Use stable artifact keys, immutable SHA-256 checksums, provider and acquisition metadata, and restricted archive locators. Keep backups under the same access policy. Git should retain only the manifest, checksums, parser configuration, tests, and reproducibility documentation.

## Required follow-up

1. Obtain the three missing artifacts and record their checksums and metadata.
2. Clarify `Idakho_1` versus `Idakho_2` and the meaning of aligned workbook rows.
3. Confirm Tura/Lutura classification and the candidate Maragoli mappings.
4. Confirm that the five Ndanyi files form the complete ordered scan.
5. Obtain written permission boundaries for retention, research, reviewer excerpts, public display, redistribution, model training, benchmark publication, and commercial APIs.
6. Determine whether the supplied Bukusu binary differs substantively from the previously reconciled draft.
7. Design and review the non-destructive, versioned source-artifact migration before database registration.

## Validation

```powershell
$env:UV_CACHE_DIR = (Resolve-Path '.uv-cache').Path
uv run python scripts/source_intake/validate_marlo_intake.py --verify-local-files
uv run pytest tests/source_intake/test_marlo_source_intake.py
```
