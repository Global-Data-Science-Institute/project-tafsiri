# Project Tafsiri — Luwanga Dictionary Semantic Review

## Why this review is being conducted

Project Tafsiri is developing a linguistically reliable Luhya language AI system. This review checks the semantic meanings recorded in an existing **Luwanga** dictionary sample. Review the language evidence itself; you are not being asked to judge the computer system.

The sample contains 150 records. The local wizard shows one record at a time, saves after each record, and can resume later.

## How to review each record

1. Read the Luwanga word and English dictionary entry.
2. Decide whether it expresses one clear meaning, is a variant, contains multiple meanings, or needs expert review.
3. Optionally provide a clearer English concept label or definition.
4. Add linguistic, cultural, grammatical, or contextual notes when helpful.
5. Indicate whether Tafsiri's initial bucket and ambiguity flag seem reasonable.
6. Select **Save & Next**.

## Decision guide

- **One Clear Meaning (`ACCEPT_SIMPLE`)**: the entry expresses one reasonably clear semantic concept.
- **Variant of Another Form (`ACCEPT_VARIANT`)**: the same concept may appear through a spelling, pronunciation, noun-class, morphological, grammatical, or closely related lexical form. Similar-looking words are not automatically variants; use your judgment.
- **Contains Multiple Meanings (`SPLIT_SENSES`)**: two or more meanings should probably be represented separately, especially for homonyms or polysemous words.
- **Needs More Linguistic Review (`NEEDS_EXPERT`)**: the evidence is unclear, cultural knowledge is necessary, several interpretations are possible, or another native speaker or specialist should review it.

> Do not create or invent a meaning merely to complete the review. If the dictionary evidence and your linguistic knowledge are insufficient, select NEEDS_EXPERT.

Preserve dialect-specific meaning. A Luwanga word must not be assumed to be a universal Luhya word. There are no wrong answers when genuine linguistic uncertainty exists; choosing `NEEDS_EXPERT` is preferable to guessing.

## Saving, resuming, and exporting

Annotations and reviewer information remain on this computer in `human_review_001_annotations.jsonl` and a local state file. The frozen source sample is never changed. You may stop the local application and resume later. Starting over requires typing an explicit confirmation and creates timestamped backups first.

Every record must have a decision and answers to both Tafsiri-assessment questions before final export. Completed exports contain all 150 original records, reviewer annotations, reviewer metadata, and timestamps.

The application is offline: it contains no Supabase access, external APIs, analytics, telemetry, remote fonts, or CDN dependencies.
