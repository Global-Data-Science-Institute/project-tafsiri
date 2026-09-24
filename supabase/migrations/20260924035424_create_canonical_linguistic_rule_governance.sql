-- Migration 009: Canonical Linguistic Rule & Promotion Governance Foundation.
-- Governance schema and deterministic taxonomies only. No rules or promotions.

CREATE TABLE public.linguistic_rule_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_type_key text NOT NULL UNIQUE,
  label text NOT NULL,
  description text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  deprecated_at timestamptz,
  replaced_by_id uuid REFERENCES public.linguistic_rule_types(id) ON DELETE RESTRICT,
  CONSTRAINT linguistic_rule_types_key_format CHECK (rule_type_key ~ '^[A-Z][A-Z0-9_]*$'),
  CONSTRAINT linguistic_rule_types_nonblank CHECK (btrim(label) <> '' AND btrim(description) <> ''),
  CONSTRAINT linguistic_rule_types_state CHECK ((is_active AND deprecated_at IS NULL) OR (NOT is_active AND deprecated_at IS NOT NULL)),
  CONSTRAINT linguistic_rule_types_replacement CHECK (replaced_by_id IS NULL OR replaced_by_id <> id)
);

INSERT INTO public.linguistic_rule_types (rule_type_key,label,description) VALUES
 ('PHONOLOGY','Phonology','Canonical phonological knowledge.'),
 ('GRAPHEME_PHONEME','Grapheme-phoneme','Canonical grapheme-to-phoneme knowledge.'),
 ('ALLOPHONY','Allophony','Canonical conditioned phonetic realization.'),
 ('TONE','Tone','Canonical tonal knowledge.'),
 ('PROSODY','Prosody','Canonical prosodic knowledge.'),
 ('SYLLABLE_STRUCTURE','Syllable structure','Canonical syllable-structure knowledge.'),
 ('MORPHOPHONOLOGY','Morphophonology','Canonical morphophonological knowledge.'),
 ('NOUN_CLASS','Noun class','Canonical noun-class knowledge.'),
 ('AGREEMENT','Agreement','Canonical agreement knowledge.'),
 ('INFLECTION','Inflection','Canonical inflectional knowledge.'),
 ('DERIVATION','Derivation','Canonical derivational knowledge.'),
 ('VERB_MORPHOLOGY','Verb morphology','Canonical verbal-morphology knowledge.'),
 ('TENSE_ASPECT','Tense and aspect','Canonical tense/aspect knowledge.'),
 ('NEGATION','Negation','Canonical negation knowledge.'),
 ('LEXICAL_CATEGORY','Lexical category','Canonical lexical-category knowledge.'),
 ('SYNTAX','Syntax','Canonical syntactic knowledge.'),
 ('WORD_ORDER','Word order','Canonical word-order knowledge.'),
 ('ARGUMENT_STRUCTURE','Argument structure','Canonical argument-structure knowledge.'),
 ('SEMANTICS','Semantics','Canonical semantic knowledge.'),
 ('PRAGMATICS','Pragmatics','Canonical pragmatic knowledge.'),
 ('MODALITY','Modality','Canonical modality knowledge.'),
 ('IDEOPHONE','Ideophone','Canonical ideophone knowledge.'),
 ('LOANWORD_ADAPTATION','Loanword adaptation','Canonical loanword-adaptation knowledge.'),
 ('TERMINOLOGY_PRINCIPLE','Terminology principle','Canonical terminology governance principle.'),
 ('DIALECT_VARIATION','Dialect variation','Canonical dialect-variation knowledge.');

CREATE TABLE public.contributor_role_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_type_key text NOT NULL UNIQUE,
  label text NOT NULL,
  description text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  deprecated_at timestamptz,
  CONSTRAINT contributor_role_types_key_format CHECK (role_type_key ~ '^[A-Z][A-Z0-9_]*$'),
  CONSTRAINT contributor_role_types_nonblank CHECK (btrim(label) <> '' AND btrim(description) <> ''),
  CONSTRAINT contributor_role_types_state CHECK ((is_active AND deprecated_at IS NULL) OR (NOT is_active AND deprecated_at IS NOT NULL))
);

