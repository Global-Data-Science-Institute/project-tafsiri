# Tafsiri Migration 011 SQL Design 001

**Status:** SQL design ready for implementation review

**Effect of this document:** no migration file, data change, staging write, or production write

## 1. Decisions

| Question | Decision |
|---|---|
| Multi-dialect lexeme | Default is separate dialect-scoped identities. Multiple dialects require explicit reviewed `lexeme_dialects` rows; similarity never merges identities. |
| Lexical category | A small CHECK vocabulary on sense revisions. A taxonomy is deferred until real reviewed data proves it necessary. |
| Verified concept cardinality | At most one current `VERIFIED` concept per sense; multiple candidate, rejected, or disputed mappings may coexist. |
| Symmetric relationship ordering | Symmetric lexeme/form types require `source_id < target_id`; directional types retain source/target semantics. |
| Normalization target | Governed text assertion first; `target_form_id` is optional. The source-entry FK remains the provenance anchor. |
| Approval authority | Dedicated lexical authority and promotion workflow deferred. Migration 011 remains empty and trusted-admin only. |
| Concept revisions | Included. Revision content becomes authoritative when `concepts.current_revision_id` is set. |
| Morphology | No morphology columns or engine in Migration 011; reviewed morphology links use existing linguistic evidence. |
| Current lemma | Included with a deferrable composite FK proving the form belongs to the same lexeme. |
| Lexical relationships | Lexeme-to-lexeme only in Migration 011. Sense relationships are deferred to avoid mixed-level ambiguity. |

## 2. Existing-schema compatibility

The design was checked against the deployed definitions of `concepts`, `concept_terms`, `dictionary_concept_candidates`, `source_entries`, `linguistic_evidence`, `languages`, `dialects`, `contributors`, `contributor_role_types`, and `contributor_roles`.

- `concepts` is extended additively. Existing columns remain untouched.
- When `current_revision_id` is non-null, `concept_revisions` is authoritative. Existing definition/domain columns are compatibility snapshots for old callers.
- New canonical code must not write `concept_terms`; the table remains available unchanged.
- `dictionary_concept_candidates` remains unchanged as legacy candidate infrastructure.
- `source_entries` remains the evidence boundary. Attestations reference it and do not duplicate source/version/artifact data.
- Dialect-language consistency is validated during promotion because existing `dialects.language_id` is nullable; Migration 011 does not add a brittle cross-table check.

## 3. Exact proposed DDL

The following is reviewed design SQL, not an executable migration file.

