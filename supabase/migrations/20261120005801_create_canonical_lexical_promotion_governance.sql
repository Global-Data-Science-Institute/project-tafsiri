-- Migration 012: private, explicit lexical research governance. No seed authority.
-- Dedicated DB logins are provisioned separately; session_user cannot be forged
-- by SET ROLE, JWT claims, custom settings, portal membership or a service key.
CREATE SCHEMA lexical_governance;
REVOKE ALL ON SCHEMA lexical_governance FROM PUBLIC,anon,authenticated,service_role;
-- A CLI schema reset can retain cluster roles. Reuse only the inert group role;
-- refuse a preexisting role with login, administrative, or inherited authority.
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='tafsiri_lexical_researcher') THEN
    CREATE ROLE tafsiri_lexical_researcher NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
  ELSIF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='tafsiri_lexical_researcher'
      AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit OR rolreplication OR rolbypassrls))
      OR EXISTS(SELECT 1 FROM pg_auth_members WHERE member='tafsiri_lexical_researcher'::regrole) THEN
    RAISE EXCEPTION 'reserved research group role has unexpected authority';
  END IF;
END $$;
GRANT USAGE ON SCHEMA lexical_governance TO tafsiri_lexical_researcher;

CREATE TABLE lexical_governance.principals (
  login_name name PRIMARY KEY,
  contributor_id uuid NOT NULL UNIQUE REFERENCES public.contributors(id),
  provisioned_by text NOT NULL DEFAULT session_user,
  provisioned_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  revoked_at timestamptz,
  CHECK (login_name NOT IN ('postgres','supabase_admin','authenticator','anon','authenticated','service_role'))
);
CREATE TABLE lexical_governance.authorities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contributor_role_id uuid NOT NULL REFERENCES public.contributor_roles(id),
  language_id uuid REFERENCES public.languages(id),
  dialect_id uuid REFERENCES public.dialects(id),
  operation_keys text[] NOT NULL CHECK (cardinality(operation_keys)>0),
  competence_reference text NOT NULL CHECK (btrim(competence_reference)<>''),
  valid_from timestamptz NOT NULL,
  valid_until timestamptz NOT NULL CHECK (valid_until>valid_from),
  granted_by text NOT NULL DEFAULT session_user,
  granted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  revoked_at timestamptz,
  CHECK (num_nonnulls(language_id,dialect_id)=1)
);
CREATE INDEX lexical_authority_role_idx ON lexical_governance.authorities(contributor_role_id);
CREATE INDEX lexical_authority_language_idx ON lexical_governance.authorities(language_id);
CREATE INDEX lexical_authority_dialect_idx ON lexical_governance.authorities(dialect_id);
CREATE TABLE lexical_governance.proposals (
  id uuid PRIMARY KEY,
  idempotency_key text NOT NULL UNIQUE CHECK (btrim(idempotency_key)<>''),
  proposal_type text NOT NULL CHECK (proposal_type IN ('CREATE','REVISE','ASSERT','DISPUTE')),
  proposal_version integer NOT NULL CHECK (proposal_version>0),
  policy_version text NOT NULL CHECK (policy_version='LEXICAL_PROMOTION_001'),
  language_id uuid REFERENCES public.languages(id),
  dialect_id uuid REFERENCES public.dialects(id),
  provenance_origin text NOT NULL CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  manifest jsonb NOT NULL CHECK (jsonb_typeof(manifest)='object'),
  requested_by uuid NOT NULL REFERENCES public.contributors(id),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  state text NOT NULL DEFAULT 'DRAFT' CHECK (state IN ('DRAFT','SUBMITTED','UNDER_REVIEW','APPROVED','EXECUTED','REJECTED','WITHDRAWN','DISPUTED')),
  evidence_snapshot jsonb,
  evidence_digest text CHECK (evidence_digest ~ '^[0-9a-f]{64}$'),
  approved_by uuid REFERENCES public.contributors(id),
  approved_at timestamptz,
  authorization_snapshot jsonb,
  executed_at timestamptz,
  CHECK (num_nonnulls(language_id,dialect_id)=1),
  CHECK ((approved_by IS NULL)=(approved_at IS NULL)),
  CHECK (state NOT IN ('APPROVED','EXECUTED') OR approved_by IS NOT NULL),
  CHECK (state<>'EXECUTED' OR executed_at IS NOT NULL)
);
CREATE INDEX lexical_proposals_requester_idx ON lexical_governance.proposals(requested_by);
CREATE INDEX lexical_proposals_approver_idx ON lexical_governance.proposals(approved_by);
CREATE INDEX lexical_proposals_language_idx ON lexical_governance.proposals(language_id);
CREATE INDEX lexical_proposals_dialect_idx ON lexical_governance.proposals(dialect_id);
CREATE TABLE lexical_governance.events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  proposal_id uuid NOT NULL REFERENCES lexical_governance.proposals(id),
  actor_id uuid NOT NULL REFERENCES public.contributors(id),
  login_name name NOT NULL DEFAULT session_user,
  action text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  details jsonb NOT NULL
);
CREATE INDEX lexical_events_proposal_idx ON lexical_governance.events(proposal_id,id);
CREATE INDEX lexical_events_actor_idx ON lexical_governance.events(actor_id);
CREATE TABLE lexical_governance.outputs (
  proposal_id uuid NOT NULL REFERENCES lexical_governance.proposals(id),
  operation_index integer NOT NULL,
  table_name text NOT NULL,
  record_id uuid NOT NULL,
  action text NOT NULL,
  before_record jsonb,
  after_record jsonb NOT NULL,
  PRIMARY KEY(proposal_id,operation_index)
);

