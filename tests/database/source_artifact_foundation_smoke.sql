BEGIN;

DO $$
BEGIN
  IF (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN (
    'source_artifacts','source_version_artifacts','source_artifact_acquisitions',
    'source_artifact_locations','source_artifact_sets','source_artifact_set_members'
  )) <> 6 THEN RAISE EXCEPTION 'Migration 010 tables missing'; END IF;
  IF EXISTS (SELECT 1 FROM public.source_artifacts) THEN
    RAISE EXCEPTION 'Migration 010 seeded artifact data';
  END IF;
  IF EXISTS (SELECT 1 FROM public.source_import_batches WHERE source_artifact_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Migration 010 backfilled historical batches';
  END IF;
END$$;

INSERT INTO public.contributors(id,name)
VALUES ('a0000000-0000-4000-8000-000000000001','Migration 010 test provider');

INSERT INTO public.sources(id,source_key,source_type,title) VALUES
  ('a0000000-0000-4000-8000-000000000010','M010-TEST-ONE','DICTIONARY','Artifact test source one'),
  ('a0000000-0000-4000-8000-000000000011','M010-TEST-TWO','DICTIONARY','Artifact test source two');
INSERT INTO public.source_versions(id,source_id,version_key) VALUES
  ('a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000010','VERSION-ONE'),
  ('a0000000-0000-4000-8000-000000000021','a0000000-0000-4000-8000-000000000011','VERSION-TWO');

INSERT INTO public.source_rights(id,source_version_id,rights_status)
VALUES ('a0000000-0000-4000-8000-000000000030','a0000000-0000-4000-8000-000000000020','UNKNOWN');
INSERT INTO public.source_use_policies(
  id,source_version_id,use_scope,decision,policy_version
) VALUES (
  'a0000000-0000-4000-8000-000000000031','a0000000-0000-4000-8000-000000000020',
  'INTERNAL_RESEARCH','UNKNOWN','M010-TEST'
);

INSERT INTO public.source_contact_events(
  id,source_version_id,contact_date,contact_method,contact_target,response_status
) VALUES (
  'a0000000-0000-4000-8000-000000000032','a0000000-0000-4000-8000-000000000020',
  CURRENT_DATE,'EMAIL','Test provider','CONTACTED'
);

INSERT INTO public.source_artifacts(
  id,artifact_key,checksum_algorithm,checksum,byte_size,media_type,page_count
) VALUES
  ('a0000000-0000-4000-8000-000000000101','ART_TEST_A','SHA256',repeat('a',64),100,'application/pdf',10),
  ('a0000000-0000-4000-8000-000000000102','ART_TEST_B','SHA256',repeat('b',64),101,'application/pdf',10),
  ('a0000000-0000-4000-8000-000000000103','ART_TEST_C','SHA256',repeat('c',64),102,'application/pdf',10),
  ('a0000000-0000-4000-8000-000000000104','ART_TEST_D','SHA256',repeat('d',64),103,'application/pdf',10),
  ('a0000000-0000-4000-8000-000000000105','ART_TEST_E','SHA256',repeat('e',64),104,'application/pdf',10),
  ('a0000000-0000-4000-8000-000000000106','ART_TEST_F','SHA256',repeat('f',64),105,'application/pdf',10),
  ('a0000000-0000-4000-8000-000000000107','ART_TEST_ZERO','SHA256',repeat('0',64),106,'application/pdf',10);

DO $$BEGIN
  BEGIN INSERT INTO public.source_artifacts(artifact_key,checksum_algorithm,checksum,byte_size,media_type)
    VALUES ('ART_BAD_HASH','SHA256','ABC123',1,'application/pdf');
    RAISE EXCEPTION 'malformed SHA-256 accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_artifacts(artifact_key,checksum_algorithm,checksum,byte_size,media_type)
    VALUES ('ART_DUPLICATE_BINARY','SHA256',repeat('a',64),100,'application/pdf');
    RAISE EXCEPTION 'duplicate binary identity accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_artifacts(artifact_key,checksum_algorithm,checksum,byte_size,media_type)
    VALUES ('ART_TEST_A','SHA256',repeat('1',64),1,'application/pdf');
    RAISE EXCEPTION 'duplicate artifact key accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN UPDATE public.source_artifacts SET checksum=repeat('1',64) WHERE artifact_key='ART_TEST_A';
    RAISE EXCEPTION 'checksum mutation accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE public.source_artifacts SET byte_size=999 WHERE artifact_key='ART_TEST_A';
    RAISE EXCEPTION 'byte-size mutation accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE public.source_artifacts SET media_type='text/plain' WHERE artifact_key='ART_TEST_A';
    RAISE EXCEPTION 'media-type mutation accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

UPDATE public.source_artifacts SET notes='safe metadata change' WHERE artifact_key='ART_TEST_A';

INSERT INTO public.source_version_artifacts(
  id,source_version_id,source_artifact_id,artifact_role,is_preferred
) VALUES
  ('a0000000-0000-4000-8000-000000000201','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000101','RECEIVED_COPY',true),
  ('a0000000-0000-4000-8000-000000000202','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000102','REFORMATTED_COPY',false),
  ('a0000000-0000-4000-8000-000000000203','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000103','RECEIVED_COPY',false),
  ('a0000000-0000-4000-8000-000000000204','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000104','RECEIVED_COPY',false),
  ('a0000000-0000-4000-8000-000000000205','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000105','RECEIVED_COPY',false),
  ('a0000000-0000-4000-8000-000000000206','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000106','RECEIVED_COPY',false),
  ('a0000000-0000-4000-8000-000000000207','a0000000-0000-4000-8000-000000000021','a0000000-0000-4000-8000-000000000107','RECEIVED_COPY',true);

DO $$BEGIN
  BEGIN INSERT INTO public.source_version_artifacts(source_version_id,source_artifact_id,artifact_role)
    VALUES ('a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000101','ARCHIVAL_COPY');
    RAISE EXCEPTION 'duplicate version/artifact association accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_version_artifacts(source_version_id,source_artifact_id,artifact_role,is_preferred)
    VALUES ('a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000107','RECEIVED_COPY',true);
    RAISE EXCEPTION 'second preferred artifact accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  IF (SELECT count(*) FROM public.source_version_artifacts WHERE source_version_id='a0000000-0000-4000-8000-000000000020') <> 6 THEN
    RAISE EXCEPTION 'alternate binaries did not coexist on one version';
  END IF;
END$$;

INSERT INTO public.source_artifact_acquisitions(
  id,source_artifact_id,acquisition_key,acquisition_type,original_filename,
  provider_contributor_id,source_contact_event_id,acquisition_channel
) VALUES (
  'a0000000-0000-4000-8000-000000000301','a0000000-0000-4000-8000-000000000101',
  'ACQ_TEST_CONTRIBUTOR','DIRECT_RESEARCHER_PROVISION','Part5.pdf',
  'a0000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000032','EMAIL'
);
INSERT INTO public.source_artifact_acquisitions(
  id,source_artifact_id,acquisition_key,acquisition_type,original_filename,
  provider_name,acquisition_channel
) VALUES
  ('a0000000-0000-4000-8000-000000000302','a0000000-0000-4000-8000-000000000101',
   'ACQ_TEST_FALLBACK','DIRECT_RESEARCHER_PROVISION','Part5 (1).pdf','External researcher','SHARED_DRIVE'),
  ('a0000000-0000-4000-8000-000000000303','a0000000-0000-4000-8000-000000000101',
   'ACQ_TEST_REPEAT','PUBLIC_DOWNLOAD','part-five.pdf',NULL,'WEB_DOWNLOAD');

DO $$BEGIN
  BEGIN INSERT INTO public.source_artifact_acquisitions(
    source_artifact_id,acquisition_key,acquisition_type,acquisition_channel
  ) VALUES (
    'a0000000-0000-4000-8000-000000000101','ACQ_BAD_PROVIDER',
    'DIRECT_RESEARCHER_PROVISION','EMAIL'
  );
    RAISE EXCEPTION 'provider-less direct acquisition accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  IF (SELECT count(*) FROM public.source_artifact_acquisitions WHERE source_artifact_id='a0000000-0000-4000-8000-000000000101') <> 3 THEN
    RAISE EXCEPTION 'multiple acquisitions for one artifact not supported';
  END IF;
  IF (SELECT count(DISTINCT original_filename) FROM public.source_artifact_acquisitions WHERE source_artifact_id='a0000000-0000-4000-8000-000000000101') <> 3 THEN
    RAISE EXCEPTION 'multiple filenames were not preserved';
  END IF;
  IF (SELECT count(*) FROM public.source_rights) <> 1 OR (SELECT count(*) FROM public.source_use_policies) <> 1 THEN
    RAISE EXCEPTION 'acquisition changed rights or use policy';
  END IF;
END$$;

INSERT INTO public.source_artifact_locations(
  id,source_artifact_id,location_key,storage_class,location_reference,availability_status,is_primary
) VALUES
  ('a0000000-0000-4000-8000-000000000401','a0000000-0000-4000-8000-000000000101',
   'PRIVATE','PRIVATE_ARCHIVE','archive:marlo/part5','RESTRICTED',true),
  ('a0000000-0000-4000-8000-000000000402','a0000000-0000-4000-8000-000000000101',
   'PUBLIC','PUBLIC_URL','https://example.invalid/part5.pdf','AVAILABLE',false);

DO $$BEGIN
  BEGIN INSERT INTO public.source_artifact_locations(
    source_artifact_id,location_key,storage_class,location_reference,is_primary
  ) VALUES (
    'a0000000-0000-4000-8000-000000000101','SECOND_PRIMARY','OBJECT_STORAGE','object:part5',true
  );
    RAISE EXCEPTION 'second primary location accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_artifact_locations(
    source_artifact_id,location_key,storage_class,location_reference
  ) VALUES (
    'a0000000-0000-4000-8000-000000000101','LOCAL_PATH','PRIVATE_ARCHIVE','C:\\private\\part5.pdf'
  );
    RAISE EXCEPTION 'local filesystem path accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

