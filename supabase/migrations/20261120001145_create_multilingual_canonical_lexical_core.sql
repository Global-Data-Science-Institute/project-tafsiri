-- Migration 011: empty multilingual Canonical Lexical Core foundation.
-- No ingestion, promotion, training, backfill, portal access or hosted deployment.
-- Apply atomically (Supabase migration runner / psql --single-transaction).
-- Existing concepts retain values and grants; all new metadata defaults to NULL.

-- Shared vocabularies are CHECK constraints in the minimum foundation.
-- All foreign keys intentionally use ON DELETE RESTRICT.

ALTER TABLE public.concepts
  ADD COLUMN lifecycle_status text,
  ADD COLUMN verification_status text,
  ADD COLUMN provenance_origin text,
  ADD COLUMN current_revision_id uuid,
  ADD COLUMN sealed_at timestamptz,
  ADD COLUMN created_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  ADD COLUMN reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  ADD COLUMN reviewed_at timestamptz,
  ADD COLUMN deprecated_at timestamptz,
  ADD COLUMN superseded_by uuid REFERENCES public.concepts(id) ON DELETE RESTRICT,
  ADD CONSTRAINT concepts_lifecycle_check CHECK (lifecycle_status IN ('PROVISIONAL','ACTIVE','DISPUTED','DEPRECATED','SUPERSEDED')),
  ADD CONSTRAINT concepts_verification_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  ADD CONSTRAINT concepts_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  ADD CONSTRAINT concepts_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  ),
  ADD CONSTRAINT concepts_lifecycle_dates_check CHECK (
    (lifecycle_status <> 'DEPRECATED' OR deprecated_at IS NOT NULL)
    AND (lifecycle_status <> 'SUPERSEDED' OR superseded_by IS NOT NULL)
    AND superseded_by IS DISTINCT FROM id
  );

CREATE TABLE public.concept_revisions (
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  concept_id uuid NOT NULL REFERENCES public.concepts(id) ON DELETE RESTRICT,
  revision_number integer NOT NULL,
  definition text NOT NULL,
  definition_language_id uuid REFERENCES public.languages(id) ON DELETE RESTRICT,
  definition_dialect_id uuid REFERENCES public.dialects(id) ON DELETE RESTRICT,
  CONSTRAINT concept_revisions_definition_scope_check CHECK (num_nonnulls(definition_language_id,definition_dialect_id)=1),
  domain text,
  subdomain text,
  notes text,
  revision_reason text NOT NULL,
  provenance_origin text NOT NULL,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  created_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT concept_revisions_number_check CHECK (revision_number > 0),
  CONSTRAINT concept_revisions_text_check CHECK (btrim(definition) <> '' AND btrim(revision_reason) <> ''),
  CONSTRAINT concept_revisions_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT concept_revisions_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT concept_revisions_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  ),
  CONSTRAINT concept_revisions_number_unique UNIQUE (concept_id,revision_number),
  CONSTRAINT concept_revisions_id_parent_unique UNIQUE (id,concept_id)
);

ALTER TABLE public.concepts
  ADD CONSTRAINT concepts_current_revision_fkey
  FOREIGN KEY (current_revision_id,id) REFERENCES public.concept_revisions(id,concept_id)
  ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE public.lexemes (
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lexeme_key text NOT NULL UNIQUE,
  language_id uuid REFERENCES public.languages(id) ON DELETE RESTRICT,
  identity_dialect_id uuid REFERENCES public.dialects(id) ON DELETE RESTRICT,
  CONSTRAINT lexemes_identity_scope_check CHECK (num_nonnulls(language_id,identity_dialect_id)=1),
  lifecycle_status text NOT NULL DEFAULT 'PROVISIONAL',
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  provenance_origin text NOT NULL,
  created_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  current_lemma_form_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deprecated_at timestamptz,
  superseded_by uuid REFERENCES public.lexemes(id) ON DELETE RESTRICT,
  CONSTRAINT lexemes_key_check CHECK (btrim(lexeme_key) <> ''),
  CONSTRAINT lexemes_lifecycle_check CHECK (lifecycle_status IN ('PROVISIONAL','ACTIVE','DISPUTED','DEPRECATED','SUPERSEDED')),
  CONSTRAINT lexemes_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT lexemes_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT lexemes_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  ),
  CONSTRAINT lexemes_lifecycle_dates_check CHECK (
    (lifecycle_status <> 'DEPRECATED' OR deprecated_at IS NOT NULL)
    AND (lifecycle_status <> 'SUPERSEDED' OR superseded_by IS NOT NULL)
    AND superseded_by IS DISTINCT FROM id
  )
);

CREATE TABLE public.lexeme_dialects (
  superseded_at timestamptz,
  superseded_by uuid REFERENCES public.lexeme_dialects(id) ON DELETE RESTRICT,
  CONSTRAINT lexeme_dialects_supersession_check CHECK ((superseded_at IS NULL)=(superseded_by IS NULL) AND superseded_by IS DISTINCT FROM id),
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lexeme_id uuid NOT NULL REFERENCES public.lexemes(id) ON DELETE RESTRICT,
  dialect_id uuid NOT NULL REFERENCES public.dialects(id) ON DELETE RESTRICT,
  role text NOT NULL,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  provenance_origin text NOT NULL,
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lexeme_dialects_role_check CHECK (role IN ('PRIMARY','ATTESTED_IN','SHARED','CONTRASTS_WITH')),
  CONSTRAINT lexeme_dialects_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT lexeme_dialects_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT lexeme_dialects_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  )
);

