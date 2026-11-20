-- Migration 013. Empty additive extensions of the existing identities/evidence.
-- No seed languages, aliases, qualifications, rights or readiness approvals.
CREATE SCHEMA language_registry;
REVOKE ALL ON SCHEMA language_registry FROM PUBLIC, anon, authenticated, service_role;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='tafsiri_registry_reader') THEN
    CREATE ROLE tafsiri_registry_reader NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
  ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname='tafsiri_registry_reader'
    AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit OR rolreplication OR rolbypassrls))
    OR EXISTS (SELECT 1 FROM pg_auth_members WHERE member='tafsiri_registry_reader'::regrole) THEN
    RAISE EXCEPTION 'reserved registry role has unexpected authority';
  END IF;
END $$;

-- One extension per EXISTING language or dialect; never a replacement identity.
CREATE TABLE language_registry.profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  language_id uuid UNIQUE REFERENCES public.languages(id),
  dialect_id uuid UNIQUE REFERENCES public.dialects(id),
  lifecycle text NOT NULL DEFAULT 'REGISTERED' CHECK (lifecycle IN ('REGISTERED','RESEARCH_ENABLED','SUSPENDED','RETIRED')),
  community_name text NOT NULL CHECK (btrim(community_name)<>''),
  approval_reference text NOT NULL CHECK (btrim(approval_reference)<>''),
  approved_by uuid NOT NULL REFERENCES public.contributors(id),
  approved_at timestamptz NOT NULL DEFAULT now(),
  CHECK (num_nonnulls(language_id,dialect_id)=1)
);
CREATE TABLE language_registry.names_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES language_registry.profiles(id),
  kind text NOT NULL CHECK (kind IN ('COMMUNITY_NAME','ALTERNATIVE_NAME','CODE')),
  value text NOT NULL CHECK (btrim(value)<>''),
  standard text,
  standard_version text,
  evidence_reference text NOT NULL CHECK (btrim(evidence_reference)<>''),
  status text NOT NULL CHECK (status IN ('PROPOSED','VERIFIED','DISPUTED','REJECTED')),
  reviewed_by uuid REFERENCES public.contributors(id),
  reviewed_at timestamptz,
  CHECK (kind<>'CODE' OR (nullif(btrim(standard),'') IS NOT NULL AND nullif(btrim(standard_version),'') IS NOT NULL)),
  CHECK ((reviewed_by IS NULL)=(reviewed_at IS NULL)),
  CHECK (status<>'VERIFIED' OR reviewed_by IS NOT NULL)
);
CREATE INDEX names_codes_profile_idx ON language_registry.names_codes(profile_id);
CREATE TABLE language_registry.classifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id uuid NOT NULL REFERENCES language_registry.profiles(id),
  object_id uuid NOT NULL REFERENCES language_registry.profiles(id),
  relationship text NOT NULL CHECK (relationship IN ('VARIETY_OF','RELATED_TO','CLASSIFIED_WITH','UNRELATED_TO')),
  status text NOT NULL CHECK (status IN ('PROPOSED','VERIFIED','DISPUTED','REJECTED')),
  evidence_reference text NOT NULL CHECK (btrim(evidence_reference)<>''),
  reviewed_by uuid REFERENCES public.contributors(id),
  reviewed_at timestamptz,
  CHECK (subject_id<>object_id),
  CHECK ((reviewed_by IS NULL)=(reviewed_at IS NULL)),
  CHECK (status<>'VERIFIED' OR reviewed_by IS NOT NULL)
);
CREATE INDEX classifications_subject_idx ON language_registry.classifications(subject_id);
CREATE INDEX classifications_object_idx ON language_registry.classifications(object_id);
CREATE TABLE language_registry.orthographies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES language_registry.profiles(id),
  orthography_key text NOT NULL CHECK (btrim(orthography_key)<>''),
  version text NOT NULL CHECK (btrim(version)<>''),
  writing_system text NOT NULL CHECK (btrim(writing_system)<>''),
  script_standard text NOT NULL CHECK (btrim(script_standard)<>''),
  script_standard_version text NOT NULL CHECK (btrim(script_standard_version)<>''),
  direction text NOT NULL CHECK (direction IN ('LTR','RTL','VERTICAL','MIXED')),
  normalization text NOT NULL CHECK (normalization IN ('PRESERVE','NFC')),
  status text NOT NULL CHECK (status IN ('PROPOSED','VERIFIED','DISPUTED','REJECTED')),
  evidence_reference text NOT NULL CHECK (btrim(evidence_reference)<>''),
  reviewed_by uuid REFERENCES public.contributors(id),
  reviewed_at timestamptz,
  UNIQUE (profile_id,orthography_key,version),
  UNIQUE (id,profile_id),
  CHECK ((reviewed_by IS NULL)=(reviewed_at IS NULL)),
  CHECK (status<>'VERIFIED' OR reviewed_by IS NOT NULL)
);
-- Independent approvals, not an ordinal ladder inferred from registration.
CREATE TABLE language_registry.capabilities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES language_registry.profiles(id),
  capability text NOT NULL CHECK (capability IN ('DATASET_ELIGIBLE','MODEL_EVALUATION_ELIGIBLE','MODEL_AVAILABLE','COMMERCIALLY_AVAILABLE')),
  approval_reference text NOT NULL CHECK (btrim(approval_reference)<>''),
  approved_by uuid NOT NULL REFERENCES public.contributors(id),
  approved_at timestamptz NOT NULL DEFAULT now(),
  valid_from timestamptz NOT NULL,
  valid_until timestamptz NOT NULL CHECK (valid_until>valid_from),
  revoked_at timestamptz
);
CREATE INDEX capabilities_profile_idx ON language_registry.capabilities(profile_id);
CREATE TABLE language_registry.configurations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES language_registry.profiles(id),
  configuration_key text NOT NULL CHECK (btrim(configuration_key)<>''),
  version integer NOT NULL CHECK (version>0),
  orthography_id uuid NOT NULL,
  content_sha256 text NOT NULL CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
  approval_reference text NOT NULL CHECK (btrim(approval_reference)<>''),
  approved_by uuid NOT NULL REFERENCES public.contributors(id),
  approved_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  UNIQUE (profile_id,configuration_key,version),
  FOREIGN KEY (orthography_id,profile_id) REFERENCES language_registry.orthographies(id,profile_id)
);
-- Exact-scope internal read access. Never inherited via classifications or names.
CREATE TABLE language_registry.access_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  login_name name NOT NULL CHECK (login_name NOT IN ('postgres','supabase_admin','authenticator','anon','authenticated','service_role')),
  profile_id uuid NOT NULL REFERENCES language_registry.profiles(id),
  approval_reference text NOT NULL CHECK (btrim(approval_reference)<>''),
  valid_from timestamptz NOT NULL,
  valid_until timestamptz NOT NULL CHECK (valid_until>valid_from),
  revoked_at timestamptz
);
CREATE INDEX access_grants_scope_idx ON language_registry.access_grants(login_name,profile_id);

