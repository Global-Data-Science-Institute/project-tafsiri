BEGIN;

DO $$
BEGIN
  IF (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN (
    'sources','source_versions','source_rights','source_use_policies','source_contact_events',
    'source_import_batches','source_entries','source_dialect_mapping_assertions'
  )) <> 8 THEN RAISE EXCEPTION 'Migration 006 tables missing'; END IF;
END$$;

INSERT INTO public.languages(id,name,iso_code)
VALUES ('60000000-0000-4000-8000-000000000001','Test language','t06');
INSERT INTO public.dialects(id,name,language_id)
VALUES ('60000000-0000-4000-8000-000000000002','Test dialect','60000000-0000-4000-8000-000000000001');
INSERT INTO public.contributors(id,name)
VALUES ('60000000-0000-4000-8000-000000000003','Migration 006 test reviewer');

INSERT INTO public.sources(id,source_key,source_type,title)
VALUES ('60000000-0000-4000-8000-000000000010','TEST-SOURCE','DICTIONARY','Test dictionary');

DO $$BEGIN
  BEGIN INSERT INTO public.sources(source_key,source_type,title) VALUES ('','DICTIONARY','Blank key');
    RAISE EXCEPTION 'blank source key accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.sources(source_key,source_type,title) VALUES ('BAD-TYPE','INVALID','Bad type');
    RAISE EXCEPTION 'invalid source type accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

INSERT INTO public.source_versions(id,source_id,version_key,edition_label)
VALUES ('60000000-0000-4000-8000-000000000020','60000000-0000-4000-8000-000000000010','draft-1','Draft 1');
DO $$BEGIN
  BEGIN INSERT INTO public.source_versions(source_id,version_key) VALUES ('60000000-0000-4000-8000-000000000010','draft-1');
    RAISE EXCEPTION 'duplicate version accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
END$$;

INSERT INTO public.source_rights(id,source_version_id,rights_status)
VALUES ('60000000-0000-4000-8000-000000000030','60000000-0000-4000-8000-000000000020','CONTACTED_NO_RESPONSE');
DO $$BEGIN
  BEGIN INSERT INTO public.source_rights(source_version_id,rights_status) VALUES ('60000000-0000-4000-8000-000000000020','INVALID');
    RAISE EXCEPTION 'invalid rights status accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  IF EXISTS (SELECT 1 FROM public.source_use_policies) THEN RAISE EXCEPTION 'rights record created a use policy'; END IF;
END$$;

INSERT INTO public.source_use_policies(id,source_version_id,use_scope,decision,policy_basis_reference,deciding_authority,policy_version)
VALUES ('60000000-0000-4000-8000-000000000040','60000000-0000-4000-8000-000000000020','INTERNAL_RESEARCH','ALLOWED','Approved test basis','Test authority','TEST-1');
DO $$BEGIN
  BEGIN INSERT INTO public.source_use_policies(source_version_id,use_scope,decision,policy_version) VALUES ('60000000-0000-4000-8000-000000000020','INVALID','UNKNOWN','TEST-1');
    RAISE EXCEPTION 'invalid scope accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_use_policies(source_version_id,use_scope,decision,policy_version) VALUES ('60000000-0000-4000-8000-000000000020','MODEL_TRAINING','INVALID','TEST-1');
    RAISE EXCEPTION 'invalid decision accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_use_policies(source_version_id,use_scope,decision,notes,policy_version) VALUES ('60000000-0000-4000-8000-000000000020','INTERNAL_RESEARCH','ALLOWED','duplicate','TEST-2');
    RAISE EXCEPTION 'duplicate current policy accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
END$$;

INSERT INTO public.source_contact_events(id,source_version_id,contact_date,contact_method,contact_target,requested_uses,response_status)
VALUES ('60000000-0000-4000-8000-000000000050','60000000-0000-4000-8000-000000000020',CURRENT_DATE,'email','rights@example.invalid',ARRAY['MODEL_TRAINING'],'NO_RESPONSE');
DO $$BEGIN
  IF (SELECT count(*) FROM public.source_rights) <> 1 OR (SELECT count(*) FROM public.source_use_policies) <> 1
  THEN RAISE EXCEPTION 'contact event mutated rights or policies'; END IF;
END$$;

INSERT INTO public.source_import_batches(
  id,source_version_id,import_batch_key,artifact_checksum,checksum_algorithm,
  import_method,import_tool,import_tool_version,transformation_config_hash,
  source_row_count,accepted_row_count,rejected_row_count
) VALUES (
  '60000000-0000-4000-8000-000000000060','60000000-0000-4000-8000-000000000020','TEST-BATCH',
  'abc123','SHA-256','file import','test-importer','1.0','config-1',2,2,0
);
DO $$BEGIN
  BEGIN INSERT INTO public.source_import_batches(source_version_id,import_batch_key,artifact_checksum,checksum_algorithm,import_method,import_tool,import_tool_version,transformation_config_hash)
    VALUES ('60000000-0000-4000-8000-000000000020','TEST-BATCH-2','abc123','SHA-256','file import','test-importer','1.0','config-1');
    RAISE EXCEPTION 'duplicate import identity accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_import_batches(source_version_id,import_batch_key,artifact_checksum,checksum_algorithm,import_method,import_tool,import_tool_version,source_row_count,accepted_row_count,rejected_row_count)
    VALUES ('60000000-0000-4000-8000-000000000020','BAD-COUNTS','different','SHA-256','file import','test-importer','1.0',1,1,1);
    RAISE EXCEPTION 'invalid row counts accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