-- Append-only identity, authority and decision trails. Only revocation can change
-- a provisioned principal/qualification. Changes require a fresh grant/login.
CREATE FUNCTION lexical_governance.guard_history() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF TG_OP='UPDATE' AND TG_TABLE_NAME IN ('principals','authorities')
     AND (to_jsonb(NEW)-'revoked_at')=(to_jsonb(OLD)-'revoked_at')
     AND to_jsonb(OLD)->>'revoked_at' IS NULL AND to_jsonb(NEW)->>'revoked_at' IS NOT NULL THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'governance history is append-only' USING ERRCODE='23514';
END $$;
-- Resolve a canonical claim to its lexical identity, never by spelling.
CREATE FUNCTION lexical_governance.claim_lexeme(t text,d jsonb) RETURNS uuid
LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE result uuid;
BEGIN
  CASE t
    WHEN 'lexemes' THEN result:=(d->>'id')::uuid;
    WHEN 'lexeme_forms','lexeme_dialects','lexical_senses' THEN result:=(d->>'lexeme_id')::uuid;
    WHEN 'lexical_sense_revisions','sense_dialects','sense_concepts' THEN
      SELECT lexeme_id INTO result FROM public.lexical_senses WHERE id=(d->>'sense_id')::uuid;
    WHEN 'lexical_relationships' THEN result:=(d->>'source_lexeme_id')::uuid;
    WHEN 'form_relationships' THEN SELECT lexeme_id INTO result FROM public.lexeme_forms WHERE id=(d->>'source_form_id')::uuid;
    WHEN 'lexical_attestations','lexical_linguistic_evidence' THEN
      result:=(d->>'lexeme_id')::uuid;
      IF d->>'form_id' IS NOT NULL THEN SELECT lexeme_id INTO result FROM public.lexeme_forms WHERE id=(d->>'form_id')::uuid; END IF;
      IF d->>'sense_revision_id' IS NOT NULL THEN SELECT s.lexeme_id INTO result FROM public.lexical_sense_revisions r JOIN public.lexical_senses s ON s.id=r.sense_id WHERE r.id=(d->>'sense_revision_id')::uuid; END IF;
      IF d->>'sense_concept_id' IS NOT NULL THEN SELECT s.lexeme_id INTO result FROM public.sense_concepts c JOIN public.lexical_senses s ON s.id=c.sense_id WHERE c.id=(d->>'sense_concept_id')::uuid; END IF;
      IF d->>'lexical_relationship_id' IS NOT NULL THEN SELECT source_lexeme_id INTO result FROM public.lexical_relationships WHERE id=(d->>'lexical_relationship_id')::uuid; END IF;
      IF d->>'form_relationship_id' IS NOT NULL THEN SELECT f.lexeme_id INTO result FROM public.form_relationships r JOIN public.lexeme_forms f ON f.id=r.source_form_id WHERE r.id=(d->>'form_relationship_id')::uuid; END IF;
    ELSE RAISE EXCEPTION 'unsupported claim table';
  END CASE;
  IF result IS NULL THEN RAISE EXCEPTION 'canonical parent missing'; END IF;
  RETURN result;
END $$;

CREATE FUNCTION lexical_governance.apply_operations(p lexical_governance.proposals,reviewer uuid) RETURNS jsonb
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE op jsonb; d jsonb; oldrow jsonb; newrow jsonb; t text; act text; cols text; vals text;
  key text; n integer:=0; result jsonb:='[]'::jsonb; lx public.lexemes; other public.lexemes; lid uuid; field text;
