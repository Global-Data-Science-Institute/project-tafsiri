-- Project Tafsiri Migration 006: source, provenance, rights, and dialect-mapping foundation.
-- Schema and access controls only. This migration intentionally inserts no data.

CREATE TABLE public.sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_key text NOT NULL UNIQUE,
  source_type text NOT NULL,
  title text NOT NULL,
  authors_or_contributors text,
  publisher_or_institution text,
  publication_year integer,
  citation text,
  primary_url text,
  rights_holder text,
  default_register text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sources_key_not_blank CHECK (btrim(source_key) <> ''),
  CONSTRAINT sources_title_not_blank CHECK (btrim(title) <> ''),
  CONSTRAINT sources_type_check CHECK (source_type IN (
    'DICTIONARY','LEXICON','WEBSITE','CORPUS','BIBLE_EDITION',
    'PROVERB_COLLECTION','FIELDWORK','COMMUNITY_CONTRIBUTION','DATASET','OTHER'
  )),
  CONSTRAINT sources_publication_year_check CHECK (
    publication_year IS NULL OR publication_year BETWEEN 1000 AND 2100
  ),
  CONSTRAINT sources_primary_url_not_blank CHECK (primary_url IS NULL OR btrim(primary_url) <> '')
);

CREATE TABLE public.source_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id uuid NOT NULL REFERENCES public.sources(id) ON DELETE RESTRICT,
  version_key text NOT NULL,
  edition_label text,
  version_label text,
  publication_date date,
  release_date date,
  canonical_url text,
  citation_override text,
  checksum text,
  checksum_algorithm text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_versions_source_key_unique UNIQUE (source_id, version_key),
  CONSTRAINT source_versions_id_source_unique UNIQUE (id, source_id),
  CONSTRAINT source_versions_key_not_blank CHECK (btrim(version_key) <> ''),
  CONSTRAINT source_versions_url_not_blank CHECK (canonical_url IS NULL OR btrim(canonical_url) <> ''),
  CONSTRAINT source_versions_checksum_pair_check CHECK (
    (checksum IS NULL AND checksum_algorithm IS NULL)
    OR (checksum IS NOT NULL AND btrim(checksum) <> '' AND checksum_algorithm IS NOT NULL AND btrim(checksum_algorithm) <> '')
  )
);

CREATE TABLE public.source_rights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  rights_status text NOT NULL,
  license_identifier text,
  license_text_or_summary text,
  rights_holder text,
  permission_document_reference text,
  jurisdiction text,
  effective_at timestamptz,
  expires_at timestamptz,
  evidence_reference text,
  notes text,
  recorded_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  superseded_at timestamptz,
  superseded_by uuid,
  CONSTRAINT source_rights_id_version_unique UNIQUE (id, source_version_id),
  CONSTRAINT source_rights_status_check CHECK (rights_status IN (
    'OPEN_LICENSE','PUBLIC_DOMAIN','PERMISSION_GRANTED','PUBLICLY_ACCESSIBLE_CITED',
    'CONTACTED_NO_RESPONSE','RESTRICTED','UNKNOWN'
  )),
  CONSTRAINT source_rights_expiry_check CHECK (expires_at IS NULL OR effective_at IS NULL OR expires_at > effective_at),
  CONSTRAINT source_rights_supersession_check CHECK (
    (superseded_at IS NULL AND superseded_by IS NULL)
    OR (superseded_at IS NOT NULL AND superseded_by IS NOT NULL AND superseded_by <> id)
  )
);

ALTER TABLE public.source_rights
  ADD CONSTRAINT source_rights_superseded_by_fkey
  FOREIGN KEY (superseded_by, source_version_id)
  REFERENCES public.source_rights(id, source_version_id) ON DELETE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE public.source_use_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  use_scope text NOT NULL,
  decision text NOT NULL DEFAULT 'UNKNOWN',
  policy_basis_reference text,
  deciding_authority text,
  policy_version text NOT NULL,
  effective_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  superseded_at timestamptz,
  superseded_by uuid,
  CONSTRAINT source_use_policies_id_version_unique UNIQUE (id, source_version_id),
  CONSTRAINT source_use_policies_scope_check CHECK (use_scope IN (
    'INTERNAL_RESEARCH','HUMAN_REVIEW','REVIEWER_DISPLAY','PUBLIC_DISPLAY',
    'REDISTRIBUTION','MODEL_TRAINING','BENCHMARK_PUBLICATION','COMMERCIAL_API'
  )),
  CONSTRAINT source_use_policies_decision_check CHECK (decision IN (
    'ALLOWED','DISALLOWED','REVIEW_REQUIRED','UNKNOWN'
  )),
  CONSTRAINT source_use_policies_version_not_blank CHECK (btrim(policy_version) <> ''),
  CONSTRAINT source_use_policies_non_unknown_basis_check CHECK (
    decision = 'UNKNOWN'
    OR (policy_basis_reference IS NOT NULL AND btrim(policy_basis_reference) <> '')
    OR (notes IS NOT NULL AND btrim(notes) <> '')
  ),
  CONSTRAINT source_use_policies_expiry_check CHECK (expires_at IS NULL OR expires_at > effective_at),
  CONSTRAINT source_use_policies_supersession_check CHECK (
    (superseded_at IS NULL AND superseded_by IS NULL)
    OR (superseded_at IS NOT NULL AND superseded_by IS NOT NULL AND superseded_by <> id)
  )
);

