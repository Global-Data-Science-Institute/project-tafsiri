# Tafsiri Import Reconciliation 001

This analysis reconstructs lineage for the existing Wanga and Lubukusu legacy dictionary rows. It performed production `SELECT` operations only. It created no database migration, import batch, source entry, lexical record, or canonical record.

## Evidence

The Wanga PDF is an authoritative source artifact with SHA-256 `848eff65d09a352feb85ba80439bbfd0107a69dcfbccf8a835670dce1ef6888f`. Its copyrighted body is intentionally excluded from Git. Lubukusu lineage work continued in [Tafsiri Lubukusu Lineage Resolution 002](lubukusu-lineage-resolution-002.md), which records a verified Academia artifact checksum and an artifact-based production crosswalk.

Repository history through tag `pre-main-modernization-2026-09` contains no dictionary bodies, importer inputs, or historical dictionary import scripts. A read-only search of the local Downloads and Projects folders also found no specifically named source artifacts.

The deterministic manifest is `artifacts/source_reconciliation/import_reconciliation_001.json`. Safe crosswalks contain database identifiers, artifact locators, normalized form hashes, controlled match classes, and confidence values. They omit dictionary forms and glosses.

## Findings

The Wanga artifact strongly overlaps both production collections. `dictionary_entries` is especially close to the PDF: 3,758 of 3,837 rows have a normalized form match and 2,727 are exact form/gloss/POS matches. The `luhya_dict` Wanga subset has 3,288 normalized form matches, but gloss and POS transformations are substantially more common.

The evidence does not establish the historical Tafsiri importer, filtering rules, row rejection rules, or a complete transformation specification. Wanga therefore remains `NOT_READY` despite its strong overlap. Lubukusu remains `NOT_READY` because Resolution 002 leaves 967 unmatched and 35 ambiguous production rows requiring entry-level review.

The raw labels `Wanga` and `Lubukusu` remain unchanged in crosswalk evidence. The registered `Wanga → Luwanga` and `Lubukusu → Bukusu` assertions remain `IN_REVIEW`.

## Future source-entry mapping

A future dictionary importer should map each parsed artifact occurrence to:

- `original_entry_locator`: stable page and occurrence sequence
- original form, gloss, POS, and source-supplied noun class
- raw dialect label
- page or source reference
- `historical_source_table` and `historical_source_row_id`
- artifact SHA-256 and occurrence sequence

Historical rows need no new lineage columns. New `source_entries` can point backward through the existing historical table and row ID fields.

## Deferred sources

- Mulembe has 1,655 unique URLs for 1,655 rows. Preserve these as candidate locators and capture timestamped archives before reconciliation; current reachability was inconclusive because bounded HEAD checks timed out.
- KenTrans V2.1 exposes 521 files with official Dataverse checksums and belongs to translation-corpus reconciliation.
- Bible and proverb artifacts belong to their register and cultural ingestion workstreams.

No import batch is ready for registration from this analysis.