BEGIN
  IF jsonb_typeof(p.manifest->'operations') IS DISTINCT FROM 'array' OR jsonb_array_length(p.manifest->'operations') NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'one to one hundred ordered operations required'; END IF;
  FOR op IN SELECT value FROM jsonb_array_elements(p.manifest->'operations') LOOP
    n:=n+1; t:=op->>'table'; act:=op->>'action'; d:=op->'data'; oldrow:=NULL;
    IF t IS NULL OR t NOT IN ('lexemes','lexeme_forms','lexeme_dialects','lexical_senses','lexical_sense_revisions','sense_dialects','sense_concepts','lexical_relationships','form_relationships','lexical_attestations','lexical_linguistic_evidence') THEN
      RAISE EXCEPTION 'table not in lexical promotion contract'; END IF;
    IF jsonb_typeof(d) IS DISTINCT FROM 'object' OR d->>'id' IS NULL THEN RAISE EXCEPTION 'stable explicit record UUID required'; END IF;
    IF act='insert' THEN
      IF d ?| ARRAY['sealed_at','reviewed_by','reviewed_at','created_by','created_at','updated_at','verification_status','mapping_status','provenance_origin','lifecycle_status','current_revision_id','current_lemma_form_id','superseded_by','superseded_at','replacement_form_id','deprecated_at'] THEN
        RAISE EXCEPTION 'caller supplied managed fields'; END IF;
      IF t<>'lexical_linguistic_evidence' THEN
        d:=d||jsonb_build_object('provenance_origin',p.provenance_origin,'reviewed_by',reviewer,'reviewed_at',clock_timestamp(),
          CASE WHEN t='sense_concepts' THEN 'mapping_status' ELSE 'verification_status' END,'VERIFIED');
      END IF;
      IF t IN ('lexemes','lexeme_forms','lexical_senses','lexical_sense_revisions') THEN d:=d||jsonb_build_object('created_by',p.requested_by); END IF;
      IF t IN ('lexemes','lexical_senses') THEN d:=d||jsonb_build_object('lifecycle_status','ACTIVE'); END IF;
      -- Dynamic names come only from the fixed table allowlist and real columns;
      -- values are parameters, never interpolated SQL.
      FOR key IN SELECT jsonb_object_keys(d) LOOP
        IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_attribute WHERE attrelid=('public.'||t)::regclass AND attname=key AND attnum>0 AND NOT attisdropped AND attgenerated='') THEN
          RAISE EXCEPTION 'unknown operation column %',key; END IF;
      END LOOP;
      SELECT string_agg(format('%I',x),',' ORDER BY x),string_agg(format('r.%I',x),',' ORDER BY x) INTO cols,vals FROM jsonb_object_keys(d) x;
      EXECUTE format('INSERT INTO public.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I,$1) r RETURNING to_jsonb(%I.*)',t,cols,vals,t,t) INTO newrow USING d;
    ELSIF act='set_current' AND t IN ('lexemes','lexical_senses') THEN
      field:=CASE WHEN t='lexemes' THEN 'current_lemma_form_id' ELSE 'current_revision_id' END;
      IF d-ARRAY['id',field]<>'{}'::jsonb OR NOT (d ? field) OR NOT ((op->'expected') ? field) OR (op->'expected')-field<>'{}'::jsonb THEN
        RAISE EXCEPTION 'exact expected current pointer required'; END IF;
      EXECUTE format('SELECT to_jsonb(r) FROM public.%I r WHERE id=$1 FOR UPDATE',t) INTO oldrow USING (d->>'id')::uuid;
      IF oldrow IS NULL OR oldrow->field IS DISTINCT FROM op->'expected'->field THEN RAISE EXCEPTION 'stale canonical revision' USING ERRCODE='40001'; END IF;
      EXECUTE format('UPDATE public.%I SET %I=$1 WHERE id=$2 RETURNING to_jsonb(%I.*)',t,field,t) INTO newrow USING (d->>field)::uuid,(d->>'id')::uuid;
    ELSIF act='dispute' AND t IN ('lexemes','lexical_senses','sense_concepts') THEN
      field:=CASE WHEN t='sense_concepts' THEN 'mapping_status' ELSE 'verification_status' END;
      IF d-ARRAY['id']<>'{}'::jsonb OR NOT (op->'expected' ? field) THEN RAISE EXCEPTION 'expected verification state required'; END IF;
      EXECUTE format('SELECT to_jsonb(r) FROM public.%I r WHERE id=$1 FOR UPDATE',t) INTO oldrow USING (d->>'id')::uuid;
      IF oldrow IS NULL OR oldrow->field IS DISTINCT FROM op->'expected'->field THEN RAISE EXCEPTION 'stale canonical status' USING ERRCODE='40001'; END IF;
      EXECUTE format('UPDATE public.%I SET %I=''DISPUTED'' WHERE id=$1 RETURNING to_jsonb(%I.*)',t,field,t) INTO newrow USING (d->>'id')::uuid;
    ELSE RAISE EXCEPTION 'operation not allowed'; END IF;
    lid:=lexical_governance.claim_lexeme(t,newrow);
    SELECT * INTO STRICT lx FROM public.lexemes WHERE id=lid;
    IF lx.language_id IS DISTINCT FROM p.language_id OR lx.identity_dialect_id IS DISTINCT FROM p.dialect_id THEN RAISE EXCEPTION 'lexical identity scope mismatch'; END IF;
    IF act<>'dispute' AND t NOT IN ('lexical_attestations','lexical_linguistic_evidence') AND (lx.verification_status<>'VERIFIED' OR lx.lifecycle_status<>'ACTIVE') THEN RAISE EXCEPTION 'lexeme is not current verified canonical knowledge'; END IF;
    IF act='set_current' AND t='lexemes' AND NOT EXISTS(SELECT 1 FROM public.lexeme_forms WHERE id=(newrow->>'current_lemma_form_id')::uuid AND form_role='LEMMA' AND verification_status='VERIFIED' AND deprecated_at IS NULL) THEN
      RAISE EXCEPTION 'current lemma must be a verified current lemma form'; END IF;
    IF act='set_current' AND t='lexical_senses' AND NOT EXISTS(SELECT 1 FROM public.lexical_sense_revisions WHERE id=(newrow->>'current_revision_id')::uuid AND verification_status='VERIFIED') THEN
      RAISE EXCEPTION 'current meaning revision must be verified'; END IF;
    IF t IN ('lexeme_dialects','sense_dialects','lexeme_forms') AND newrow->>'dialect_id' IS NOT NULL AND (newrow->>'dialect_id')::uuid IS DISTINCT FROM p.dialect_id THEN
      RAISE EXCEPTION 'dialect scope expansion requires separate authority'; END IF;
    IF t IN ('lexical_relationships','form_relationships') THEN
      IF t='lexical_relationships' THEN SELECT * INTO STRICT other FROM public.lexemes WHERE id=(newrow->>'target_lexeme_id')::uuid;
      ELSE SELECT l.* INTO STRICT other FROM public.lexeme_forms f JOIN public.lexemes l ON l.id=f.lexeme_id WHERE f.id=(newrow->>'target_form_id')::uuid; END IF;
      IF other.language_id IS DISTINCT FROM p.language_id OR other.identity_dialect_id IS DISTINCT FROM p.dialect_id THEN RAISE EXCEPTION 'cross-scope relationship requires a future multi-scope approval'; END IF;
    END IF;
    IF t='lexical_attestations' AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p.manifest->'evidence') e WHERE (e->>'source_entry_id')::uuid=(newrow->>'source_entry_id')::uuid AND e->>'role'=newrow->>'evidence_role') THEN
      RAISE EXCEPTION 'attestation not in reviewed evidence set'; END IF;
    IF t='lexical_linguistic_evidence' AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p.manifest->'evidence') e WHERE (e->>'evidence_id')::uuid=(newrow->>'evidence_id')::uuid) THEN
      RAISE EXCEPTION 'linguistic evidence not in reviewed set'; END IF;
    INSERT INTO lexical_governance.outputs VALUES(p.id,n,t,(newrow->>'id')::uuid,act,oldrow,newrow);
    result:=result||jsonb_build_array(jsonb_build_object('table',t,'action',act,'id',newrow->>'id'));
  END LOOP;
  -- Every inserted primary claim needs a reviewed source attestation; every
  -- disclosed source (including contrary sources) remains linked to a claim.
  FOR op IN SELECT value FROM jsonb_array_elements(p.manifest->'operations') LOOP
    t:=op->>'table';
    field:=CASE t WHEN 'lexemes' THEN 'lexeme_id' WHEN 'lexeme_forms' THEN 'form_id' WHEN 'lexical_sense_revisions' THEN 'sense_revision_id' WHEN 'sense_concepts' THEN 'sense_concept_id' WHEN 'lexical_relationships' THEN 'lexical_relationship_id' WHEN 'form_relationships' THEN 'form_relationship_id' ELSE NULL END;
    IF op->>'action'='insert' AND field IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.lexical_attestations a
      JOIN lexical_governance.outputs o ON o.record_id=a.id AND o.table_name='lexical_attestations' AND o.proposal_id=p.id
      WHERE to_jsonb(a)->>field=op->'data'->>'id' AND a.evidence_role IN ('SUPPORTS','HISTORICAL_SUPPORT')) THEN
      RAISE EXCEPTION 'claim-level supporting attestation missing for %',t; END IF;
  END LOOP;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p.manifest->'evidence') e WHERE NOT EXISTS(
    SELECT 1 FROM public.lexical_attestations a JOIN lexical_governance.outputs o ON o.record_id=a.id AND o.table_name='lexical_attestations' AND o.proposal_id=p.id
    WHERE a.source_entry_id=(e->>'source_entry_id')::uuid AND a.evidence_role=e->>'role')) THEN RAISE EXCEPTION 'disclosed source missing claim attestation'; END IF;
  -- Never fire caller-owned deferred triggers inside a definer function.
  SET CONSTRAINTS public.lexemes_current_lemma_fkey,public.lexical_senses_current_revision_fkey,
    public.lexemes_successor_check,public.lexeme_dialects_successor_check,public.lexeme_forms_successor_check,
    public.lexical_senses_successor_check,public.sense_dialects_successor_check,public.sense_concepts_successor_check,
    public.lexical_relationships_successor_check,public.form_relationships_successor_check,public.lexical_linguistic_evidence_successor_check IMMEDIATE;
  SET CONSTRAINTS public.lexemes_current_lemma_fkey,public.lexical_senses_current_revision_fkey,
    public.lexemes_successor_check,public.lexeme_dialects_successor_check,public.lexeme_forms_successor_check,
    public.lexical_senses_successor_check,public.sense_dialects_successor_check,public.sense_concepts_successor_check,
    public.lexical_relationships_successor_check,public.form_relationships_successor_check,public.lexical_linguistic_evidence_successor_check DEFERRED;
  RETURN result;