ALTER TABLE public.source_use_policies
  ADD CONSTRAINT source_use_policies_superseded_by_fkey
  FOREIGN KEY (superseded_by, source_version_id)
  REFERENCES public.source_use_policies(id, source_version_id) ON DELETE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;

CREATE UNIQUE INDEX source_use_policies_current_unique
  ON public.source_use_policies (source_version_id, use_scope)
  WHERE superseded_at IS NULL;

CREATE TABLE public.source_contact_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id uuid REFERENCES public.sources(id) ON DELETE RESTRICT,
  source_version_id uuid REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  contact_date date NOT NULL,
  contact_method text NOT NULL,
  contact_target text NOT NULL,
  requested_uses text[] NOT NULL DEFAULT '{}',
  response_status text NOT NULL,
  response_date date,
  evidence_document_reference text,
  notes text,
  recorded_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_contact_events_source_check CHECK (source_id IS NOT NULL OR source_version_id IS NOT NULL),
  CONSTRAINT source_contact_events_method_not_blank CHECK (btrim(contact_method) <> ''),
  CONSTRAINT source_contact_events_target_not_blank CHECK (btrim(contact_target) <> ''),
  CONSTRAINT source_contact_events_requested_uses_check CHECK (
    requested_uses <@ ARRAY[
      'INTERNAL_RESEARCH','HUMAN_REVIEW','REVIEWER_DISPLAY','PUBLIC_DISPLAY',
      'REDISTRIBUTION','MODEL_TRAINING','BENCHMARK_PUBLICATION','COMMERCIAL_API'
    ]::text[]
  ),
  CONSTRAINT source_contact_events_response_check CHECK (response_status IN (
    'NOT_CONTACTED','CONTACTED','NO_RESPONSE','PERMISSION_GRANTED',
    'PERMISSION_DENIED','MORE_INFORMATION_REQUESTED'
  )),
  CONSTRAINT source_contact_events_response_date_check CHECK (response_date IS NULL OR response_date >= contact_date)
);

ALTER TABLE public.source_contact_events
  ADD CONSTRAINT source_contact_events_version_source_fkey
  FOREIGN KEY (source_version_id, source_id)
  REFERENCES public.source_versions(id, source_id) ON DELETE RESTRICT;

CREATE TABLE public.source_import_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  import_batch_key text NOT NULL,
  original_artifact_name text,
  original_artifact_location text,
  artifact_checksum text NOT NULL,
  checksum_algorithm text NOT NULL,
  import_method text NOT NULL,
  import_tool text NOT NULL,
  import_tool_version text NOT NULL,
  transformation_specification text,
  transformation_config_hash text,
  normalization_version text,
  imported_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  imported_at timestamptz NOT NULL DEFAULT now(),
  source_row_count integer,
  accepted_row_count integer,
  rejected_row_count integer,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_import_batches_key_unique UNIQUE (source_version_id, import_batch_key),
  CONSTRAINT source_import_batches_id_version_unique UNIQUE (id, source_version_id),
  CONSTRAINT source_import_batches_key_not_blank CHECK (btrim(import_batch_key) <> ''),
  CONSTRAINT source_import_batches_checksum_not_blank CHECK (btrim(artifact_checksum) <> '' AND btrim(checksum_algorithm) <> ''),
  CONSTRAINT source_import_batches_method_not_blank CHECK (btrim(import_method) <> ''),
  CONSTRAINT source_import_batches_tool_not_blank CHECK (btrim(import_tool) <> '' AND btrim(import_tool_version) <> ''),
  CONSTRAINT source_import_batches_counts_nonnegative CHECK (
    (source_row_count IS NULL OR source_row_count >= 0)
    AND (accepted_row_count IS NULL OR accepted_row_count >= 0)
    AND (rejected_row_count IS NULL OR rejected_row_count >= 0)
  ),
  CONSTRAINT source_import_batches_counts_consistent CHECK (
    source_row_count IS NULL OR accepted_row_count IS NULL OR rejected_row_count IS NULL
    OR accepted_row_count + rejected_row_count <= source_row_count
  )
);