CREATE TABLE public.lexeme_forms (
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_key text NOT NULL UNIQUE,
  lexeme_id uuid NOT NULL REFERENCES public.lexemes(id) ON DELETE RESTRICT,
  representation_text text NOT NULL,
  representation_system text NOT NULL,
  form_role text NOT NULL,
  orthography_key text,
  orthography_version text,
  CONSTRAINT lexeme_forms_orthography_check CHECK (
    (orthography_key IS NULL AND orthography_version IS NULL) OR
    (orthography_key IS NOT NULL AND orthography_version IS NOT NULL AND btrim(orthography_key)<>'' AND btrim(orthography_version)<>'')),
  dialect_id uuid REFERENCES public.dialects(id) ON DELETE RESTRICT,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  provenance_origin text NOT NULL,
  created_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  replacement_form_id uuid REFERENCES public.lexeme_forms(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  deprecated_at timestamptz,
  CONSTRAINT lexeme_forms_key_text_check CHECK (btrim(form_key) <> '' AND btrim(representation_text) <> ''),
  CONSTRAINT lexeme_forms_system_check CHECK (representation_system IN ('ORTHOGRAPHIC','IPA_PHONEMIC','IPA_PHONETIC','TONE_MARKED_ORTHOGRAPHIC','TRANSLITERATION','OTHER')),
  CONSTRAINT lexeme_forms_role_check CHECK (form_role IN ('LEMMA','ORTHOGRAPHIC_VARIANT','HISTORICAL','INFLECTED','DERIVED','BORROWED','TONE_MARKED','ALTERNATE_TRANSCRIPTION','OTHER')),
  CONSTRAINT lexeme_forms_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT lexeme_forms_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT lexeme_forms_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  ),
  CONSTRAINT lexeme_forms_replacement_check CHECK (replacement_form_id IS DISTINCT FROM id),
  CONSTRAINT lexeme_forms_deprecation_check CHECK (deprecated_at IS NULL OR replacement_form_id IS NOT NULL),
  CONSTRAINT lexeme_forms_id_parent_unique UNIQUE (id,lexeme_id)
);

ALTER TABLE public.lexemes ADD CONSTRAINT lexemes_current_lemma_fkey
  FOREIGN KEY (current_lemma_form_id,id) REFERENCES public.lexeme_forms(id,lexeme_id)
  ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE public.form_normalizations (
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  normalization_key text NOT NULL UNIQUE,
  source_entry_id uuid NOT NULL REFERENCES public.source_entries(id) ON DELETE RESTRICT,
  target_form_id uuid REFERENCES public.lexeme_forms(id) ON DELETE RESTRICT,
  normalized_text text NOT NULL,
  scope_language_id uuid REFERENCES public.languages(id) ON DELETE RESTRICT,
  scope_dialect_id uuid REFERENCES public.dialects(id) ON DELETE RESTRICT,
  CONSTRAINT form_normalizations_scope_check CHECK (num_nonnulls(scope_language_id,scope_dialect_id)=1),
  normalization_policy_version text NOT NULL,
  normalization_method text NOT NULL,
  provenance_origin text NOT NULL,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  rationale text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT form_normalizations_text_check CHECK (
    btrim(normalization_key) <> '' AND btrim(normalized_text) <> ''
    AND btrim(normalization_policy_version) <> '' AND btrim(normalization_method) <> '' AND btrim(rationale) <> ''
  ),
  CONSTRAINT form_normalizations_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT form_normalizations_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT form_normalizations_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  ),
  CONSTRAINT form_normalizations_version_unique UNIQUE NULLS NOT DISTINCT (source_entry_id,scope_language_id,scope_dialect_id,normalization_policy_version,normalized_text)
);

CREATE TABLE public.lexical_senses (
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sense_key text NOT NULL UNIQUE,
  lexeme_id uuid NOT NULL REFERENCES public.lexemes(id) ON DELETE RESTRICT,
  lifecycle_status text NOT NULL DEFAULT 'PROVISIONAL',
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  provenance_origin text NOT NULL,
  current_revision_id uuid,
  created_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  deprecated_at timestamptz,
  superseded_by uuid REFERENCES public.lexical_senses(id) ON DELETE RESTRICT,
  CONSTRAINT lexical_senses_key_check CHECK (btrim(sense_key) <> ''),
  CONSTRAINT lexical_senses_lifecycle_check CHECK (lifecycle_status IN ('PROVISIONAL','ACTIVE','DISPUTED','DEPRECATED','SUPERSEDED')),
  CONSTRAINT lexical_senses_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT lexical_senses_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT lexical_senses_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  ),
  CONSTRAINT lexical_senses_lifecycle_dates_check CHECK (
    (lifecycle_status <> 'DEPRECATED' OR deprecated_at IS NOT NULL)
    AND (lifecycle_status <> 'SUPERSEDED' OR superseded_by IS NOT NULL)
    AND superseded_by IS DISTINCT FROM id
  )
);

CREATE TABLE public.lexical_sense_revisions (
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sense_id uuid NOT NULL REFERENCES public.lexical_senses(id) ON DELETE RESTRICT,
  revision_number integer NOT NULL,
  definition text NOT NULL,
  definition_language_id uuid REFERENCES public.languages(id) ON DELETE RESTRICT,
  definition_dialect_id uuid REFERENCES public.dialects(id) ON DELETE RESTRICT,
  CONSTRAINT lexical_sense_revisions_definition_scope_check CHECK (num_nonnulls(definition_language_id,definition_dialect_id)=1),
  lexical_category text NOT NULL DEFAULT 'UNKNOWN',
  source_category_label text,
  register text,
  domain text,
  grammatical_restrictions text,
  cultural_context text,
  usage_notes text,
  revision_reason text NOT NULL,
  provenance_origin text NOT NULL,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  created_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sense_revisions_number_check CHECK (revision_number > 0),
  CONSTRAINT sense_revisions_text_check CHECK (btrim(definition) <> '' AND btrim(revision_reason) <> ''),
  CONSTRAINT sense_revisions_category_check CHECK (lexical_category IN ('NOUN','VERB','ADJECTIVE','ADVERB','PRONOUN','DETERMINER','NUMERAL','ADPOSITION','CONJUNCTION','INTERJECTION','IDEOPHONE','PARTICLE','OTHER','UNKNOWN')),
  CONSTRAINT sense_revisions_register_check CHECK (register IS NULL OR register IN ('GENERAL','RELIGIOUS','HISTORICAL','TECHNICAL','COLLOQUIAL','FORMAL','CULTURAL','OTHER')),
  CONSTRAINT sense_revisions_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT sense_revisions_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT sense_revisions_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  ),
  CONSTRAINT sense_revisions_number_unique UNIQUE (sense_id,revision_number),
  CONSTRAINT sense_revisions_id_parent_unique UNIQUE (id,sense_id)
);