END $$;
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['principals','authorities','events','outputs'] LOOP
    EXECUTE format('CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON lexical_governance.%I FOR EACH ROW EXECUTE FUNCTION lexical_governance.guard_history()',t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['principals','authorities','proposals','events','outputs'] LOOP
    EXECUTE format('ALTER TABLE lexical_governance.%I ENABLE ROW LEVEL SECURITY',t);
    EXECUTE format('CREATE TRIGGER no_truncate BEFORE TRUNCATE ON lexical_governance.%I FOR EACH STATEMENT EXECUTE FUNCTION lexical_governance.guard_history()',t);
  END LOOP;
END $$;
CREATE FUNCTION lexical_governance.guard_proposal() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'proposal history cannot be deleted'; END IF;
  IF (to_jsonb(NEW)-ARRAY['state','evidence_snapshot','evidence_digest','approved_by','approved_at','authorization_snapshot','executed_at'])
     IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['state','evidence_snapshot','evidence_digest','approved_by','approved_at','authorization_snapshot','executed_at'])
     OR NOT ((OLD.state='DRAFT' AND NEW.state IN ('SUBMITTED','WITHDRAWN'))
       OR (OLD.state='SUBMITTED' AND NEW.state IN ('UNDER_REVIEW','WITHDRAWN','REJECTED'))
       OR (OLD.state='UNDER_REVIEW' AND NEW.state IN ('APPROVED','REJECTED','WITHDRAWN','DISPUTED'))
       OR (OLD.state='APPROVED' AND NEW.state IN ('EXECUTED','WITHDRAWN','DISPUTED'))
       OR (OLD.state='EXECUTED' AND NEW.state='DISPUTED')) THEN
    RAISE EXCEPTION 'illegal proposal mutation/transition' USING ERRCODE='23514';
  END IF;
  IF OLD.state<>'DRAFT' AND (NEW.evidence_snapshot IS DISTINCT FROM OLD.evidence_snapshot OR NEW.evidence_digest IS DISTINCT FROM OLD.evidence_digest) THEN
    RAISE EXCEPTION 'reviewed evidence cannot change'; END IF;
  IF OLD.approved_by IS NOT NULL AND (NEW.approved_by IS DISTINCT FROM OLD.approved_by OR NEW.approved_at IS DISTINCT FROM OLD.approved_at OR NEW.authorization_snapshot IS DISTINCT FROM OLD.authorization_snapshot) THEN
    RAISE EXCEPTION 'approval history cannot change'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER proposal_history BEFORE UPDATE OR DELETE ON lexical_governance.proposals
FOR EACH ROW EXECUTE FUNCTION lexical_governance.guard_proposal();

CREATE FUNCTION lexical_governance.actor() RETURNS uuid
LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE a uuid;
BEGIN
  SELECT contributor_id INTO a FROM lexical_governance.principals
  WHERE login_name=session_user AND revoked_at IS NULL;
  IF a IS NULL THEN RAISE EXCEPTION 'dedicated research login required' USING ERRCODE='42501'; END IF;
  RETURN a;