INSERT INTO public.contributor_role_types (role_type_key,label,description) VALUES
 ('LINGUISTIC_REVIEWER','Linguistic reviewer','May perform evidence review within an explicitly granted scope.'),
 ('SENIOR_LINGUISTIC_REVIEWER','Senior linguistic reviewer','May perform senior linguistic review within an explicitly granted scope.'),
 ('DIALECT_SPECIALIST','Dialect specialist','Holds authority for a named dialect within the granted scope.'),
 ('DOMAIN_SPECIALIST','Domain specialist','Holds authority for a named linguistic domain.'),
 ('RESEARCH_ADMIN','Research administrator','Administers governed research workflows.'),
 ('CANONICAL_APPROVER','Canonical approver','May approve canonical promotions within the granted scope.');

CREATE TABLE public.linguistic_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_key text NOT NULL UNIQUE,
  rule_type_id uuid NOT NULL REFERENCES public.linguistic_rule_types(id) ON DELETE RESTRICT,
  lifecycle_status text NOT NULL DEFAULT 'PROVISIONAL',
  current_revision_id uuid,
  created_by_promotion_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  deprecated_at timestamptz,
  superseded_at timestamptz,
  CONSTRAINT linguistic_rules_key_nonblank CHECK (btrim(rule_key) <> ''),
  CONSTRAINT linguistic_rules_status_check CHECK (lifecycle_status IN ('PROVISIONAL','ACTIVE','DISPUTED','DEPRECATED','SUPERSEDED')),
  CONSTRAINT linguistic_rules_lifecycle_dates CHECK (
    (lifecycle_status <> 'DEPRECATED' OR deprecated_at IS NOT NULL) AND
    (lifecycle_status <> 'SUPERSEDED' OR superseded_at IS NOT NULL)
  )
);

CREATE TABLE public.linguistic_rule_promotions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promotion_key text NOT NULL UNIQUE,
  action text NOT NULL,
  status text NOT NULL DEFAULT 'DRAFT',
  target_rule_id uuid REFERENCES public.linguistic_rules(id) ON DELETE RESTRICT,
  proposed_rule_type_id uuid REFERENCES public.linguistic_rule_types(id) ON DELETE RESTRICT,
  proposed_scope text,
  proposed_statement text,
  evidence_set_checksum text NOT NULL,
  policy_version text NOT NULL,
  risk_class text NOT NULL,
  authority_policy text NOT NULL,
  requested_by uuid NOT NULL REFERENCES public.contributors(id) ON DELETE RESTRICT,
  requested_at timestamptz NOT NULL DEFAULT now(),
  approved_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  approved_at timestamptz,
  reason text NOT NULL,
  idempotency_key text NOT NULL UNIQUE,
  applied_at timestamptz,
  transaction_reference text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT linguistic_rule_promotions_key_nonblank CHECK (btrim(promotion_key) <> '' AND btrim(idempotency_key) <> ''),
  CONSTRAINT linguistic_rule_promotions_action_check CHECK (action IN ('CREATE_RULE','CREATE_REVISION','DEPRECATE_RULE','SUPERSEDE_RULE','DISPUTE_RULE','REACTIVATE_RULE')),
  CONSTRAINT linguistic_rule_promotions_status_check CHECK (status IN ('DRAFT','READY_FOR_REVIEW','APPROVED','REJECTED','WITHDRAWN','APPLIED')),
  CONSTRAINT linguistic_rule_promotions_scope_check CHECK (proposed_scope IS NULL OR proposed_scope IN ('DIALECT','MULTI_DIALECT','FAMILY_GENERALIZATION')),
  CONSTRAINT linguistic_rule_promotions_checksum_check CHECK (evidence_set_checksum ~ '^[0-9a-f]{64}$'),
  CONSTRAINT linguistic_rule_promotions_nonblank CHECK (btrim(policy_version) <> '' AND btrim(reason) <> ''),
  CONSTRAINT linguistic_rule_promotions_risk_check CHECK (risk_class IN ('DESCRIPTIVE_LOW_RISK','OPERATIONAL','HIGH_IMPACT')),
  CONSTRAINT linguistic_rule_promotions_authority_check CHECK (authority_policy IN ('SINGLE_RESEARCHER_ALLOWED','SEPARATION_REQUIRED')),
  CONSTRAINT linguistic_rule_promotions_approval_pair CHECK ((approved_by IS NULL AND approved_at IS NULL) OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)),
  CONSTRAINT linguistic_rule_promotions_state_invariants CHECK (
    (status NOT IN ('APPROVED','APPLIED') OR (approved_by IS NOT NULL AND approved_at IS NOT NULL)) AND
    (status <> 'APPLIED' OR applied_at IS NOT NULL) AND
    (status NOT IN ('REJECTED','WITHDRAWN') OR applied_at IS NULL)
  ),
  CONSTRAINT linguistic_rule_promotions_proposal_check CHECK (
    action NOT IN ('CREATE_RULE','CREATE_REVISION') OR
    (proposed_rule_type_id IS NOT NULL AND proposed_scope IS NOT NULL AND NULLIF(btrim(proposed_statement),'') IS NOT NULL)
  )
);