INSERT INTO public.source_artifact_sets(
  id,artifact_set_key,source_version_id,set_type,label
) VALUES (
  'a0000000-0000-4000-8000-000000000501','NDANYI_TEST_SET',
  'a0000000-0000-4000-8000-000000000020','MULTIPART_DOCUMENT','Five-part scan'
);
INSERT INTO public.source_artifact_set_members(
  id,artifact_set_id,source_version_id,source_artifact_id,sequence_number,component_label
) VALUES
  ('a0000000-0000-4000-8000-000000000511','a0000000-0000-4000-8000-000000000501','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000101',1,'Part 1'),
  ('a0000000-0000-4000-8000-000000000512','a0000000-0000-4000-8000-000000000501','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000102',2,'Part 2'),
  ('a0000000-0000-4000-8000-000000000513','a0000000-0000-4000-8000-000000000501','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000103',3,'Part 3'),
  ('a0000000-0000-4000-8000-000000000514','a0000000-0000-4000-8000-000000000501','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000104',4,'Part 4'),
  ('a0000000-0000-4000-8000-000000000515','a0000000-0000-4000-8000-000000000501','a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000105',5,'Part 5');

DO $$BEGIN
  BEGIN INSERT INTO public.source_artifact_set_members(
    artifact_set_id,source_version_id,source_artifact_id,sequence_number
  ) VALUES (
    'a0000000-0000-4000-8000-000000000501','a0000000-0000-4000-8000-000000000020',
    'a0000000-0000-4000-8000-000000000106',5
  );
    RAISE EXCEPTION 'duplicate component sequence accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_artifact_set_members(
    artifact_set_id,source_version_id,source_artifact_id,sequence_number
  ) VALUES (
    'a0000000-0000-4000-8000-000000000501','a0000000-0000-4000-8000-000000000020',
    'a0000000-0000-4000-8000-000000000101',6
  );
    RAISE EXCEPTION 'duplicate artifact membership accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  IF (SELECT array_agg(sequence_number ORDER BY sequence_number) FROM public.source_artifact_set_members WHERE artifact_set_id='a0000000-0000-4000-8000-000000000501') <> ARRAY[1,2,3,4,5] THEN
    RAISE EXCEPTION 'multipart ordering failed';
  END IF;
