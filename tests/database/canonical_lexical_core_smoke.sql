-- Migration 011: synthetic, rollback-only SQL-01..SQL-14 foundation checks.
-- SQL-07/13 promotion scope and SQL-14 export decisions remain future workflows;
-- here we prove that the foundation grants no such runtime capability or rights.
BEGIN;
CREATE TEMP TABLE m011_results (label text NOT NULL);
GRANT INSERT, SELECT ON m011_results TO anon,authenticated,service_role;
CREATE FUNCTION pg_temp.ok(label text, condition boolean) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
  IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %',label; END IF;
  INSERT INTO m011_results VALUES(label);
END $$;
CREATE FUNCTION pg_temp.fails(label text, statement text, expected_state text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE actual text;
BEGIN
  BEGIN EXECUTE statement; EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS actual=RETURNED_SQLSTATE; END;
  IF actual IS DISTINCT FROM expected_state THEN
    RAISE EXCEPTION 'FAIL: % expected SQLSTATE %, got %',label,expected_state,coalesce(actual,'success');
  END IF;
  PERFORM pg_temp.ok(label,true);
END $$;
CREATE FUNCTION pg_temp.id(n integer) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
  SELECT ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
$$;

-- SQL-12: all new objects exist and start empty, even with populated legacy data.
DO $$ DECLARE t text; n bigint; BEGIN
  FOREACH t IN ARRAY ARRAY['lexemes','lexeme_dialects','lexeme_forms','form_normalizations',
    'lexical_senses','lexical_sense_revisions','sense_dialects','sense_concepts',
    'lexical_attestations','lexical_linguistic_evidence','lexical_relationships','form_relationships','concept_revisions'] LOOP
    EXECUTE format('SELECT count(*) FROM public.%I',t) INTO n;
    PERFORM pg_temp.ok('SQL-12 empty '||t,n=0);
  END LOOP;
END $$;

INSERT INTO public.languages(id,name) VALUES(pg_temp.id(1),'M011 synthetic language A'),(pg_temp.id(2),'M011 synthetic language B');
INSERT INTO public.dialects(id,name,language_id) VALUES
  (pg_temp.id(3),'M011 synthetic parentless variety',NULL),(pg_temp.id(4),'M011 synthetic variety B',pg_temp.id(2));
INSERT INTO public.contributors(id,name) VALUES(pg_temp.id(5),'M011 synthetic reviewer');
INSERT INTO public.sources(id,source_key,source_type,title) VALUES(pg_temp.id(6),'M011-SOURCE','OTHER','Synthetic source');
INSERT INTO public.source_versions(id,source_id,version_key) VALUES(pg_temp.id(7),pg_temp.id(6),'M011-V1');
INSERT INTO public.source_import_batches(id,source_version_id,import_batch_key,artifact_checksum,checksum_algorithm,import_method,import_tool,import_tool_version)
  VALUES(pg_temp.id(8),pg_temp.id(7),'M011-BATCH','synthetic','SHA256','TEST','TEST','1');
INSERT INTO public.source_entries(id,source_version_id,import_batch_id,original_form,raw_dialect_label,source_entry_checksum)
  VALUES(pg_temp.id(9),pg_temp.id(7),pg_temp.id(8),'Exact Synthetic Form','Unresolved test label','synthetic-entry');
INSERT INTO public.linguistic_evidence(id,source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,extraction_method)
  SELECT pg_temp.id(10),pg_temp.id(7),id,'DIALECT','fixture:1','Synthetic morphology evidence','IMPORTED','HUMAN_MANUAL'
  FROM public.linguistic_evidence_types WHERE evidence_type_key='GRAPHEME_PHONEME_RULE';
SELECT pg_temp.ok('SQL-07 evidence import creates no lexemes',NOT EXISTS(SELECT 1 FROM public.lexemes));
UPDATE public.linguistic_evidence SET verification_status='VERIFIED',reviewed_by=pg_temp.id(5),reviewed_at=now() WHERE id=pg_temp.id(10);
SELECT pg_temp.ok('SQL-07 human evidence verification creates no lexemes',NOT EXISTS(SELECT 1 FROM public.lexemes));

INSERT INTO public.lexemes(id,lexeme_key,language_id,identity_dialect_id,provenance_origin) VALUES
  (pg_temp.id(11),'M011-L1',pg_temp.id(1),NULL,'IMPORTED'),
  (pg_temp.id(12),'M011-L2',pg_temp.id(2),NULL,'HUMAN'),
  (pg_temp.id(13),'M011-L3',NULL,pg_temp.id(3),'HUMAN'),
  (pg_temp.id(14),'M011-L4',NULL,pg_temp.id(4),'HUMAN'),
  (pg_temp.id(15),'M011-L5',NULL,pg_temp.id(3),'HUMAN');
SELECT pg_temp.ok('SQL-01 language identity',EXISTS(SELECT 1 FROM public.lexemes WHERE id=pg_temp.id(11)));
SELECT pg_temp.ok('SQL-01 parentless variety identity',EXISTS(SELECT 1 FROM public.lexemes l JOIN public.dialects d ON d.id=l.identity_dialect_id WHERE l.id=pg_temp.id(13) AND d.language_id IS NULL));
SELECT pg_temp.fails('SQL-01 both scopes',$q$INSERT INTO public.lexemes(lexeme_key,language_id,identity_dialect_id,provenance_origin) VALUES('bad',pg_temp.id(1),pg_temp.id(3),'HUMAN')$q$,'23514');
SELECT pg_temp.fails('SQL-01 no scope',$q$INSERT INTO public.lexemes(lexeme_key,provenance_origin) VALUES('bad','HUMAN')$q$,'23514');
SELECT pg_temp.fails('SQL-01 duplicate opaque key',$q$INSERT INTO public.lexemes(lexeme_key,language_id,provenance_origin) VALUES('M011-L1',pg_temp.id(1),'HUMAN')$q$,'23505');
SELECT pg_temp.fails('SQL-01 immutable identity scope',$q$UPDATE public.lexemes SET language_id=pg_temp.id(2) WHERE id=pg_temp.id(11)$q$,'23514');
SELECT pg_temp.fails('SQL-01 invalid lifecycle',$q$UPDATE public.lexemes SET lifecycle_status='FAKE' WHERE id=pg_temp.id(11)$q$,'23514');

INSERT INTO public.lexeme_forms(id,form_key,lexeme_id,representation_text,representation_system,form_role,provenance_origin)
  SELECT pg_temp.id(100+n),'M011-F'||n,pg_temp.id(11+n),'Same synthetic string','ORTHOGRAPHIC','LEMMA','IMPORTED' FROM generate_series(0,4) n;
SELECT pg_temp.ok('SQL-02 identical spelling preserves languages varieties homographs',(SELECT count(DISTINCT lexeme_id)=5 FROM public.lexeme_forms WHERE representation_text='Same synthetic string'));
SELECT pg_temp.ok('SQL-02 no automatic relationships',NOT EXISTS(SELECT 1 FROM public.lexical_relationships));
SELECT pg_temp.fails('SQL-02 orthography needs a version',$q$UPDATE public.lexeme_forms SET orthography_key='test' WHERE id=pg_temp.id(100)$q$,'23514');
UPDATE public.lexeme_forms SET orthography_key='M011-ORTH',orthography_version='1' WHERE id=pg_temp.id(100);

INSERT INTO public.lexical_senses(id,sense_key,lexeme_id,provenance_origin) VALUES
  (pg_temp.id(200),'M011-S1',pg_temp.id(11),'HUMAN'),(pg_temp.id(201),'M011-S2',pg_temp.id(11),'HUMAN');
INSERT INTO public.lexical_sense_revisions(id,sense_id,revision_number,definition,definition_language_id,revision_reason,provenance_origin)
  VALUES(pg_temp.id(300),pg_temp.id(200),1,'Synthetic definition one',pg_temp.id(2),'fixture','HUMAN'),
        (pg_temp.id(301),pg_temp.id(201),1,'Synthetic definition two',pg_temp.id(1),'fixture','HUMAN');
SELECT pg_temp.ok('SQL-02 polysemy preserved',(SELECT count(*)=2 FROM public.lexical_senses WHERE lexeme_id=pg_temp.id(11)));
SELECT pg_temp.ok('SQL-05 definition differs from lexeme language',(SELECT definition_language_id=pg_temp.id(2) FROM public.lexical_sense_revisions WHERE id=pg_temp.id(300)));
SELECT pg_temp.fails('SQL-05 missing definition scope',$q$INSERT INTO public.lexical_sense_revisions(sense_id,revision_number,definition,revision_reason,provenance_origin) VALUES(pg_temp.id(200),2,'Test','fixture','HUMAN')$q$,'23514');
SELECT pg_temp.fails('SQL-05 both definition scopes',$q$UPDATE public.lexical_sense_revisions SET definition_dialect_id=pg_temp.id(3) WHERE id=pg_temp.id(300)$q$,'23514');
INSERT INTO public.concepts(id,concept_key,definition_en) VALUES(pg_temp.id(20),'M011-C1','Legacy fixture one'),(pg_temp.id(21),'M011-C2','Legacy fixture two');
SELECT pg_temp.ok('SQL-11 no fabricated concept provenance',(SELECT num_nonnulls(provenance_origin,lifecycle_status,verification_status,sealed_at)=0 FROM public.concepts WHERE id=pg_temp.id(20)));
SELECT pg_temp.fails('SQL-11 partial concept metadata',$q$UPDATE public.concepts SET provenance_origin='HUMAN' WHERE id=pg_temp.id(20)$q$,'23514');
INSERT INTO public.concept_revisions(id,concept_id,revision_number,definition,definition_dialect_id,revision_reason,provenance_origin)
  VALUES(pg_temp.id(400),pg_temp.id(20),1,'Synthetic variety definition',pg_temp.id(3),'fixture','HUMAN'),
        (pg_temp.id(401),pg_temp.id(21),1,'Synthetic other definition',pg_temp.id(4),'fixture','HUMAN');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT pg_temp.fails('SQL-03 foreign current form',$q$UPDATE public.lexemes SET current_lemma_form_id=pg_temp.id(101) WHERE id=pg_temp.id(11)$q$,'23503');
SELECT pg_temp.fails('SQL-03 foreign sense revision',$q$UPDATE public.lexical_senses SET current_revision_id=pg_temp.id(301) WHERE id=pg_temp.id(200)$q$,'23503');
SELECT pg_temp.fails('SQL-03 foreign concept revision',$q$UPDATE public.concepts SET lifecycle_status='PROVISIONAL',verification_status='UNVERIFIED',provenance_origin='HUMAN',current_revision_id=pg_temp.id(401) WHERE id=pg_temp.id(20)$q$,'23503');
UPDATE public.lexemes SET current_lemma_form_id=pg_temp.id(100) WHERE id=pg_temp.id(11);
UPDATE public.lexical_senses SET current_revision_id=pg_temp.id(300) WHERE id=pg_temp.id(200);
UPDATE public.concepts SET lifecycle_status='PROVISIONAL',verification_status='UNVERIFIED',provenance_origin='HUMAN',current_revision_id=pg_temp.id(400) WHERE id=pg_temp.id(20);
SELECT pg_temp.ok('SQL-03 owned current pointers accepted',true);

INSERT INTO public.form_normalizations(id,normalization_key,source_entry_id,normalized_text,scope_language_id,normalization_policy_version,normalization_method,provenance_origin,rationale) VALUES
  (pg_temp.id(500),'M011-N1',pg_temp.id(9),'Synthetic normalized',pg_temp.id(1),'1','TEST','IMPORTED','fixture'),
  (pg_temp.id(501),'M011-N2',pg_temp.id(9),'Synthetic normalized',pg_temp.id(2),'1','TEST','IMPORTED','fixture');
SELECT pg_temp.ok('SQL-06 independent scoped normalization',(SELECT count(*)=2 FROM public.form_normalizations));
SELECT pg_temp.fails('SQL-06 duplicate scoped normalization',$q$INSERT INTO public.form_normalizations(normalization_key,source_entry_id,normalized_text,scope_language_id,normalization_policy_version,normalization_method,provenance_origin,rationale) VALUES('duplicate',pg_temp.id(9),'Synthetic normalized',pg_temp.id(1),'1','TEST','IMPORTED','fixture')$q$,'23505');
SELECT pg_temp.ok('SQL-06 exact original retained',(SELECT original_form='Exact Synthetic Form' AND raw_dialect_label='Unresolved test label' FROM public.source_entries WHERE id=pg_temp.id(9)));

INSERT INTO public.lexeme_dialects(id,lexeme_id,dialect_id,role,provenance_origin) VALUES(pg_temp.id(600),pg_temp.id(13),pg_temp.id(3),'PRIMARY','HUMAN');
INSERT INTO public.sense_dialects(id,sense_id,dialect_id,role,provenance_origin) VALUES(pg_temp.id(601),pg_temp.id(200),pg_temp.id(3),'ATTESTED_IN','HUMAN');
INSERT INTO public.sense_concepts(id,sense_id,concept_id,provenance_origin,rationale) VALUES(pg_temp.id(602),pg_temp.id(200),pg_temp.id(20),'HUMAN','fixture'),(pg_temp.id(603),pg_temp.id(200),pg_temp.id(21),'HUMAN','competing fixture');
INSERT INTO public.lexical_relationships(id,source_lexeme_id,target_lexeme_id,relationship_type,provenance_origin) VALUES(pg_temp.id(604),pg_temp.id(11),pg_temp.id(12),'COGNATE_WITH','HUMAN');
INSERT INTO public.form_relationships(id,source_form_id,target_form_id,relationship_type,provenance_origin) VALUES(pg_temp.id(605),pg_temp.id(100),pg_temp.id(101),'ORTHOGRAPHIC_VARIANT','HUMAN');
INSERT INTO public.lexical_attestations(id,attestation_key,source_entry_id,lexeme_id,claim_type,evidence_role,provenance_origin) VALUES
  (pg_temp.id(606),'M011-A1',pg_temp.id(9),pg_temp.id(11),'LEXEME_IDENTITY','SUPPORTS','IMPORTED'),
  (pg_temp.id(607),'M011-A2',pg_temp.id(9),pg_temp.id(11),'LEXEME_IDENTITY','CONTRADICTS','IMPORTED');
SELECT pg_temp.ok('SQL-07 contradictory attestations retained',(SELECT count(*)=2 FROM public.lexical_attestations));
SELECT pg_temp.fails('SQL-07 no attestation target',$q$INSERT INTO public.lexical_attestations(attestation_key,source_entry_id,claim_type,evidence_role,provenance_origin) VALUES('bad',pg_temp.id(9),'FORM','SUPPORTS','HUMAN')$q$,'23514');
SELECT pg_temp.fails('SQL-07 two attestation targets',$q$UPDATE public.lexical_attestations SET form_id=pg_temp.id(100) WHERE id=pg_temp.id(606)$q$,'23514');
SELECT pg_temp.fails('SQL-07 missing source entry',$q$UPDATE public.lexical_attestations SET source_entry_id=pg_temp.id(9999) WHERE id=pg_temp.id(606)$q$,'23514');
SELECT pg_temp.fails('SQL-07 missing inserted source FK',$q$INSERT INTO public.lexical_attestations(attestation_key,source_entry_id,lexeme_id,claim_type,evidence_role,provenance_origin) VALUES('missing-source',pg_temp.id(9999),pg_temp.id(11),'FORM','SUPPORTS','HUMAN')$q$,'23503');
INSERT INTO public.lexical_linguistic_evidence(id,evidence_id,lexeme_id,evidence_role) VALUES(pg_temp.id(608),pg_temp.id(10),pg_temp.id(11),'MORPHOLOGY');
SELECT pg_temp.fails('SQL-07 evidence association immutable',$q$UPDATE public.lexical_linguistic_evidence SET evidence_role='TONE' WHERE id=pg_temp.id(608)$q$,'23514');

-- SQL-04: exercise the same guard on every actual row type (including concepts).
DO $$ DECLARE t text; state_col text; patch jsonb; saved timestamptz; stmt text; BEGIN
  FOR t,state_col,patch IN SELECT * FROM (VALUES
    ('lexemes','verification_status','{"language_id":"00000000-0000-4000-8000-000000000002"}'::jsonb),
    ('lexeme_dialects','verification_status','{"role":"SHARED"}'::jsonb),
    ('lexeme_forms','verification_status','{"representation_text":"changed"}'::jsonb),
    ('form_normalizations','verification_status','{"normalized_text":"changed"}'::jsonb),
    ('lexical_senses','verification_status','{"lexeme_id":"00000000-0000-4000-8000-000000000012"}'::jsonb),
    ('lexical_sense_revisions','verification_status','{"definition":"changed"}'::jsonb),
    ('sense_dialects','verification_status','{"role":"CONTRASTS_WITH"}'::jsonb),
    ('sense_concepts','mapping_status','{"rationale":"changed"}'::jsonb),
    ('lexical_attestations','verification_status','{"notes":"changed"}'::jsonb),
    ('lexical_relationships','verification_status','{"relationship_type":"RELATED_TO"}'::jsonb),
    ('form_relationships','verification_status','{"relationship_type":"PHONOLOGICAL_VARIANT"}'::jsonb),
    ('concept_revisions','verification_status','{"definition":"changed"}'::jsonb),
    ('concepts','verification_status','{"definition_en":"changed"}'::jsonb)
  ) AS v(t,s,p) LOOP
    -- Select one row only, avoiding competing sense-concept verification.
    EXECUTE format('UPDATE public.%I SET %I=''VERIFIED'',reviewed_by=pg_temp.id(5),reviewed_at=now() WHERE id=(SELECT min(id::text)::uuid FROM public.%I)',t,state_col,t);
    EXECUTE format('SELECT sealed_at FROM public.%I ORDER BY id LIMIT 1',t) INTO saved;
    PERFORM pg_temp.ok('SQL-04 sealed '||t,saved IS NOT NULL);
    EXECUTE format('UPDATE public.%I SET %I=''DISPUTED'' WHERE sealed_at IS NOT NULL',t,state_col);
    EXECUTE format('SELECT sealed_at FROM public.%I ORDER BY id LIMIT 1',t) INTO saved;
    PERFORM pg_temp.ok('SQL-04 downgrade retains seal '||t,saved IS NOT NULL);
    SELECT format('UPDATE public.%I SET %I=%L WHERE sealed_at IS NOT NULL',t,key,value) INTO stmt FROM jsonb_each_text(patch);
    PERFORM pg_temp.fails('SQL-04 semantic mutation '||t,stmt,'23514');
    PERFORM pg_temp.fails('SQL-04 provenance mutation '||t,format('UPDATE public.%I SET provenance_origin=''MACHINE_GENERATED'' WHERE sealed_at IS NOT NULL',t),'23514');
    PERFORM pg_temp.fails('SQL-04 clear seal '||t,format('UPDATE public.%I SET sealed_at=NULL WHERE sealed_at IS NOT NULL',t),'23514');
    PERFORM pg_temp.fails('SQL-04 change seal '||t,format('UPDATE public.%I SET sealed_at=now()+interval ''1 second'' WHERE sealed_at IS NOT NULL',t),'23514');
    PERFORM pg_temp.fails('SQL-04 delete history '||t,format('DELETE FROM public.%I WHERE sealed_at IS NOT NULL',t),'23514');
  END LOOP;
END $$;
SELECT pg_temp.fails('SQL-04 forged insert seal',$q$INSERT INTO public.lexemes(lexeme_key,language_id,provenance_origin,sealed_at) VALUES('forged',pg_temp.id(1),'HUMAN',now())$q$,'23514');
INSERT INTO public.lexemes(lexeme_key,language_id,provenance_origin,verification_status,reviewed_by,reviewed_at)
  VALUES('M011-VERIFIED-INSERT',pg_temp.id(1),'HUMAN','VERIFIED',pg_temp.id(5),now());
SELECT pg_temp.ok('SQL-04 verified insert server seal',(SELECT sealed_at IS NOT NULL FROM public.lexemes WHERE lexeme_key='M011-VERIFIED-INSERT'));
SELECT pg_temp.fails('SQL-04 sealed claimed JSON mutation',$q$UPDATE public.lexical_attestations SET claimed_value='{"changed":true}'::jsonb WHERE id=pg_temp.id(606)$q$,'23514');
SELECT pg_temp.fails('SQL-04 missing attribution',$q$UPDATE public.lexeme_forms SET verification_status='VERIFIED' WHERE id=pg_temp.id(101)$q$,'23514');
SELECT pg_temp.fails('SQL-04 immutable original reviewer',$q$UPDATE public.lexeme_forms SET reviewed_by=NULL,reviewed_at=NULL WHERE id=pg_temp.id(100)$q$,'23514');
SELECT pg_temp.fails('SQL-04 evidence deletion',$q$DELETE FROM public.lexical_linguistic_evidence WHERE id=pg_temp.id(608)$q$,'23514');
INSERT INTO public.lexical_sense_revisions(sense_id,revision_number,definition,definition_language_id,revision_reason,provenance_origin) VALUES(pg_temp.id(200),2,'Synthetic correction',pg_temp.id(1),'correct prior analysis','HUMAN');
SELECT pg_temp.ok('SQL-04 replacement revision possible',(SELECT count(*)=2 FROM public.lexical_sense_revisions WHERE sense_id=pg_temp.id(200)));

UPDATE public.sense_concepts SET mapping_status='VERIFIED' WHERE id=pg_temp.id(602);
SELECT pg_temp.fails('SQL-08 second current verified concept',$q$UPDATE public.sense_concepts SET mapping_status='VERIFIED',reviewed_by=pg_temp.id(5),reviewed_at=now() WHERE id=pg_temp.id(603)$q$,'23505');
SELECT pg_temp.fails('SQL-09 reversed symmetric relationship',$q$INSERT INTO public.lexical_relationships(source_lexeme_id,target_lexeme_id,relationship_type,provenance_origin) VALUES(pg_temp.id(12),pg_temp.id(11),'COGNATE_WITH','HUMAN')$q$,'23514');
SELECT pg_temp.fails('SQL-09 self relationship',$q$INSERT INTO public.form_relationships(source_form_id,target_form_id,relationship_type,provenance_origin) VALUES(pg_temp.id(100),pg_temp.id(100),'BORROWED_FORM','HUMAN')$q$,'23514');
SELECT pg_temp.fails('SQL-09 nonexistent endpoint',$q$INSERT INTO public.lexical_relationships(source_lexeme_id,target_lexeme_id,relationship_type,provenance_origin) VALUES(pg_temp.id(12),pg_temp.id(9999),'BORROWED_FROM','HUMAN')$q$,'23503');
INSERT INTO public.lexical_relationships(source_lexeme_id,target_lexeme_id,relationship_type,provenance_origin) VALUES(pg_temp.id(12),pg_temp.id(11),'BORROWED_FROM','HUMAN');
SELECT pg_temp.ok('SQL-09 directional borrowing accepted',true);

-- SQL-13: cycles, same-parent replacement and irreversible edges.
UPDATE public.lexemes SET lifecycle_status='SUPERSEDED',superseded_by=pg_temp.id(15) WHERE id=pg_temp.id(13);
SELECT pg_temp.fails('SQL-13 successor cycle',$q$UPDATE public.lexemes SET lifecycle_status='SUPERSEDED',superseded_by=pg_temp.id(13) WHERE id=pg_temp.id(15)$q$,'23514');
SELECT pg_temp.fails('SQL-13 rewritten successor',$q$UPDATE public.lexemes SET lifecycle_status='PROVISIONAL',superseded_by=NULL WHERE id=pg_temp.id(13)$q$,'23514');
SELECT pg_temp.fails('SQL-13 different-parent form replacement',$q$UPDATE public.lexeme_forms SET replacement_form_id=pg_temp.id(101),deprecated_at=now() WHERE id=pg_temp.id(100)$q$,'23514');
INSERT INTO public.lexeme_forms(id,form_key,lexeme_id,representation_text,representation_system,form_role,provenance_origin) VALUES(pg_temp.id(105),'M011-F5',pg_temp.id(11),'Synthetic corrected form','ORTHOGRAPHIC','LEMMA','HUMAN');
UPDATE public.lexeme_forms SET replacement_form_id=pg_temp.id(105),deprecated_at=now() WHERE id=pg_temp.id(100);
SELECT pg_temp.ok('SQL-13 same-parent replacement accepted',true);
SELECT pg_temp.fails('SQL-13 form replacement cycle',$q$UPDATE public.lexeme_forms SET replacement_form_id=pg_temp.id(100),deprecated_at=now() WHERE id=pg_temp.id(105)$q$,'23514');
SELECT pg_temp.fails('SQL-13 retirement timestamp rewrite',$q$UPDATE public.lexeme_forms SET deprecated_at=now()+interval '1 day' WHERE id=pg_temp.id(100)$q$,'23514');
SELECT pg_temp.fails('SQL-13 superseded lifecycle reversal',$q$UPDATE public.lexemes SET lifecycle_status='ACTIVE' WHERE id=pg_temp.id(13)$q$,'23514');
UPDATE public.sense_concepts SET superseded_at=now(),superseded_by=pg_temp.id(603) WHERE id=pg_temp.id(602);
SELECT pg_temp.fails('SQL-13 mapping cycle',$q$UPDATE public.sense_concepts SET superseded_at=now(),superseded_by=pg_temp.id(602) WHERE id=pg_temp.id(603)$q$,'23514');
SELECT pg_temp.fails('SQL-13 unsealed successor cannot reparent',$q$UPDATE public.sense_concepts SET sense_id=pg_temp.id(201) WHERE id=pg_temp.id(603)$q$,'23514');
INSERT INTO public.lexeme_dialects(id,lexeme_id,dialect_id,role,provenance_origin) VALUES(pg_temp.id(610),pg_temp.id(13),pg_temp.id(3),'ATTESTED_IN','HUMAN');
UPDATE public.lexeme_dialects SET superseded_at=now(),superseded_by=pg_temp.id(610) WHERE id=pg_temp.id(600);
SELECT pg_temp.fails('SQL-13 lexeme scope cycle',$q$UPDATE public.lexeme_dialects SET superseded_at=now(),superseded_by=pg_temp.id(600) WHERE id=pg_temp.id(610)$q$,'23514');
INSERT INTO public.sense_dialects(id,sense_id,dialect_id,role,provenance_origin) VALUES(pg_temp.id(611),pg_temp.id(200),pg_temp.id(3),'RESTRICTED_TO','HUMAN');
UPDATE public.sense_dialects SET superseded_at=now(),superseded_by=pg_temp.id(611) WHERE id=pg_temp.id(601);
SELECT pg_temp.fails('SQL-13 sense scope cycle',$q$UPDATE public.sense_dialects SET superseded_at=now(),superseded_by=pg_temp.id(601) WHERE id=pg_temp.id(611)$q$,'23514');
INSERT INTO public.lexical_linguistic_evidence(id,evidence_id,lexeme_id,evidence_role) VALUES(pg_temp.id(612),pg_temp.id(10),pg_temp.id(11),'TONE');
UPDATE public.lexical_linguistic_evidence SET superseded_at=now(),superseded_by=pg_temp.id(612) WHERE id=pg_temp.id(608);
SELECT pg_temp.fails('SQL-13 evidence association cycle',$q$UPDATE public.lexical_linguistic_evidence SET superseded_at=now(),superseded_by=pg_temp.id(608) WHERE id=pg_temp.id(612)$q$,'23514');
INSERT INTO public.lexical_relationships(id,source_lexeme_id,target_lexeme_id,relationship_type,provenance_origin) VALUES(pg_temp.id(613),pg_temp.id(11),pg_temp.id(12),'RELATED_TO','HUMAN');
UPDATE public.lexical_relationships SET superseded_at=now(),superseded_by=pg_temp.id(613) WHERE id=pg_temp.id(604);
SELECT pg_temp.fails('SQL-13 lexeme relationship cycle',$q$UPDATE public.lexical_relationships SET superseded_at=now(),superseded_by=pg_temp.id(604) WHERE id=pg_temp.id(613)$q$,'23514');
INSERT INTO public.form_relationships(id,source_form_id,target_form_id,relationship_type,provenance_origin) VALUES(pg_temp.id(614),pg_temp.id(100),pg_temp.id(101),'PHONOLOGICAL_VARIANT','HUMAN');
UPDATE public.form_relationships SET superseded_at=now(),superseded_by=pg_temp.id(614) WHERE id=pg_temp.id(605);
SELECT pg_temp.fails('SQL-13 form relationship cycle',$q$UPDATE public.form_relationships SET superseded_at=now(),superseded_by=pg_temp.id(605) WHERE id=pg_temp.id(614)$q$,'23514');
UPDATE public.lexical_senses SET lifecycle_status='SUPERSEDED',superseded_by=pg_temp.id(201) WHERE id=pg_temp.id(200);
SELECT pg_temp.fails('SQL-13 sense identity cycle',$q$UPDATE public.lexical_senses SET lifecycle_status='SUPERSEDED',superseded_by=pg_temp.id(200) WHERE id=pg_temp.id(201)$q$,'23514');
UPDATE public.concepts SET lifecycle_status='SUPERSEDED',superseded_by=pg_temp.id(21) WHERE id=pg_temp.id(20);
SELECT pg_temp.fails('SQL-13 concept cycle',$q$UPDATE public.concepts SET lifecycle_status='SUPERSEDED',verification_status='UNVERIFIED',provenance_origin='HUMAN',superseded_by=pg_temp.id(20) WHERE id=pg_temp.id(21)$q$,'23514');

-- The circular current-form FK really is deferrable, not only parent-checked.
SET CONSTRAINTS ALL DEFERRED;
INSERT INTO public.lexemes(id,lexeme_key,language_id,current_lemma_form_id,provenance_origin)
  VALUES(pg_temp.id(700),'M011-DEFERRED',pg_temp.id(1),pg_temp.id(701),'HUMAN');
INSERT INTO public.lexeme_forms(id,form_key,lexeme_id,representation_text,representation_system,form_role,provenance_origin)
  VALUES(pg_temp.id(701),'M011-DEFERRED-F',pg_temp.id(700),'Synthetic deferred form','ORTHOGRAPHIC','LEMMA','HUMAN');
SET CONSTRAINTS ALL IMMEDIATE;
SELECT pg_temp.ok('SQL-03 circular insertion deferred until child exists',true);

-- SQL-10: effective privileges, RLS, actual access attempts, function and view surface.
DO $$ DECLARE t text; r text; p text; BEGIN
  FOREACH t IN ARRAY ARRAY['lexemes','lexeme_dialects','lexeme_forms','form_normalizations','lexical_senses','lexical_sense_revisions','sense_dialects','sense_concepts','lexical_attestations','lexical_linguistic_evidence','lexical_relationships','form_relationships','concept_revisions'] LOOP
    PERFORM pg_temp.ok('SQL-10 RLS '||t,(SELECT relrowsecurity FROM pg_class WHERE oid=('public.'||t)::regclass));
    PERFORM pg_temp.ok('SQL-10 no policies '||t,NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=t));
    FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
      FOREACH p IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] LOOP
        PERFORM pg_temp.ok('SQL-10 deny '||r||' '||p||' '||t,NOT has_table_privilege(r,'public.'||t,p));
      END LOOP;
    END LOOP;
    FOREACH p IN ARRAY ARRAY['SELECT','INSERT','UPDATE'] LOOP
      PERFORM pg_temp.ok('SQL-10 service '||p||' '||t,has_table_privilege('service_role','public.'||t,p));
    END LOOP;
    PERFORM pg_temp.ok('SQL-10 no service deletion '||t,NOT has_table_privilege('service_role','public.'||t,'DELETE') AND NOT has_table_privilege('service_role','public.'||t,'TRUNCATE'));
    PERFORM pg_temp.fails('SQL-10 owner truncate guard '||t,format('TRUNCATE public.%I CASCADE',t),'23514');
  END LOOP;
  FOREACH r IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
    FOREACH p IN ARRAY ARRAY['tafsiri_guard_lexical_record','tafsiri_lock_lexical_successor','tafsiri_check_lexical_successor'] LOOP
      PERFORM pg_temp.ok('SQL-10 no direct function execution '||r||p,NOT has_function_privilege(r,'public.'||p||'()','EXECUTE'));
    END LOOP;
  END LOOP;
