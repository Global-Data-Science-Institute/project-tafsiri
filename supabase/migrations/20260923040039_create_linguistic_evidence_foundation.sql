-- Project Tafsiri Migration 007: Linguistic Literature & Evidence Foundation.
-- Schema plus governed taxonomy only. No publications or linguistic evidence are inserted.

ALTER TABLE public.sources DROP CONSTRAINT sources_type_check;
ALTER TABLE public.sources ADD CONSTRAINT sources_type_check CHECK (source_type IN (
  'DICTIONARY','LEXICON','WEBSITE','CORPUS','BIBLE_EDITION','PROVERB_COLLECTION',
  'FIELDWORK','COMMUNITY_CONTRIBUTION','DATASET','OTHER','JOURNAL_ARTICLE',
  'ACADEMIC_PAPER','BOOK_CHAPTER','THESIS','DISSERTATION','GRAMMAR',
  'CONFERENCE_PAPER','TECHNICAL_REPORT'
));

CREATE TABLE public.source_scholarly_metadata (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL UNIQUE REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  authority_type text NOT NULL DEFAULT 'UNKNOWN',
  publication_title text,
  journal_title text,
  volume text,
  issue text,
  page_start text,
  page_end text,
  institution text,
  degree_type text,
  conference_name text,
  publication_status text,
  peer_reviewed boolean,
  language_of_publication text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_scholarly_authority_check CHECK (authority_type IN (
    'PEER_REVIEWED','PUBLISHED_BOOK_CHAPTER','DOCTORAL_DISSERTATION','MASTERS_THESIS',
    'CONFERENCE_PROCEEDINGS','INSTITUTIONAL_REPORT','WORKING_PAPER','BOOK','OTHER','UNKNOWN'
  )),
  CONSTRAINT source_scholarly_text_check CHECK (
    (publication_title IS NULL OR btrim(publication_title) <> '') AND
    (journal_title IS NULL OR btrim(journal_title) <> '') AND
    (institution IS NULL OR btrim(institution) <> '') AND
    (degree_type IS NULL OR btrim(degree_type) <> '')
  )
);

CREATE TABLE public.source_identifiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id uuid REFERENCES public.sources(id) ON DELETE RESTRICT,
  source_version_id uuid REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  identifier_type text NOT NULL,
  identifier_value text NOT NULL,
  canonical_url text,
  is_primary boolean NOT NULL DEFAULT false,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_identifiers_owner_check CHECK (num_nonnulls(source_id, source_version_id) = 1),
  CONSTRAINT source_identifiers_type_check CHECK (identifier_type IN (
    'DOI','ISBN','ISSN','HANDLE','ARK','OCLC','INSTITUTIONAL_REPOSITORY_ID',
    'ZENODO_DOI','DATAVERSE_DOI','OTHER'
  )),
  CONSTRAINT source_identifiers_value_not_blank CHECK (btrim(identifier_value) <> ''),
  CONSTRAINT source_identifiers_url_not_blank CHECK (canonical_url IS NULL OR btrim(canonical_url) <> ''),
  CONSTRAINT source_identifiers_status_check CHECK (verification_status IN (
    'UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED'
  )),
  CONSTRAINT source_identifiers_exact_unique UNIQUE (identifier_type, identifier_value)
);

CREATE UNIQUE INDEX source_identifiers_doi_ci_unique
  ON public.source_identifiers (identifier_type, lower(identifier_value))
  WHERE identifier_type IN ('DOI','ZENODO_DOI','DATAVERSE_DOI');