```sql
-- Shared vocabularies are CHECK constraints in the minimum foundation.
-- All foreign keys intentionally use ON DELETE RESTRICT.

ALTER TABLE public.concepts
  ADD COLUMN lifecycle_status text NOT NULL DEFAULT 'PROVISIONAL',
  ADD COLUMN verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  ADD COLUMN provenance_origin text NOT NULL DEFAULT 'HUMAN',
  ADD COLUMN current_revision_id uuid,
  ADD COLUMN created_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  ADD COLUMN reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  ADD COLUMN reviewed_at timestamptz,
  ADD COLUMN deprecated_at timestamptz,
  ADD COLUMN superseded_by uuid REFERENCES public.concepts(id) ON DELETE RESTRICT,
  ADD CONSTRAINT concepts_lifecycle_check CHECK (lifecycle_status IN ('PROVISIONAL','ACTIVE','DISPUTED','DEPRECATED','SUPERSEDED')),
  ADD CONSTRAINT concepts_verification_check CHECK (verification_status IN ('UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED')),
  ADD CONSTRAINT concepts_origin_check CHECK (provenance_origin IN ('HUMAN','IMPORTED','MACHINE_GENERATED')),
  ADD CONSTRAINT concepts_review_check CHECK (
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  ADD CONSTRAINT concepts_lifecycle_dates_check CHECK (
    (lifecycle_status <> 'DEPRECATED' OR deprecated_at IS NOT NULL)
    AND (lifecycle_status <> 'SUPERSEDED' OR superseded_by IS NOT NULL)
    AND superseded_by IS DISTINCT FROM id
  );

CREATE TABLE public.concept_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  concept_id uuid NOT NULL REFERENCES public.concepts(id) ON DELETE RESTRICT,
  revision_number integer NOT NULL,
  definition text NOT NULL,
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT concept_revisions_number_unique UNIQUE (concept_id,revision_number),
  CONSTRAINT concept_revisions_id_parent_unique UNIQUE (id,concept_id)
);

ALTER TABLE public.concepts
  ADD CONSTRAINT concepts_current_revision_fkey
  FOREIGN KEY (current_revision_id,id) REFERENCES public.concept_revisions(id,concept_id)
  ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE public.lexemes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lexeme_key text NOT NULL UNIQUE,
  language_id uuid NOT NULL REFERENCES public.languages(id) ON DELETE RESTRICT,
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT lexemes_lifecycle_dates_check CHECK (
    (lifecycle_status <> 'DEPRECATED' OR deprecated_at IS NOT NULL)
    AND (lifecycle_status <> 'SUPERSEDED' OR superseded_by IS NOT NULL)
    AND superseded_by IS DISTINCT FROM id
  )
);

CREATE TABLE public.lexeme_dialects (
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT lexeme_dialects_unique UNIQUE (lexeme_id,dialect_id,role)
);

CREATE TABLE public.lexeme_forms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  form_key text NOT NULL UNIQUE,
  lexeme_id uuid NOT NULL REFERENCES public.lexemes(id) ON DELETE RESTRICT,
  representation_text text NOT NULL,
  representation_system text NOT NULL,
  form_role text NOT NULL,
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT lexeme_forms_replacement_check CHECK (replacement_form_id IS DISTINCT FROM id),
  CONSTRAINT lexeme_forms_deprecation_check CHECK (deprecated_at IS NULL OR replacement_form_id IS NOT NULL),
  CONSTRAINT lexeme_forms_id_parent_unique UNIQUE (id,lexeme_id)
);

ALTER TABLE public.lexemes ADD CONSTRAINT lexemes_current_lemma_fkey
  FOREIGN KEY (current_lemma_form_id,id) REFERENCES public.lexeme_forms(id,lexeme_id)
  ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE public.form_normalizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  normalization_key text NOT NULL UNIQUE,
  source_entry_id uuid NOT NULL REFERENCES public.source_entries(id) ON DELETE RESTRICT,
  target_form_id uuid REFERENCES public.lexeme_forms(id) ON DELETE RESTRICT,
  normalized_text text NOT NULL,
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT form_normalizations_version_unique UNIQUE (source_entry_id,normalization_policy_version,normalized_text)
);

CREATE TABLE public.lexical_senses (
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT lexical_senses_lifecycle_dates_check CHECK (
    (lifecycle_status <> 'DEPRECATED' OR deprecated_at IS NOT NULL)
    AND (lifecycle_status <> 'SUPERSEDED' OR superseded_by IS NOT NULL)
    AND superseded_by IS DISTINCT FROM id
  )
);

CREATE TABLE public.lexical_sense_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sense_id uuid NOT NULL REFERENCES public.lexical_senses(id) ON DELETE RESTRICT,
  revision_number integer NOT NULL,
  definition text NOT NULL,
  lexical_category text NOT NULL DEFAULT 'UNKNOWN',
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT sense_revisions_number_unique UNIQUE (sense_id,revision_number),
  CONSTRAINT sense_revisions_id_parent_unique UNIQUE (id,sense_id)
);

ALTER TABLE public.lexical_senses ADD CONSTRAINT lexical_senses_current_revision_fkey
  FOREIGN KEY (current_revision_id,id) REFERENCES public.lexical_sense_revisions(id,sense_id)
  ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE public.sense_dialects (
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT sense_dialects_unique UNIQUE (sense_id,dialect_id,role)
);

CREATE TABLE public.sense_concepts (
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
    (mapping_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (mapping_status IN ('CANDIDATE','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT sense_concepts_supersession_check CHECK ((superseded_at IS NULL) = (superseded_by IS NULL) AND superseded_by IS DISTINCT FROM id)
);
CREATE UNIQUE INDEX sense_concepts_current_verified_unique ON public.sense_concepts(sense_id)
  WHERE mapping_status='VERIFIED' AND superseded_at IS NULL;

CREATE TABLE public.lexical_relationships (
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT lexical_relationships_supersession_check CHECK ((superseded_at IS NULL) = (superseded_by IS NULL) AND superseded_by IS DISTINCT FROM id)
);
CREATE UNIQUE INDEX lexical_relationships_current_unique
  ON public.lexical_relationships(source_lexeme_id,target_lexeme_id,relationship_type)
  WHERE superseded_at IS NULL;

CREATE TABLE public.form_relationships (
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  ),
  CONSTRAINT form_relationships_supersession_check CHECK ((superseded_at IS NULL) = (superseded_by IS NULL) AND superseded_by IS DISTINCT FROM id)
);
CREATE UNIQUE INDEX form_relationships_current_unique
  ON public.form_relationships(source_form_id,target_form_id,relationship_type)
  WHERE superseded_at IS NULL;

CREATE TABLE public.lexical_attestations (
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
    (verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    OR (verification_status IN ('UNVERIFIED','IN_REVIEW') AND reviewed_by IS NULL AND reviewed_at IS NULL)
  )
);

CREATE TABLE public.lexical_linguistic_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evidence_id uuid NOT NULL REFERENCES public.linguistic_evidence(id) ON DELETE RESTRICT,
  lexeme_id uuid REFERENCES public.lexemes(id) ON DELETE RESTRICT,
  form_id uuid REFERENCES public.lexeme_forms(id) ON DELETE RESTRICT,
  sense_revision_id uuid REFERENCES public.lexical_sense_revisions(id) ON DELETE RESTRICT,
  evidence_role text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lexical_linguistic_evidence_target_check CHECK (num_nonnulls(lexeme_id,form_id,sense_revision_id)=1),
  CONSTRAINT lexical_linguistic_evidence_role_check CHECK (evidence_role IN ('PRONUNCIATION','TONE','SYLLABIFICATION','MORPHOLOGY','ETYMOLOGY','OTHER')),
  CONSTRAINT lexical_linguistic_evidence_unique UNIQUE NULLS NOT DISTINCT (evidence_id,lexeme_id,form_id,sense_revision_id,evidence_role)
);

-- Narrow SECURITY INVOKER guards. Semantic fields freeze after verification.
CREATE FUNCTION public.tafsiri_guard_verified_lexical_rows()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF TG_TABLE_NAME='lexeme_forms' AND OLD.verification_status='VERIFIED' AND
     (NEW.lexeme_id IS DISTINCT FROM OLD.lexeme_id OR NEW.representation_text IS DISTINCT FROM OLD.representation_text OR NEW.representation_system IS DISTINCT FROM OLD.representation_system)
  THEN RAISE EXCEPTION 'verified form identity is immutable'; END IF;
  IF TG_TABLE_NAME='lexical_sense_revisions' AND OLD.verification_status='VERIFIED' AND
     (NEW.sense_id IS DISTINCT FROM OLD.sense_id OR NEW.revision_number IS DISTINCT FROM OLD.revision_number OR NEW.definition IS DISTINCT FROM OLD.definition OR NEW.lexical_category IS DISTINCT FROM OLD.lexical_category OR NEW.register IS DISTINCT FROM OLD.register OR NEW.domain IS DISTINCT FROM OLD.domain OR NEW.grammatical_restrictions IS DISTINCT FROM OLD.grammatical_restrictions OR NEW.cultural_context IS DISTINCT FROM OLD.cultural_context OR NEW.usage_notes IS DISTINCT FROM OLD.usage_notes)
  THEN RAISE EXCEPTION 'verified sense revision content is immutable'; END IF;
  IF TG_TABLE_NAME='concept_revisions' AND OLD.verification_status='VERIFIED' AND
     (NEW.concept_id IS DISTINCT FROM OLD.concept_id OR NEW.revision_number IS DISTINCT FROM OLD.revision_number OR NEW.definition IS DISTINCT FROM OLD.definition OR NEW.domain IS DISTINCT FROM OLD.domain OR NEW.subdomain IS DISTINCT FROM OLD.subdomain OR NEW.notes IS DISTINCT FROM OLD.notes)
  THEN RAISE EXCEPTION 'verified concept revision content is immutable'; END IF;
  IF TG_TABLE_NAME='lexical_attestations' AND OLD.verification_status='VERIFIED' AND
     (NEW.source_entry_id IS DISTINCT FROM OLD.source_entry_id OR NEW.lexeme_id IS DISTINCT FROM OLD.lexeme_id OR NEW.form_id IS DISTINCT FROM OLD.form_id OR NEW.sense_revision_id IS DISTINCT FROM OLD.sense_revision_id OR NEW.sense_concept_id IS DISTINCT FROM OLD.sense_concept_id OR NEW.lexical_relationship_id IS DISTINCT FROM OLD.lexical_relationship_id OR NEW.form_relationship_id IS DISTINCT FROM OLD.form_relationship_id OR NEW.claim_type IS DISTINCT FROM OLD.claim_type OR NEW.evidence_role IS DISTINCT FROM OLD.evidence_role OR NEW.claimed_value IS DISTINCT FROM OLD.claimed_value)
  THEN RAISE EXCEPTION 'verified attestation semantics are immutable'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER lexeme_forms_verified_guard BEFORE UPDATE ON public.lexeme_forms FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_verified_lexical_rows();
CREATE TRIGGER sense_revisions_verified_guard BEFORE UPDATE ON public.lexical_sense_revisions FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_verified_lexical_rows();
CREATE TRIGGER concept_revisions_verified_guard BEFORE UPDATE ON public.concept_revisions FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_verified_lexical_rows();
CREATE TRIGGER lexical_attestations_verified_guard BEFORE UPDATE ON public.lexical_attestations FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_verified_lexical_rows();

-- Correctness and direct lookup indexes only.
CREATE INDEX lexemes_language_lifecycle_idx ON public.lexemes(language_id,lifecycle_status);
CREATE INDEX lexemes_verification_idx ON public.lexemes(verification_status);
CREATE INDEX lexeme_dialects_dialect_idx ON public.lexeme_dialects(dialect_id,role);
CREATE INDEX lexeme_dialects_lexeme_idx ON public.lexeme_dialects(lexeme_id);
CREATE INDEX lexeme_forms_lexeme_idx ON public.lexeme_forms(lexeme_id);
CREATE INDEX lexeme_forms_dialect_system_idx ON public.lexeme_forms(dialect_id,representation_system);
CREATE INDEX lexeme_forms_search_idx ON public.lexeme_forms(lower(representation_text));
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
  public.form_relationships,public.concept_revisions FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE public.lexemes,public.lexeme_dialects,public.lexeme_forms,public.form_normalizations,
  public.lexical_senses,public.lexical_sense_revisions,public.sense_dialects,public.sense_concepts,
  public.lexical_attestations,public.lexical_linguistic_evidence,public.lexical_relationships,
  public.form_relationships,public.concept_revisions TO service_role;
REVOKE ALL ON FUNCTION public.tafsiri_guard_verified_lexical_rows() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.tafsiri_guard_verified_lexical_rows() TO service_role;

COMMENT ON TABLE public.lexemes IS 'Stable lexical identities; never source rows or spellings.';
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
```

