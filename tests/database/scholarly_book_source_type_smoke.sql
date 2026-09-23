BEGIN;

DO $$
DECLARE
  candidate_type text;
  accepted_types text[] := ARRAY[
    'DICTIONARY','LEXICON','WEBSITE','CORPUS','BIBLE_EDITION','PROVERB_COLLECTION',
    'FIELDWORK','COMMUNITY_CONTRIBUTION','DATASET','OTHER','JOURNAL_ARTICLE',
    'ACADEMIC_PAPER','BOOK_CHAPTER','THESIS','DISSERTATION','GRAMMAR',
    'CONFERENCE_PAPER','TECHNICAL_REPORT','BOOK'
  ];
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.sources s
    WHERE s.source_type <> ALL (accepted_types)
  ) THEN
    RAISE EXCEPTION 'an existing source is invalid under the Migration 008 vocabulary';
  END IF;

  FOREACH candidate_type IN ARRAY accepted_types LOOP
    INSERT INTO public.sources(source_key, source_type, title)
    VALUES ('M008-' || candidate_type, candidate_type, 'Migration 008 ' || candidate_type);
  END LOOP;

  IF (SELECT count(*) FROM public.sources WHERE source_key LIKE 'M008-%') <> cardinality(accepted_types) THEN
    RAISE EXCEPTION 'not every expected source type was accepted';
  END IF;

  BEGIN
    INSERT INTO public.sources(source_key, source_type, title)
    VALUES ('M008-INVALID', 'INVALID', 'Migration 008 invalid type');
    RAISE EXCEPTION 'invalid source type accepted';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END$$;

ROLLBACK;
