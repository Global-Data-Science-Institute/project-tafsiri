-- Project Tafsiri Migration 003: online multi-reviewer linguistic evaluation.
-- Schema and access controls only; this migration intentionally inserts no data.

CREATE TABLE public.evaluation_studies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  study_key text NOT NULL UNIQUE,
  title text NOT NULL,
  description text NOT NULL,
  dialect_id uuid NOT NULL REFERENCES public.dialects(id) ON DELETE RESTRICT,
  pipeline_version text NOT NULL,
  evidence_schema_version text NOT NULL,
  configuration_hash text NOT NULL,
  source_artifact_hash text NOT NULL,
  study_status text NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  activated_at timestamptz,
  closed_at timestamptz,
  archived_at timestamptz,
  CONSTRAINT evaluation_studies_key_not_blank CHECK (btrim(study_key) <> ''),
  CONSTRAINT evaluation_studies_title_not_blank CHECK (btrim(title) <> ''),
  CONSTRAINT evaluation_studies_description_not_blank CHECK (btrim(description) <> ''),
  CONSTRAINT evaluation_studies_pipeline_version_not_blank CHECK (btrim(pipeline_version) <> ''),
  CONSTRAINT evaluation_studies_evidence_schema_version_not_blank CHECK (btrim(evidence_schema_version) <> ''),
  CONSTRAINT evaluation_studies_configuration_hash_not_blank CHECK (btrim(configuration_hash) <> ''),
  CONSTRAINT evaluation_studies_source_artifact_hash_not_blank CHECK (btrim(source_artifact_hash) <> ''),
  CONSTRAINT evaluation_studies_status_check CHECK (study_status IN ('draft', 'active', 'closed', 'archived')),
  CONSTRAINT evaluation_studies_timestamp_consistency_check CHECK (
    (study_status = 'draft' AND activated_at IS NULL AND closed_at IS NULL AND archived_at IS NULL)
    OR (study_status = 'active' AND activated_at IS NOT NULL AND closed_at IS NULL AND archived_at IS NULL)
    OR (study_status = 'closed' AND activated_at IS NOT NULL AND closed_at IS NOT NULL AND archived_at IS NULL)
    OR (study_status = 'archived' AND activated_at IS NOT NULL AND archived_at IS NOT NULL)
  )
);

CREATE TABLE public.evaluation_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  study_id uuid NOT NULL REFERENCES public.evaluation_studies(id) ON DELETE RESTRICT,
  item_number integer NOT NULL,
  dictionary_entry_id uuid NOT NULL REFERENCES public.dictionary_entries(id) ON DELETE RESTRICT,
  source_snapshot jsonb NOT NULL,
  source_hash text NOT NULL,
  sampling_group text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT evaluation_items_number_positive CHECK (item_number > 0),
  CONSTRAINT evaluation_items_source_snapshot_object_check CHECK (jsonb_typeof(source_snapshot) = 'object'),
  CONSTRAINT evaluation_items_source_hash_not_blank CHECK (btrim(source_hash) <> ''),
  CONSTRAINT evaluation_items_sampling_group_not_blank CHECK (btrim(sampling_group) <> ''),
  CONSTRAINT evaluation_items_study_number_unique UNIQUE (study_id, item_number),
  CONSTRAINT evaluation_items_study_dictionary_entry_unique UNIQUE (study_id, dictionary_entry_id)
);

CREATE TABLE public.evaluation_item_pipeline_snapshots (
  evaluation_item_id uuid PRIMARY KEY REFERENCES public.evaluation_items(id) ON DELETE RESTRICT,
  pipeline_snapshot jsonb NOT NULL,
  pipeline_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT evaluation_pipeline_snapshot_object_check CHECK (jsonb_typeof(pipeline_snapshot) = 'object'),
  CONSTRAINT evaluation_pipeline_hash_not_blank CHECK (btrim(pipeline_hash) <> '')
);

CREATE TABLE public.reviewer_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE RESTRICT,
  reviewer_code text NOT NULL UNIQUE,
  display_name text,
  organization text,
  notes text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reviewer_profiles_code_not_blank CHECK (btrim(reviewer_code) <> ''),
  CONSTRAINT reviewer_profiles_display_name_not_blank CHECK (display_name IS NULL OR btrim(display_name) <> ''),
  CONSTRAINT reviewer_profiles_organization_not_blank CHECK (organization IS NULL OR btrim(organization) <> '')
);

