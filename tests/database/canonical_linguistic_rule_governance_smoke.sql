-- Migration 009 rollback-only functional and security smoke tests.
BEGIN;

DO $$
DECLARE taxonomy_count integer; role_count integer;
BEGIN
  SELECT count(*) INTO taxonomy_count FROM public.linguistic_rule_types;
  SELECT count(*) INTO role_count FROM public.contributor_role_types;
  IF taxonomy_count <> 25 THEN RAISE EXCEPTION 'expected 25 rule types, got %',taxonomy_count; END IF;
  IF role_count <> 6 THEN RAISE EXCEPTION 'expected 6 contributor role types, got %',role_count; END IF;
  IF (SELECT count(*) FROM public.linguistic_rules)<>0 THEN RAISE EXCEPTION 'canonical rule table must begin empty'; END IF;
  IF (SELECT count(*) FROM public.linguistic_rule_promotions)<>0 THEN RAISE EXCEPTION 'promotion table must begin empty'; END IF;
  IF (SELECT count(*) FROM public.contributor_roles)<>0 THEN RAISE EXCEPTION 'contributor roles must begin empty'; END IF;
END $$;

DO $$
DECLARE
  v_contributor uuid; v_type uuid; v_role_type uuid; v_dialect uuid; v_evidence uuid;
  v_source uuid; v_version uuid; v_evidence_type uuid;
  v_promotion uuid; v_rule uuid; v_rule2 uuid; v_revision uuid; v_dialect_link uuid;
  v_evidence_link uuid; v_condition uuid; v_supersession uuid; failed boolean;
