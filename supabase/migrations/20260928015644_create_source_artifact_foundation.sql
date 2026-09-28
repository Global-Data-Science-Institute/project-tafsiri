-- Project Tafsiri Migration 010: source artifact and acquisition foundation.
-- Schema and access controls only. This migration intentionally inserts no data.

CREATE TABLE public.source_artifacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  artifact_key text NOT NULL UNIQUE,
  checksum_algorithm text NOT NULL,
  checksum text NOT NULL,
  byte_size bigint NOT NULL,
  media_type text NOT NULL,
  artifact_kind text NOT NULL DEFAULT 'SOURCE_REPRESENTATION',
  artifact_status text NOT NULL DEFAULT 'REGISTERED',
  page_count integer,
  workbook_sheet_count integer,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_artifacts_identity_unique UNIQUE (checksum_algorithm, checksum),
  CONSTRAINT source_artifacts_key_not_blank CHECK (btrim(artifact_key) <> ''),
  CONSTRAINT source_artifacts_algorithm_check CHECK (checksum_algorithm IN ('SHA256')),
  CONSTRAINT source_artifacts_sha256_check CHECK (
    checksum_algorithm <> 'SHA256' OR checksum ~ '^[0-9a-f]{64}$'
  ),
  CONSTRAINT source_artifacts_byte_size_nonnegative CHECK (byte_size >= 0),
  CONSTRAINT source_artifacts_media_type_not_blank CHECK (btrim(media_type) <> ''),
  CONSTRAINT source_artifacts_kind_check CHECK (artifact_kind IN (
    'SOURCE_REPRESENTATION','DERIVED_REPRESENTATION'
  )),
  CONSTRAINT source_artifacts_status_check CHECK (artifact_status IN (
    'REGISTERED','QUARANTINED'
  )),
  CONSTRAINT source_artifacts_page_count_positive CHECK (page_count IS NULL OR page_count > 0),
  CONSTRAINT source_artifacts_sheet_count_nonnegative CHECK (
    workbook_sheet_count IS NULL OR workbook_sheet_count >= 0
  )
);

CREATE TABLE public.source_version_artifacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  source_artifact_id uuid NOT NULL REFERENCES public.source_artifacts(id) ON DELETE RESTRICT,
  artifact_role text NOT NULL,
  is_preferred boolean NOT NULL DEFAULT false,
  evidence_reference text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_version_artifacts_pair_unique UNIQUE (source_version_id, source_artifact_id),
  CONSTRAINT source_version_artifacts_role_check CHECK (artifact_role IN (
    'SOURCE_REPRESENTATION','RECEIVED_COPY','ARCHIVAL_COPY','REFORMATTED_COPY',
    'DERIVED_COPY','OCR_DERIVATIVE','NORMALIZED_DERIVATIVE','OTHER'
  )),
  CONSTRAINT source_version_artifacts_evidence_not_blank CHECK (
    evidence_reference IS NULL OR btrim(evidence_reference) <> ''
  )
);

CREATE UNIQUE INDEX source_version_artifacts_preferred_unique
  ON public.source_version_artifacts (source_version_id)
  WHERE is_preferred;

CREATE INDEX source_version_artifacts_artifact_idx
  ON public.source_version_artifacts (source_artifact_id);

CREATE TABLE public.source_artifact_acquisitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_artifact_id uuid NOT NULL REFERENCES public.source_artifacts(id) ON DELETE RESTRICT,
  acquisition_key text NOT NULL UNIQUE,
  acquisition_type text NOT NULL,
  acquired_at timestamptz,
  original_filename text,
  provider_contributor_id uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  provider_name text,
  source_contact_event_id uuid REFERENCES public.source_contact_events(id) ON DELETE RESTRICT,
  acquisition_channel text NOT NULL,
  acquisition_group_key text,
  evidence_reference text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_artifact_acquisitions_key_not_blank CHECK (btrim(acquisition_key) <> ''),
  CONSTRAINT source_artifact_acquisitions_type_check CHECK (acquisition_type IN (
    'DIRECT_RESEARCHER_PROVISION','PUBLIC_DOWNLOAD','INSTITUTIONAL_REPOSITORY',
    'AUTHOR_WEBSITE','PROJECT_ARCHIVE','LEGACY_IMPORT','OTHER'
  )),
  CONSTRAINT source_artifact_acquisitions_filename_not_blank CHECK (
    original_filename IS NULL OR btrim(original_filename) <> ''
  ),
  CONSTRAINT source_artifact_acquisitions_provider_name_not_blank CHECK (
    provider_name IS NULL OR btrim(provider_name) <> ''
  ),
  CONSTRAINT source_artifact_acquisitions_channel_check CHECK (acquisition_channel IN (
    'EMAIL','SHARED_DRIVE','WEB_DOWNLOAD','INSTITUTIONAL_TRANSFER',
    'LOCAL_RESEARCH_ARCHIVE','PROJECT_GENERATED','OTHER'
  )),
  CONSTRAINT source_artifact_acquisitions_group_not_blank CHECK (
    acquisition_group_key IS NULL OR btrim(acquisition_group_key) <> ''
  ),
  CONSTRAINT source_artifact_acquisitions_evidence_not_blank CHECK (
    evidence_reference IS NULL OR btrim(evidence_reference) <> ''
  ),
  CONSTRAINT source_artifact_acquisitions_direct_provider_check CHECK (
    acquisition_type <> 'DIRECT_RESEARCHER_PROVISION'
    OR provider_contributor_id IS NOT NULL
    OR NULLIF(btrim(provider_name), '') IS NOT NULL
  )
);