CREATE UNIQUE INDEX source_import_batches_identity_unique
  ON public.source_import_batches (
    source_version_id, artifact_checksum, checksum_algorithm, import_tool,
    import_tool_version, COALESCE(transformation_config_hash, '')
  );

CREATE TABLE public.source_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL,
  import_batch_id uuid NOT NULL,
  original_entry_locator text,
  original_form text,
  original_gloss text,
  original_part_of_speech text,
  original_noun_class text,
  raw_dialect_label text,
  original_page text,
  original_url text,
  original_identifier text,
  original_formatting jsonb,
  historical_source_table text,
  historical_source_row_id text,
  source_entry_checksum text NOT NULL,
  occurrence_sequence integer NOT NULL DEFAULT 1,
  imported_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_entries_batch_version_fkey
    FOREIGN KEY (import_batch_id, source_version_id)
    REFERENCES public.source_import_batches(id, source_version_id) ON DELETE RESTRICT,
  CONSTRAINT source_entries_id_batch_version_unique UNIQUE (id, import_batch_id, source_version_id),
  CONSTRAINT source_entries_content_check CHECK (
    NULLIF(btrim(original_form), '') IS NOT NULL
    OR NULLIF(btrim(original_gloss), '') IS NOT NULL
    OR NULLIF(btrim(original_part_of_speech), '') IS NOT NULL
    OR NULLIF(btrim(original_noun_class), '') IS NOT NULL
    OR NULLIF(btrim(raw_dialect_label), '') IS NOT NULL
    OR NULLIF(btrim(original_identifier), '') IS NOT NULL
    OR original_formatting IS NOT NULL
  ),
  CONSTRAINT source_entries_history_pair_check CHECK (
    (historical_source_table IS NULL AND historical_source_row_id IS NULL)
    OR (
      historical_source_table IS NOT NULL AND btrim(historical_source_table) <> ''
      AND historical_source_row_id IS NOT NULL AND btrim(historical_source_row_id) <> ''
    )
  ),
  CONSTRAINT source_entries_checksum_not_blank CHECK (btrim(source_entry_checksum) <> ''),
  CONSTRAINT source_entries_occurrence_positive CHECK (occurrence_sequence > 0)
);

CREATE UNIQUE INDEX source_entries_locator_unique
  ON public.source_entries (import_batch_id, original_entry_locator)
  WHERE original_entry_locator IS NOT NULL;

CREATE UNIQUE INDEX source_entries_checksum_occurrence_unique
  ON public.source_entries (import_batch_id, source_entry_checksum, occurrence_sequence);

