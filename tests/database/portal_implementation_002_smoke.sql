\set ON_ERROR_STOP on
BEGIN;
INSERT INTO public.languages(id,name,iso_code) VALUES ('10000000-0000-0000-0000-000000000001','Test Luhya','tst');
INSERT INTO public.dialects(id,name,language_id) VALUES ('10000000-0000-0000-0000-000000000002','Luwanga','10000000-0000-0000-0000-000000000001');
INSERT INTO public.dictionary_entries(id,dialect_id,word,word_normalized,english_definition) VALUES ('10000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000002','test','test','test definition');
INSERT INTO auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at) VALUES
 ('10000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000000','authenticated','authenticated','a@test.invalid','',now()),
 ('10000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000000','authenticated','authenticated','b@test.invalid','',now());
INSERT INTO public.reviewer_profiles(id,auth_user_id,reviewer_code) VALUES
 ('10000000-0000-0000-0000-000000000020','10000000-0000-0000-0000-000000000010','TEST-A'),
 ('10000000-0000-0000-0000-000000000021','10000000-0000-0000-0000-000000000011','TEST-B');
INSERT INTO public.evaluation_studies(id,study_key,title,description,dialect_id,pipeline_version,evidence_schema_version,configuration_hash,source_artifact_hash)
 VALUES ('10000000-0000-0000-0000-000000000030','PORTAL-002-TEST','Portal test','Rollback-only test','10000000-0000-0000-0000-000000000002','test','test','test','test');
INSERT INTO public.evaluation_items(id,study_id,item_number,dictionary_entry_id,source_snapshot,source_hash,sampling_group)
 VALUES ('10000000-0000-0000-0000-000000000040','10000000-0000-0000-0000-000000000030',1,'10000000-0000-0000-0000-000000000003','{"word":"test"}','test','bucket_A');
INSERT INTO public.evaluation_item_pipeline_snapshots(evaluation_item_id,pipeline_snapshot,pipeline_hash)
 VALUES ('10000000-0000-0000-0000-000000000040','{"bucket":"A"}','test');
UPDATE public.evaluation_studies SET study_status='active' WHERE id='10000000-0000-0000-0000-000000000030';
INSERT INTO public.reviewer_study_participation(id,reviewer_id,study_id) VALUES
 ('10000000-0000-0000-0000-000000000050','10000000-0000-0000-0000-000000000020','10000000-0000-0000-0000-000000000030'),
 ('10000000-0000-0000-0000-000000000051','10000000-0000-0000-0000-000000000021','10000000-0000-0000-0000-000000000030');
INSERT INTO public.reviewer_dialect_expertise(reviewer_id,dialect_id,expertise_level) VALUES
 ('10000000-0000-0000-0000-000000000020','10000000-0000-0000-0000-000000000002','familiar'),
 ('10000000-0000-0000-0000-000000000021','10000000-0000-0000-0000-000000000002','fluent');
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000010',true);
SET LOCAL ROLE authenticated;
DO $$BEGIN IF (SELECT count(*) FROM public.reviewer_profiles)<>1 OR (SELECT count(*) FROM public.reviewer_study_participation)<>1 THEN RAISE EXCEPTION 'Reviewer A isolation failed'; END IF; END$$;
RESET ROLE;
UPDATE public.reviewer_study_participation SET participation_information_version='HE001-PARTICIPATION-V1' WHERE id='10000000-0000-0000-0000-000000000050';
UPDATE public.reviewer_study_participation SET onboarding_completed_at='1970-01-01' WHERE id='10000000-0000-0000-0000-000000000050';
UPDATE public.reviewer_study_participation SET participation_status='active' WHERE id='10000000-0000-0000-0000-000000000050';
INSERT INTO public.review_assignments(id,evaluation_item_id,reviewer_id) VALUES ('10000000-0000-0000-0000-000000000060','10000000-0000-0000-0000-000000000040','10000000-0000-0000-0000-000000000020');
INSERT INTO public.review_annotations(id,assignment_id,primary_decision) VALUES ('10000000-0000-0000-0000-000000000070','10000000-0000-0000-0000-000000000060','ACCEPT_SIMPLE');
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000010',true); SET LOCAL ROLE authenticated;
DO $$BEGIN IF (SELECT count(*) FROM public.evaluation_item_pipeline_snapshots)<>0 THEN RAISE EXCEPTION 'Pipeline visible before Stage A'; END IF; END$$; RESET ROLE;
UPDATE public.review_annotations SET annotation_status='primary_submitted' WHERE id='10000000-0000-0000-0000-000000000070';
DO $$BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.review_annotations WHERE id='10000000-0000-0000-0000-000000000070' AND primary_submitted_at IS NOT NULL AND pipeline_revealed_at IS NOT NULL) THEN RAISE EXCEPTION 'Stage A timestamps missing'; END IF;
 BEGIN UPDATE public.review_annotations SET primary_decision='NEEDS_EXPERT' WHERE id='10000000-0000-0000-0000-000000000070'; RAISE EXCEPTION 'Stage A mutation unexpectedly allowed'; EXCEPTION WHEN OTHERS THEN IF SQLERRM='Stage A mutation unexpectedly allowed' THEN RAISE; END IF; END;
END$$;
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000010',true); SET LOCAL ROLE authenticated;
DO $$BEGIN IF (SELECT count(*) FROM public.evaluation_item_pipeline_snapshots)<>1 THEN RAISE EXCEPTION 'Reviewer A pipeline reveal failed'; END IF; END$$; RESET ROLE;
SELECT set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000011',true); SET LOCAL ROLE authenticated;
DO $$BEGIN IF (SELECT count(*) FROM public.review_assignments)<>0 OR (SELECT count(*) FROM public.review_annotations)<>0 OR (SELECT count(*) FROM public.evaluation_item_pipeline_snapshots)<>0 THEN RAISE EXCEPTION 'Reviewer B isolation failed'; END IF; END$$; RESET ROLE;
UPDATE public.review_annotations SET pipeline_bucket_correct='YES',pipeline_ambiguity_correct='YES',annotation_status='submitted' WHERE id='10000000-0000-0000-0000-000000000070';
DO $$BEGIN IF NOT EXISTS(SELECT 1 FROM public.review_assignments WHERE id='10000000-0000-0000-0000-000000000060' AND assignment_status='completed' AND completed_at IS NOT NULL) THEN RAISE EXCEPTION 'assignment not completed'; END IF; END$$;
UPDATE public.reviewer_study_participation SET participation_status='completed' WHERE id='10000000-0000-0000-0000-000000000050';
ROLLBACK;