CREATE TABLE public.source_access_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  url text NOT NULL,
  location_type text NOT NULL,
  host text,
  is_primary boolean NOT NULL DEFAULT false,
  availability text NOT NULL,
  downloadable boolean,
  accessed_at timestamptz,
  artifact_filename text,
  artifact_sha256 text,
  artifact_bytes bigint,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_access_url_not_blank CHECK (btrim(url) <> ''),
  CONSTRAINT source_access_location_type_check CHECK (location_type IN (
    'PUBLISHER','INSTITUTIONAL_REPOSITORY','AUTHOR_SITE','DATA_REPOSITORY',
    'ACADEMIA','RESEARCHGATE','ZENODO','OTHER'
  )),
  CONSTRAINT source_access_availability_check CHECK (availability IN (
    'OPEN_FULL_TEXT','PUBLIC_FULL_TEXT_UNCLEAR_LICENSE','ABSTRACT_ONLY','PAYWALLED',
    'METADATA_ONLY','UNAVAILABLE'
  )),
  CONSTRAINT source_access_bytes_check CHECK (artifact_bytes IS NULL OR artifact_bytes >= 0),
  CONSTRAINT source_access_sha256_check CHECK (
    artifact_sha256 IS NULL OR artifact_sha256 ~ '^[0-9A-Fa-f]{64}$'
  ),
  CONSTRAINT source_access_location_unique UNIQUE (source_version_id, url)
);

CREATE TABLE public.source_variety_mentions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  literal_variety_name text NOT NULL,
  candidate_dialect_id uuid REFERENCES public.dialects(id) ON DELETE RESTRICT,
  mention_scope text NOT NULL,
  locator text,
  mapping_status text NOT NULL DEFAULT 'UNMAPPED',
  rationale text,
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT source_variety_literal_not_blank CHECK (btrim(literal_variety_name) <> ''),
  CONSTRAINT source_variety_scope_check CHECK (mention_scope IN (
    'TITLE','ABSTRACT','DOCUMENT','SECTION','PASSAGE','EXAMPLE','METADATA'
  )),
  CONSTRAINT source_variety_status_check CHECK (mapping_status IN (
    'UNMAPPED','CANDIDATE','IN_REVIEW','VERIFIED','REJECTED','DISPUTED'
  )),
  CONSTRAINT source_variety_candidate_check CHECK (
    (mapping_status = 'UNMAPPED' AND candidate_dialect_id IS NULL)
    OR (mapping_status <> 'UNMAPPED' AND candidate_dialect_id IS NOT NULL)
  ),
  CONSTRAINT source_variety_review_pair_check CHECK (
    (reviewed_by IS NULL AND reviewed_at IS NULL) OR
    (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
  ),
  CONSTRAINT source_variety_verified_check CHECK (
    mapping_status <> 'VERIFIED' OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
  )
);

CREATE TABLE public.linguistic_evidence_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evidence_type_key text NOT NULL UNIQUE,
  category text NOT NULL,
  description text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  deprecated_at timestamptz,
  CONSTRAINT linguistic_evidence_types_key_check CHECK (evidence_type_key ~ '^[A-Z][A-Z0-9_]*$'),
  CONSTRAINT linguistic_evidence_types_category_check CHECK (category IN (
    'PHONOLOGY','MORPHOLOGY','SYNTAX','SEMANTICS_PRAGMATICS','LEXICAL','EXAMPLE','ACOUSTIC'
  )),
  CONSTRAINT linguistic_evidence_types_description_not_blank CHECK (btrim(description) <> ''),
  CONSTRAINT linguistic_evidence_types_deprecation_check CHECK (
    (is_active AND deprecated_at IS NULL) OR (NOT is_active AND deprecated_at IS NOT NULL)
  )
);