CREATE TABLE public.source_dialect_mapping_assertions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  import_batch_id uuid,
  source_entry_id uuid,
  raw_dialect_label text NOT NULL,
  canonical_dialect_id uuid NOT NULL REFERENCES public.dialects(id) ON DELETE RESTRICT,
  mapping_scope text NOT NULL,
  authority text,
  rationale text,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  policy_version text NOT NULL,
  effective_at timestamptz NOT NULL DEFAULT now(),
  superseded_at timestamptz,
  superseded_by uuid,
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_dialect_mappings_id_version_unique UNIQUE (id, source_version_id),
  CONSTRAINT source_dialect_mappings_batch_version_fkey
    FOREIGN KEY (import_batch_id, source_version_id)
    REFERENCES public.source_import_batches(id, source_version_id) ON DELETE RESTRICT,
  CONSTRAINT source_dialect_mappings_entry_scope_fkey
    FOREIGN KEY (source_entry_id, import_batch_id, source_version_id)
    REFERENCES public.source_entries(id, import_batch_id, source_version_id) ON DELETE RESTRICT,
  CONSTRAINT source_dialect_mappings_label_not_blank CHECK (btrim(raw_dialect_label) <> ''),
  CONSTRAINT source_dialect_mappings_scope_check CHECK (mapping_scope IN (
    'SOURCE_VERSION','IMPORT_BATCH','SOURCE_ENTRY'
  )),
  CONSTRAINT source_dialect_mappings_scope_fields_check CHECK (
    (mapping_scope = 'SOURCE_VERSION' AND import_batch_id IS NULL AND source_entry_id IS NULL)
    OR (mapping_scope = 'IMPORT_BATCH' AND import_batch_id IS NOT NULL AND source_entry_id IS NULL)
    OR (mapping_scope = 'SOURCE_ENTRY' AND import_batch_id IS NOT NULL AND source_entry_id IS NOT NULL)
  ),
  CONSTRAINT source_dialect_mappings_status_check CHECK (verification_status IN (
    'UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED'
  )),
  CONSTRAINT source_dialect_mappings_policy_not_blank CHECK (btrim(policy_version) <> ''),
  CONSTRAINT source_dialect_mappings_verified_check CHECK (
    verification_status <> 'VERIFIED'
    OR (
      authority IS NOT NULL AND btrim(authority) <> ''
      AND rationale IS NOT NULL AND btrim(rationale) <> ''
      AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL
    )
  ),
  CONSTRAINT source_dialect_mappings_review_consistency_check CHECK (
    (reviewed_by IS NULL AND reviewed_at IS NULL)
    OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
  ),
  CONSTRAINT source_dialect_mappings_supersession_check CHECK (
    (superseded_at IS NULL AND superseded_by IS NULL)
    OR (superseded_at IS NOT NULL AND superseded_by IS NOT NULL AND superseded_by <> id)
  )
);

ALTER TABLE public.source_dialect_mapping_assertions
  ADD CONSTRAINT source_dialect_mappings_superseded_by_fkey
  FOREIGN KEY (superseded_by, source_version_id)
  REFERENCES public.source_dialect_mapping_assertions(id, source_version_id) ON DELETE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;

CREATE INDEX source_rights_version_idx ON public.source_rights (source_version_id);
CREATE INDEX source_entries_version_idx ON public.source_entries (source_version_id);
CREATE INDEX source_dialect_mappings_dialect_idx ON public.source_dialect_mapping_assertions (canonical_dialect_id);
CREATE INDEX source_dialect_mappings_raw_label_idx ON public.source_dialect_mapping_assertions (raw_dialect_label);

CREATE TRIGGER sources_updated_at
  BEFORE UPDATE ON public.sources
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_touch_updated_at();

CREATE TRIGGER source_versions_updated_at
  BEFORE UPDATE ON public.source_versions
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_touch_updated_at();

ALTER TABLE public.sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_rights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_use_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_contact_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_import_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_dialect_mapping_assertions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.sources FROM anon, authenticated;
REVOKE ALL ON TABLE public.source_versions FROM anon, authenticated;
REVOKE ALL ON TABLE public.source_rights FROM anon, authenticated;
REVOKE ALL ON TABLE public.source_use_policies FROM anon, authenticated;
REVOKE ALL ON TABLE public.source_contact_events FROM anon, authenticated;
REVOKE ALL ON TABLE public.source_import_batches FROM anon, authenticated;
REVOKE ALL ON TABLE public.source_entries FROM anon, authenticated;
REVOKE ALL ON TABLE public.source_dialect_mapping_assertions FROM anon, authenticated;

GRANT ALL PRIVILEGES ON TABLE public.sources TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_versions TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_rights TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_use_policies TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_contact_events TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_import_batches TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_entries TO service_role;
GRANT ALL PRIVILEGES ON TABLE public.source_dialect_mapping_assertions TO service_role;

COMMENT ON TABLE public.sources IS
  'Registry of source works and collections; source metadata is evidence and is not canonical linguistic data.';
COMMENT ON TABLE public.source_rights IS
  'Descriptive rights evidence. Rights status never grants a use automatically; consult source_use_policies.';
COMMENT ON TABLE public.source_use_policies IS
  'Explicit, use-specific policy decisions independent of descriptive source-rights status.';
COMMENT ON TABLE public.source_contact_events IS
  'Administrative outreach evidence; contact outcomes do not automatically change rights or use policies.';
COMMENT ON TABLE public.source_entries IS
  'Append-oriented imported source evidence. Original fields must not be overwritten to perform linguistic correction.';
COMMENT ON COLUMN public.source_entries.raw_dialect_label IS
  'Dialect label exactly as represented by the source; canonical mapping is stored separately.';
COMMENT ON TABLE public.source_dialect_mapping_assertions IS
  'Reviewed source-context assertions mapping raw dialect labels to canonical dialect identities.';