## 4. DDL order

1. Extend `concepts` without removing columns.
2. Create `concept_revisions`; then add its composite current pointer.
3. Create `lexemes` and `lexeme_dialects`.
4. Create `lexeme_forms`; then add the composite current-lemma pointer.
5. Create normalizations.
6. Create `lexical_senses`, revisions, then the composite current-revision pointer.
7. Create sense dialects and concept mappings.
8. Create lexeme-level and form-level relationships.
9. Create attestations and linguistic-evidence links after every target exists.
10. Add narrow guards, indexes, RLS, grants, and comments.

Circular pointers are added only after child tables exist. Composite foreign keys prove parent consistency and are deferrable for atomic creation.

## 5. Security and effective privileges

RLS is enabled immediately with no policies. `PUBLIC`, `anon`, and `authenticated` receive no table privileges. Only `service_role` receives table privileges. The guard is `SECURITY INVOKER`, has an empty search path, is not an RPC, and is not executable by client roles. Default privileges remain unchanged. The Reviewer Portal gets no access.

## 6. Rights and training boundary

Lexical tables do not copy rights. Future dataset builds must traverse attestation → source entry → import batch → artifact → source version → use policies. Canonical status never grants training, redistribution, publication, or serving permission.

## 7. Rollback-only test matrix