CREATE TABLE public.linguistic_rule_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id uuid NOT NULL REFERENCES public.linguistic_rules(id) ON DELETE RESTRICT,
  revision_number integer NOT NULL,
  canonical_statement text NOT NULL,
  scope text NOT NULL,
  conditions_summary text,
  exceptions_summary text,
  structured_parameters jsonb,
  structured_schema_version text,
  reason text NOT NULL,
  policy_version text NOT NULL,
  created_by_promotion_id uuid NOT NULL REFERENCES public.linguistic_rule_promotions(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  effective_at timestamptz,
  retired_at timestamptz,
  CONSTRAINT linguistic_rule_revisions_number_positive CHECK (revision_number > 0),
  CONSTRAINT linguistic_rule_revisions_statement_nonblank CHECK (btrim(canonical_statement) <> ''),
  CONSTRAINT linguistic_rule_revisions_scope_check CHECK (scope IN ('DIALECT','MULTI_DIALECT','FAMILY_GENERALIZATION')),
  CONSTRAINT linguistic_rule_revisions_nonblank CHECK (btrim(reason) <> '' AND btrim(policy_version) <> ''),
  CONSTRAINT linguistic_rule_revisions_structured_pair CHECK ((structured_parameters IS NULL) = (structured_schema_version IS NULL)),
  CONSTRAINT linguistic_rule_revisions_unique UNIQUE (rule_id,revision_number),
  CONSTRAINT linguistic_rule_revisions_id_rule_unique UNIQUE (id,rule_id)
);

ALTER TABLE public.linguistic_rules
  ADD CONSTRAINT linguistic_rules_current_revision_fkey
  FOREIGN KEY (current_revision_id,id) REFERENCES public.linguistic_rule_revisions(id,rule_id)
  ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE public.linguistic_rules
  ADD CONSTRAINT linguistic_rules_created_promotion_fkey
  FOREIGN KEY (created_by_promotion_id) REFERENCES public.linguistic_rule_promotions(id) ON DELETE RESTRICT;

CREATE TABLE public.linguistic_rule_dialects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_revision_id uuid NOT NULL REFERENCES public.linguistic_rule_revisions(id) ON DELETE RESTRICT,
  dialect_id uuid NOT NULL REFERENCES public.dialects(id) ON DELETE RESTRICT,
  role text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT linguistic_rule_dialects_role_check CHECK (role IN ('APPLIES_TO','CONTRASTS_WITH','EXCEPTION','SUPPORTED_VARIETY')),
  CONSTRAINT linguistic_rule_dialects_unique UNIQUE (rule_revision_id,dialect_id,role)
);

CREATE TABLE public.linguistic_rule_conditions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_revision_id uuid NOT NULL REFERENCES public.linguistic_rule_revisions(id) ON DELETE RESTRICT,
  condition_type text NOT NULL,
  condition_statement text NOT NULL,
  structured_value jsonb,
  order_index integer NOT NULL DEFAULT 0,
  is_negated boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT linguistic_rule_conditions_type_check CHECK (condition_type IN ('PHONOLOGICAL_ENVIRONMENT','MORPHOLOGICAL_CONTEXT','SYNTACTIC_CONTEXT','SEMANTIC_CONTEXT','REGISTER','DIALECT_VARIANT','SPEAKER_VARIATION','LEXICAL_EXCEPTION','OTHER')),
  CONSTRAINT linguistic_rule_conditions_statement_nonblank CHECK (btrim(condition_statement) <> ''),
  CONSTRAINT linguistic_rule_conditions_order_check CHECK (order_index >= 0),
  CONSTRAINT linguistic_rule_conditions_order_unique UNIQUE (rule_revision_id,order_index)
);