CREATE TABLE public.reviewer_dialect_expertise (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reviewer_id uuid NOT NULL REFERENCES public.reviewer_profiles(id) ON DELETE RESTRICT,
  dialect_id uuid NOT NULL REFERENCES public.dialects(id) ON DELETE RESTRICT,
  expertise_level text NOT NULL,
  native_speaker boolean,
  self_reported boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reviewer_dialect_expertise_level_check CHECK (expertise_level IN ('native', 'fluent', 'advanced', 'familiar')),
  CONSTRAINT reviewer_dialect_expertise_reviewer_dialect_unique UNIQUE (reviewer_id, dialect_id)
);

CREATE TABLE public.review_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evaluation_item_id uuid NOT NULL REFERENCES public.evaluation_items(id) ON DELETE RESTRICT,
  reviewer_id uuid NOT NULL REFERENCES public.reviewer_profiles(id) ON DELETE RESTRICT,
  assignment_role text NOT NULL DEFAULT 'reviewer',
  assignment_status text NOT NULL DEFAULT 'active',
  assigned_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  deactivated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT review_assignments_role_check CHECK (assignment_role IN ('reviewer', 'adjudicator')),
  CONSTRAINT review_assignments_status_check CHECK (assignment_status IN ('active', 'completed', 'deactivated')),
  CONSTRAINT review_assignments_timestamp_consistency_check CHECK (
    (assignment_status = 'active' AND completed_at IS NULL AND deactivated_at IS NULL)
    OR (assignment_status = 'completed' AND completed_at IS NOT NULL AND deactivated_at IS NULL)
    OR (assignment_status = 'deactivated' AND completed_at IS NULL AND deactivated_at IS NOT NULL)
  ),
  CONSTRAINT review_assignments_item_reviewer_unique UNIQUE (evaluation_item_id, reviewer_id)
);

CREATE TABLE public.review_annotations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id uuid NOT NULL UNIQUE REFERENCES public.review_assignments(id) ON DELETE RESTRICT,
  annotation_status text NOT NULL DEFAULT 'in_progress',
  primary_decision text,
  reviewer_concept_label text,
  reviewer_definition text,
  reviewer_notes text,
  pipeline_bucket_correct text,
  pipeline_ambiguity_correct text,
  primary_started_at timestamptz NOT NULL DEFAULT now(),
  primary_submitted_at timestamptz,
  pipeline_revealed_at timestamptz,
  submitted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT review_annotations_status_check CHECK (annotation_status IN ('in_progress', 'primary_submitted', 'submitted')),
  CONSTRAINT review_annotations_decision_check CHECK (primary_decision IS NULL OR primary_decision IN ('ACCEPT_SIMPLE', 'ACCEPT_VARIANT', 'SPLIT_SENSES', 'NEEDS_EXPERT')),
  CONSTRAINT review_annotations_bucket_correct_check CHECK (pipeline_bucket_correct IS NULL OR pipeline_bucket_correct IN ('YES', 'NO', 'UNSURE')),
  CONSTRAINT review_annotations_ambiguity_correct_check CHECK (pipeline_ambiguity_correct IS NULL OR pipeline_ambiguity_correct IN ('YES', 'NO', 'UNSURE')),
  CONSTRAINT review_annotations_concept_label_not_blank CHECK (reviewer_concept_label IS NULL OR btrim(reviewer_concept_label) <> ''),
  CONSTRAINT review_annotations_definition_not_blank CHECK (reviewer_definition IS NULL OR btrim(reviewer_definition) <> ''),
  CONSTRAINT review_annotations_stage_consistency_check CHECK (
    (annotation_status = 'in_progress' AND primary_submitted_at IS NULL AND pipeline_revealed_at IS NULL AND submitted_at IS NULL AND pipeline_bucket_correct IS NULL AND pipeline_ambiguity_correct IS NULL)
    OR (annotation_status = 'primary_submitted' AND primary_decision IS NOT NULL AND primary_submitted_at IS NOT NULL AND pipeline_revealed_at IS NOT NULL AND submitted_at IS NULL)
    OR (annotation_status = 'submitted' AND primary_decision IS NOT NULL AND primary_submitted_at IS NOT NULL AND pipeline_revealed_at IS NOT NULL AND submitted_at IS NOT NULL AND pipeline_bucket_correct IS NOT NULL AND pipeline_ambiguity_correct IS NOT NULL)
  )
);