| ID | Test | Expected |
|---|---|---|
| A–B | Valid lexeme; duplicate key | Insert succeeds; duplicate rejected |
| C–D | Same spelling across lexemes; form ownership | Allowed; parent retained |
| E | Mutate verified form identity | Rejected by guard |
| F | Source entry with unresolved dialect label | Attestation succeeds without dialect FK |
| G–K | Multiple senses, revision 1, unique numbering, current-parent consistency, immutable verified revision | Required behavior enforced |
| L–M | Concept revision and current-parent consistency | Required behavior enforced |
| N–O | Multiple candidates; second current verified mapping | Candidates allowed; second verified rejected |
| P–Q | Zero/two attestation targets; missing source entry | Rejected |
| R | Supporting and contradicting attestations | Both retained |
| S–U | Lexical self-link, reversed symmetric duplicate, directional relationship | Rejected; rejected; allowed |
| V | Form self-link | Rejected |
| W | Add normalization | Source entry original form unchanged |
| X–Z | RLS, client table access, function execution | Enabled; denied; denied |

Every test runs inside `BEGIN`/`ROLLBACK` using synthetic languages, dialects, contributors, import lineage, source entries, evidence, lexemes, forms, senses, and concepts. It must assert all thirteen new tables return to their pre-test counts.