INSERT INTO public.linguistic_evidence_types (evidence_type_key, category, description) VALUES
  ('PHONEME_INVENTORY','PHONOLOGY','Reported phoneme inventory.'),
  ('GRAPHEME_PHONEME_RULE','PHONOLOGY','Reported grapheme to phoneme correspondence.'),
  ('ALLOPHONIC_RULE','PHONOLOGY','Reported conditioned phonetic realization.'),
  ('TONE_RULE','PHONOLOGY','Reported tonal rule.'),
  ('TONE_PATTERN','PHONOLOGY','Reported tonal pattern.'),
  ('STRESS_RULE','PHONOLOGY','Reported stress rule.'),
  ('PROSODIC_RULE','PHONOLOGY','Reported prosodic rule.'),
  ('SYLLABLE_RULE','PHONOLOGY','Reported syllable structure or process.'),
  ('VOWEL_LENGTH_RULE','PHONOLOGY','Reported vowel length rule.'),
  ('PHONOLOGICAL_PROCESS','PHONOLOGY','Reported phonological process.'),
  ('MORPHOPHONOLOGICAL_RULE','PHONOLOGY','Reported morphophonological rule.'),
  ('NOUN_CLASS_RULE','MORPHOLOGY','Reported noun class behavior.'),
  ('AGREEMENT_RULE','MORPHOLOGY','Reported agreement behavior.'),
  ('CONCORD_RULE','MORPHOLOGY','Reported concord behavior.'),
  ('INFLECTION_RULE','MORPHOLOGY','Reported inflectional behavior.'),
  ('DERIVATION_RULE','MORPHOLOGY','Reported derivational behavior.'),
  ('VERB_TEMPLATE','MORPHOLOGY','Reported verb template.'),
  ('TENSE_ASPECT_RULE','MORPHOLOGY','Reported tense or aspect behavior.'),
  ('NEGATION_RULE','MORPHOLOGY','Reported negation behavior.'),
  ('AUGMENTATIVE_RULE','MORPHOLOGY','Reported augmentative behavior.'),
  ('DIMINUTIVE_RULE','MORPHOLOGY','Reported diminutive behavior.'),
  ('LEXICAL_CATEGORY_ASSERTION','LEXICAL','Reported lexical category analysis.'),
  ('SYNTACTIC_RULE','SYNTAX','Reported syntactic behavior.'),
  ('WORD_ORDER_RULE','SYNTAX','Reported word order behavior.'),
  ('ARGUMENT_STRUCTURE_RULE','SYNTAX','Reported argument structure behavior.'),
  ('OBJECT_MARKING_RULE','SYNTAX','Reported object marking behavior.'),
  ('SEMANTIC_RULE','SEMANTICS_PRAGMATICS','Reported semantic behavior.'),
  ('PRAGMATIC_RULE','SEMANTICS_PRAGMATICS','Reported pragmatic behavior.'),
  ('MODALITY_RULE','SEMANTICS_PRAGMATICS','Reported modality behavior.'),
  ('EVIDENTIALITY_RULE','SEMANTICS_PRAGMATICS','Reported evidentiality behavior.'),
  ('IDEOPHONE_ASSERTION','LEXICAL','Reported ideophone analysis.'),
  ('LOANWORD_ADAPTATION_RULE','LEXICAL','Reported loanword adaptation behavior.'),
  ('TERMINOLOGY_ASSERTION','LEXICAL','Reported terminology observation without a canonical decision.'),
  ('DIALECT_VARIATION_ASSERTION','LEXICAL','Reported variation among named varieties.'),
  ('EXAMPLE_SENTENCE','EXAMPLE','Located sentence example.'),
  ('INTERLINEAR_EXAMPLE','EXAMPLE','Located interlinear example.'),
  ('MINIMAL_PAIR','EXAMPLE','Located minimal pair.'),
  ('PARADIGM','EXAMPLE','Located linguistic paradigm.'),
  ('ACOUSTIC_OBSERVATION','ACOUSTIC','Reported acoustic observation.'),
  ('ACOUSTIC_TOKEN','ACOUSTIC','Located acoustic token observation.');