CREATE TABLE public.evaluation_adjudications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evaluation_item_id uuid NOT NULL UNIQUE REFERENCES public.evaluation_items(id) ON DELETE RESTRICT,
  adjudicator_assignment_id uuid NOT NULL UNIQUE REFERENCES public.review_assignments(id) ON DELETE RESTRICT,
  adjudication_status text NOT NULL DEFAULT 'in_progress',
  adjudicated_decision text,
  adjudicated_concept_label text,
  adjudicated_definition text,
  adjudicator_notes text,
  started_at timestamptz NOT NULL DEFAULT now(),
  submitted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT evaluation_adjudications_status_check CHECK (adjudication_status IN ('in_progress', 'submitted')),
  CONSTRAINT evaluation_adjudications_decision_check CHECK (adjudicated_decision IS NULL OR adjudicated_decision IN ('ACCEPT_SIMPLE', 'ACCEPT_VARIANT', 'SPLIT_SENSES', 'NEEDS_EXPERT', 'UNRESOLVED')),
  CONSTRAINT evaluation_adjudications_label_not_blank CHECK (adjudicated_concept_label IS NULL OR btrim(adjudicated_concept_label) <> ''),
  CONSTRAINT evaluation_adjudications_definition_not_blank CHECK (adjudicated_definition IS NULL OR btrim(adjudicated_definition) <> ''),
  CONSTRAINT evaluation_adjudications_submission_check CHECK (
    (adjudication_status = 'in_progress' AND submitted_at IS NULL)
    OR (adjudication_status = 'submitted' AND adjudicated_decision IS NOT NULL AND submitted_at IS NOT NULL)
  )
);

CREATE INDEX evaluation_studies_dialect_status_idx ON public.evaluation_studies (dialect_id, study_status);
CREATE INDEX evaluation_items_study_idx ON public.evaluation_items (study_id);
CREATE INDEX evaluation_items_dictionary_entry_idx ON public.evaluation_items (dictionary_entry_id);
CREATE INDEX reviewer_profiles_auth_user_idx ON public.reviewer_profiles (auth_user_id);
CREATE INDEX reviewer_dialect_expertise_dialect_idx ON public.reviewer_dialect_expertise (dialect_id, expertise_level);
CREATE INDEX review_assignments_reviewer_status_idx ON public.review_assignments (reviewer_id, assignment_status);
CREATE INDEX review_assignments_item_role_idx ON public.review_assignments (evaluation_item_id, assignment_role);
CREATE INDEX review_annotations_status_idx ON public.review_annotations (annotation_status);
CREATE INDEX evaluation_adjudications_assignment_idx ON public.evaluation_adjudications (adjudicator_assignment_id);