END $$;

-- All entry points use this lock order. SHARE locks protect evidence/rights and
-- authority from concurrent edits (including new contrary rows) through commit.
-- Conservative first-pilot locking; no hosted writes are performed by this file.
CREATE FUNCTION lexical_governance.lock_inputs() RETURNS void
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF current_setting('transaction_isolation')<>'read committed' THEN
    RAISE EXCEPTION 'promotion requires READ COMMITTED' USING ERRCODE='25000'; END IF;
  PERFORM pg_advisory_xact_lock(12012,1);
  LOCK TABLE lexical_governance.principals,lexical_governance.authorities,
    public.contributor_roles,public.contributor_role_types,public.languages,public.dialects,
    public.sources,public.source_versions,public.source_entries,public.source_import_batches,
    public.source_artifacts,public.source_version_artifacts,public.source_rights,public.source_use_policies,
    public.source_dialect_mapping_assertions,public.source_variety_mentions,public.linguistic_evidence,
    public.linguistic_evidence_dialects,public.linguistic_evidence_relations IN SHARE MODE;
END $$;

CREATE FUNCTION lexical_governance.authorize(p lexical_governance.proposals,a uuid) RETURNS jsonb
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE op jsonb; grants jsonb:='[]'::jsonb; g jsonb;
BEGIN
  IF a=p.requested_by THEN RAISE EXCEPTION 'independent canonical approver required' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM lexical_governance.principals WHERE contributor_id=a AND revoked_at IS NULL) THEN
    RAISE EXCEPTION 'approver login revoked' USING ERRCODE='42501'; END IF;
  FOR op IN SELECT value FROM jsonb_array_elements(p.manifest->'operations') LOOP
    SELECT to_jsonb(q)||jsonb_build_object('role',to_jsonb(r),'role_type',to_jsonb(t)) INTO g
    FROM lexical_governance.authorities q JOIN public.contributor_roles r ON r.id=q.contributor_role_id
    JOIN public.contributor_role_types t ON t.id=r.role_type_id
    WHERE r.contributor_id=a AND t.role_type_key='CANONICAL_APPROVER' AND t.is_active
      AND r.revoked_at IS NULL AND r.valid_from<=clock_timestamp() AND (r.valid_until IS NULL OR r.valid_until>clock_timestamp())
      AND (r.dialect_id IS NULL OR r.dialect_id=p.dialect_id) AND (r.domain IS NULL OR r.domain='LEXICAL')
      AND q.language_id IS NOT DISTINCT FROM p.language_id AND q.dialect_id IS NOT DISTINCT FROM p.dialect_id
      AND q.revoked_at IS NULL AND q.valid_from<=clock_timestamp() AND q.valid_until>clock_timestamp()
      AND ((op->>'action')||':'||(op->>'table'))=ANY(q.operation_keys)
    ORDER BY q.id LIMIT 1;
    IF g IS NULL THEN RAISE EXCEPTION 'missing current scoped authority for %',op->>'table' USING ERRCODE='42501'; END IF;
    grants:=grants||jsonb_build_array(g);
  END LOOP;
  RETURN grants;
END $$;

-- Each manifest evidence item binds a source entry, linguistic evidence, and
-- artifact. Supporting evidence must be human reviewed and locator-exact.
CREATE FUNCTION lexical_governance.evidence(p lexical_governance.proposals) RETURNS jsonb
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE item jsonb; e public.linguistic_evidence; s public.source_entries; art public.source_artifacts;
  snap jsonb:='[]'::jsonb; rights jsonb; policies jsonb; maps jsonb; rels jsonb; n bigint; v uuid;