INSERT INTO public.source_entries(
  id,source_version_id,import_batch_id,original_entry_locator,original_form,
  source_entry_checksum,occurrence_sequence
) VALUES (
  '60000000-0000-4000-8000-000000000070','60000000-0000-4000-8000-000000000020',
  '60000000-0000-4000-8000-000000000060','entry-1','test-form','entry-hash',1
);
INSERT INTO public.source_entries(
  id,source_version_id,import_batch_id,original_form,source_entry_checksum,occurrence_sequence
) VALUES (
  '60000000-0000-4000-8000-000000000071','60000000-0000-4000-8000-000000000020',
  '60000000-0000-4000-8000-000000000060','test-form','entry-hash',2
);
DO $$BEGIN
  BEGIN INSERT INTO public.source_entries(source_version_id,import_batch_id,source_entry_checksum)
    VALUES ('60000000-0000-4000-8000-000000000020','60000000-0000-4000-8000-000000000060','empty');
    RAISE EXCEPTION 'empty source entry accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_entries(source_version_id,import_batch_id,original_entry_locator,original_form,source_entry_checksum)
    VALUES ('60000000-0000-4000-8000-000000000020','60000000-0000-4000-8000-000000000060','entry-1','duplicate','other');
    RAISE EXCEPTION 'duplicate locator accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_entries(source_version_id,import_batch_id,original_form,source_entry_checksum,occurrence_sequence)
    VALUES ('60000000-0000-4000-8000-000000000020','60000000-0000-4000-8000-000000000060','duplicate','entry-hash',1);
    RAISE EXCEPTION 'duplicate checksum occurrence accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_entries(source_version_id,import_batch_id,original_form,source_entry_checksum)
    VALUES ('60000000-0000-4000-8000-000000000099','60000000-0000-4000-8000-000000000060','wrong version','wrong');
    RAISE EXCEPTION 'mismatched version accepted'; EXCEPTION WHEN foreign_key_violation THEN NULL; END;
END$$;

INSERT INTO public.source_dialect_mapping_assertions(
  id,source_version_id,raw_dialect_label,canonical_dialect_id,mapping_scope,policy_version
) VALUES (
  '60000000-0000-4000-8000-000000000080','60000000-0000-4000-8000-000000000020',
  'Test raw label','60000000-0000-4000-8000-000000000002','SOURCE_VERSION','TEST-MAPPING-1'
);
INSERT INTO public.source_dialect_mapping_assertions(
  id,source_version_id,import_batch_id,source_entry_id,raw_dialect_label,canonical_dialect_id,
  mapping_scope,authority,rationale,verification_status,policy_version,reviewed_by,reviewed_at
) VALUES (
  '60000000-0000-4000-8000-000000000081','60000000-0000-4000-8000-000000000020',
  '60000000-0000-4000-8000-000000000060','60000000-0000-4000-8000-000000000070',
  'Test raw label','60000000-0000-4000-8000-000000000002','SOURCE_ENTRY','Test authority',
  'Reviewed mapping','VERIFIED','TEST-MAPPING-1','60000000-0000-4000-8000-000000000003',now()
);
DO $$BEGIN
  BEGIN INSERT INTO public.source_dialect_mapping_assertions(source_version_id,raw_dialect_label,canonical_dialect_id,mapping_scope,verification_status,policy_version)
    VALUES ('60000000-0000-4000-8000-000000000020','Bad status','60000000-0000-4000-8000-000000000002','SOURCE_VERSION','INVALID','TEST');
    RAISE EXCEPTION 'invalid mapping status accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO public.source_dialect_mapping_assertions(source_version_id,raw_dialect_label,canonical_dialect_id,mapping_scope,verification_status,policy_version)
    VALUES ('60000000-0000-4000-8000-000000000020','No reviewer','60000000-0000-4000-8000-000000000002','SOURCE_VERSION','VERIFIED','TEST');
    RAISE EXCEPTION 'verified mapping without authority accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'sources','source_versions','source_rights','source_use_policies','source_contact_events',
    'source_import_batches','source_entries','source_dialect_mapping_assertions'
  ] LOOP
    IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid=('public.'||t)::regclass) THEN
      RAISE EXCEPTION 'RLS disabled on %', t;
    END IF;
    IF has_table_privilege('anon','public.'||t,'SELECT')
       OR has_table_privilege('anon','public.'||t,'INSERT')
       OR has_table_privilege('authenticated','public.'||t,'SELECT')
       OR has_table_privilege('authenticated','public.'||t,'INSERT')
       OR has_table_privilege('authenticated','public.'||t,'UPDATE')
       OR has_table_privilege('authenticated','public.'||t,'DELETE') THEN
      RAISE EXCEPTION 'client privilege leak on %', t;
    END IF;
    IF NOT has_table_privilege('service_role','public.'||t,'SELECT,INSERT,UPDATE,DELETE') THEN
      RAISE EXCEPTION 'service_role administrative privileges missing on %', t;
    END IF;
  END LOOP;
END$$;

SET LOCAL ROLE anon;
DO $$BEGIN
  BEGIN PERFORM count(*) FROM public.sources; RAISE EXCEPTION 'anon read unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO public.sources(source_key,source_type,title) VALUES ('ANON','OTHER','anon'); RAISE EXCEPTION 'anon write unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END$$;
RESET ROLE;

SET LOCAL ROLE authenticated;
DO $$BEGIN
  BEGIN PERFORM count(*) FROM public.source_contact_events; RAISE EXCEPTION 'authenticated contact read unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE public.source_entries SET original_form='changed'; RAISE EXCEPTION 'authenticated source update unexpectedly allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END$$;
RESET ROLE;

ROLLBACK;