CREATE TABLE public.linguistic_rule_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_revision_id uuid NOT NULL REFERENCES public.linguistic_rule_revisions(id) ON DELETE RESTRICT,
  evidence_id uuid NOT NULL REFERENCES public.linguistic_evidence(id) ON DELETE RESTRICT,
  evidence_role text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT linguistic_rule_evidence_role_check CHECK (evidence_role IN ('SUPPORTS','CONTRADICTS','QUALIFIES','EXCEPTION','HISTORICAL_SUPPORT')),
  CONSTRAINT linguistic_rule_evidence_unique UNIQUE (rule_revision_id,evidence_id,evidence_role)
);

CREATE TABLE public.linguistic_rule_supersessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  superseded_rule_id uuid NOT NULL REFERENCES public.linguistic_rules(id) ON DELETE RESTRICT,
  replacement_rule_id uuid NOT NULL REFERENCES public.linguistic_rules(id) ON DELETE RESTRICT,
  relationship_type text NOT NULL,
  promotion_id uuid NOT NULL REFERENCES public.linguistic_rule_promotions(id) ON DELETE RESTRICT,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT linguistic_rule_supersessions_type_check CHECK (relationship_type IN ('REPLACED_BY','SPLIT_INTO','MERGED_INTO','REFINED_BY')),
  CONSTRAINT linguistic_rule_supersessions_no_self CHECK (superseded_rule_id <> replacement_rule_id),
  CONSTRAINT linguistic_rule_supersessions_reason_nonblank CHECK (btrim(reason) <> ''),
  CONSTRAINT linguistic_rule_supersessions_unique UNIQUE (superseded_rule_id,replacement_rule_id,relationship_type)
);

CREATE TABLE public.contributor_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contributor_id uuid NOT NULL REFERENCES public.contributors(id) ON DELETE RESTRICT,
  role_type_id uuid NOT NULL REFERENCES public.contributor_role_types(id) ON DELETE RESTRICT,
  dialect_id uuid REFERENCES public.dialects(id) ON DELETE RESTRICT,
  domain text,
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_until timestamptz,
  granted_by uuid REFERENCES public.contributors(id) ON DELETE RESTRICT,
  granted_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  revoked_at timestamptz,
  CONSTRAINT contributor_roles_domain_nonblank CHECK (domain IS NULL OR btrim(domain) <> ''),
  CONSTRAINT contributor_roles_validity CHECK (valid_until IS NULL OR valid_until > valid_from),
  CONSTRAINT contributor_roles_revocation CHECK (revoked_at IS NULL OR revoked_at >= granted_at),
  CONSTRAINT contributor_roles_scope_unique UNIQUE NULLS NOT DISTINCT (contributor_id,role_type_id,dialect_id,domain,valid_from)
);

CREATE TABLE public.linguistic_rule_promotion_outputs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  promotion_id uuid NOT NULL REFERENCES public.linguistic_rule_promotions(id) ON DELETE RESTRICT,
  output_type text NOT NULL,
  output_action text NOT NULL,
  rule_id uuid REFERENCES public.linguistic_rules(id) ON DELETE RESTRICT,
  revision_id uuid REFERENCES public.linguistic_rule_revisions(id) ON DELETE RESTRICT,
  dialect_link_id uuid REFERENCES public.linguistic_rule_dialects(id) ON DELETE RESTRICT,
  evidence_link_id uuid REFERENCES public.linguistic_rule_evidence(id) ON DELETE RESTRICT,
  condition_id uuid REFERENCES public.linguistic_rule_conditions(id) ON DELETE RESTRICT,
  supersession_id uuid REFERENCES public.linguistic_rule_supersessions(id) ON DELETE RESTRICT,
  order_index integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT linguistic_rule_outputs_type_check CHECK (output_type IN ('RULE','REVISION','DIALECT_LINK','EVIDENCE_LINK','CONDITION','SUPERSESSION')),
  CONSTRAINT linguistic_rule_outputs_action_check CHECK (output_action IN ('CREATED','REUSED','UPDATED','SUPERSEDED')),
  CONSTRAINT linguistic_rule_outputs_order_check CHECK (order_index >= 0),
  CONSTRAINT linguistic_rule_outputs_one_target CHECK (num_nonnulls(rule_id,revision_id,dialect_link_id,evidence_link_id,condition_id,supersession_id)=1),
  CONSTRAINT linguistic_rule_outputs_type_target CHECK (
    (output_type='RULE' AND rule_id IS NOT NULL) OR
    (output_type='REVISION' AND revision_id IS NOT NULL) OR
    (output_type='DIALECT_LINK' AND dialect_link_id IS NOT NULL) OR
    (output_type='EVIDENCE_LINK' AND evidence_link_id IS NOT NULL) OR
    (output_type='CONDITION' AND condition_id IS NOT NULL) OR
    (output_type='SUPERSESSION' AND supersession_id IS NOT NULL)
  ),
  CONSTRAINT linguistic_rule_outputs_order_unique UNIQUE (promotion_id,order_index)
);