-- Existing source/version/entry/evidence identities, component-level assertions.
-- An unresolved literal has NO identity. Conflicting interpretations coexist.
CREATE TABLE language_registry.source_scopes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL REFERENCES public.source_versions(id),
  source_entry_id uuid,
  import_batch_id uuid,
  evidence_id uuid,
  component text NOT NULL CHECK (component IN ('DOCUMENT','EVIDENCE','HEADWORD','GLOSS','EXAMPLE','COMMENTARY','REFERENCE')),
  locator text NOT NULL CHECK (btrim(locator)<>''),
  literal_label text NOT NULL CHECK (btrim(literal_label)<>''),
  language_id uuid REFERENCES public.languages(id),
  dialect_id uuid REFERENCES public.dialects(id),
  status text NOT NULL CHECK (status IN ('UNRESOLVED','PROPOSED','VERIFIED','DISPUTED','REJECTED')),
  evidence_reference text NOT NULL CHECK (btrim(evidence_reference)<>''),
  reviewed_by uuid REFERENCES public.contributors(id),
  reviewed_at timestamptz,
  FOREIGN KEY (source_entry_id,import_batch_id,source_version_id) REFERENCES public.source_entries(id,import_batch_id,source_version_id),
  FOREIGN KEY (evidence_id,source_version_id) REFERENCES public.linguistic_evidence(id,source_version_id),
  CHECK ((source_entry_id IS NULL)=(import_batch_id IS NULL)),
  CHECK (component<>'EVIDENCE' OR evidence_id IS NOT NULL),
  CHECK (num_nonnulls(language_id,dialect_id)<=1),
  CHECK (status<>'UNRESOLVED' OR num_nonnulls(language_id,dialect_id)=0),
  CHECK (status<>'VERIFIED' OR (num_nonnulls(language_id,dialect_id)=1 AND reviewed_by IS NOT NULL)),
  CHECK ((reviewed_by IS NULL)=(reviewed_at IS NULL))
);
CREATE INDEX source_scopes_version_idx ON language_registry.source_scopes(source_version_id);
CREATE INDEX source_scopes_entry_idx ON language_registry.source_scopes(source_entry_id);
CREATE INDEX source_scopes_evidence_idx ON language_registry.source_scopes(evidence_id);
CREATE INDEX source_scopes_language_idx ON language_registry.source_scopes(language_id);
CREATE INDEX source_scopes_dialect_idx ON language_registry.source_scopes(dialect_id);
CREATE FUNCTION language_registry.check_source_scope() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF current_setting('transaction_isolation')<>'read committed' THEN RAISE EXCEPTION 'scope changes require READ COMMITTED'; END IF;
  IF NEW.evidence_id IS NOT NULL THEN
    PERFORM 1 FROM public.linguistic_evidence WHERE id=NEW.evidence_id FOR UPDATE;
  END IF;
  IF NEW.source_entry_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.source_entries WHERE id=NEW.source_entry_id AND source_version_id=NEW.source_version_id
  ) THEN RAISE EXCEPTION 'source entry version mismatch'; END IF;
  IF NEW.evidence_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.linguistic_evidence WHERE id=NEW.evidence_id AND source_version_id=NEW.source_version_id
  ) THEN RAISE EXCEPTION 'evidence version mismatch'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER source_scope_lineage BEFORE INSERT OR UPDATE ON language_registry.source_scopes