CREATE TABLE public.linguistic_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_version_id uuid NOT NULL REFERENCES public.source_versions(id) ON DELETE RESTRICT,
  evidence_type_id uuid NOT NULL REFERENCES public.linguistic_evidence_types(id) ON DELETE RESTRICT,
  evidence_scope text NOT NULL,
  source_locator text NOT NULL,
  summary text NOT NULL,
  certainty numeric(4,3),
  provenance_origin text NOT NULL,
  verification_status text NOT NULL DEFAULT 'UNVERIFIED',
  extraction_method text NOT NULL,
  extractor_version text,
  tool_or_model text,
  prompt_version text,
  extracted_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  extracted_at timestamptz NOT NULL DEFAULT now(),
  reviewed_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  superseded_at timestamptz,
  superseded_by uuid,
  CONSTRAINT linguistic_evidence_id_version_unique UNIQUE (id, source_version_id),
  CONSTRAINT linguistic_evidence_scope_check CHECK (evidence_scope IN (
    'DIALECT','MULTI_DIALECT_COMPARATIVE','PROTO_LANGUAGE','FAMILY_GENERALIZATION'
  )),
  CONSTRAINT linguistic_evidence_locator_not_blank CHECK (btrim(source_locator) <> ''),
  CONSTRAINT linguistic_evidence_summary_not_blank CHECK (btrim(summary) <> ''),
  CONSTRAINT linguistic_evidence_certainty_check CHECK (certainty IS NULL OR certainty BETWEEN 0 AND 1),
  CONSTRAINT linguistic_evidence_origin_check CHECK (provenance_origin IN (
    'HUMAN','MACHINE_GENERATED','IMPORTED'
  )),
  CONSTRAINT linguistic_evidence_status_check CHECK (verification_status IN (
    'UNVERIFIED','IN_REVIEW','VERIFIED','REJECTED','DISPUTED'
  )),
  CONSTRAINT linguistic_evidence_method_check CHECK (extraction_method IN (
    'HUMAN_MANUAL','LLM_ASSISTED','DETERMINISTIC_PARSER'
  )),
  CONSTRAINT linguistic_evidence_verified_check CHECK (
    verification_status <> 'VERIFIED' OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
  ),
  CONSTRAINT linguistic_evidence_review_pair_check CHECK (
    (reviewed_by IS NULL AND reviewed_at IS NULL) OR
    (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
  ),
  CONSTRAINT linguistic_evidence_supersession_check CHECK (
    (superseded_at IS NULL AND superseded_by IS NULL) OR
    (superseded_at IS NOT NULL AND superseded_by IS NOT NULL AND superseded_by <> id)
  )
);

ALTER TABLE public.linguistic_evidence ADD CONSTRAINT linguistic_evidence_superseded_by_fkey
  FOREIGN KEY (superseded_by, source_version_id)
  REFERENCES public.linguistic_evidence(id, source_version_id) ON DELETE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE public.linguistic_evidence_dialects (
  evidence_id uuid NOT NULL REFERENCES public.linguistic_evidence(id) ON DELETE RESTRICT,
  dialect_id uuid NOT NULL REFERENCES public.dialects(id) ON DELETE RESTRICT,
  role text NOT NULL,
  source_variety_mention_id uuid REFERENCES public.source_variety_mentions(id) ON DELETE RESTRICT,
  notes text,
  CONSTRAINT linguistic_evidence_dialects_role_check CHECK (role IN (
    'PRIMARY','COMPARISON','CONTRAST','EXCEPTION'
  )),
  PRIMARY KEY (evidence_id, dialect_id, role)
);

CREATE TABLE public.linguistic_evidence_notations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evidence_id uuid NOT NULL REFERENCES public.linguistic_evidence(id) ON DELETE RESTRICT,
  notation_type text NOT NULL,
  notation_text text NOT NULL,
  label text,
  order_index integer NOT NULL DEFAULT 0,
  notes text,
  CONSTRAINT linguistic_notations_type_check CHECK (notation_type IN (
    'IPA_PHONEMIC','IPA_PHONETIC','ORTHOGRAPHIC','H_L_TONE','AUTOSEGMENTAL',
    'FEATURE_DESCRIPTION','OTHER'
  )),
  CONSTRAINT linguistic_notations_text_not_blank CHECK (notation_text <> ''),
  CONSTRAINT linguistic_notations_order_check CHECK (order_index >= 0),
  CONSTRAINT linguistic_notations_order_unique UNIQUE (evidence_id, order_index)
);

CREATE TABLE public.grapheme_phoneme_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evidence_id uuid NOT NULL UNIQUE REFERENCES public.linguistic_evidence(id) ON DELETE RESTRICT,
  grapheme text NOT NULL,
  phoneme text,
  allophone text,
  environment text,
  exception_condition text,
  orthography_context text,
  notes text,
  CONSTRAINT grapheme_phoneme_grapheme_not_blank CHECK (grapheme <> ''),
  CONSTRAINT grapheme_phoneme_target_check CHECK (
    NULLIF(phoneme, '') IS NOT NULL OR NULLIF(allophone, '') IS NOT NULL
  )
);