CREATE INDEX source_artifact_acquisitions_artifact_idx
  ON public.source_artifact_acquisitions (source_artifact_id);
CREATE INDEX source_artifact_acquisitions_provider_idx
  ON public.source_artifact_acquisitions (provider_contributor_id)
  WHERE provider_contributor_id IS NOT NULL;
CREATE INDEX source_artifact_acquisitions_contact_idx
  ON public.source_artifact_acquisitions (source_contact_event_id)
  WHERE source_contact_event_id IS NOT NULL;
CREATE INDEX source_artifact_acquisitions_group_idx
  ON public.source_artifact_acquisitions (acquisition_group_key)
  WHERE acquisition_group_key IS NOT NULL;

CREATE TABLE public.source_artifact_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_artifact_id uuid NOT NULL REFERENCES public.source_artifacts(id) ON DELETE RESTRICT,
  location_key text NOT NULL,
  storage_class text NOT NULL,
  location_reference text NOT NULL,
  availability_status text NOT NULL DEFAULT 'UNKNOWN',
  is_primary boolean NOT NULL DEFAULT false,
  verified_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_artifact_locations_key_unique UNIQUE (source_artifact_id, location_key),
  CONSTRAINT source_artifact_locations_key_not_blank CHECK (btrim(location_key) <> ''),
  CONSTRAINT source_artifact_locations_storage_check CHECK (storage_class IN (
    'PRIVATE_ARCHIVE','OBJECT_STORAGE','PUBLIC_URL','INSTITUTIONAL_REPOSITORY',
    'AUTHOR_SITE','DATA_REPOSITORY','OTHER'
  )),
  CONSTRAINT source_artifact_locations_reference_not_blank CHECK (btrim(location_reference) <> ''),
  CONSTRAINT source_artifact_locations_no_local_path_check CHECK (
    location_reference !~ '^[A-Za-z]:[\\/]'
    AND location_reference !~ '^/'
    AND lower(location_reference) !~ '^file:'
  ),
  CONSTRAINT source_artifact_locations_availability_check CHECK (availability_status IN (
    'AVAILABLE','UNAVAILABLE','RESTRICTED','UNKNOWN'
  ))
);

CREATE UNIQUE INDEX source_artifact_locations_primary_unique
  ON public.source_artifact_locations (source_artifact_id)
  WHERE is_primary;

CREATE TABLE public.source_artifact_sets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  artifact_set_key text NOT NULL UNIQUE,
  source_version_id uuid NOT NULL REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  set_type text NOT NULL,
  label text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_artifact_sets_id_version_unique UNIQUE (id, source_version_id),
  CONSTRAINT source_artifact_sets_key_not_blank CHECK (btrim(artifact_set_key) <> ''),
  CONSTRAINT source_artifact_sets_type_check CHECK (set_type IN (
    'MULTIPART_DOCUMENT','VOLUME_SET','SCAN_SECTION_SET','CORPUS_PACKAGE',
    'AUDIO_COLLECTION','OTHER'
  )),
  CONSTRAINT source_artifact_sets_label_not_blank CHECK (label IS NULL OR btrim(label) <> '')
);

CREATE INDEX source_artifact_sets_version_idx
  ON public.source_artifact_sets (source_version_id);

CREATE TABLE public.source_artifact_set_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  artifact_set_id uuid NOT NULL,
  source_version_id uuid NOT NULL,
  source_artifact_id uuid NOT NULL,
  sequence_number integer NOT NULL,
  component_label text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_artifact_set_members_set_version_fkey
    FOREIGN KEY (artifact_set_id, source_version_id)
    REFERENCES public.source_artifact_sets(id, source_version_id) ON DELETE RESTRICT,
  CONSTRAINT source_artifact_set_members_version_artifact_fkey
    FOREIGN KEY (source_version_id, source_artifact_id)
    REFERENCES public.source_version_artifacts(source_version_id, source_artifact_id) ON DELETE RESTRICT,
  CONSTRAINT source_artifact_set_members_artifact_unique UNIQUE (artifact_set_id, source_artifact_id),
  CONSTRAINT source_artifact_set_members_sequence_unique UNIQUE (artifact_set_id, sequence_number),
  CONSTRAINT source_artifact_set_members_sequence_positive CHECK (sequence_number > 0),
  CONSTRAINT source_artifact_set_members_label_not_blank CHECK (
    component_label IS NULL OR btrim(component_label) <> ''
  )
);