FOR EACH ROW EXECUTE FUNCTION language_registry.check_source_scope();

-- Widen only the scope enum; all historical values and rows remain valid.
ALTER TABLE public.linguistic_evidence DROP CONSTRAINT linguistic_evidence_scope_check;
ALTER TABLE public.linguistic_evidence ADD CONSTRAINT linguistic_evidence_scope_check
  CHECK (evidence_scope IN ('DIALECT','MULTI_DIALECT_COMPARATIVE','PROTO_LANGUAGE','FAMILY_GENERALIZATION','LANGUAGE','MULTILINGUAL'));
CREATE FUNCTION language_registry.validate_evidence_scope() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE ident uuid; e public.linguistic_evidence; n integer;
BEGIN
  ident:=(to_jsonb(NEW)->>CASE WHEN TG_TABLE_NAME='linguistic_evidence' THEN 'id' ELSE 'evidence_id' END)::uuid;
  IF ident IS NULL THEN RETURN NULL; END IF;
  SELECT * INTO e FROM public.linguistic_evidence WHERE id=ident FOR UPDATE;
  IF e.evidence_scope NOT IN ('LANGUAGE','MULTILINGUAL') THEN RETURN NULL; END IF;
  IF current_setting('transaction_isolation')<>'read committed' THEN RAISE EXCEPTION 'scope changes require READ COMMITTED'; END IF;
  SELECT count(DISTINCT CASE WHEN language_id IS NOT NULL THEN 'language:'||language_id::text ELSE 'variety:'||dialect_id::text END) INTO n
    FROM language_registry.source_scopes WHERE evidence_id=ident AND component='EVIDENCE'
      AND status=CASE WHEN e.verification_status='VERIFIED' THEN 'VERIFIED' ELSE 'PROPOSED' END;
  IF e.verification_status<>'VERIFIED' THEN
    SELECT count(DISTINCT CASE WHEN language_id IS NOT NULL THEN 'language:'||language_id::text ELSE 'variety:'||dialect_id::text END) INTO n FROM language_registry.source_scopes
      WHERE evidence_id=ident AND component='EVIDENCE' AND status IN ('PROPOSED','VERIFIED','DISPUTED');
  END IF;
  IF (e.evidence_scope='LANGUAGE' AND (n<>1 OR EXISTS(SELECT 1 FROM language_registry.source_scopes
      WHERE evidence_id=ident AND component='EVIDENCE' AND dialect_id IS NOT NULL AND status IN ('PROPOSED','VERIFIED'))))
    OR (e.evidence_scope='MULTILINGUAL' AND n<2) THEN
    RAISE EXCEPTION 'explicit compatible evidence language scopes required'; END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER multilingual_evidence_scope AFTER INSERT OR UPDATE ON public.linguistic_evidence
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION language_registry.validate_evidence_scope();
CREATE CONSTRAINT TRIGGER multilingual_scope_assertion AFTER INSERT OR UPDATE ON language_registry.source_scopes
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION language_registry.validate_evidence_scope();