ALTER TABLE public.lexical_senses ADD CONSTRAINT lexical_senses_current_revision_fkey
  FOREIGN KEY (current_revision_id,id) REFERENCES public.lexical_sense_revisions(id,sense_id)
  ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE public.sense_dialects (
  superseded_at timestamptz,
  superseded_by uuid REFERENCES public.sense_dialects(id) ON DELETE RESTRICT,
  CONSTRAINT sense_dialects_supersession_check CHECK ((superseded_at IS NULL)=(superseded_by IS NULL) AND superseded_by IS DISTINCT FROM id),
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sense_id uuid NOT NULL REFERENCES public.lexical_senses(id) ON DELETE RESTRICT,
  dialect_id uuid NOT NULL REFERENCES public.dialects(id) ON DELETE RESTRICT,
  role text NOT NULL,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  provenance_origin text NOT NULL,
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sense_dialects_role_check CHECK (role IN ('APPLIES_TO','ATTESTED_IN','RESTRICTED_TO','CONTRASTS_WITH')),
  CONSTRAINT sense_dialects_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT sense_dialects_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT sense_dialects_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  )
);

CREATE TABLE public.sense_concepts (
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sense_id uuid NOT NULL REFERENCES public.lexical_senses(id) ON DELETE RESTRICT,
  concept_id uuid NOT NULL REFERENCES public.concepts(id) ON DELETE RESTRICT,
  mapping_status text NOT NULL DEFAULT 'CANDIDATE',
  provenance_origin text NOT NULL,
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  confidence numeric(5,4),
  rationale text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  superseded_at timestamptz,
  superseded_by uuid REFERENCES public.sense_concepts(id) ON DELETE RESTRICT,
  CONSTRAINT sense_concepts_status_check CHECK (mapping_status IN ('CANDIDATE','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT sense_concepts_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT sense_concepts_confidence_check CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  CONSTRAINT sense_concepts_rationale_check CHECK (btrim(rationale) <> ''),
  CONSTRAINT sense_concepts_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((mapping_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  ),
  CONSTRAINT sense_concepts_supersession_check CHECK ((superseded_at IS NULL) = (superseded_by IS NULL) AND superseded_by IS DISTINCT FROM id)
);
CREATE UNIQUE INDEX sense_concepts_current_verified_unique ON public.sense_concepts(sense_id)
  WHERE mapping_status='VERIFIED' AND superseded_at IS NULL;

CREATE TABLE public.lexical_relationships (
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_lexeme_id uuid NOT NULL REFERENCES public.lexemes(id) ON DELETE RESTRICT,
  target_lexeme_id uuid NOT NULL REFERENCES public.lexemes(id) ON DELETE RESTRICT,
  relationship_type text NOT NULL,
  provenance_origin text NOT NULL,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  superseded_at timestamptz,
  superseded_by uuid REFERENCES public.lexical_relationships(id) ON DELETE RESTRICT,
  CONSTRAINT lexical_relationships_type_check CHECK (relationship_type IN ('DERIVED_FROM','BORROWED_FROM','COGNATE_WITH','SYNONYM_OF','ANTONYM_OF','RELATED_TO','OTHER')),
  CONSTRAINT lexical_relationships_self_check CHECK (source_lexeme_id <> target_lexeme_id),
  CONSTRAINT lexical_relationships_order_check CHECK (relationship_type IN ('DERIVED_FROM','BORROWED_FROM','OTHER') OR source_lexeme_id < target_lexeme_id),
  CONSTRAINT lexical_relationships_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT lexical_relationships_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT lexical_relationships_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  ),
  CONSTRAINT lexical_relationships_supersession_check CHECK ((superseded_at IS NULL) = (superseded_by IS NULL) AND superseded_by IS DISTINCT FROM id)
);
CREATE UNIQUE INDEX lexical_relationships_current_unique
  ON public.lexical_relationships(source_lexeme_id,target_lexeme_id,relationship_type)
  WHERE superseded_at IS NULL;

CREATE TABLE public.form_relationships (
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_form_id uuid NOT NULL REFERENCES public.lexeme_forms(id) ON DELETE RESTRICT,
  target_form_id uuid NOT NULL REFERENCES public.lexeme_forms(id) ON DELETE RESTRICT,
  relationship_type text NOT NULL,
  provenance_origin text NOT NULL,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  superseded_at timestamptz,
  superseded_by uuid REFERENCES public.form_relationships(id) ON DELETE RESTRICT,
  CONSTRAINT form_relationships_type_check CHECK (relationship_type IN ('ORTHOGRAPHIC_VARIANT','PHONOLOGICAL_VARIANT','MORPHOLOGICAL_VARIANT','HISTORICAL_VARIANT','BORROWED_FORM','INFLECTED_FORM','DERIVED_FORM','ALTERNATE_TRANSCRIPTION')),
  CONSTRAINT form_relationships_self_check CHECK (source_form_id <> target_form_id),
  CONSTRAINT form_relationships_order_check CHECK (
    relationship_type IN ('BORROWED_FORM','INFLECTED_FORM','DERIVED_FORM') OR source_form_id < target_form_id
  ),
  CONSTRAINT form_relationships_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT form_relationships_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT form_relationships_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  ),
  CONSTRAINT form_relationships_supersession_check CHECK ((superseded_at IS NULL) = (superseded_by IS NULL) AND superseded_by IS DISTINCT FROM id)
);
CREATE UNIQUE INDEX form_relationships_current_unique
  ON public.form_relationships(source_form_id,target_form_id,relationship_type)
  WHERE superseded_at IS NULL;

CREATE TABLE public.lexical_attestations (
  sealed_at timestamptz,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attestation_key text NOT NULL UNIQUE,
  source_entry_id uuid NOT NULL REFERENCES public.source_entries(id) ON DELETE RESTRICT,
  lexeme_id uuid REFERENCES public.lexemes(id) ON DELETE RESTRICT,
  form_id uuid REFERENCES public.lexeme_forms(id) ON DELETE RESTRICT,
  sense_revision_id uuid REFERENCES public.lexical_sense_revisions(id) ON DELETE RESTRICT,
  sense_concept_id uuid REFERENCES public.sense_concepts(id) ON DELETE RESTRICT,
  lexical_relationship_id uuid REFERENCES public.lexical_relationships(id) ON DELETE RESTRICT,
  form_relationship_id uuid REFERENCES public.form_relationships(id) ON DELETE RESTRICT,
  claim_type text NOT NULL,
  evidence_role text NOT NULL,
  claimed_value jsonb,
  provenance_origin text NOT NULL,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lexical_attestations_key_check CHECK (btrim(attestation_key) <> ''),
  CONSTRAINT lexical_attestations_target_check CHECK (num_nonnulls(lexeme_id,form_id,sense_revision_id,sense_concept_id,lexical_relationship_id,form_relationship_id)=1),
  CONSTRAINT lexical_attestations_claim_check CHECK (claim_type IN ('LEXEME_IDENTITY','FORM','LEXICAL_CATEGORY','SENSE','DIALECT_SCOPE','CONCEPT_MAPPING','RELATIONSHIP','BORROWING','OTHER')),
  CONSTRAINT lexical_attestations_role_check CHECK (evidence_role IN ('SUPPORTS','CONTRADICTS','QUALIFIES','EXCEPTION','HISTORICAL_SUPPORT')),
  CONSTRAINT lexical_attestations_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  CONSTRAINT lexical_attestations_status_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  CONSTRAINT lexical_attestations_review_check CHECK (
    (reviewed_by IS NULL) = (reviewed_at IS NULL)
    AND ((verification_status NOT IN ('VERIFIED','REJECTED','DISPUTED') AND sealed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
  )
);

CREATE TABLE public.lexical_linguistic_evidence (
  superseded_at timestamptz,
  superseded_by uuid REFERENCES public.lexical_linguistic_evidence(id) ON DELETE RESTRICT,
  CONSTRAINT lexical_linguistic_evidence_supersession_check CHECK ((superseded_at IS NULL)=(superseded_by IS NULL) AND superseded_by IS DISTINCT FROM id),
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evidence_id uuid NOT NULL REFERENCES public.linguistic_evidence(id) ON DELETE RESTRICT,
  lexeme_id uuid REFERENCES public.lexemes(id) ON DELETE RESTRICT,
  form_id uuid REFERENCES public.lexeme_forms(id) ON DELETE RESTRICT,
  sense_revision_id uuid REFERENCES public.lexical_sense_revisions(id) ON DELETE RESTRICT,
  evidence_role text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lexical_linguistic_evidence_target_check CHECK (num_nonnulls(lexeme_id,form_id,sense_revision_id)=1),
  CONSTRAINT lexical_linguistic_evidence_role_check CHECK (evidence_role IN ('PRONUNCIATION','TONE','SYLLABIFICATION','MORPHOLOGY','ETYMOLOGY','OTHER'))
);

-- Correctness and direct lookup indexes only.
CREATE INDEX lexemes_language_lifecycle_idx ON public.lexemes(language_id,lifecycle_status);
CREATE INDEX lexemes_verification_idx ON public.lexemes(verification_status);
CREATE INDEX lexeme_dialects_dialect_idx ON public.lexeme_dialects(dialect_id,role);
CREATE INDEX lexeme_dialects_lexeme_idx ON public.lexeme_dialects(lexeme_id);
CREATE INDEX lexeme_forms_lexeme_idx ON public.lexeme_forms(lexeme_id);
CREATE INDEX lexeme_forms_dialect_system_idx ON public.lexeme_forms(dialect_id,representation_system);
CREATE INDEX lexeme_forms_search_idx ON public.lexeme_forms(representation_text);
CREATE INDEX form_normalizations_source_idx ON public.form_normalizations(source_entry_id);
CREATE INDEX form_normalizations_policy_idx ON public.form_normalizations(normalization_policy_version);
CREATE INDEX lexical_senses_lexeme_lifecycle_idx ON public.lexical_senses(lexeme_id,lifecycle_status);
CREATE INDEX sense_revisions_sense_idx ON public.lexical_sense_revisions(sense_id,revision_number);
CREATE INDEX sense_dialects_dialect_idx ON public.sense_dialects(dialect_id);
CREATE INDEX sense_concepts_concept_status_idx ON public.sense_concepts(concept_id,mapping_status);
CREATE INDEX sense_concepts_sense_status_idx ON public.sense_concepts(sense_id,mapping_status);
CREATE INDEX lexical_attestations_source_idx ON public.lexical_attestations(source_entry_id);
CREATE INDEX lexical_attestations_lexeme_idx ON public.lexical_attestations(lexeme_id) WHERE lexeme_id IS NOT NULL;
CREATE INDEX lexical_attestations_form_idx ON public.lexical_attestations(form_id) WHERE form_id IS NOT NULL;
CREATE INDEX lexical_attestations_sense_idx ON public.lexical_attestations(sense_revision_id) WHERE sense_revision_id IS NOT NULL;
CREATE INDEX lexical_attestations_concept_idx ON public.lexical_attestations(sense_concept_id) WHERE sense_concept_id IS NOT NULL;
CREATE INDEX lexical_attestations_lexrel_idx ON public.lexical_attestations(lexical_relationship_id) WHERE lexical_relationship_id IS NOT NULL;
CREATE INDEX lexical_attestations_formrel_idx ON public.lexical_attestations(form_relationship_id) WHERE form_relationship_id IS NOT NULL;
CREATE INDEX lexical_attestations_status_claim_idx ON public.lexical_attestations(verification_status,claim_type);
CREATE INDEX lexical_evidence_evidence_idx ON public.lexical_linguistic_evidence(evidence_id);
CREATE INDEX lexical_relationships_source_idx ON public.lexical_relationships(source_lexeme_id);
CREATE INDEX lexical_relationships_target_idx ON public.lexical_relationships(target_lexeme_id);
CREATE INDEX lexical_relationships_type_idx ON public.lexical_relationships(relationship_type);
CREATE INDEX form_relationships_source_idx ON public.form_relationships(source_form_id);
CREATE INDEX form_relationships_target_idx ON public.form_relationships(target_form_id);
CREATE INDEX form_relationships_type_idx ON public.form_relationships(relationship_type);

ALTER TABLE public.lexemes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lexeme_dialects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lexeme_forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.form_normalizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lexical_senses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lexical_sense_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sense_dialects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sense_concepts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lexical_attestations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lexical_linguistic_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lexical_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.form_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.concept_revisions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.lexemes,public.lexeme_dialects,public.lexeme_forms,public.form_normalizations,
  public.lexical_senses,public.lexical_sense_revisions,public.sense_dialects,public.sense_concepts,
  public.lexical_attestations,public.lexical_linguistic_evidence,public.lexical_relationships,
  public.form_relationships,public.concept_revisions FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.lexemes,public.lexeme_dialects,public.lexeme_forms,public.form_normalizations,
  public.lexical_senses,public.lexical_sense_revisions,public.sense_dialects,public.sense_concepts,
  public.lexical_attestations,public.lexical_linguistic_evidence,public.lexical_relationships,
  public.form_relationships,public.concept_revisions TO service_role;

COMMENT ON TABLE public.lexemes IS 'Stable lexical identities with explicit language or variety scope; never source rows or spellings.';
COMMENT ON TABLE public.lexeme_dialects IS 'Reviewed dialect scope assertions for a lexeme; dialect identities remain first class.';
COMMENT ON TABLE public.lexeme_forms IS 'Governed representations of lexemes; exact source forms remain in source_entries.';
COMMENT ON TABLE public.form_normalizations IS 'Versioned normalization assertions that retain their exact source entry.';
COMMENT ON TABLE public.lexical_senses IS 'Stable meaning identities whose content is stored in immutable revisions.';
COMMENT ON TABLE public.lexical_sense_revisions IS 'Versioned semantic content for a stable lexical sense identity.';
COMMENT ON TABLE public.sense_dialects IS 'Reviewed dialect scope assertions for an individual lexical sense.';
COMMENT ON TABLE public.sense_concepts IS 'Governed, optional sense-to-concept mappings with preserved candidate history.';
COMMENT ON TABLE public.lexical_attestations IS 'Claim-level source-entry evidence for canonical lexical assertions.';
COMMENT ON TABLE public.lexical_linguistic_evidence IS 'Typed links from lexical assertions to registered linguistic evidence.';
COMMENT ON TABLE public.lexical_relationships IS 'Governed relationships between stable lexeme identities.';
COMMENT ON TABLE public.form_relationships IS 'Governed relationships between lexical form representations.';
COMMENT ON TABLE public.concept_revisions IS 'Versioned semantic content for the existing stable concept identity.';
COMMENT ON COLUMN public.concepts.current_revision_id IS 'Optional authoritative revision pointer; legacy snapshot columns remain for compatibility.';

-- New metadata is all-unclassified for legacy concepts, or explicitly classified.
-- Existing SELECT grants on concepts intentionally remain unchanged. These are
-- compatibility metadata, not private audit notes or private revision text.
ALTER TABLE public.concepts ADD CONSTRAINT concepts_core_metadata_check CHECK (
  (num_nonnulls(lifecycle_status,verification_status,provenance_origin,current_revision_id,
    created_by,reviewed_by,reviewed_at,deprecated_at,superseded_by,sealed_at)=0)
  OR (lifecycle_status IS NOT NULL AND verification_status IS NOT NULL AND provenance_origin IS NOT NULL)
);
CREATE UNIQUE INDEX lexeme_dialects_current_unique ON public.lexeme_dialects(lexeme_id,dialect_id,role) WHERE superseded_at IS NULL;
CREATE UNIQUE INDEX sense_dialects_current_unique ON public.sense_dialects(sense_id,dialect_id,role) WHERE superseded_at IS NULL;
CREATE UNIQUE INDEX lexical_linguistic_evidence_current_unique ON public.lexical_linguistic_evidence
  (evidence_id,lexeme_id,form_id,sense_revision_id,evidence_role) NULLS NOT DISTINCT WHERE superseded_at IS NULL;
CREATE INDEX lexemes_variety_lifecycle_idx ON public.lexemes(identity_dialect_id,lifecycle_status);
CREATE INDEX form_normalizations_language_idx ON public.form_normalizations(scope_language_id,normalization_policy_version);
CREATE INDEX form_normalizations_dialect_idx ON public.form_normalizations(scope_dialect_id,normalization_policy_version);
ALTER TABLE public.lexemes ADD CONSTRAINT lexemes_successor_state_check
  CHECK ((lifecycle_status='SUPERSEDED')=(superseded_by IS NOT NULL));
ALTER TABLE public.lexical_senses ADD CONSTRAINT lexical_senses_successor_state_check
  CHECK ((lifecycle_status='SUPERSEDED')=(superseded_by IS NOT NULL));
ALTER TABLE public.concepts ADD CONSTRAINT concepts_successor_state_check
  CHECK ((lifecycle_status='SUPERSEDED')=(superseded_by IS NOT NULL));

-- All record access below uses JSONB with validated per-table field contracts.
-- Unknown/future columns are immutable after sealing unless explicitly allowed.
-- There is no record-field branch that can reference a nonexistent column.
CREATE FUNCTION public.tafsiri_guard_lexical_record()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  prior jsonb; next_row jsonb; status_field text := TG_ARGV[0];
  mutable_fields text[] := string_to_array(TG_ARGV[1], ',');
  identity_fields text[] := string_to_array(TG_ARGV[2], ',');
  field text; seal timestamptz;
BEGIN
  IF TG_OP='TRUNCATE' THEN
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='canonical history cannot be truncated';
  END IF;
  IF TG_OP='DELETE' THEN
    IF TG_TABLE_NAME='concepts' AND to_jsonb(OLD)->>'lifecycle_status' IS NULL THEN RETURN OLD; END IF;
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='canonical history cannot be deleted';
  END IF;
  next_row := to_jsonb(NEW);
  IF TG_OP='UPDATE' THEN prior := to_jsonb(OLD); END IF;
  -- Leave unclassified legacy concept writes alone. CHECKs reject partial adoption.
  IF TG_TABLE_NAME='concepts' AND next_row->>'lifecycle_status' IS NULL
     AND (TG_OP='INSERT' OR prior->>'lifecycle_status' IS NULL) THEN RETURN NEW; END IF;
  FOREACH field IN ARRAY identity_fields LOOP
    IF NOT next_row ? field THEN RAISE EXCEPTION 'invalid lexical identity guard field %',field; END IF;
    IF TG_OP='UPDATE' AND next_row->field IS DISTINCT FROM prior->field THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='lexical identity and provenance are immutable';
    END IF;
  END LOOP;
  FOREACH field IN ARRAY ARRAY['superseded_at','deprecated_at'] LOOP
    IF TG_OP='UPDATE' AND prior->>field IS NOT NULL AND next_row->field IS DISTINCT FROM prior->field THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='recorded retirement timestamps are immutable';
    END IF;
  END LOOP;
  IF status_field='' THEN
    -- Evidence links have no independent verification status; immutable on insert.
    IF TG_OP='UPDATE' AND (next_row-mutable_fields) IS DISTINCT FROM (prior-mutable_fields) THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='linguistic evidence association is immutable';
    END IF;
    RETURN NEW;
  END IF;
  IF NOT (next_row ? status_field AND next_row ? 'sealed_at') THEN
    RAISE EXCEPTION 'invalid lexical sealing contract';
  END IF;
  IF TG_OP='INSERT' THEN
    IF next_row->>'sealed_at' IS NOT NULL THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='sealed_at is server-controlled';
    END IF;
  ELSE
    IF next_row->'sealed_at' IS DISTINCT FROM prior->'sealed_at' THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='sealed_at is irreversible and server-controlled';
    END IF;
    IF prior->>'sealed_at' IS NOT NULL AND (next_row-mutable_fields) IS DISTINCT FROM (prior-mutable_fields) THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='sealed lexical content and attribution are immutable';
    END IF;
  END IF;
  IF next_row->>'sealed_at' IS NULL AND next_row->>status_field='VERIFIED' THEN
    seal := clock_timestamp();
    NEW := jsonb_populate_record(NEW,jsonb_build_object('sealed_at',seal));
  END IF;
  RETURN NEW;
END $$;

-- Serialize graph edits by relation. Deferred checks see the complete transaction.
-- Reject snapshot-isolation graph edits: an advisory lock cannot refresh an old
-- REPEATABLE READ snapshot. SERIALIZABLE supplies SSI; READ COMMITTED is supported.
CREATE FUNCTION public.tafsiri_lock_lexical_successor()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE before_row jsonb; after_row jsonb := to_jsonb(NEW); edge text := TG_ARGV[0];
BEGIN
  IF TG_OP='UPDATE' THEN before_row := to_jsonb(OLD); END IF;
  IF after_row->edge IS NOT DISTINCT FROM before_row->edge THEN RETURN NEW; END IF;
  IF TG_OP='INSERT' AND after_row->>edge IS NULL THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND before_row->>edge IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='successor decisions cannot be rewritten';
  END IF;
  IF current_setting('transaction_isolation')='repeatable read' THEN
    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='successor edits require READ COMMITTED or SERIALIZABLE';
  END IF;
  PERFORM pg_advisory_xact_lock(11011,TG_RELID::integer);
  RETURN NEW;
END $$;

CREATE FUNCTION public.tafsiri_check_lexical_successor()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE cyclic boolean; current_row jsonb; target_row jsonb; edge text := TG_ARGV[0]; field text;
BEGIN
  EXECUTE format('SELECT to_jsonb(t) FROM %I.%I t WHERE id=$1',TG_TABLE_SCHEMA,TG_TABLE_NAME)
    INTO current_row USING NEW.id;
  IF current_row->>edge IS NULL THEN RETURN NULL; END IF;
  EXECUTE format('SELECT to_jsonb(t) FROM %I.%I t WHERE id=$1',TG_TABLE_SCHEMA,TG_TABLE_NAME)
    INTO target_row USING (current_row->>edge)::uuid;
  -- Missing endpoint is reported by the FK. Check exact parent/scope when present.
  IF target_row IS NOT NULL AND TG_ARGV[1]<>'' THEN
    FOREACH field IN ARRAY string_to_array(TG_ARGV[1],',') LOOP
      IF NOT current_row ? field THEN RAISE EXCEPTION 'invalid successor parent field'; END IF;
      IF current_row->field IS DISTINCT FROM target_row->field THEN
        RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='successor must retain its parent or identity scope';
      END IF;
    END LOOP;
  END IF;
  EXECUTE format('WITH RECURSIVE chain(id) AS (
    SELECT %1$I FROM %2$I.%3$I WHERE id=$1
    UNION SELECT t.%1$I FROM %2$I.%3$I t JOIN chain c ON t.id=c.id
    WHERE t.%1$I IS NOT NULL) SELECT EXISTS(SELECT 1 FROM chain WHERE id=$1)',
    edge,TG_TABLE_SCHEMA,TG_TABLE_NAME) INTO cyclic USING NEW.id;
  IF cyclic THEN RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='lexical successor cycle'; END IF;
  RETURN NULL;
END $$;

CREATE TRIGGER concepts_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.concepts
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','lifecycle_status,verification_status,updated_at,current_revision_id,deprecated_at,superseded_by','id,concept_key,created_at');
CREATE TRIGGER concepts_truncate_guard BEFORE TRUNCATE ON public.concepts
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','lifecycle_status,verification_status,updated_at,current_revision_id,deprecated_at,superseded_by','id,concept_key,created_at');
CREATE TRIGGER concepts_successor_lock BEFORE INSERT OR UPDATE ON public.concepts
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_lock_lexical_successor('superseded_by');
CREATE CONSTRAINT TRIGGER concepts_successor_check AFTER INSERT OR UPDATE ON public.concepts
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_check_lexical_successor('superseded_by','');

CREATE TRIGGER concept_revisions_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.concept_revisions
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status','id,concept_id,revision_number,created_at,provenance_origin,created_by');
CREATE TRIGGER concept_revisions_truncate_guard BEFORE TRUNCATE ON public.concept_revisions
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status','id,concept_id,revision_number,created_at,provenance_origin,created_by');

CREATE TRIGGER lexemes_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.lexemes
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,lifecycle_status,updated_at,current_lemma_form_id,deprecated_at,superseded_by','id,lexeme_key,language_id,identity_dialect_id,provenance_origin,created_by,created_at');
CREATE TRIGGER lexemes_truncate_guard BEFORE TRUNCATE ON public.lexemes
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,lifecycle_status,updated_at,current_lemma_form_id,deprecated_at,superseded_by','id,lexeme_key,language_id,identity_dialect_id,provenance_origin,created_by,created_at');
CREATE TRIGGER lexemes_successor_lock BEFORE INSERT OR UPDATE ON public.lexemes
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_lock_lexical_successor('superseded_by');
CREATE CONSTRAINT TRIGGER lexemes_successor_check AFTER INSERT OR UPDATE ON public.lexemes
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_check_lexical_successor('superseded_by','language_id,identity_dialect_id');

CREATE TRIGGER lexeme_dialects_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.lexeme_dialects
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,superseded_at,superseded_by','id,lexeme_id,created_at,provenance_origin');
CREATE TRIGGER lexeme_dialects_truncate_guard BEFORE TRUNCATE ON public.lexeme_dialects
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,superseded_at,superseded_by','id,lexeme_id,created_at,provenance_origin');
CREATE TRIGGER lexeme_dialects_successor_lock BEFORE INSERT OR UPDATE ON public.lexeme_dialects
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_lock_lexical_successor('superseded_by');
CREATE CONSTRAINT TRIGGER lexeme_dialects_successor_check AFTER INSERT OR UPDATE ON public.lexeme_dialects
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_check_lexical_successor('superseded_by','lexeme_id');

CREATE TRIGGER lexeme_forms_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.lexeme_forms
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,replacement_form_id,deprecated_at','id,form_key,lexeme_id,created_by,created_at,provenance_origin');
CREATE TRIGGER lexeme_forms_truncate_guard BEFORE TRUNCATE ON public.lexeme_forms
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,replacement_form_id,deprecated_at','id,form_key,lexeme_id,created_by,created_at,provenance_origin');
CREATE TRIGGER lexeme_forms_successor_lock BEFORE INSERT OR UPDATE ON public.lexeme_forms
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_lock_lexical_successor('replacement_form_id');
CREATE CONSTRAINT TRIGGER lexeme_forms_successor_check AFTER INSERT OR UPDATE ON public.lexeme_forms
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_check_lexical_successor('replacement_form_id','lexeme_id');

CREATE TRIGGER form_normalizations_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.form_normalizations
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status','id,normalization_key,source_entry_id,created_at,provenance_origin');
CREATE TRIGGER form_normalizations_truncate_guard BEFORE TRUNCATE ON public.form_normalizations
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status','id,normalization_key,source_entry_id,created_at,provenance_origin');

CREATE TRIGGER lexical_senses_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.lexical_senses
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,lifecycle_status,current_revision_id,deprecated_at,superseded_by','id,sense_key,lexeme_id,created_by,created_at,provenance_origin');
CREATE TRIGGER lexical_senses_truncate_guard BEFORE TRUNCATE ON public.lexical_senses
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,lifecycle_status,current_revision_id,deprecated_at,superseded_by','id,sense_key,lexeme_id,created_by,created_at,provenance_origin');
CREATE TRIGGER lexical_senses_successor_lock BEFORE INSERT OR UPDATE ON public.lexical_senses
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_lock_lexical_successor('superseded_by');
CREATE CONSTRAINT TRIGGER lexical_senses_successor_check AFTER INSERT OR UPDATE ON public.lexical_senses
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_check_lexical_successor('superseded_by','lexeme_id');

CREATE TRIGGER lexical_sense_revisions_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.lexical_sense_revisions
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status','id,sense_id,revision_number,created_by,created_at,provenance_origin');
CREATE TRIGGER lexical_sense_revisions_truncate_guard BEFORE TRUNCATE ON public.lexical_sense_revisions
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status','id,sense_id,revision_number,created_by,created_at,provenance_origin');

CREATE TRIGGER sense_dialects_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.sense_dialects
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,superseded_at,superseded_by','id,sense_id,created_at,provenance_origin');
CREATE TRIGGER sense_dialects_truncate_guard BEFORE TRUNCATE ON public.sense_dialects
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,superseded_at,superseded_by','id,sense_id,created_at,provenance_origin');
CREATE TRIGGER sense_dialects_successor_lock BEFORE INSERT OR UPDATE ON public.sense_dialects
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_lock_lexical_successor('superseded_by');
CREATE CONSTRAINT TRIGGER sense_dialects_successor_check AFTER INSERT OR UPDATE ON public.sense_dialects
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_check_lexical_successor('superseded_by','sense_id');

CREATE TRIGGER sense_concepts_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.sense_concepts
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('mapping_status','mapping_status,superseded_at,superseded_by','id,sense_id,created_at,provenance_origin');
CREATE TRIGGER sense_concepts_truncate_guard BEFORE TRUNCATE ON public.sense_concepts
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('mapping_status','mapping_status,superseded_at,superseded_by','id,sense_id,created_at,provenance_origin');
CREATE TRIGGER sense_concepts_successor_lock BEFORE INSERT OR UPDATE ON public.sense_concepts
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_lock_lexical_successor('superseded_by');
CREATE CONSTRAINT TRIGGER sense_concepts_successor_check AFTER INSERT OR UPDATE ON public.sense_concepts
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_check_lexical_successor('superseded_by','sense_id');

CREATE TRIGGER lexical_relationships_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.lexical_relationships
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,superseded_at,superseded_by','id,source_lexeme_id,created_at,provenance_origin');
CREATE TRIGGER lexical_relationships_truncate_guard BEFORE TRUNCATE ON public.lexical_relationships
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,superseded_at,superseded_by','id,source_lexeme_id,created_at,provenance_origin');
CREATE TRIGGER lexical_relationships_successor_lock BEFORE INSERT OR UPDATE ON public.lexical_relationships
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_lock_lexical_successor('superseded_by');
CREATE CONSTRAINT TRIGGER lexical_relationships_successor_check AFTER INSERT OR UPDATE ON public.lexical_relationships
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_check_lexical_successor('superseded_by','source_lexeme_id');

CREATE TRIGGER form_relationships_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.form_relationships
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,superseded_at,superseded_by','id,source_form_id,created_at,provenance_origin');
CREATE TRIGGER form_relationships_truncate_guard BEFORE TRUNCATE ON public.form_relationships
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status,superseded_at,superseded_by','id,source_form_id,created_at,provenance_origin');
CREATE TRIGGER form_relationships_successor_lock BEFORE INSERT OR UPDATE ON public.form_relationships
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_lock_lexical_successor('superseded_by');
CREATE CONSTRAINT TRIGGER form_relationships_successor_check AFTER INSERT OR UPDATE ON public.form_relationships
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_check_lexical_successor('superseded_by','source_form_id');

CREATE TRIGGER lexical_attestations_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.lexical_attestations
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status','id,attestation_key,source_entry_id,created_at,provenance_origin');
CREATE TRIGGER lexical_attestations_truncate_guard BEFORE TRUNCATE ON public.lexical_attestations
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('verification_status','verification_status','id,attestation_key,source_entry_id,created_at,provenance_origin');

CREATE TRIGGER lexical_linguistic_evidence_record_guard BEFORE INSERT OR UPDATE OR DELETE ON public.lexical_linguistic_evidence
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_lexical_record('','superseded_at,superseded_by','id,evidence_id,lexeme_id,form_id,sense_revision_id,created_at');
CREATE TRIGGER lexical_linguistic_evidence_truncate_guard BEFORE TRUNCATE ON public.lexical_linguistic_evidence
  FOR EACH STATEMENT EXECUTE FUNCTION public.tafsiri_guard_lexical_record('','superseded_at,superseded_by','id,evidence_id,lexeme_id,form_id,sense_revision_id,created_at');
CREATE TRIGGER lexical_linguistic_evidence_successor_lock BEFORE INSERT OR UPDATE ON public.lexical_linguistic_evidence
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_lock_lexical_successor('superseded_by');
CREATE CONSTRAINT TRIGGER lexical_linguistic_evidence_successor_check AFTER INSERT OR UPDATE ON public.lexical_linguistic_evidence
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_check_lexical_successor('superseded_by','lexeme_id,form_id,sense_revision_id');

REVOKE ALL ON FUNCTION public.tafsiri_guard_lexical_record(),public.tafsiri_lock_lexical_successor(),public.tafsiri_check_lexical_successor() FROM PUBLIC,anon,authenticated,service_role;
-- Trigger functions are not RPCs; trigger execution does not require client EXECUTE.
COMMENT ON FUNCTION public.tafsiri_guard_lexical_record() IS 'Invoker-only irreversible sealing with per-table allowlists; no promotion or approval authority.';
COMMENT ON FUNCTION public.tafsiri_check_lexical_successor() IS 'Deferred parent and cycle validation; graph writes serialize through the before trigger.';
CREATE INDEX clc_fk_1_idx ON public.concept_revisions(definition_language_id);
CREATE INDEX clc_fk_2_idx ON public.concept_revisions(definition_dialect_id);
CREATE INDEX clc_fk_3_idx ON public.concept_revisions(reviewed_by);
CREATE INDEX clc_fk_4_idx ON public.concept_revisions(created_by);
CREATE INDEX clc_fk_5_idx ON public.lexemes(created_by);
CREATE INDEX clc_fk_6_idx ON public.lexemes(reviewed_by);
CREATE INDEX clc_fk_7_idx ON public.lexemes(superseded_by);
CREATE INDEX clc_fk_8_idx ON public.lexeme_dialects(superseded_by);
CREATE INDEX clc_fk_9_idx ON public.lexeme_dialects(reviewed_by);
CREATE INDEX clc_fk_10_idx ON public.lexeme_forms(created_by);
CREATE INDEX clc_fk_11_idx ON public.lexeme_forms(reviewed_by);
CREATE INDEX clc_fk_12_idx ON public.lexeme_forms(replacement_form_id);
CREATE INDEX clc_fk_13_idx ON public.form_normalizations(target_form_id);
CREATE INDEX clc_fk_14_idx ON public.form_normalizations(reviewed_by);
CREATE INDEX clc_fk_15_idx ON public.lexical_senses(created_by);
CREATE INDEX clc_fk_16_idx ON public.lexical_senses(reviewed_by);
CREATE INDEX clc_fk_17_idx ON public.lexical_senses(superseded_by);
CREATE INDEX clc_fk_18_idx ON public.lexical_sense_revisions(definition_language_id);
CREATE INDEX clc_fk_19_idx ON public.lexical_sense_revisions(definition_dialect_id);
CREATE INDEX clc_fk_20_idx ON public.lexical_sense_revisions(reviewed_by);
CREATE INDEX clc_fk_21_idx ON public.lexical_sense_revisions(created_by);
CREATE INDEX clc_fk_22_idx ON public.sense_dialects(superseded_by);
CREATE INDEX clc_fk_23_idx ON public.sense_dialects(reviewed_by);
CREATE INDEX clc_fk_24_idx ON public.sense_concepts(reviewed_by);
CREATE INDEX clc_fk_25_idx ON public.sense_concepts(superseded_by);
CREATE INDEX clc_fk_26_idx ON public.lexical_relationships(reviewed_by);
CREATE INDEX clc_fk_27_idx ON public.lexical_relationships(superseded_by);
CREATE INDEX clc_fk_28_idx ON public.form_relationships(reviewed_by);
CREATE INDEX clc_fk_29_idx ON public.form_relationships(superseded_by);
CREATE INDEX clc_fk_30_idx ON public.lexical_attestations(reviewed_by);
CREATE INDEX clc_fk_31_idx ON public.lexical_linguistic_evidence(superseded_by);
CREATE INDEX clc_fk_32_idx ON public.lexical_linguistic_evidence(lexeme_id);
CREATE INDEX clc_fk_33_idx ON public.lexical_linguistic_evidence(form_id);
CREATE INDEX clc_fk_34_idx ON public.lexical_linguistic_evidence(sense_revision_id);
CREATE INDEX concepts_current_revision_idx ON public.concepts(current_revision_id);
CREATE INDEX concepts_created_by_idx ON public.concepts(created_by);
CREATE INDEX concepts_reviewed_by_idx ON public.concepts(reviewed_by);
CREATE INDEX concepts_superseded_by_idx ON public.concepts(superseded_by);
CREATE INDEX lexemes_current_lemma_idx ON public.lexemes(current_lemma_form_id);
CREATE INDEX lexical_senses_current_revision_idx ON public.lexical_senses(current_revision_id);
