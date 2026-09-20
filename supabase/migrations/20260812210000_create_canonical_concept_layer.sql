CREATE TABLE public.concepts (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  concept_key   text        NOT NULL UNIQUE,
  definition_en text        NOT NULL,
  domain        text,
  subdomain     text,
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT concepts_key_not_blank CHECK (
    btrim(concept_key) <> ''
  ),
  CONSTRAINT concepts_definition_not_blank CHECK (
    btrim(definition_en) <> ''
  )
);

CREATE TABLE public.concept_terms (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  concept_id          uuid        NOT NULL REFERENCES public.concepts(id),
  language_id         uuid        NOT NULL REFERENCES public.languages(id),
  dialect_id          uuid        REFERENCES public.dialects(id),
  term                text,
  term_normalized     text,
  explanation_text    text,
  term_kind           text        NOT NULL DEFAULT 'native',
  dictionary_entry_id uuid        REFERENCES public.dictionary_entries(id),
  provenance_type     text        NOT NULL,
  source_reference    text,
  verification_status text        NOT NULL DEFAULT 'unverified',
  verified_by         uuid        REFERENCES public.contributors(id),
  verified_at         timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT concept_terms_term_kind_check CHECK (
    term_kind IN (
      'native',
      'borrowed',
      'descriptive',
      'transliterated',
      'preserve_explain',
      'uncertain',
      'no_equivalent'
    )
  ),
  CONSTRAINT concept_terms_provenance_type_check CHECK (
    provenance_type IN (
      'human',
      'published_source',
      'imported',
      'machine_generated'
    )
  ),
  CONSTRAINT concept_terms_verification_status_check CHECK (
    verification_status IN (
      'unverified',
      'in_review',
      'verified',
      'rejected',
      'disputed'
    )
  ),
  CONSTRAINT concept_terms_content_check CHECK (
    (term IS NOT NULL AND btrim(term) <> '')
    OR (explanation_text IS NOT NULL AND btrim(explanation_text) <> '')
  ),
  CONSTRAINT concept_terms_null_term_kind_check CHECK (
    term IS NOT NULL OR term_kind IN ('uncertain', 'no_equivalent')
  ),
  CONSTRAINT concept_terms_orphan_normalization_check CHECK (
    term IS NOT NULL OR term_normalized IS NULL
  ),
  CONSTRAINT concept_terms_normalized_not_blank CHECK (
    term_normalized IS NULL OR btrim(term_normalized) <> ''
  ),
  CONSTRAINT concept_terms_no_equivalent_check CHECK (
    term_kind <> 'no_equivalent'
    OR (
      term IS NULL
      AND explanation_text IS NOT NULL
      AND btrim(explanation_text) <> ''
    )
  ),
  CONSTRAINT concept_terms_preserve_explain_check CHECK (
    term_kind <> 'preserve_explain'
    OR (
      term IS NOT NULL
      AND btrim(term) <> ''
      AND explanation_text IS NOT NULL
      AND btrim(explanation_text) <> ''
    )
  ),
  CONSTRAINT concept_terms_verification_consistency_check CHECK (
    (
      verification_status = 'verified'
      AND verified_by IS NOT NULL
      AND verified_at IS NOT NULL
    )
    OR
    (
      verification_status <> 'verified'
      AND verified_by IS NULL
      AND verified_at IS NULL
    )
  )
);

CREATE UNIQUE INDEX concept_terms_language_term_unique
  ON public.concept_terms (
    concept_id,
    language_id,
    (COALESCE(term_normalized, term))
  )
  WHERE dialect_id IS NULL AND term IS NOT NULL;

CREATE UNIQUE INDEX concept_terms_dialect_term_unique
  ON public.concept_terms (
    concept_id,
    language_id,
    dialect_id,
    (COALESCE(term_normalized, term))
  )
  WHERE dialect_id IS NOT NULL AND term IS NOT NULL;

CREATE UNIQUE INDEX concept_terms_language_no_equivalent_unique
  ON public.concept_terms (concept_id, language_id)
  WHERE dialect_id IS NULL AND term_kind = 'no_equivalent' AND term IS NULL;

CREATE UNIQUE INDEX concept_terms_dialect_no_equivalent_unique
  ON public.concept_terms (concept_id, language_id, dialect_id)
  WHERE dialect_id IS NOT NULL AND term_kind = 'no_equivalent' AND term IS NULL;

CREATE INDEX concept_terms_concept_id_idx
  ON public.concept_terms (concept_id);

CREATE INDEX concept_terms_language_dialect_idx
  ON public.concept_terms (language_id, dialect_id);

CREATE INDEX concept_terms_dictionary_entry_idx
  ON public.concept_terms (dictionary_entry_id)
  WHERE dictionary_entry_id IS NOT NULL;

CREATE INDEX concept_terms_verification_status_idx
  ON public.concept_terms (verification_status);

CREATE INDEX concept_terms_term_normalized_idx
  ON public.concept_terms (term_normalized)
  WHERE term_normalized IS NOT NULL;

ALTER TABLE public.concepts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.concept_terms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read access"
  ON public.concepts
  FOR SELECT
  USING (true);

CREATE POLICY "Public read access"
  ON public.concept_terms
  FOR SELECT
  USING (true);

REVOKE ALL PRIVILEGES ON TABLE public.concepts
  FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.concept_terms
  FROM anon, authenticated;

GRANT SELECT ON TABLE public.concepts
  TO anon, authenticated;

GRANT SELECT ON TABLE public.concept_terms
  TO anon, authenticated;

GRANT ALL PRIVILEGES ON TABLE public.concepts
  TO service_role;

GRANT ALL PRIVILEGES ON TABLE public.concept_terms
  TO service_role;