-- Freeze study evidence after activation and maintain study lifecycle timestamps.
CREATE FUNCTION public.tafsiri_guard_evaluation_study()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := now();
    IF OLD.study_status <> 'draft' THEN
      IF NEW.study_key IS DISTINCT FROM OLD.study_key OR NEW.dialect_id IS DISTINCT FROM OLD.dialect_id
         OR NEW.pipeline_version IS DISTINCT FROM OLD.pipeline_version OR NEW.evidence_schema_version IS DISTINCT FROM OLD.evidence_schema_version
         OR NEW.configuration_hash IS DISTINCT FROM OLD.configuration_hash OR NEW.source_artifact_hash IS DISTINCT FROM OLD.source_artifact_hash THEN
        RAISE EXCEPTION 'frozen study evidence metadata cannot be changed';
      END IF;
    END IF;
    IF NEW.study_status IS DISTINCT FROM OLD.study_status THEN
      IF OLD.study_status = 'draft' AND NEW.study_status = 'active' THEN
        IF btrim(NEW.study_key) = '' OR btrim(NEW.title) = '' OR btrim(NEW.description) = '' OR btrim(NEW.pipeline_version) = ''
           OR btrim(NEW.evidence_schema_version) = '' OR btrim(NEW.configuration_hash) = '' OR btrim(NEW.source_artifact_hash) = '' THEN
          RAISE EXCEPTION 'required study metadata is incomplete';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM public.evaluation_items i WHERE i.study_id = OLD.id)
           OR EXISTS (SELECT 1 FROM public.evaluation_items i LEFT JOIN public.evaluation_item_pipeline_snapshots p ON p.evaluation_item_id = i.id WHERE i.study_id = OLD.id AND p.evaluation_item_id IS NULL) THEN
          RAISE EXCEPTION 'study activation requires at least one item and a pipeline snapshot for every item';
        END IF;
        NEW.activated_at := now(); NEW.closed_at := NULL; NEW.archived_at := NULL;
      ELSIF OLD.study_status = 'active' AND NEW.study_status = 'closed' THEN
        NEW.activated_at := OLD.activated_at; NEW.closed_at := now(); NEW.archived_at := NULL;
      ELSIF OLD.study_status IN ('active', 'closed') AND NEW.study_status = 'archived' THEN
        NEW.activated_at := OLD.activated_at; NEW.closed_at := OLD.closed_at; NEW.archived_at := now();
      ELSE
        RAISE EXCEPTION 'invalid study status transition from % to %', OLD.study_status, NEW.study_status;
      END IF;
    ELSIF NEW.activated_at IS DISTINCT FROM OLD.activated_at OR NEW.closed_at IS DISTINCT FROM OLD.closed_at OR NEW.archived_at IS DISTINCT FROM OLD.archived_at THEN
      RAISE EXCEPTION 'study lifecycle timestamps are server-controlled';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.tafsiri_guard_evaluation_item()
RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
DECLARE v_status text;
BEGIN
  SELECT study_status INTO v_status FROM public.evaluation_studies WHERE id = COALESCE(NEW.study_id, OLD.study_id);
  IF v_status IS DISTINCT FROM 'draft' THEN RAISE EXCEPTION 'evaluation items are immutable outside draft studies'; END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.tafsiri_guard_pipeline_snapshot()
RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
DECLARE v_status text;
BEGIN
  SELECT s.study_status INTO v_status FROM public.evaluation_items i JOIN public.evaluation_studies s ON s.id=i.study_id WHERE i.id=COALESCE(NEW.evaluation_item_id, OLD.evaluation_item_id);
  IF v_status IS DISTINCT FROM 'draft' THEN RAISE EXCEPTION 'pipeline snapshots are immutable outside draft studies'; END IF;
  RETURN NEW;
END;
$$;

CREATE FUNCTION public.tafsiri_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $$ BEGIN NEW.updated_at := now(); RETURN NEW; END; $$;

