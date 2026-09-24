BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.sources WHERE source_type NOT IN (
    'DICTIONARY','LEXICON','WEBSITE','CORPUS','BIBLE_EDITION','PROVERB_COLLECTION',
    'FIELDWORK','COMMUNITY_CONTRIBUTION','DATASET','OTHER','JOURNAL_ARTICLE',
    'ACADEMIC_PAPER','BOOK_CHAPTER','THESIS','DISSERTATION','GRAMMAR',
    'CONFERENCE_PAPER','TECHNICAL_REPORT'
  )) THEN RAISE EXCEPTION 'an existing source violates the expanded source-type constraint'; END IF;
  IF (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN (
    'source_scholarly_metadata','source_identifiers','source_access_locations','source_variety_mentions',
    'linguistic_evidence_types','linguistic_evidence','linguistic_evidence_dialects',
    'linguistic_evidence_notations','grapheme_phoneme_evidence','linguistic_examples',
    'linguistic_example_tiers','linguistic_evidence_relations'
  )) <> 12 THEN RAISE EXCEPTION 'Migration 007 tables missing'; END IF;
  -- Migration 009 may provide the separate canonical governance layer, but Migration 007
  -- must never populate it as a side effect of evidence creation.
  IF to_regclass('public.linguistic_rules') IS NOT NULL AND (SELECT count(*) FROM public.linguistic_rules) <> 0
  THEN RAISE EXCEPTION 'Migration 007 inserted canonical rules'; END IF;
  IF (SELECT count(*) FROM public.linguistic_evidence) <> 0
    OR (SELECT count(*) FROM public.grapheme_phoneme_evidence) <> 0
    OR (SELECT count(*) FROM public.linguistic_examples) <> 0
  THEN RAISE EXCEPTION 'Migration 007 inserted linguistic data'; END IF;
END$$;

INSERT INTO public.languages(id,name,iso_code) VALUES
  ('70000000-0000-4000-8000-000000000001','Migration 007 test language','t07');
INSERT INTO public.dialects(id,name,language_id) VALUES
  ('70000000-0000-4000-8000-000000000002','Migration 007 test dialect','70000000-0000-4000-8000-000000000001');
INSERT INTO public.contributors(id,name) VALUES
  ('70000000-0000-4000-8000-000000000003','Migration 007 test reviewer');

INSERT INTO public.sources(id,source_key,source_type,title) VALUES
  ('70000000-0000-4000-8000-000000000009','M007-LEGACY','DICTIONARY','Migration 007 legacy source'),
  ('70000000-0000-4000-8000-000000000010','M007-JOURNAL','JOURNAL_ARTICLE','Migration 007 journal'),
  ('70000000-0000-4000-8000-000000000011','M007-THESIS','THESIS','Migration 007 thesis');
DO $$BEGIN
  BEGIN INSERT INTO public.sources(source_key,source_type,title) VALUES ('M007-BAD','INVALID','Bad type');
    RAISE EXCEPTION 'invalid source type accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

INSERT INTO public.source_versions(id,source_id,version_key) VALUES
  ('70000000-0000-4000-8000-000000000020','70000000-0000-4000-8000-000000000010','published');
INSERT INTO public.source_scholarly_metadata(source_version_id,authority_type,journal_title,peer_reviewed)
VALUES ('70000000-0000-4000-8000-000000000020','PEER_REVIEWED','Test Journal',true);

INSERT INTO public.source_identifiers(id,source_version_id,identifier_type,identifier_value,is_primary)
VALUES ('70000000-0000-4000-8000-000000000030','70000000-0000-4000-8000-000000000020','DOI','10.1000/Test',true);
DO $$BEGIN
  BEGIN INSERT INTO public.source_identifiers(source_version_id,identifier_type,identifier_value)
    VALUES ('70000000-0000-4000-8000-000000000020','DOI','10.1000/test');
    RAISE EXCEPTION 'case-insensitive DOI duplicate accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_identifiers(source_id,source_version_id,identifier_type,identifier_value)
    VALUES ('70000000-0000-4000-8000-000000000010','70000000-0000-4000-8000-000000000020','ISBN','978-test');
    RAISE EXCEPTION 'identifier with two owners accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

INSERT INTO public.source_access_locations(source_version_id,url,location_type,availability,downloadable)
VALUES ('70000000-0000-4000-8000-000000000020','https://example.invalid/paper','PUBLISHER','ABSTRACT_ONLY',false);
DO $$BEGIN
  BEGIN INSERT INTO public.source_access_locations(source_version_id,url,location_type,availability)
    VALUES ('70000000-0000-4000-8000-000000000020','https://example.invalid/bad','PUBLISHER','INVALID');
    RAISE EXCEPTION 'invalid availability accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  IF EXISTS (SELECT 1 FROM public.source_rights r WHERE r.source_version_id='70000000-0000-4000-8000-000000000020')
    OR EXISTS (SELECT 1 FROM public.source_use_policies p WHERE p.source_version_id='70000000-0000-4000-8000-000000000020')
  THEN RAISE EXCEPTION 'access location created rights or policy'; END IF;