CREATE TABLE public.linguistic_examples (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evidence_id uuid NOT NULL REFERENCES public.linguistic_evidence(id) ON DELETE RESTRICT,
  source_locator text NOT NULL,
  example_type text NOT NULL,
  dialect_id uuid REFERENCES public.dialects(id) ON DELETE RESTRICT,
  source_text text,
  free_translation text,
  display_policy text NOT NULL DEFAULT 'UNKNOWN',
  rights_note text,
  order_index integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT linguistic_examples_locator_not_blank CHECK (btrim(source_locator) <> ''),
  CONSTRAINT linguistic_examples_type_check CHECK (example_type IN (
    'WORD','PHRASE','SENTENCE','MINIMAL_PAIR','PARADIGM_ITEM','OTHER'
  )),
  CONSTRAINT linguistic_examples_display_check CHECK (display_policy IN (
    'RESEARCH_ONLY','REVIEWER_ALLOWED','PUBLIC_ALLOWED','UNKNOWN'
  )),
  CONSTRAINT linguistic_examples_content_check CHECK (
    NULLIF(source_text, '') IS NOT NULL OR NULLIF(free_translation, '') IS NOT NULL
  ),
  CONSTRAINT linguistic_examples_order_check CHECK (order_index >= 0),
  CONSTRAINT linguistic_examples_order_unique UNIQUE (evidence_id, order_index)
);

CREATE TABLE public.linguistic_example_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  example_id uuid NOT NULL REFERENCES public.linguistic_examples(id) ON DELETE RESTRICT,
  tier_type text NOT NULL,
  tier_order integer NOT NULL,
  content text NOT NULL,
  language_or_notation text,
  CONSTRAINT linguistic_example_tiers_type_check CHECK (tier_type IN (
    'ORTHOGRAPHY','SEGMENTATION','MORPHEME_GLOSS','WORD_GLOSS','FREE_TRANSLATION',
    'PHONEMIC','PHONETIC','TONE','OTHER'
  )),
  CONSTRAINT linguistic_example_tiers_order_check CHECK (tier_order >= 0),
  CONSTRAINT linguistic_example_tiers_content_not_blank CHECK (content <> ''),
  CONSTRAINT linguistic_example_tiers_order_unique UNIQUE (example_id, tier_order)
);

CREATE TABLE public.linguistic_evidence_relations (
  source_evidence_id uuid NOT NULL REFERENCES public.linguistic_evidence(id) ON DELETE RESTRICT,
  target_evidence_id uuid NOT NULL REFERENCES public.linguistic_evidence(id) ON DELETE RESTRICT,
  relation_type text NOT NULL,
  rationale text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT linguistic_evidence_relations_type_check CHECK (relation_type IN (
    'SUPPORTS','CONTRADICTS','REFINES','ALTERNATIVE_TO'
  )),
  CONSTRAINT linguistic_evidence_relations_no_self_check CHECK (source_evidence_id <> target_evidence_id),
  PRIMARY KEY (source_evidence_id, target_evidence_id, relation_type)
);

CREATE FUNCTION public.tafsiri_validate_g2p_evidence_type()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE evidence_key text;
BEGIN
  SELECT t.evidence_type_key INTO evidence_key
  FROM public.linguistic_evidence e
  JOIN public.linguistic_evidence_types t ON t.id = e.evidence_type_id
  WHERE e.id = NEW.evidence_id;
  IF evidence_key NOT IN ('GRAPHEME_PHONEME_RULE','ALLOPHONIC_RULE') THEN
    RAISE EXCEPTION 'G2P evidence requires GRAPHEME_PHONEME_RULE or ALLOPHONIC_RULE';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER grapheme_phoneme_evidence_type_guard
  BEFORE INSERT OR UPDATE OF evidence_id ON public.grapheme_phoneme_evidence
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_validate_g2p_evidence_type();

CREATE FUNCTION public.tafsiri_guard_reviewed_evidence_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF OLD.verification_status IN ('VERIFIED','REJECTED','DISPUTED') AND (
    NEW.source_version_id IS DISTINCT FROM OLD.source_version_id OR
    NEW.evidence_type_id IS DISTINCT FROM OLD.evidence_type_id OR
    NEW.evidence_scope IS DISTINCT FROM OLD.evidence_scope OR
    NEW.source_locator IS DISTINCT FROM OLD.source_locator OR
    NEW.summary IS DISTINCT FROM OLD.summary OR
    NEW.provenance_origin IS DISTINCT FROM OLD.provenance_origin OR
    NEW.extraction_method IS DISTINCT FROM OLD.extraction_method OR
    NEW.extracted_by IS DISTINCT FROM OLD.extracted_by OR
    NEW.extracted_at IS DISTINCT FROM OLD.extracted_at
  ) THEN
    RAISE EXCEPTION 'Reviewed evidence content is append-oriented; supersede it instead';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER linguistic_evidence_reviewed_update_guard
  BEFORE UPDATE ON public.linguistic_evidence
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_reviewed_evidence_update();