BEGIN
  IF jsonb_typeof(p.manifest->'evidence') IS DISTINCT FROM 'array' OR jsonb_array_length(p.manifest->'evidence')=0
     OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p.manifest->'evidence') x WHERE x->>'role'='SUPPORTS') THEN
    RAISE EXCEPTION 'supporting registered evidence required'; END IF;
  IF NULLIF(btrim(p.manifest->>'contradiction_statement'),'') IS NULL THEN RAISE EXCEPTION 'contradiction disclosure required'; END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(p.manifest->'evidence') LOOP
    IF item->>'role' NOT IN ('SUPPORTS','CONTRADICTS','QUALIFIES','HISTORICAL_SUPPORT') OR item->>'role' IS NULL THEN RAISE EXCEPTION 'invalid evidence role'; END IF;
    SELECT * INTO STRICT s FROM public.source_entries WHERE id=(item->>'source_entry_id')::uuid;
    SELECT * INTO STRICT e FROM public.linguistic_evidence WHERE id=(item->>'evidence_id')::uuid;
    SELECT * INTO STRICT art FROM public.source_artifacts WHERE id=(item->>'artifact_id')::uuid;
    v:=s.source_version_id;
    IF e.source_version_id<>v OR e.source_locator IS DISTINCT FROM s.original_entry_locator OR art.artifact_status<>'REGISTERED'
       OR NOT EXISTS(SELECT 1 FROM public.source_version_artifacts WHERE source_version_id=v AND source_artifact_id=art.id)
       OR NOT EXISTS(SELECT 1 FROM public.source_import_batches WHERE id=s.import_batch_id AND artifact_checksum=art.checksum AND checksum_algorithm=art.checksum_algorithm) THEN
      RAISE EXCEPTION 'entry/evidence/artifact lineage mismatch'; END IF;
    IF item->>'role' IN ('SUPPORTS','HISTORICAL_SUPPORT') AND (e.verification_status<>'VERIFIED' OR e.reviewed_by IS NULL OR e.superseded_at IS NOT NULL) THEN
      RAISE EXCEPTION 'supporting evidence requires current human verification'; END IF;
    IF item->>'role' IN ('SUPPORTS','HISTORICAL_SUPPORT') AND p.dialect_id IS NOT NULL AND
       (e.evidence_scope<>'DIALECT' OR NOT EXISTS(SELECT 1 FROM public.linguistic_evidence_dialects WHERE evidence_id=e.id AND dialect_id=p.dialect_id AND role='PRIMARY')
       OR EXISTS(SELECT 1 FROM public.linguistic_evidence_dialects WHERE evidence_id=e.id AND role='PRIMARY' AND dialect_id<>p.dialect_id)) THEN
      RAISE EXCEPTION 'supporting evidence has incompatible linguistic scope'; END IF;
    SELECT count(*),jsonb_agg(to_jsonb(r) ORDER BY r.id) INTO n,rights FROM public.source_rights r
      WHERE source_version_id=v AND superseded_at IS NULL;
    IF n<>1 OR rights->0->>'rights_status' NOT IN ('OPEN_LICENSE','PUBLIC_DOMAIN','PERMISSION_GRANTED')
       OR (rights->0->>'effective_at')::timestamptz>clock_timestamp()
       OR (rights->0->>'expires_at')::timestamptz<=clock_timestamp() THEN RAISE EXCEPTION 'unknown, ambiguous or expired source rights'; END IF;
    SELECT count(*),jsonb_agg(to_jsonb(u) ORDER BY u.use_scope) INTO n,policies FROM public.source_use_policies u
      WHERE source_version_id=v AND use_scope IN ('INTERNAL_RESEARCH','HUMAN_REVIEW') AND superseded_at IS NULL;
    IF n<>2 OR EXISTS(SELECT 1 FROM jsonb_array_elements(policies) x WHERE x->>'decision'<>'ALLOWED'
       OR (x->>'effective_at')::timestamptz>clock_timestamp() OR (x->>'expires_at')::timestamptz<=clock_timestamp()) THEN
      RAISE EXCEPTION 'explicit current research and human review permissions required'; END IF;
    SELECT coalesce(jsonb_agg(to_jsonb(m) ORDER BY m.id),'[]') INTO maps
      FROM public.source_dialect_mapping_assertions m WHERE m.source_version_id=v AND m.raw_dialect_label=s.raw_dialect_label AND m.superseded_at IS NULL
      AND (m.mapping_scope='SOURCE_VERSION' OR m.import_batch_id=s.import_batch_id AND (m.mapping_scope='IMPORT_BATCH' OR m.source_entry_id=s.id));
    IF p.dialect_id IS NOT NULL AND (NOT EXISTS(SELECT 1 FROM jsonb_array_elements(maps) x WHERE x->>'verification_status'='VERIFIED' AND (x->>'canonical_dialect_id')::uuid=p.dialect_id)
       OR EXISTS(SELECT 1 FROM jsonb_array_elements(maps) x WHERE x->>'verification_status'='VERIFIED' AND (x->>'canonical_dialect_id')::uuid<>p.dialect_id)) THEN
      RAISE EXCEPTION 'unresolved or conflicting source variety label'; END IF;
    -- Language-level scope cannot be inferred from a dialect's classification.
    -- It requires an independent approver's explicit reviewed scope rationale.
    IF p.language_id IS NOT NULL AND (NULLIF(btrim(p.manifest->>'language_scope_rationale'),'') IS NULL OR s.raw_dialect_label IS NOT NULL) THEN
      RAISE EXCEPTION 'language scope requires explicit rationale and no unresolved variety label'; END IF;
    SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.source_evidence_id,r.target_evidence_id,r.relation_type),'[]') INTO rels
      FROM public.linguistic_evidence_relations r WHERE r.source_evidence_id=e.id OR r.target_evidence_id=e.id;
    IF EXISTS(SELECT 1 FROM public.linguistic_evidence_relations r WHERE r.relation_type IN ('CONTRADICTS','ALTERNATIVE_TO')
      AND (r.source_evidence_id=e.id OR r.target_evidence_id=e.id)
      AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p.manifest->'evidence') x WHERE (x->>'evidence_id')::uuid=CASE WHEN r.source_evidence_id=e.id THEN r.target_evidence_id ELSE r.source_evidence_id END)) THEN
      RAISE EXCEPTION 'known contradictory/alternative evidence omitted'; END IF;
    IF item->>'role'='SUPPORTS' AND EXISTS(SELECT 1 FROM public.linguistic_evidence_relations r
      WHERE r.relation_type IN ('CONTRADICTS','ALTERNATIVE_TO') AND (r.source_evidence_id=e.id OR r.target_evidence_id=e.id)
      AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p.manifest->'evidence') x
        WHERE (x->>'evidence_id')::uuid=CASE WHEN r.source_evidence_id=e.id THEN r.target_evidence_id ELSE r.source_evidence_id END
        AND x->>'role' IN ('CONTRADICTS','QUALIFIES'))) THEN RAISE EXCEPTION 'contradiction must be explicitly classified'; END IF;
    snap:=snap||jsonb_build_array(jsonb_build_object('reference',item,'entry',to_jsonb(s),'evidence',to_jsonb(e),'artifact',to_jsonb(art),
      'source_version',(SELECT to_jsonb(x) FROM public.source_versions x WHERE id=v),
      'source',(SELECT to_jsonb(x) FROM public.sources x WHERE id=(SELECT source_id FROM public.source_versions WHERE id=v)),
      'batch',(SELECT to_jsonb(x) FROM public.source_import_batches x WHERE id=s.import_batch_id),
      'artifact_links',(SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM public.source_version_artifacts x WHERE source_version_id=v),
      'evidence_scopes',(SELECT jsonb_agg(to_jsonb(x) ORDER BY dialect_id,role) FROM public.linguistic_evidence_dialects x WHERE evidence_id=e.id),
      'variety_mentions',(SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM public.source_variety_mentions x WHERE source_version_id=v),
      'rights',rights,'research_policies',policies,'mappings',maps,'relations',rels));
  END LOOP;
  RETURN snap;