CREATE FUNCTION public.tafsiri_guard_review_annotation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public AS $$
DECLARE v_assignment public.review_assignments%ROWTYPE;
BEGIN
  SELECT * INTO v_assignment FROM public.review_assignments WHERE id=NEW.assignment_id FOR UPDATE;
  IF NOT FOUND OR v_assignment.assignment_role <> 'reviewer' THEN RAISE EXCEPTION 'annotation requires a reviewer assignment'; END IF;
  IF TG_OP='INSERT' THEN
    IF NEW.annotation_status <> 'in_progress' OR NEW.primary_submitted_at IS NOT NULL OR NEW.pipeline_revealed_at IS NOT NULL OR NEW.submitted_at IS NOT NULL THEN
      RAISE EXCEPTION 'new annotations must begin in progress with server-controlled timestamps';
    END IF;
    IF v_assignment.assignment_status <> 'active' THEN RAISE EXCEPTION 'annotation requires an active assignment'; END IF;
    NEW.primary_started_at:=now(); NEW.created_at:=now(); NEW.updated_at:=now();
    RETURN NEW;
  END IF;
  IF NEW.assignment_id IS DISTINCT FROM OLD.assignment_id THEN RAISE EXCEPTION 'annotation assignment is immutable'; END IF;
  IF OLD.annotation_status='submitted' THEN RAISE EXCEPTION 'submitted annotations are immutable'; END IF;
  IF NEW.primary_started_at IS DISTINCT FROM OLD.primary_started_at OR NEW.primary_submitted_at IS DISTINCT FROM OLD.primary_submitted_at
     OR NEW.pipeline_revealed_at IS DISTINCT FROM OLD.pipeline_revealed_at OR NEW.submitted_at IS DISTINCT FROM OLD.submitted_at THEN
    RAISE EXCEPTION 'annotation timestamps are server-controlled';
  END IF;
  IF OLD.annotation_status='in_progress' THEN
    IF NEW.pipeline_bucket_correct IS NOT NULL OR NEW.pipeline_ambiguity_correct IS NOT NULL THEN RAISE EXCEPTION 'Stage B fields are unavailable before primary submission'; END IF;
    IF NEW.annotation_status='primary_submitted' THEN
      IF NEW.primary_decision IS NULL THEN RAISE EXCEPTION 'primary decision is required'; END IF;
      IF v_assignment.assignment_status <> 'active' THEN RAISE EXCEPTION 'submission requires an active assignment'; END IF;
      NEW.primary_submitted_at:=now(); NEW.pipeline_revealed_at:=now();
    ELSIF NEW.annotation_status <> 'in_progress' THEN RAISE EXCEPTION 'invalid annotation status transition'; END IF;
  ELSIF OLD.annotation_status='primary_submitted' THEN
    IF NEW.primary_decision IS DISTINCT FROM OLD.primary_decision OR NEW.reviewer_concept_label IS DISTINCT FROM OLD.reviewer_concept_label
       OR NEW.reviewer_definition IS DISTINCT FROM OLD.reviewer_definition OR NEW.reviewer_notes IS DISTINCT FROM OLD.reviewer_notes THEN
      RAISE EXCEPTION 'primary fields are frozen after primary submission';
    END IF;
    IF NEW.annotation_status='submitted' THEN
      IF NEW.pipeline_bucket_correct IS NULL OR NEW.pipeline_ambiguity_correct IS NULL THEN RAISE EXCEPTION 'Stage B assessments are required'; END IF;
      IF v_assignment.assignment_status <> 'active' THEN RAISE EXCEPTION 'submission requires an active assignment'; END IF;
      NEW.submitted_at:=now();
      UPDATE public.review_assignments SET assignment_status='completed', completed_at=now(), deactivated_at=NULL WHERE id=v_assignment.id AND assignment_role='reviewer' AND assignment_status='active';
      IF NOT FOUND THEN RAISE EXCEPTION 'reviewer assignment could not be completed'; END IF;
    ELSIF NEW.annotation_status <> 'primary_submitted' THEN RAISE EXCEPTION 'invalid annotation status transition'; END IF;
  END IF;
  NEW.updated_at:=now(); RETURN NEW;
END;
$$;

CREATE FUNCTION public.tafsiri_guard_adjudication()
RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, public AS $$
DECLARE v_assignment public.review_assignments%ROWTYPE;
BEGIN
  SELECT * INTO v_assignment FROM public.review_assignments WHERE id=NEW.adjudicator_assignment_id;
  IF NOT FOUND OR v_assignment.assignment_role <> 'adjudicator' OR v_assignment.evaluation_item_id <> NEW.evaluation_item_id OR v_assignment.assignment_status <> 'active' THEN
    RAISE EXCEPTION 'adjudication requires the active adjudicator assignment for this item';
  END IF;
  IF TG_OP='INSERT' THEN
    IF NEW.adjudication_status <> 'in_progress' OR NEW.submitted_at IS NOT NULL THEN RAISE EXCEPTION 'new adjudications must begin in progress'; END IF;
    NEW.started_at:=now(); NEW.created_at:=now(); NEW.updated_at:=now(); RETURN NEW;
  END IF;
  IF NEW.evaluation_item_id IS DISTINCT FROM OLD.evaluation_item_id OR NEW.adjudicator_assignment_id IS DISTINCT FROM OLD.adjudicator_assignment_id THEN RAISE EXCEPTION 'adjudication association is immutable'; END IF;
  IF OLD.adjudication_status='submitted' THEN RAISE EXCEPTION 'submitted adjudications are immutable'; END IF;
  IF NEW.started_at IS DISTINCT FROM OLD.started_at OR NEW.submitted_at IS DISTINCT FROM OLD.submitted_at THEN RAISE EXCEPTION 'adjudication timestamps are server-controlled'; END IF;
  IF NEW.adjudication_status='submitted' THEN
    IF NEW.adjudicated_decision IS NULL THEN RAISE EXCEPTION 'adjudicated decision is required'; END IF;
    NEW.submitted_at:=now();
  ELSIF NEW.adjudication_status <> 'in_progress' THEN RAISE EXCEPTION 'invalid adjudication status transition'; END IF;
  NEW.updated_at:=now(); RETURN NEW;