END$$;

INSERT INTO public.source_variety_mentions(id,source_version_id,literal_variety_name,candidate_dialect_id,mention_scope,mapping_status)
VALUES ('70000000-0000-4000-8000-000000000040','70000000-0000-4000-8000-000000000020','Llogoori',
  '70000000-0000-4000-8000-000000000002','DOCUMENT','CANDIDATE');
DO $$BEGIN
  IF (SELECT literal_variety_name FROM public.source_variety_mentions WHERE id='70000000-0000-4000-8000-000000000040') <> 'Llogoori'
  THEN RAISE EXCEPTION 'literal variety label changed'; END IF;
  BEGIN INSERT INTO public.source_variety_mentions(source_version_id,literal_variety_name,candidate_dialect_id,mention_scope,mapping_status)
    VALUES ('70000000-0000-4000-8000-000000000020','Invalid','70000000-0000-4000-8000-000000000099','DOCUMENT','CANDIDATE');
    RAISE EXCEPTION 'invalid candidate dialect accepted'; EXCEPTION WHEN foreign_key_violation THEN NULL; END;
END$$;

DO $$BEGIN
  BEGIN INSERT INTO public.linguistic_evidence(source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,extraction_method)
    VALUES ('70000000-0000-4000-8000-000000000020','70000000-0000-4000-8000-000000000099','DIALECT','p. 1','Invalid type','HUMAN','HUMAN_MANUAL');
    RAISE EXCEPTION 'invalid evidence type accepted'; EXCEPTION WHEN foreign_key_violation THEN NULL; END;
  BEGIN INSERT INTO public.linguistic_evidence(source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,extraction_method)
    SELECT '70000000-0000-4000-8000-000000000020',id,'DIALECT',' ','Blank locator','HUMAN','HUMAN_MANUAL'
    FROM public.linguistic_evidence_types WHERE evidence_type_key='GRAPHEME_PHONEME_RULE';
    RAISE EXCEPTION 'blank locator accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.linguistic_evidence(source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,extraction_method)
    SELECT '70000000-0000-4000-8000-000000000020',id,'INVALID','p. 1','Bad scope','HUMAN','HUMAN_MANUAL'
    FROM public.linguistic_evidence_types WHERE evidence_type_key='GRAPHEME_PHONEME_RULE';
    RAISE EXCEPTION 'invalid scope accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.linguistic_evidence(source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,extraction_method)
    SELECT '70000000-0000-4000-8000-000000000020',id,'DIALECT','p. 1','Bad origin','INVALID','HUMAN_MANUAL'
    FROM public.linguistic_evidence_types WHERE evidence_type_key='GRAPHEME_PHONEME_RULE';
    RAISE EXCEPTION 'invalid origin accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.linguistic_evidence(source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,verification_status,extraction_method)
    SELECT '70000000-0000-4000-8000-000000000020',id,'DIALECT','p. 1','No reviewer','HUMAN','VERIFIED','HUMAN_MANUAL'
    FROM public.linguistic_evidence_types WHERE evidence_type_key='GRAPHEME_PHONEME_RULE';
    RAISE EXCEPTION 'verified evidence without reviewer accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

INSERT INTO public.linguistic_evidence(id,source_version_id,evidence_type_id,evidence_scope,source_locator,summary,
  provenance_origin,verification_status,extraction_method,tool_or_model,reviewed_by,reviewed_at)
SELECT '70000000-0000-4000-8000-000000000050','70000000-0000-4000-8000-000000000020',id,
  'DIALECT','p. 12, example 3','Test pronunciation evidence','MACHINE_GENERATED','VERIFIED','LLM_ASSISTED',
  'test-model','70000000-0000-4000-8000-000000000003',now()
FROM public.linguistic_evidence_types WHERE evidence_type_key='GRAPHEME_PHONEME_RULE';
INSERT INTO public.linguistic_evidence(id,source_version_id,evidence_type_id,evidence_scope,source_locator,summary,
  provenance_origin,extraction_method)
SELECT '70000000-0000-4000-8000-000000000051','70000000-0000-4000-8000-000000000020',id,
  'DIALECT','p. 13','Alternative analysis','HUMAN','HUMAN_MANUAL'