END $$;

CREATE FUNCTION lexical_governance.create_proposal(document jsonb) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a uuid; ident uuid; existing lexical_governance.proposals;
BEGIN
  PERFORM lexical_governance.lock_inputs(); a:=lexical_governance.actor(); ident:=(document->>'id')::uuid;
  SELECT * INTO existing FROM lexical_governance.proposals WHERE idempotency_key=document->>'idempotency_key';
  IF FOUND THEN
    IF existing.requested_by=a AND existing.manifest=document THEN RETURN existing.id; END IF;
    RAISE EXCEPTION 'idempotency key belongs to different content';
  END IF;
  IF document->>'policy_version' IS DISTINCT FROM 'LEXICAL_PROMOTION_001' OR
     jsonb_typeof(document->'operations') IS DISTINCT FROM 'array' OR jsonb_array_length(document->'operations') NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'unsupported policy or operation list'; END IF;
  INSERT INTO lexical_governance.proposals(id,idempotency_key,proposal_type,proposal_version,policy_version,language_id,dialect_id,provenance_origin,manifest,requested_by)
    VALUES(ident,document->>'idempotency_key',document->>'proposal_type',(document->>'proposal_version')::integer,document->>'policy_version',
      (document->>'language_id')::uuid,(document->>'dialect_id')::uuid,document->>'provenance_origin',document,a);
  INSERT INTO lexical_governance.events(proposal_id,actor_id,action,details) VALUES(ident,a,'CREATE',jsonb_build_object('policy_version',document->>'policy_version','proposal_version',document->'proposal_version'));
  RETURN ident;
END $$;

CREATE FUNCTION lexical_governance.command(proposal uuid,action text DEFAULT 'dry_run',decision jsonb DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a uuid; p lexical_governance.proposals; snap jsonb; digest text; authority jsonb; results jsonb;
  missing text[]:='{}'::text[]; err text; code text; review_actor uuid;
BEGIN
  PERFORM lexical_governance.lock_inputs(); a:=lexical_governance.actor();
  SELECT * INTO STRICT p FROM lexical_governance.proposals WHERE id=proposal FOR UPDATE;
  -- Private proposal narratives are available only to the proposer or a current
  -- independently qualified approver, not every provisioned researcher.
  BEGIN
    IF a<>p.requested_by THEN PERFORM lexical_governance.authorize(p,a); END IF;
    IF action='inspect' THEN
      RETURN jsonb_build_object('proposal',to_jsonb(p),'events',(SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM lexical_governance.events e WHERE proposal_id=p.id),
        'outputs',(SELECT jsonb_agg(to_jsonb(o) ORDER BY operation_index) FROM lexical_governance.outputs o WHERE proposal_id=p.id));
    END IF;
    IF action='execute' AND p.executed_at IS NOT NULL THEN
      RETURN jsonb_build_object('ok',true,'idempotent',true,'state',p.state,'outputs',(SELECT jsonb_agg(to_jsonb(o) ORDER BY operation_index) FROM lexical_governance.outputs o WHERE proposal_id=p.id));
    END IF;
    IF action IN ('submit','approve','execute','dry_run') THEN
      snap:=lexical_governance.evidence(p);
      digest:=encode(extensions.digest(convert_to(jsonb_build_object('policy',p.policy_version,'manifest',p.manifest,'evidence',snap)::text,'UTF8'),'sha256'),'hex');
      IF p.evidence_digest IS NOT NULL AND digest<>p.evidence_digest THEN RAISE EXCEPTION 'evidence checksum changed; new proposal and review required'; END IF;
    END IF;
    IF action='dry_run' THEN
      IF p.executed_at IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'executable',false,'state',p.state,'already_executed',true); END IF;
      IF p.state<>'APPROVED' THEN missing:=array_append(missing,'separate approval required'); END IF;
      review_actor:=coalesce(p.approved_by,a);
      BEGIN authority:=lexical_governance.authorize(p,review_actor);
        IF p.approved_by IS NOT NULL AND authority IS DISTINCT FROM p.authorization_snapshot THEN missing:=array_append(missing,'approval authority changed'); END IF;
      EXCEPTION WHEN OTHERS THEN missing:=array_append(missing,SQLERRM); END;
      BEGIN
        results:=lexical_governance.apply_operations(p,review_actor);
        RAISE EXCEPTION 'rollback dry run' USING ERRCODE='PT012';
      EXCEPTION WHEN SQLSTATE 'PT012' THEN NULL;
      END;
      RETURN jsonb_build_object('ok',true,'executable',cardinality(missing)=0,'operations',results,'evidence',p.manifest->'evidence',
        'evidence_digest',digest,'missing_approvals',to_jsonb(missing),'conflicts','[]'::jsonb);
    ELSIF action='submit' AND p.state='DRAFT' AND a=p.requested_by THEN
      UPDATE lexical_governance.proposals SET state='SUBMITTED',evidence_snapshot=snap,evidence_digest=digest WHERE id=p.id;
    ELSIF action='review' AND p.state='SUBMITTED' THEN
      authority:=lexical_governance.authorize(p,a);
      UPDATE lexical_governance.proposals SET state='UNDER_REVIEW' WHERE id=p.id;
    ELSIF action='approve' AND p.state='UNDER_REVIEW' THEN
      authority:=lexical_governance.authorize(p,a);
      IF decision->>'evidence_digest' IS DISTINCT FROM digest OR decision->>'source_fidelity_confirmed' IS DISTINCT FROM 'true'
         OR NULLIF(btrim(decision->>'scope_assessment'),'') IS NULL OR NULLIF(btrim(decision->>'contradiction_assessment'),'') IS NULL THEN
        RAISE EXCEPTION 'explicit reviewed digest, source fidelity, scope and contradiction assessments required'; END IF;
      -- Approval also rehearses the exact coordinated operation; no outputs persist.
      BEGIN
        results:=lexical_governance.apply_operations(p,a);
        RAISE EXCEPTION 'rollback approval rehearsal' USING ERRCODE='PT012';
      EXCEPTION WHEN SQLSTATE 'PT012' THEN NULL; END;
      UPDATE lexical_governance.proposals SET state='APPROVED',approved_by=a,approved_at=clock_timestamp(),authorization_snapshot=authority WHERE id=p.id;
    ELSIF action='execute' AND p.state='APPROVED' THEN
      authority:=lexical_governance.authorize(p,p.approved_by);
      IF authority IS DISTINCT FROM p.authorization_snapshot THEN RAISE EXCEPTION 'approval authority changed; new review required'; END IF;
      results:=lexical_governance.apply_operations(p,p.approved_by);
      UPDATE lexical_governance.proposals SET state='EXECUTED',executed_at=clock_timestamp() WHERE id=p.id;
    ELSIF action='withdraw' AND a=p.requested_by AND p.state IN ('DRAFT','SUBMITTED','UNDER_REVIEW','APPROVED') THEN
      UPDATE lexical_governance.proposals SET state='WITHDRAWN' WHERE id=p.id;
    ELSIF action IN ('reject','dispute') THEN
      authority:=lexical_governance.authorize(p,a);
      IF NULLIF(btrim(decision->>'reason'),'') IS NULL THEN RAISE EXCEPTION 'decision reason required'; END IF;
      UPDATE lexical_governance.proposals SET state=CASE WHEN action='reject' THEN 'REJECTED' ELSE 'DISPUTED' END WHERE id=p.id;
    ELSE RAISE EXCEPTION 'illegal action, state or actor'; END IF;
    INSERT INTO lexical_governance.events(proposal_id,actor_id,action,details)
      VALUES(p.id,a,upper(action),jsonb_build_object('decision',decision,'evidence_digest',digest,'authority',authority,'outputs',results));
    RETURN jsonb_build_object('ok',true,'state',(SELECT state FROM lexical_governance.proposals WHERE id=p.id),'outputs',results,'evidence_digest',digest);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS err=MESSAGE_TEXT,code=RETURNED_SQLSTATE;
    -- The block rolls back ALL coordinated writes, then retains the failure
    -- event. The client must commit this response to retain its audit event.
    IF action<>'dry_run' THEN INSERT INTO lexical_governance.events(proposal_id,actor_id,action,details)
      VALUES(p.id,a,'FAILED_'||upper(action),jsonb_build_object('sqlstate',code,'message',err)); END IF;
    RETURN jsonb_build_object('ok',false,'executable',false,'sqlstate',code,'conflicts',jsonb_build_array(err),
      'planned_operations',p.manifest->'operations','evidence',p.manifest->'evidence',
      'missing_approvals',CASE WHEN p.approved_by IS NULL THEN jsonb_build_array('separate approval required') ELSE to_jsonb(missing) END);
  END;
