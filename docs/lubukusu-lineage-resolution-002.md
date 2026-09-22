# Tafsiri Lubukusu Lineage Resolution 002

This reconciliation used production `SELECT` evidence only. It performed zero production writes and did not register a batch or create `source_entries`.

## Artifact evidence

The verified document page is [Lubukusu-English dictionary](https://www.academia.edu/1901981/Lubukusu_English_dictionary). The page and downloaded title page identify Michael Marlo, Adrian Sifuna, and Aggrey Wasike as compilers/editors and date the draft September 1, 2008. The work is also listed on the author-associated [Michael Marlo](https://missouri.academia.edu/MichaelMarlo) and [Aggrey Wasike](https://utoronto.academia.edu/AggreyWasike) profiles. These locations establish provenance; they do not establish an open license.

The manually downloaded `Lubukusu_English_dictionary.pdf` is 857,700 bytes, 107 pages, and has SHA-256 `34426921c2cf2f6dd61a738a343fdda4b2d74f5c479b7c7c4bbd6cb677f49b82`. PDF metadata records Ghostscript 9.05 and a 2014-02-12 creation/modification timestamp. Visible title page and transcription notes match the inspected 2008 draft. The PDF remains outside Git.

The [public textual mirror](https://pdfcoffee.com/lubukusu-english-dictionarypdf-pdf-free.html) matches the title, editors, date, front matter, and visible lexical content. Its binary could not be retrieved, so comparison is `UNCERTAIN`. Glottolog describes a related 2007, 187-page manuscript; it is treated as an earlier related version rather than the same binary.

## Parser and validation

The PDF's embedded fonts lack a usable Unicode character map. `scripts/source_reconciliation/lubukusu_pdf.py` therefore renders pages and applies pinned RapidOCR models. It orders detections by page, column, and position, then recognizes controlled POS abbreviations and joins continuation lines. Source spelling, tone, doubled vowels, raw POS, raw OCR text, `(?)`, page, sequence, and an entry checksum are retained. Accent removal is available only as a separate secondary search key.

The parser produced 6,116 entries. Manual checks covered:

- page 4: initial entries and syllable boundary notation;
- page 51: `khúú-` tone and length, multiword expressions, wrapped and comma separated glosses, and `(?)`;
- page 107: the final adjective and a POS line separated from its gloss;
- title and transcription pages: identity, acute high tone, doubled vowel length, and abbreviation definitions.

The OCR output is deterministic under the recorded renderer, engine, model hashes, configuration, and artifact checksum. It is not yet a critical edition: entry boundary and recognition review remains necessary for unmatched production rows.

## Reconciliation

| Measure | Count |
|---|---:|
| Parsed artifact entries | 6,116 |
| Production Lubukusu rows | 3,935 |
| Exact form matches | 1,939 |
| Transcription preserving normalized form matches | 1,941 |
| Secondary accent insensitive form matches | 2,968 |
| Exact form and gloss matches | 1,821 |
| Normalized form, gloss, and POS matches | 1,836 |
| Exact full triples | 1,820 |
| Punctuation formatting | 15 |
| Gloss formatting | 1 |
| Likely transformations | 105 |
| Tone or diacritic differences | 992 |
| Ambiguous production rows | 35 |
| Production rows with no source form match | 967 |
| Unassigned artifact entries | 3,204 |
| Duplicate source form excess | 1 |
| Source entries carrying uncertainty | 421 |

The source history described in the publication is distinct from the Tafsiri import. The publication's combination of Appleby, KWL, Mutonyi, and de Blois material, followed by Sifuna retranslation, Wasike verification/tone marking, and Marlo editing, is confirmed. Tone removal and limited punctuation, gloss, and POS normalization in Tafsiri are strongly inferred. The historical Tafsiri parser, filters, merges, and rejection rules remain unknown.

## Readiness

`LUBUKUSU_2008_RECONCILED_BATCH_001` is recorded as a proposal only. Its artifact and parser identities are reproducible, but 967 unmatched and 35 ambiguous production rows require entry-level review. These exceptions are bounded in the exception manifest and safe crosswalk; neither file contains dictionary body text.

The batch and a later controlled `source artifact → source_import_batch → source_entries` process remain `NOT_READY`. Production writes remain zero.