END $$;
SET LOCAL ROLE anon;
SELECT pg_temp.fails('SQL-10 anonymous read',$q$SELECT * FROM public.lexemes$q$,'42501');
SELECT pg_temp.fails('SQL-10 anonymous write',$q$INSERT INTO public.lexemes(lexeme_key,language_id,provenance_origin) VALUES('anon',pg_temp.id(1),'HUMAN')$q$,'42501');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT pg_temp.fails('SQL-10 reviewer read',$q$SELECT * FROM public.concept_revisions$q$,'42501');
SELECT pg_temp.fails('SQL-10 reviewer RPC',$q$SELECT public.tafsiri_guard_lexical_record()$q$,'42501');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT pg_temp.fails('SQL-10 service cannot delete',$q$DELETE FROM public.lexeme_forms$q$,'42501');
SELECT pg_temp.fails('SQL-10 service cannot bypass seal',$q$UPDATE public.lexeme_forms SET representation_text='bypass' WHERE id=pg_temp.id(100)$q$,'23514');
RESET ROLE;
SELECT pg_temp.ok('SQL-10 no new definer functions',NOT EXISTS(SELECT 1 FROM pg_proc WHERE proname IN ('tafsiri_guard_lexical_record','tafsiri_lock_lexical_successor','tafsiri_check_lexical_successor') AND prosecdef));
SELECT pg_temp.ok('SQL-10 no views on new canonical tables',NOT EXISTS(
  SELECT 1 FROM pg_depend d JOIN pg_rewrite rw ON rw.oid=d.objid JOIN pg_class v ON v.oid=rw.ev_class
  WHERE d.refobjid='public.lexemes'::regclass AND v.relkind IN ('v','m')));

-- SQL-14 does not introduce a training exporter or commercial service. Keep the
-- real rights decisions separate; never manufacture a test-only approval gate.
INSERT INTO public.source_use_policies(source_version_id,use_scope,decision,policy_version) VALUES(pg_temp.id(7),'MODEL_TRAINING','UNKNOWN','M011');
SELECT pg_temp.ok('SQL-14 verification grants no training rights',(SELECT decision='UNKNOWN' FROM public.source_use_policies WHERE source_version_id=pg_temp.id(7) AND use_scope='MODEL_TRAINING'));
SELECT pg_temp.ok('SQL-14 no commercial permission invented',NOT EXISTS(SELECT 1 FROM public.source_use_policies WHERE source_version_id=pg_temp.id(7) AND use_scope='COMMERCIAL_API' AND decision='ALLOWED'));
SELECT pg_temp.ok('SQL-14 no runtime/export objects',to_regclass('public.approved_training_exports') IS NULL AND to_regclass('public.commercial_model_releases') IS NULL);
SELECT 'Migration 011 smoke assertions passed: '||count(*) FROM m011_results;
ROLLBACK;