FROM public.linguistic_evidence_types WHERE evidence_type_key='ALLOPHONIC_RULE';
DO $$BEGIN
  IF (SELECT provenance_origin FROM public.linguistic_evidence WHERE id='70000000-0000-4000-8000-000000000050') <> 'MACHINE_GENERATED'
  THEN RAISE EXCEPTION 'verification changed machine provenance'; END IF;
END$$;

INSERT INTO public.linguistic_evidence_dialects(evidence_id,dialect_id,role,source_variety_mention_id)
VALUES ('70000000-0000-4000-8000-000000000050','70000000-0000-4000-8000-000000000002','PRIMARY',
  '70000000-0000-4000-8000-000000000040');
INSERT INTO public.linguistic_evidence_notations(id,evidence_id,notation_type,notation_text,order_index)
VALUES ('70000000-0000-4000-8000-000000000060','70000000-0000-4000-8000-000000000050','IPA_PHONETIC',
  'β x á aː H L ꜜH',0);
DO $$BEGIN
  IF (SELECT notation_text FROM public.linguistic_evidence_notations WHERE id='70000000-0000-4000-8000-000000000060') <> 'β x á aː H L ꜜH'
  THEN RAISE EXCEPTION 'Unicode notation was not preserved exactly'; END IF;
END$$;

INSERT INTO public.grapheme_phoneme_evidence(evidence_id,grapheme,phoneme,allophone,environment)
VALUES ('70000000-0000-4000-8000-000000000050','b','/b/','[β]','test environment');

INSERT INTO public.linguistic_examples(id,evidence_id,source_locator,example_type,dialect_id,source_text,display_policy)
VALUES ('70000000-0000-4000-8000-000000000070','70000000-0000-4000-8000-000000000050','p. 12, example 3',
  'WORD','70000000-0000-4000-8000-000000000002','test','RESEARCH_ONLY');
INSERT INTO public.linguistic_example_tiers(example_id,tier_type,tier_order,content) VALUES
  ('70000000-0000-4000-8000-000000000070','ORTHOGRAPHY',0,'test'),
  ('70000000-0000-4000-8000-000000000070','SEGMENTATION',1,'te-st'),
  ('70000000-0000-4000-8000-000000000070','MORPHEME_GLOSS',2,'TEST-GLOSS'),
  ('70000000-0000-4000-8000-000000000070','FREE_TRANSLATION',3,'test translation');
DO $$BEGIN
  BEGIN INSERT INTO public.linguistic_examples(evidence_id,source_locator,example_type,source_text,display_policy)
    VALUES ('70000000-0000-4000-8000-000000000050','p. 14','WORD','bad','INVALID');
    RAISE EXCEPTION 'invalid display policy accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

INSERT INTO public.linguistic_evidence_relations(source_evidence_id,target_evidence_id,relation_type,rationale)
VALUES ('70000000-0000-4000-8000-000000000050','70000000-0000-4000-8000-000000000051','CONTRADICTS','Test disagreement');
DO $$BEGIN
  BEGIN INSERT INTO public.linguistic_evidence_relations(source_evidence_id,target_evidence_id,relation_type)
    VALUES ('70000000-0000-4000-8000-000000000050','70000000-0000-4000-8000-000000000050','SUPPORTS');
    RAISE EXCEPTION 'self relation accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'source_scholarly_metadata','source_identifiers','source_access_locations','source_variety_mentions',
    'linguistic_evidence_types','linguistic_evidence','linguistic_evidence_dialects',
    'linguistic_evidence_notations','grapheme_phoneme_evidence','linguistic_examples',
    'linguistic_example_tiers','linguistic_evidence_relations'
  ] LOOP
    IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid=('public.'||t)::regclass) THEN
      RAISE EXCEPTION 'RLS disabled on %', t;
    END IF;
    IF has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE')
      OR has_table_privilege('authenticated','public.'||t,'SELECT,INSERT,UPDATE,DELETE')
    THEN RAISE EXCEPTION 'client privilege leak on %', t; END IF;
    IF NOT has_table_privilege('service_role','public.'||t,'SELECT,INSERT,UPDATE,DELETE')
    THEN RAISE EXCEPTION 'service_role privileges missing on %', t; END IF;
  END LOOP;
END$$;

SET LOCAL ROLE anon;
DO $$BEGIN
  BEGIN PERFORM count(*) FROM public.linguistic_evidence; RAISE EXCEPTION 'anon read unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END$$;
RESET ROLE;
SET LOCAL ROLE authenticated;
DO $$BEGIN
  BEGIN PERFORM count(*) FROM public.linguistic_examples; RAISE EXCEPTION 'authenticated read unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END$$;
RESET ROLE;

ROLLBACK;
