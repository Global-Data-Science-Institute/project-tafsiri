CREATE TABLE public.dictionary_concept_candidates (
  id                       uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  dictionary_entry_id      uuid          NOT NULL REFERENCES public.dictionary_entries(id),
  concept_id               uuid          REFERENCES public.concepts(id),
  proposed_definition_en   text,
  mapping_status           text          NOT NULL DEFAULT 'proposed',
  mapping_source           text          NOT NULL,
  confidence               numeric(3,2),
  evidence                 jsonb,
  review_notes             text,
  reviewed_by              uuid          REFERENCES public.contributors(id),
  reviewed_at              timestamptz,
  promoted_concept_term_id uuid          REFERENCES public.concept_terms(id),
  created_at               timestamptz   NOT NULL DEFAULT now(),
  updated_at               timestamptz   NOT NULL DEFAULT now(),

  CONSTRAINT dictionary_concept_candidates_mapping_status_check CHECK (
    mapping_status IN (
      'proposed',
      'in_review',
      'approved',
      'rejected',
      'needs_split',
      'insufficient_evidence'
    )
  ),
  CONSTRAINT dictionary_concept_candidates_mapping_source_check CHECK (
    mapping_source IN (
      'human',
      'rule_based',
      'imported',
      'machine_generated'
    )
  ),
  CONSTRAINT dictionary_concept_candidates_confidence_check CHECK (
    confidence IS NULL OR confidence BETWEEN 0.00 AND 1.00
  ),
  CONSTRAINT dictionary_concept_candidates_definition_not_blank CHECK (
    proposed_definition_en IS NULL OR btrim(proposed_definition_en) <> ''
  ),
  CONSTRAINT dictionary_concept_candidates_approval_check CHECK (
    mapping_status <> 'approved'
    OR (
      concept_id IS NOT NULL
      AND reviewed_by IS NOT NULL
      AND reviewed_at IS NOT NULL
    )
  ),
  CONSTRAINT dictionary_concept_candidates_promotion_check CHECK (
    promoted_concept_term_id IS NULL
    OR (
      mapping_status = 'approved'
      AND concept_id IS NOT NULL
    )
  )
);

CREATE UNIQUE INDEX dictionary_concept_candidates_entry_concept_unique
  ON public.dictionary_concept_candidates (dictionary_entry_id, concept_id)
  WHERE concept_id IS NOT NULL;

CREATE INDEX dictionary_concept_candidates_dictionary_entry_idx
  ON public.dictionary_concept_candidates (dictionary_entry_id);

CREATE INDEX dictionary_concept_candidates_concept_idx
  ON public.dictionary_concept_candidates (concept_id)
  WHERE concept_id IS NOT NULL;

CREATE INDEX dictionary_concept_candidates_status_idx
  ON public.dictionary_concept_candidates (mapping_status);

CREATE INDEX dictionary_concept_candidates_source_idx
  ON public.dictionary_concept_candidates (mapping_source);

CREATE INDEX dictionary_concept_candidates_reviewer_idx
  ON public.dictionary_concept_candidates (reviewed_by)
  WHERE reviewed_by IS NOT NULL;

CREATE INDEX dictionary_concept_candidates_promoted_term_idx
  ON public.dictionary_concept_candidates (promoted_concept_term_id)
  WHERE promoted_concept_term_id IS NOT NULL;

ALTER TABLE public.dictionary_concept_candidates ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.dictionary_concept_candidates
  FROM anon, authenticated;

GRANT ALL PRIVILEGES ON TABLE public.dictionary_concept_candidates
  TO service_role;