END$$;

INSERT INTO public.source_import_batches(
  id,source_version_id,import_batch_key,artifact_checksum,checksum_algorithm,
  import_method,import_tool,import_tool_version
) VALUES (
  'a0000000-0000-4000-8000-000000000601','a0000000-0000-4000-8000-000000000020',
  'HISTORICAL-NULL','historical','SHA-256','legacy','legacy-tool','1'
);
INSERT INTO public.source_import_batches(
  id,source_version_id,source_artifact_id,import_batch_key,artifact_checksum,checksum_algorithm,
  import_method,import_tool,import_tool_version
) VALUES (
  'a0000000-0000-4000-8000-000000000602','a0000000-0000-4000-8000-000000000020',
  'a0000000-0000-4000-8000-000000000101','LINKED-VALID',repeat('a',64),'SHA256',
  'deterministic','test-parser','1'
);

DO $$BEGIN
  IF (SELECT source_artifact_id FROM public.source_import_batches WHERE import_batch_key='HISTORICAL-NULL') IS NOT NULL THEN
    RAISE EXCEPTION 'nullable historical artifact link failed';
  END IF;
  BEGIN INSERT INTO public.source_import_batches(
    source_version_id,source_artifact_id,import_batch_key,artifact_checksum,checksum_algorithm,
    import_method,import_tool,import_tool_version
  ) VALUES (
    'a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000107',
    'LINKED-MISMATCH',repeat('0',64),'SHA256','deterministic','test-parser','2'
  );
    RAISE EXCEPTION 'mismatched batch/artifact version accepted'; EXCEPTION WHEN foreign_key_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_import_batches(
    source_version_id,source_artifact_id,import_batch_key,artifact_checksum,checksum_algorithm,
    import_method,import_tool,import_tool_version
  ) VALUES (
    'a0000000-0000-4000-8000-000000000020','a0000000-0000-4000-8000-000000000102',
    'LINKED-WRONG-CHECKSUM',repeat('a',64),'SHA256','deterministic','test-parser','3'
  );
    RAISE EXCEPTION 'mismatched batch/artifact checksum accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'source_artifacts','source_version_artifacts','source_artifact_acquisitions',
    'source_artifact_locations','source_artifact_sets','source_artifact_set_members'
  ] LOOP
    IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid=('public.'||t)::regclass) THEN
      RAISE EXCEPTION 'RLS disabled on %', t;
    END IF;
    IF EXISTS (
         SELECT 1 FROM information_schema.role_table_grants
         WHERE table_schema='public' AND table_name=t AND grantee='PUBLIC'
       )
       OR has_table_privilege('anon','public.'||t,'SELECT,INSERT,UPDATE,DELETE')
       OR has_table_privilege('authenticated','public.'||t,'SELECT,INSERT,UPDATE,DELETE') THEN
      RAISE EXCEPTION 'client privilege leak on %', t;
    END IF;
    IF NOT has_table_privilege('service_role','public.'||t,'SELECT,INSERT,UPDATE,DELETE') THEN
      RAISE EXCEPTION 'service_role privileges missing on %', t;
    END IF;
  END LOOP;
  IF EXISTS (
       SELECT 1 FROM information_schema.role_routine_grants
       WHERE specific_schema='public'
         AND routine_name='tafsiri_guard_source_artifact_identity'
         AND grantee='PUBLIC'
     )
     OR has_function_privilege('anon','public.tafsiri_guard_source_artifact_identity()','EXECUTE')
     OR has_function_privilege('authenticated','public.tafsiri_guard_source_artifact_identity()','EXECUTE') THEN
    RAISE EXCEPTION 'artifact identity helper execution leaked';
  END IF;
  IF NOT has_function_privilege('service_role','public.tafsiri_guard_source_artifact_identity()','EXECUTE') THEN
    RAISE EXCEPTION 'service_role helper execution missing';
  END IF;
  IF EXISTS (
       SELECT 1 FROM information_schema.role_routine_grants
       WHERE specific_schema='public'
         AND routine_name='tafsiri_validate_import_batch_artifact'
         AND grantee='PUBLIC'
     )
     OR has_function_privilege('anon','public.tafsiri_validate_import_batch_artifact()','EXECUTE')
     OR has_function_privilege('authenticated','public.tafsiri_validate_import_batch_artifact()','EXECUTE') THEN
    RAISE EXCEPTION 'batch artifact helper execution leaked';
  END IF;
  IF NOT has_function_privilege('service_role','public.tafsiri_validate_import_batch_artifact()','EXECUTE') THEN
    RAISE EXCEPTION 'service_role batch artifact helper execution missing';
  END IF;
END$$;

SET LOCAL ROLE anon;
DO $$BEGIN
  BEGIN PERFORM count(*) FROM public.source_artifacts; RAISE EXCEPTION 'anon read unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO public.source_artifacts(artifact_key,checksum_algorithm,checksum,byte_size,media_type)
    VALUES ('ANON','SHA256',repeat('9',64),1,'text/plain'); RAISE EXCEPTION 'anon write unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END$$;
RESET ROLE;

SET LOCAL ROLE authenticated;
DO $$BEGIN
  BEGIN PERFORM count(*) FROM public.source_artifact_acquisitions; RAISE EXCEPTION 'authenticated read unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE public.source_artifact_locations SET notes='changed'; RAISE EXCEPTION 'authenticated update unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END$$;
RESET ROLE;

ROLLBACK;