CREATE FUNCTION public.tafsiri_validate_rule_evidence_support()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE evidence_status text;
BEGIN
  IF NEW.evidence_role='SUPPORTS' THEN
    SELECT verification_status INTO evidence_status FROM public.linguistic_evidence WHERE id=NEW.evidence_id;
    IF evidence_status IS DISTINCT FROM 'VERIFIED' THEN
      RAISE EXCEPTION 'SUPPORTS requires VERIFIED linguistic evidence';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER linguistic_rule_evidence_support_guard
BEFORE INSERT OR UPDATE OF evidence_id,evidence_role ON public.linguistic_rule_evidence
FOR EACH ROW EXECUTE FUNCTION public.tafsiri_validate_rule_evidence_support();

CREATE FUNCTION public.tafsiri_validate_active_rule_scope()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE revision_scope text; applies_count integer;
BEGIN
  IF NEW.lifecycle_status='ACTIVE' THEN
    IF NEW.current_revision_id IS NULL THEN RAISE EXCEPTION 'ACTIVE rule requires current revision'; END IF;
    SELECT scope INTO revision_scope FROM public.linguistic_rule_revisions WHERE id=NEW.current_revision_id AND rule_id=NEW.id;
    SELECT count(*) INTO applies_count FROM public.linguistic_rule_dialects WHERE rule_revision_id=NEW.current_revision_id AND role='APPLIES_TO';
    IF revision_scope='DIALECT' AND applies_count<>1 THEN RAISE EXCEPTION 'DIALECT ACTIVE rule requires exactly one APPLIES_TO link'; END IF;
    IF revision_scope='MULTI_DIALECT' AND applies_count<2 THEN RAISE EXCEPTION 'MULTI_DIALECT ACTIVE rule requires at least two APPLIES_TO links'; END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER linguistic_rules_active_scope_guard
BEFORE INSERT OR UPDATE OF lifecycle_status,current_revision_id ON public.linguistic_rules
FOR EACH ROW EXECUTE FUNCTION public.tafsiri_validate_active_rule_scope();

CREATE FUNCTION public.tafsiri_guard_rule_revision_update()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE applied boolean; active boolean;
BEGIN
  SELECT status='APPLIED' INTO applied FROM public.linguistic_rule_promotions WHERE id=OLD.created_by_promotion_id;
  SELECT lifecycle_status IN ('ACTIVE','DISPUTED','DEPRECATED','SUPERSEDED') INTO active FROM public.linguistic_rules WHERE id=OLD.rule_id;
  IF (COALESCE(applied,false) OR COALESCE(active,false)) AND (
    NEW.rule_id IS DISTINCT FROM OLD.rule_id OR NEW.revision_number IS DISTINCT FROM OLD.revision_number OR
    NEW.canonical_statement IS DISTINCT FROM OLD.canonical_statement OR NEW.scope IS DISTINCT FROM OLD.scope OR
    NEW.conditions_summary IS DISTINCT FROM OLD.conditions_summary OR NEW.exceptions_summary IS DISTINCT FROM OLD.exceptions_summary OR
    NEW.structured_parameters IS DISTINCT FROM OLD.structured_parameters OR NEW.structured_schema_version IS DISTINCT FROM OLD.structured_schema_version OR
    NEW.reason IS DISTINCT FROM OLD.reason OR NEW.policy_version IS DISTINCT FROM OLD.policy_version OR
    NEW.created_by_promotion_id IS DISTINCT FROM OLD.created_by_promotion_id
  ) THEN RAISE EXCEPTION 'Applied or canonical rule revisions are immutable; create a new revision'; END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER linguistic_rule_revisions_update_guard