The complete proposed DDL was syntax and dependency checked against the local Supabase PostgreSQL schema on 2026-09-28 inside one `BEGIN`/`ROLLBACK` transaction. The transaction reached `ROLLBACK` successfully. A post-transaction check confirmed that `public.lexemes` did not exist and that no Migration 011 column remained on `public.concepts`.

## 8. Real-world nonpersistent fixtures

- **Appleby → Wanga/Bukusu:** one historical entry supports separate modern dialect lexemes/forms; optional reviewed cognate or historical links.
- **Luyia workbook:** row alignment remains source-provided correspondence and creates no lexical relationship automatically.
- **Idakho_1 / Idakho_2:** raw labels remain on source entries; attestations need no dialect mapping.
- **Lutura:** raw evidence persists and can later receive a separate mapping assertion.
- **Homograph:** identical orthographic forms on unrelated lexemes coexist.
- **Polysemy:** one lexeme owns two sense identities and revisions.
- **Borrowing:** directional `BORROWED_FROM` evidence preserves source language analysis.
- **No equivalent:** no lexeme is created; a later lexical-gap assertion records preserve-and-explain policy.

## 9. Empty-foundation and compatibility assertions

After a future Migration 011 deployment, all thirteen new tables must contain zero rows. Existing `concepts`, `concept_terms`, and `dictionary_concept_candidates` counts and definitions remain unchanged. Migration 011 seeds no lexemes, forms, senses, concepts, mappings, attestations, or relationships and performs no legacy backfill.

## 10. Deferred structures

Deferred: lexical candidates, assignments, approval authority, promotion/output tables, lexical-gap assertions, sense-to-sense relationships, morphology structures, expressions/idioms/proverbs, serving projections, embeddings, derived datasets, and public APIs.

## 11. Open implementation questions

1. Should the migration implementation factor repeated verification checks into domains, accepting the operational cost of schema-level domain types?
2. Should `concepts` compatibility snapshots be updated by trusted promotion code or remain frozen once a current revision exists?
3. Does normalization require parent-consistent target-form validation against a future candidate lexeme, or is an optional unrestricted form target sufficient?
4. Which contributor role types and separation-of-duty rules belong in the later lexical promotion migration?
5. Should `OTHER` lexical relationships be directional by default or require an explicit direction column?

## 12. Recommendation

The design is ready to be converted into a versioned Migration 011 implementation with a dedicated SQL smoke test. No migration file was created by this task.

**READY TO IMPLEMENT MIGRATION 011**

Staging writes: **ZERO**. Production writes: **ZERO**.
