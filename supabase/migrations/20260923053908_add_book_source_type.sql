-- Project Tafsiri Migration 008: add the scholarly BOOK source type.
-- Vocabulary-only change. No source or linguistic data is inserted.

ALTER TABLE public.sources DROP CONSTRAINT sources_type_check;

ALTER TABLE public.sources ADD CONSTRAINT sources_type_check CHECK (source_type IN (
  'DICTIONARY','LEXICON','WEBSITE','CORPUS','BIBLE_EDITION','PROVERB_COLLECTION',
  'FIELDWORK','COMMUNITY_CONTRIBUTION','DATASET','OTHER','JOURNAL_ARTICLE',
  'ACADEMIC_PAPER','BOOK_CHAPTER','THESIS','DISSERTATION','GRAMMAR',
  'CONFERENCE_PAPER','TECHNICAL_REPORT','BOOK'
));