CREATE INDEX source_artifact_set_members_artifact_idx
  ON public.source_artifact_set_members (source_artifact_id);
CREATE INDEX source_artifact_set_members_version_idx
  ON public.source_artifact_set_members (source_version_id);

ALTER TABLE public.source_import_batches
  ADD COLUMN source_artifact_id uuid;

ALTER TABLE public.source_import_batches
  ADD CONSTRAINT source_import_batches_version_artifact_fkey
  FOREIGN KEY (source_version_id, source_artifact_id)
  REFERENCES public.source_version_artifacts(source_version_id, source_artifact_id)
  ON DELETE RESTRICT;

CREATE INDEX source_import_batches_artifact_idx
  ON public.source_import_batches (source_artifact_id)
  WHERE source_artifact_id IS NOT NULL;

CREATE FUNCTION public.tafsiri_validate_import_batch_artifact()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  registered_algorithm text;
  registered_checksum text;
BEGIN
  IF NEW.source_artifact_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT artifact.checksum_algorithm, artifact.checksum
  INTO registered_algorithm, registered_checksum
  FROM public.source_artifacts AS artifact
  WHERE artifact.id = NEW.source_artifact_id;

  IF registered_algorithm IS NULL
     OR upper(replace(NEW.checksum_algorithm, '-', '')) <> registered_algorithm
     OR lower(NEW.artifact_checksum) <> registered_checksum THEN
    RAISE EXCEPTION 'import batch artifact checksum does not match registered artifact identity'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER source_import_batches_artifact_identity_check
  BEFORE INSERT OR UPDATE OF source_artifact_id, artifact_checksum, checksum_algorithm
  ON public.source_import_batches
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_validate_import_batch_artifact();

CREATE FUNCTION public.tafsiri_guard_source_artifact_identity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF NEW.checksum_algorithm IS DISTINCT FROM OLD.checksum_algorithm
     OR NEW.checksum IS DISTINCT FROM OLD.checksum
     OR NEW.byte_size IS DISTINCT FROM OLD.byte_size
     OR NEW.media_type IS DISTINCT FROM OLD.media_type THEN
    RAISE EXCEPTION 'source artifact binary identity fields are immutable'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER source_artifacts_identity_immutable
  BEFORE UPDATE ON public.source_artifacts
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_source_artifact_identity();

CREATE TRIGGER source_artifact_locations_updated_at
  BEFORE UPDATE ON public.source_artifact_locations
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_touch_updated_at();

ALTER TABLE public.source_artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_version_artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_artifact_acquisitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_artifact_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_artifact_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_artifact_set_members ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.source_artifacts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.source_version_artifacts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.source_artifact_acquisitions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.source_artifact_locations FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.source_artifact_sets FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.source_artifact_set_members FROM PUBLIC, anon, authenticated;

GRANT ALL PRIVILEGES ON TABLE public.source_artifacts TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_version_artifacts TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_artifact_acquisitions TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_artifact_locations TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_artifact_sets TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_artifact_set_members TO service_role;

REVOKE ALL ON FUNCTION public.tafsiri_guard_source_artifact_identity() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tafsiri_guard_source_artifact_identity() TO service_role;
REVOKE ALL ON FUNCTION public.tafsiri_validate_import_batch_artifact() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tafsiri_validate_import_batch_artifact() TO service_role;

COMMENT ON TABLE public.source_artifacts IS
  'Immutable content-addressed artifact identity. Artifact identity is distinct from source version, acquisition, location, rights, and import execution.';
COMMENT ON TABLE public.source_version_artifacts IS
  'Many-to-many association between intellectual source versions and exact artifact bytes; preferred means Tafsiri processing/reference preference, not canonical or legal authority.';
COMMENT ON TABLE public.source_artifact_acquisitions IS
  'Receipt provenance for exact artifacts. Acquisition, including direct researcher provision, never grants rights or changes source use policy.';
COMMENT ON TABLE public.source_artifact_locations IS
  'Portable retrieval/storage references. Location availability and storage access are distinct from copyright and permitted use.';
COMMENT ON TABLE public.source_artifact_sets IS
  'Logical ordered artifact grouping for a source version, including multipart documents.';
COMMENT ON TABLE public.source_artifact_set_members IS
  'Ordered membership whose artifacts must already be associated with the artifact set source version.';
COMMENT ON COLUMN public.source_import_batches.source_artifact_id IS
  'Optional exact artifact processed by this execution. Historical batches remain NULL until separately reconciled by proven checksum; no automatic backfill is performed.';
COMMENT ON COLUMN public.source_import_batches.artifact_checksum IS
  'Immutable historical import snapshot retained from Migration 006; new linked batches must also resolve to the registered artifact identity.';