CREATE INDEX source_access_locations_version_idx ON public.source_access_locations (source_version_id);
CREATE INDEX source_variety_mentions_version_idx ON public.source_variety_mentions (source_version_id);
CREATE INDEX source_variety_mentions_dialect_idx ON public.source_variety_mentions (candidate_dialect_id);
CREATE INDEX linguistic_evidence_version_idx ON public.linguistic_evidence (source_version_id);
CREATE INDEX linguistic_evidence_type_idx ON public.linguistic_evidence (evidence_type_id);
CREATE INDEX linguistic_evidence_status_idx ON public.linguistic_evidence (verification_status);
CREATE INDEX linguistic_evidence_dialects_dialect_idx ON public.linguistic_evidence_dialects (dialect_id);
CREATE INDEX linguistic_evidence_notations_evidence_idx ON public.linguistic_evidence_notations (evidence_id);
CREATE INDEX linguistic_examples_evidence_idx ON public.linguistic_examples (evidence_id);
CREATE INDEX linguistic_example_tiers_example_idx ON public.linguistic_example_tiers (example_id);
CREATE INDEX linguistic_evidence_relations_target_idx ON public.linguistic_evidence_relations (target_evidence_id);

CREATE TRIGGER source_scholarly_metadata_updated_at
  BEFORE UPDATE ON public.source_scholarly_metadata
  FOR EACH ROW EXECUTE FUNCTION public.tafsiri_touch_updated_at();

ALTER TABLE public.source_scholarly_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_identifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_access_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_variety_mentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_evidence_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_evidence_dialects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_evidence_notations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grapheme_phoneme_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_examples ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_example_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_evidence_relations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.source_scholarly_metadata, public.source_identifiers,
  public.source_access_locations, public.source_variety_mentions,
  public.linguistic_evidence_types, public.linguistic_evidence,
  public.linguistic_evidence_dialects, public.linguistic_evidence_notations,
  public.grapheme_phoneme_evidence, public.linguistic_examples,
  public.linguistic_example_tiers, public.linguistic_evidence_relations
FROM anon, authenticated;

GRANT ALL PRIVILEGES ON TABLE public.source_scholarly_metadata, public.source_identifiers,
  public.source_access_locations, public.source_variety_mentions,
  public.linguistic_evidence_types, public.linguistic_evidence,
  public.linguistic_evidence_dialects, public.linguistic_evidence_notations,
  public.grapheme_phoneme_evidence, public.linguistic_examples,
  public.linguistic_example_tiers, public.linguistic_evidence_relations
TO service_role;

REVOKE ALL ON FUNCTION public.tafsiri_validate_g2p_evidence_type() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.tafsiri_guard_reviewed_evidence_update() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tafsiri_validate_g2p_evidence_type() TO service_role;
GRANT EXECUTE ON FUNCTION public.tafsiri_guard_reviewed_evidence_update() TO service_role;

COMMENT ON TABLE public.source_access_locations IS
  'Locations where a version may be accessed. Availability is descriptive and never grants reuse rights.';
COMMENT ON COLUMN public.source_variety_mentions.literal_variety_name IS
  'Variety label exactly as reported by the source; canonical dialect mapping is separate and reviewed.';
COMMENT ON TABLE public.linguistic_evidence IS
  'Located Tafsiri interpretations of scholarly observations; evidence is not a canonical or executable linguistic rule.';
COMMENT ON TABLE public.grapheme_phoneme_evidence IS
  'Structured pronunciation evidence only; rows are not executable G2P rules.';
COMMENT ON TABLE public.linguistic_examples IS
  'Source examples governed by explicit display policy independently of publication availability.';