BEFORE UPDATE ON public.linguistic_rule_revisions
FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_rule_revision_update();

CREATE FUNCTION public.tafsiri_prevent_rule_supersession_cycle()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF EXISTS (
    WITH RECURSIVE successors(id) AS (
      SELECT NEW.replacement_rule_id
      UNION
      SELECT s.replacement_rule_id FROM public.linguistic_rule_supersessions s JOIN successors x ON s.superseded_rule_id=x.id
    ) SELECT 1 FROM successors WHERE id=NEW.superseded_rule_id
  ) THEN RAISE EXCEPTION 'linguistic rule supersession cycle detected'; END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER linguistic_rule_supersessions_cycle_guard
BEFORE INSERT OR UPDATE OF superseded_rule_id,replacement_rule_id ON public.linguistic_rule_supersessions
FOR EACH ROW EXECUTE FUNCTION public.tafsiri_prevent_rule_supersession_cycle();

CREATE INDEX linguistic_rules_type_idx ON public.linguistic_rules(rule_type_id);
CREATE INDEX linguistic_rules_status_idx ON public.linguistic_rules(lifecycle_status);
CREATE INDEX linguistic_rule_dialects_dialect_idx ON public.linguistic_rule_dialects(dialect_id);
CREATE INDEX linguistic_rule_evidence_evidence_idx ON public.linguistic_rule_evidence(evidence_id);
CREATE INDEX linguistic_rule_promotions_status_idx ON public.linguistic_rule_promotions(status);
CREATE INDEX contributor_roles_contributor_idx ON public.contributor_roles(contributor_id);
CREATE INDEX contributor_roles_role_type_idx ON public.contributor_roles(role_type_id);
CREATE INDEX linguistic_rule_supersessions_replacement_idx ON public.linguistic_rule_supersessions(replacement_rule_id);

ALTER TABLE public.linguistic_rule_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_rule_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_rule_dialects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_rule_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_rule_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_rule_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_rule_promotion_outputs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linguistic_rule_supersessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contributor_role_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contributor_roles ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.linguistic_rule_types,public.linguistic_rules,public.linguistic_rule_revisions,
 public.linguistic_rule_dialects,public.linguistic_rule_conditions,public.linguistic_rule_evidence,
 public.linguistic_rule_promotions,public.linguistic_rule_promotion_outputs,public.linguistic_rule_supersessions,
 public.contributor_role_types,public.contributor_roles FROM PUBLIC,anon,authenticated;
GRANT ALL PRIVILEGES ON TABLE public.linguistic_rule_types,public.linguistic_rules,public.linguistic_rule_revisions,
 public.linguistic_rule_dialects,public.linguistic_rule_conditions,public.linguistic_rule_evidence,
 public.linguistic_rule_promotions,public.linguistic_rule_promotion_outputs,public.linguistic_rule_supersessions,
 public.contributor_role_types,public.contributor_roles TO service_role;

REVOKE ALL ON FUNCTION public.tafsiri_validate_rule_evidence_support() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tafsiri_validate_active_rule_scope() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tafsiri_guard_rule_revision_update() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.tafsiri_prevent_rule_supersession_cycle() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.tafsiri_validate_rule_evidence_support(),public.tafsiri_validate_active_rule_scope(),
 public.tafsiri_guard_rule_revision_update(),public.tafsiri_prevent_rule_supersession_cycle() TO service_role;

COMMENT ON TABLE public.linguistic_rules IS 'Stable governed rule identities. Verified evidence is not canonical knowledge, and canonical status does not imply runtime enablement.';
COMMENT ON TABLE public.linguistic_rule_revisions IS 'Append-oriented semantic revisions; corrections create new revisions rather than rewriting canonical history.';
COMMENT ON TABLE public.linguistic_rule_evidence IS 'Traceability from canonical revisions to reviewed evidence and exact source provenance.';
COMMENT ON TABLE public.linguistic_rule_promotions IS 'Explicit governance decisions; APPROVED is distinct from successful transactional APPLIED state.';
COMMENT ON TABLE public.contributor_roles IS 'Explicit scoped authority assignments; authority is never inferred from contributor name, email, auth metadata, or application role.';

-- Transactional promotion application is intentionally deferred until the first pilot supplies
-- validated payload shapes. This migration provides constraints and narrowly secured validation
-- triggers without introducing a premature privileged SECURITY DEFINER function.