BEGIN
  INSERT INTO public.contributors(name,email) VALUES('Migration 009 Test Reviewer','migration-009-test@example.invalid') RETURNING id INTO v_contributor;
  INSERT INTO public.dialects(name,description) VALUES('Migration 009 Test Dialect','Rollback-only fixture.') RETURNING id INTO v_dialect;
  INSERT INTO public.sources(source_key,source_type,title) VALUES('MIGRATION_009_TEST_SOURCE','OTHER','Migration 009 rollback-only source') RETURNING id INTO v_source;
  INSERT INTO public.source_versions(source_id,version_key) VALUES(v_source,'TEST_VERSION') RETURNING id INTO v_version;
  SELECT id INTO v_evidence_type FROM public.linguistic_evidence_types WHERE evidence_type_key='GRAPHEME_PHONEME_RULE';
  INSERT INTO public.linguistic_evidence(source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,verification_status,extraction_method,reviewed_by,reviewed_at)
  VALUES(v_version,v_evidence_type,'DIALECT','rollback test locator','Rollback-only verified evidence.','HUMAN','VERIFIED','HUMAN_MANUAL',v_contributor,now()) RETURNING id INTO v_evidence;
  SELECT id INTO v_type FROM public.linguistic_rule_types WHERE rule_type_key='GRAPHEME_PHONEME';
  SELECT id INTO v_role_type FROM public.contributor_role_types WHERE role_type_key='CANONICAL_APPROVER';
  IF num_nulls(v_contributor,v_type,v_role_type,v_dialect,v_evidence)>0 THEN RAISE EXCEPTION 'required fixture missing'; END IF;

  INSERT INTO public.linguistic_rule_promotions(
    promotion_key,action,status,proposed_rule_type_id,proposed_scope,proposed_statement,
    evidence_set_checksum,policy_version,risk_class,authority_policy,requested_by,reason,idempotency_key
  ) VALUES (
    'TEST_PROMOTION_009','CREATE_RULE','DRAFT',v_type,'DIALECT','Test canonical statement.',
    repeat('a',64),'TEST_POLICY_001','OPERATIONAL','SINGLE_RESEARCHER_ALLOWED',v_contributor,'Rollback-only test.','TEST_IDEMPOTENCY_009'
  ) RETURNING id INTO v_promotion;

  INSERT INTO public.linguistic_rules(rule_key,rule_type_id,created_by_promotion_id)
  VALUES('TEST_RULE_009',v_type,v_promotion) RETURNING id INTO v_rule;
  INSERT INTO public.linguistic_rules(rule_key,rule_type_id,created_by_promotion_id)
  VALUES('TEST_RULE_009_REPLACEMENT',v_type,v_promotion) RETURNING id INTO v_rule2;
  UPDATE public.linguistic_rule_promotions SET target_rule_id=v_rule WHERE id=v_promotion;

  INSERT INTO public.linguistic_rule_revisions(rule_id,revision_number,canonical_statement,scope,reason,policy_version,created_by_promotion_id)
  VALUES(v_rule,1,'Test canonical statement.','DIALECT','Initial rollback-only revision.','TEST_POLICY_001',v_promotion)
  RETURNING id INTO v_revision;
  INSERT INTO public.linguistic_rule_dialects(rule_revision_id,dialect_id,role)
  VALUES(v_revision,v_dialect,'APPLIES_TO') RETURNING id INTO v_dialect_link;
  INSERT INTO public.linguistic_rule_conditions(rule_revision_id,condition_type,condition_statement)
  VALUES(v_revision,'PHONOLOGICAL_ENVIRONMENT','Rollback-only test environment.') RETURNING id INTO v_condition;
  INSERT INTO public.linguistic_rule_evidence(rule_revision_id,evidence_id,evidence_role)
  VALUES(v_revision,v_evidence,'SUPPORTS') RETURNING id INTO v_evidence_link;
  INSERT INTO public.linguistic_rule_evidence(rule_revision_id,evidence_id,evidence_role)
  VALUES(v_revision,v_evidence,'CONTRADICTS');
  UPDATE public.linguistic_rules SET current_revision_id=v_revision,lifecycle_status='ACTIVE' WHERE id=v_rule;

  INSERT INTO public.linguistic_rule_supersessions(superseded_rule_id,replacement_rule_id,relationship_type,promotion_id,reason)
  VALUES(v_rule,v_rule2,'REPLACED_BY',v_promotion,'Rollback-only test.') RETURNING id INTO v_supersession;

  INSERT INTO public.linguistic_rule_promotion_outputs(promotion_id,output_type,output_action,rule_id,order_index)
  VALUES(v_promotion,'RULE','CREATED',v_rule,0);
  INSERT INTO public.linguistic_rule_promotion_outputs(promotion_id,output_type,output_action,revision_id,order_index)
  VALUES(v_promotion,'REVISION','CREATED',v_revision,1);
  INSERT INTO public.linguistic_rule_promotion_outputs(promotion_id,output_type,output_action,dialect_link_id,order_index)
  VALUES(v_promotion,'DIALECT_LINK','CREATED',v_dialect_link,2);
  INSERT INTO public.linguistic_rule_promotion_outputs(promotion_id,output_type,output_action,evidence_link_id,order_index)
  VALUES(v_promotion,'EVIDENCE_LINK','CREATED',v_evidence_link,3);
  INSERT INTO public.linguistic_rule_promotion_outputs(promotion_id,output_type,output_action,condition_id,order_index)
  VALUES(v_promotion,'CONDITION','CREATED',v_condition,4);
  INSERT INTO public.linguistic_rule_promotion_outputs(promotion_id,output_type,output_action,supersession_id,order_index)
  VALUES(v_promotion,'SUPERSESSION','CREATED',v_supersession,5);

  INSERT INTO public.contributor_roles(contributor_id,role_type_id,dialect_id,domain,granted_by)
  VALUES(v_contributor,v_role_type,v_dialect,'GRAPHEME_PHONEME',v_contributor);

  failed=false; BEGIN INSERT INTO public.linguistic_rules(rule_key,rule_type_id) VALUES('TEST_RULE_009',v_type); EXCEPTION WHEN unique_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'duplicate rule key accepted'; END IF;
  failed=false; BEGIN INSERT INTO public.linguistic_rules(rule_key,rule_type_id) VALUES('BAD_TYPE',gen_random_uuid()); EXCEPTION WHEN foreign_key_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'invalid rule type accepted'; END IF;
  failed=false; BEGIN INSERT INTO public.linguistic_rule_revisions(rule_id,revision_number,canonical_statement,scope,reason,policy_version,created_by_promotion_id) VALUES(v_rule,1,'duplicate','DIALECT','x','x',v_promotion); EXCEPTION WHEN unique_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'duplicate revision number accepted'; END IF;
  failed=false; BEGIN INSERT INTO public.linguistic_rule_revisions(rule_id,revision_number,canonical_statement,scope,reason,policy_version,created_by_promotion_id) VALUES(v_rule,2,' ','DIALECT','x','x',v_promotion); EXCEPTION WHEN check_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'blank statement accepted'; END IF;
  failed=false; BEGIN INSERT INTO public.linguistic_rule_dialects(rule_revision_id,dialect_id,role) VALUES(v_revision,gen_random_uuid(),'APPLIES_TO'); EXCEPTION WHEN foreign_key_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'invalid dialect accepted'; END IF;

  UPDATE public.linguistic_evidence SET verification_status='UNVERIFIED' WHERE id=v_evidence;
  failed=false; BEGIN INSERT INTO public.linguistic_rule_evidence(rule_revision_id,evidence_id,evidence_role) VALUES(v_revision,v_evidence,'SUPPORTS'); EXCEPTION WHEN raise_exception THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'SUPPORTS accepted non-verified evidence'; END IF;
  UPDATE public.linguistic_evidence SET verification_status='VERIFIED' WHERE id=v_evidence;

  failed=false; BEGIN INSERT INTO public.linguistic_rule_promotions(promotion_key,action,status,evidence_set_checksum,policy_version,risk_class,authority_policy,requested_by,reason,idempotency_key) VALUES('BAD_ACTION','UPDATE','DRAFT',repeat('b',64),'x','OPERATIONAL','SINGLE_RESEARCHER_ALLOWED',v_contributor,'x','BAD_ACTION'); EXCEPTION WHEN check_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'invalid promotion action accepted'; END IF;
  failed=false; BEGIN INSERT INTO public.linguistic_rule_promotions(promotion_key,action,status,evidence_set_checksum,policy_version,risk_class,authority_policy,requested_by,reason,idempotency_key) VALUES('BAD_STATUS','DISPUTE_RULE','UNKNOWN',repeat('b',64),'x','OPERATIONAL','SINGLE_RESEARCHER_ALLOWED',v_contributor,'x','BAD_STATUS'); EXCEPTION WHEN check_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'invalid promotion status accepted'; END IF;
  failed=false; BEGIN UPDATE public.linguistic_rule_promotions SET status='APPROVED' WHERE id=v_promotion; EXCEPTION WHEN check_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'APPROVED without approver accepted'; END IF;
  UPDATE public.linguistic_rule_promotions SET approved_by=v_contributor,approved_at=now(),status='APPROVED' WHERE id=v_promotion;
  failed=false; BEGIN UPDATE public.linguistic_rule_promotions SET status='APPLIED' WHERE id=v_promotion; EXCEPTION WHEN check_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'APPLIED without applied_at accepted'; END IF;
  failed=false; BEGIN INSERT INTO public.linguistic_rule_promotions(promotion_key,action,status,evidence_set_checksum,policy_version,risk_class,authority_policy,requested_by,reason,idempotency_key) VALUES('DUP_IDEMPOTENCY','DISPUTE_RULE','DRAFT',repeat('b',64),'x','OPERATIONAL','SINGLE_RESEARCHER_ALLOWED',v_contributor,'x','TEST_IDEMPOTENCY_009'); EXCEPTION WHEN unique_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'duplicate idempotency key accepted'; END IF;
  failed=false; BEGIN INSERT INTO public.linguistic_rule_promotion_outputs(promotion_id,output_type,output_action,rule_id,revision_id,order_index) VALUES(v_promotion,'RULE','CREATED',v_rule,v_revision,10); EXCEPTION WHEN check_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'promotion output accepted multiple targets'; END IF;
  failed=false; BEGIN INSERT INTO public.linguistic_rule_supersessions(superseded_rule_id,replacement_rule_id,relationship_type,promotion_id,reason) VALUES(v_rule,v_rule,'REPLACED_BY',v_promotion,'x'); EXCEPTION WHEN check_violation OR raise_exception THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'self supersession accepted'; END IF;
  failed=false; BEGIN INSERT INTO public.contributor_roles(contributor_id,role_type_id) VALUES(v_contributor,gen_random_uuid()); EXCEPTION WHEN foreign_key_violation THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'invalid contributor role type accepted'; END IF;

  failed=false; BEGIN UPDATE public.linguistic_rule_revisions SET canonical_statement='silently rewritten' WHERE id=v_revision; EXCEPTION WHEN raise_exception THEN failed=true; END;
  IF NOT failed THEN RAISE EXCEPTION 'active revision was mutable'; END IF;