END $$;

-- Revoke the privileged application bypass from 011. Existing source/rule/portal
-- grants are not changed. The private definer entry points are the only new path.
REVOKE INSERT,UPDATE ON public.lexemes,public.lexeme_forms,public.lexeme_dialects,
  public.lexical_senses,public.lexical_sense_revisions,public.sense_dialects,public.sense_concepts,
  public.lexical_attestations,public.lexical_linguistic_evidence,public.lexical_relationships,
  public.form_relationships,public.form_normalizations,public.concept_revisions FROM service_role;

CREATE FUNCTION public.tafsiri_guard_concept_governance() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE fields text[]:=ARRAY['lifecycle_status','verification_status','provenance_origin','current_revision_id','sealed_at','created_by','reviewed_by','reviewed_at','deprecated_at','superseded_by'];
  k text;
BEGIN
  -- Legacy public concept values retain their existing contract. New governance
  -- metadata cannot be adopted or changed by a service/client table write.
  IF current_user IN ('postgres','supabase_admin') THEN RETURN NEW; END IF;
  FOREACH k IN ARRAY fields LOOP
    IF (TG_OP='INSERT' AND to_jsonb(NEW)->>k IS NOT NULL) OR
       (TG_OP='UPDATE' AND to_jsonb(NEW)->k IS DISTINCT FROM to_jsonb(OLD)->k) THEN
      RAISE EXCEPTION 'concept governance requires owner-managed workflow' USING ERRCODE='42501'; END IF;
  END LOOP;
  RETURN NEW;
END $$;
CREATE TRIGGER concepts_governance_boundary BEFORE INSERT OR UPDATE ON public.concepts
FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_concept_governance();
REVOKE ALL ON FUNCTION public.tafsiri_guard_concept_governance() FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL TABLES IN SCHEMA lexical_governance FROM PUBLIC,anon,authenticated,service_role,tafsiri_lexical_researcher;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA lexical_governance FROM PUBLIC,anon,authenticated,service_role,tafsiri_lexical_researcher;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA lexical_governance FROM PUBLIC,anon,authenticated,service_role,tafsiri_lexical_researcher;
GRANT EXECUTE ON FUNCTION lexical_governance.create_proposal(jsonb),lexical_governance.command(uuid,text,jsonb) TO tafsiri_lexical_researcher;
COMMENT ON SCHEMA lexical_governance IS 'Private direct-DB research workflow; no PostgREST/JWT/portal authority; no seed principals or qualifications.';