END;
$$;

CREATE TRIGGER evaluation_studies_guard BEFORE UPDATE ON public.evaluation_studies FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_evaluation_study();
CREATE TRIGGER evaluation_items_guard BEFORE INSERT OR UPDATE OR DELETE ON public.evaluation_items FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_evaluation_item();
CREATE TRIGGER evaluation_pipeline_snapshots_guard BEFORE INSERT OR UPDATE OR DELETE ON public.evaluation_item_pipeline_snapshots FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_pipeline_snapshot();
CREATE TRIGGER reviewer_profiles_updated_at BEFORE UPDATE ON public.reviewer_profiles FOR EACH ROW EXECUTE FUNCTION public.tafsiri_touch_updated_at();
CREATE TRIGGER reviewer_dialect_expertise_updated_at BEFORE UPDATE ON public.reviewer_dialect_expertise FOR EACH ROW EXECUTE FUNCTION public.tafsiri_touch_updated_at();
CREATE TRIGGER review_annotations_guard BEFORE INSERT OR UPDATE ON public.review_annotations FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_review_annotation();
CREATE TRIGGER evaluation_adjudications_guard BEFORE INSERT OR UPDATE ON public.evaluation_adjudications FOR EACH ROW EXECUTE FUNCTION public.tafsiri_guard_adjudication();

-- Trigger functions are not client APIs. In particular, the annotation guard is
-- SECURITY DEFINER solely so its final-submit branch can transactionally complete
-- the associated reviewer assignment, a table reviewers cannot update directly.
REVOKE ALL ON FUNCTION public.tafsiri_guard_evaluation_study() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tafsiri_guard_evaluation_item() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tafsiri_guard_pipeline_snapshot() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tafsiri_touch_updated_at() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tafsiri_guard_review_annotation() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tafsiri_guard_adjudication() FROM PUBLIC;