END $$;

DO $$
DECLARE v_table_name text; rel_rls boolean; forbidden_count integer; service_count integer;
BEGIN
  FOREACH v_table_name IN ARRAY ARRAY['linguistic_rule_types','linguistic_rules','linguistic_rule_revisions','linguistic_rule_dialects','linguistic_rule_conditions','linguistic_rule_evidence','linguistic_rule_promotions','linguistic_rule_promotion_outputs','linguistic_rule_supersessions','contributor_role_types','contributor_roles'] LOOP
    SELECT relrowsecurity INTO rel_rls FROM pg_class WHERE oid=format('public.%I',v_table_name)::regclass;
    IF NOT rel_rls THEN RAISE EXCEPTION 'RLS disabled on %',v_table_name; END IF;
    SELECT count(*) INTO forbidden_count FROM information_schema.role_table_grants g WHERE g.table_schema='public' AND g.table_name=v_table_name AND g.grantee IN ('PUBLIC','anon','authenticated');
    IF forbidden_count<>0 THEN RAISE EXCEPTION 'client privileges found on %',v_table_name; END IF;
    SELECT count(*) INTO service_count FROM information_schema.role_table_grants g WHERE g.table_schema='public' AND g.table_name=v_table_name AND g.grantee='service_role';
    IF service_count=0 THEN RAISE EXCEPTION 'service_role privileges missing on %',v_table_name; END IF;
  END LOOP;
END $$;

DO $$
DECLARE fn text; forbidden_count integer;
BEGIN
  FOREACH fn IN ARRAY ARRAY['tafsiri_validate_rule_evidence_support','tafsiri_validate_active_rule_scope','tafsiri_guard_rule_revision_update','tafsiri_prevent_rule_supersession_cycle'] LOOP
    SELECT count(*) INTO forbidden_count FROM information_schema.routine_privileges WHERE routine_schema='public' AND routine_name=fn AND grantee IN ('PUBLIC','anon','authenticated');
    IF forbidden_count<>0 THEN RAISE EXCEPTION 'forbidden execute privilege on %',fn; END IF;
  END LOOP;
END $$;

ROLLBACK;

-- Post-rollback assertions are intentionally performed by deployment verification:
-- governance entity tables remain empty and the 110 verified evidence rows remain unchanged.