-- Existing policy 001 never hashes the new assertion layer. Fail closed until
-- an independently reviewed policy binds those assertions and qualifications.
CREATE FUNCTION language_registry.guard_legacy_promotion() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  LOCK TABLE language_registry.source_scopes IN SHARE MODE;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(NEW.manifest->'evidence') item
    JOIN public.linguistic_evidence e ON e.id=(item->>'evidence_id')::uuid
    WHERE e.evidence_scope IN ('LANGUAGE','MULTILINGUAL') OR EXISTS (
      SELECT 1 FROM language_registry.source_scopes s WHERE s.source_version_id=e.source_version_id)) THEN
    RAISE EXCEPTION 'multilingual source scopes require a new reviewed promotion policy';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER multilingual_promotion_policy BEFORE INSERT OR UPDATE ON lexical_governance.proposals
FOR EACH ROW EXECUTE FUNCTION language_registry.guard_legacy_promotion();

CREATE TABLE language_registry.events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  object_table text NOT NULL,
  object_id uuid NOT NULL,
  actor text NOT NULL DEFAULT session_user,
  recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  old_record jsonb,
  new_record jsonb NOT NULL
);
CREATE FUNCTION language_registry.audit_change() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  INSERT INTO language_registry.events(object_table,object_id,old_record,new_record)
    VALUES(TG_TABLE_NAME,NEW.id,CASE WHEN TG_OP='UPDATE' THEN to_jsonb(OLD) END,to_jsonb(NEW));
  RETURN NEW;
END $$;
CREATE FUNCTION language_registry.immutable_record() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF TG_OP='UPDATE' AND TG_TABLE_NAME='profiles'
    AND (to_jsonb(NEW)-ARRAY['lifecycle','approval_reference','approved_by','approved_at'])=
        (to_jsonb(OLD)-ARRAY['lifecycle','approval_reference','approved_by','approved_at']) THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND TG_TABLE_NAME IN ('names_codes','classifications','orthographies','source_scopes')
    AND (to_jsonb(NEW)-ARRAY['status','reviewed_by','reviewed_at'])=
        (to_jsonb(OLD)-ARRAY['status','reviewed_by','reviewed_at']) THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND TG_TABLE_NAME IN ('capabilities','configurations','access_grants')
    AND (to_jsonb(NEW)-'revoked_at')=(to_jsonb(OLD)-'revoked_at')
    AND to_jsonb(OLD)->>'revoked_at' IS NULL AND to_jsonb(NEW)->>'revoked_at' IS NOT NULL THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'registry history is immutable; create a new assertion or revoke approval';
END $$;