-- Narrow SECURITY DEFINER predicates avoid circular RLS evaluation. They return
-- only access decisions, pin search_path, and never expose row contents.
CREATE FUNCTION public.tafsiri_current_reviewer_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public AS $$ SELECT id FROM public.reviewer_profiles WHERE auth_user_id=auth.uid() AND is_active LIMIT 1 $$;
CREATE FUNCTION public.tafsiri_has_item_assignment(p_item_id uuid, p_role text DEFAULT NULL)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public AS $$ SELECT EXISTS(SELECT 1 FROM public.review_assignments a WHERE a.evaluation_item_id=p_item_id AND a.reviewer_id=public.tafsiri_current_reviewer_id() AND a.assignment_status IN ('active','completed') AND (p_role IS NULL OR a.assignment_role=p_role)) $$;
CREATE FUNCTION public.tafsiri_owns_assignment(p_assignment_id uuid, p_role text DEFAULT NULL)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public AS $$ SELECT EXISTS(SELECT 1 FROM public.review_assignments a WHERE a.id=p_assignment_id AND a.reviewer_id=public.tafsiri_current_reviewer_id() AND a.assignment_status IN ('active','completed') AND (p_role IS NULL OR a.assignment_role=p_role)) $$;
CREATE FUNCTION public.tafsiri_reviewer_pipeline_access(p_item_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public AS $$ SELECT EXISTS(SELECT 1 FROM public.review_assignments a JOIN public.review_annotations n ON n.assignment_id=a.id WHERE a.evaluation_item_id=p_item_id AND a.reviewer_id=public.tafsiri_current_reviewer_id() AND a.assignment_role='reviewer' AND n.primary_submitted_at IS NOT NULL) $$;
CREATE FUNCTION public.tafsiri_adjudicator_can_read_annotation(p_assignment_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public AS $$ SELECT EXISTS(SELECT 1 FROM public.review_assignments reviewed JOIN public.review_annotations n ON n.assignment_id=reviewed.id JOIN public.review_assignments adjudicator ON adjudicator.evaluation_item_id=reviewed.evaluation_item_id WHERE reviewed.id=p_assignment_id AND n.annotation_status='submitted' AND adjudicator.reviewer_id=public.tafsiri_current_reviewer_id() AND adjudicator.assignment_role='adjudicator' AND adjudicator.assignment_status IN ('active','completed')) $$;

REVOKE ALL ON FUNCTION public.tafsiri_current_reviewer_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tafsiri_has_item_assignment(uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tafsiri_owns_assignment(uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tafsiri_reviewer_pipeline_access(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tafsiri_adjudicator_can_read_annotation(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.tafsiri_current_reviewer_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.tafsiri_has_item_assignment(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.tafsiri_owns_assignment(uuid,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.tafsiri_reviewer_pipeline_access(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.tafsiri_adjudicator_can_read_annotation(uuid) TO authenticated, service_role;

ALTER TABLE public.evaluation_studies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluation_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluation_item_pipeline_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviewer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviewer_dialect_expertise ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_annotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluation_adjudications ENABLE ROW LEVEL SECURITY;

CREATE POLICY evaluation_studies_assigned_read ON public.evaluation_studies FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.evaluation_items i WHERE i.study_id=id AND public.tafsiri_has_item_assignment(i.id,NULL)));
CREATE POLICY evaluation_items_assigned_read ON public.evaluation_items FOR SELECT TO authenticated USING (public.tafsiri_has_item_assignment(id,NULL));
CREATE POLICY evaluation_pipeline_staged_read ON public.evaluation_item_pipeline_snapshots FOR SELECT TO authenticated USING (public.tafsiri_has_item_assignment(evaluation_item_id,'adjudicator') OR public.tafsiri_reviewer_pipeline_access(evaluation_item_id));
CREATE POLICY reviewer_profiles_own_read ON public.reviewer_profiles FOR SELECT TO authenticated USING (auth_user_id=auth.uid());
CREATE POLICY reviewer_expertise_own_read ON public.reviewer_dialect_expertise FOR SELECT TO authenticated USING (reviewer_id=public.tafsiri_current_reviewer_id());
CREATE POLICY review_assignments_own_read ON public.review_assignments FOR SELECT TO authenticated USING (reviewer_id=public.tafsiri_current_reviewer_id());
CREATE POLICY review_annotations_permitted_read ON public.review_annotations FOR SELECT TO authenticated USING (public.tafsiri_owns_assignment(assignment_id,'reviewer') OR public.tafsiri_adjudicator_can_read_annotation(assignment_id));
CREATE POLICY review_annotations_own_insert ON public.review_annotations FOR INSERT TO authenticated WITH CHECK (public.tafsiri_owns_assignment(assignment_id,'reviewer'));
CREATE POLICY review_annotations_own_update ON public.review_annotations FOR UPDATE TO authenticated USING (public.tafsiri_owns_assignment(assignment_id,'reviewer')) WITH CHECK (public.tafsiri_owns_assignment(assignment_id,'reviewer'));
CREATE POLICY adjudications_assigned_read ON public.evaluation_adjudications FOR SELECT TO authenticated USING (public.tafsiri_owns_assignment(adjudicator_assignment_id,'adjudicator'));
CREATE POLICY adjudications_assigned_insert ON public.evaluation_adjudications FOR INSERT TO authenticated WITH CHECK (public.tafsiri_owns_assignment(adjudicator_assignment_id,'adjudicator'));
CREATE POLICY adjudications_assigned_update ON public.evaluation_adjudications FOR UPDATE TO authenticated USING (public.tafsiri_owns_assignment(adjudicator_assignment_id,'adjudicator')) WITH CHECK (public.tafsiri_owns_assignment(adjudicator_assignment_id,'adjudicator'));

REVOKE ALL PRIVILEGES ON TABLE public.evaluation_studies, public.evaluation_items, public.evaluation_item_pipeline_snapshots, public.reviewer_profiles, public.reviewer_dialect_expertise, public.review_assignments, public.review_annotations, public.evaluation_adjudications FROM anon, authenticated;
GRANT SELECT ON TABLE public.evaluation_studies, public.evaluation_items, public.evaluation_item_pipeline_snapshots, public.reviewer_profiles, public.reviewer_dialect_expertise, public.review_assignments TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.review_annotations, public.evaluation_adjudications TO authenticated;
GRANT ALL PRIVILEGES ON TABLE public.evaluation_studies, public.evaluation_items, public.evaluation_item_pipeline_snapshots, public.reviewer_profiles, public.reviewer_dialect_expertise, public.review_assignments, public.review_annotations, public.evaluation_adjudications TO service_role;