CREATE FUNCTION language_registry.lookup(kind text, identity uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p language_registry.profiles; result jsonb;
BEGIN
  IF kind NOT IN ('language','variety') OR kind IS NULL OR identity IS NULL THEN
    RAISE EXCEPTION 'exact language or variety identity required'; END IF;
  SELECT * INTO p FROM language_registry.profiles
    WHERE (kind='language' AND language_id=identity) OR (kind='variety' AND dialect_id=identity);
  IF p.id IS NULL OR NOT EXISTS (SELECT 1 FROM language_registry.access_grants g
    WHERE g.profile_id=p.id AND g.login_name=session_user AND g.revoked_at IS NULL
      AND now()>=g.valid_from AND now()<g.valid_until) THEN
    RAISE EXCEPTION 'registry scope access denied' USING ERRCODE='42501'; END IF;
  SELECT jsonb_build_object('contract_version',1,'kind',kind,'id',identity,
    'community_name',p.community_name,'lifecycle',p.lifecycle,
    'registered',true,'research_enabled',p.lifecycle='RESEARCH_ENABLED',
    'names_codes',coalesce((SELECT jsonb_agg(jsonb_build_object('kind',n.kind,'value',n.value,'standard',n.standard,'standard_version',n.standard_version) ORDER BY n.id)
      FROM language_registry.names_codes n WHERE n.profile_id=p.id AND n.status='VERIFIED'),'[]'::jsonb),
    'classification_uncertain',EXISTS (SELECT 1 FROM language_registry.classifications c WHERE c.subject_id=p.id AND c.status IN ('PROPOSED','DISPUTED')),
    'orthographies',coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'key',o.orthography_key,'version',o.version,'writing_system',o.writing_system,'script_standard',o.script_standard,'script_standard_version',o.script_standard_version,'direction',o.direction,'normalization',o.normalization) ORDER BY o.id)
      FROM language_registry.orthographies o WHERE o.profile_id=p.id AND o.status='VERIFIED'),'[]'::jsonb),
    'capabilities',coalesce((SELECT jsonb_agg(DISTINCT c.capability) FROM language_registry.capabilities c
      WHERE c.profile_id=p.id AND c.revoked_at IS NULL AND now()>=c.valid_from AND now()<c.valid_until AND p.lifecycle='RESEARCH_ENABLED'),'[]'::jsonb)) INTO result;
  RETURN result;
END $$;

CREATE FUNCTION language_registry.resolve_configuration(kind text, identity uuid, config_key text, config_version integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE info jsonb; result jsonb;
BEGIN
  info:=language_registry.lookup(kind,identity);
  IF info->>'research_enabled'<>'true' THEN RAISE EXCEPTION 'research not enabled'; END IF;
  SELECT jsonb_build_object('key',c.configuration_key,'version',c.version,'sha256',c.content_sha256,'orthography_id',c.orthography_id)
    INTO result FROM language_registry.configurations c JOIN language_registry.profiles p ON p.id=c.profile_id
    JOIN language_registry.orthographies o ON o.id=c.orthography_id AND o.status='VERIFIED'
    WHERE ((kind='language' AND p.language_id=identity) OR (kind='variety' AND p.dialect_id=identity))
      AND c.configuration_key=config_key AND c.version=config_version AND c.revoked_at IS NULL;
  IF result IS NULL THEN RAISE EXCEPTION 'approved configuration version unavailable'; END IF;
  RETURN result;
END $$;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['profiles','names_codes','classifications','orthographies','capabilities','configurations','access_grants','source_scopes','events'] LOOP
    EXECUTE format('ALTER TABLE language_registry.%I ENABLE ROW LEVEL SECURITY',t);
    EXECUTE format('REVOKE ALL ON language_registry.%I FROM PUBLIC,anon,authenticated,service_role,tafsiri_registry_reader',t);
    EXECUTE format('CREATE TRIGGER immutable_history BEFORE UPDATE OR DELETE ON language_registry.%I FOR EACH ROW EXECUTE FUNCTION language_registry.immutable_record()',t);
    EXECUTE format('CREATE TRIGGER immutable_truncate BEFORE TRUNCATE ON language_registry.%I FOR EACH STATEMENT EXECUTE FUNCTION language_registry.immutable_record()',t);
    IF t<>'events' THEN
      EXECUTE format('CREATE TRIGGER registry_audit AFTER INSERT OR UPDATE ON language_registry.%I FOR EACH ROW EXECUTE FUNCTION language_registry.audit_change()',t);
    END IF;
  END LOOP;
END $$;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA language_registry FROM PUBLIC,anon,authenticated,service_role,tafsiri_registry_reader;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA language_registry FROM PUBLIC,anon,authenticated,service_role,tafsiri_registry_reader;
GRANT USAGE ON SCHEMA language_registry TO tafsiri_registry_reader;
GRANT EXECUTE ON FUNCTION language_registry.lookup(text,uuid),language_registry.resolve_configuration(text,uuid,text,integer) TO tafsiri_registry_reader;
