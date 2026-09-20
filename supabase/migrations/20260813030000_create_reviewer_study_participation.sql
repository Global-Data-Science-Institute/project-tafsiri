-- Project Tafsiri Migration 005: study-specific reviewer participation.
-- Schema/security only. This migration intentionally inserts no data.

CREATE TABLE public.reviewer_study_participation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reviewer_id uuid NOT NULL REFERENCES public.reviewer_profiles(id) ON DELETE RESTRICT,
  study_id uuid NOT NULL REFERENCES public.evaluation_studies(id) ON DELETE RESTRICT,
  participation_status text NOT NULL DEFAULT 'onboarding',
  participation_information_version text,
  participation_acknowledged_at timestamptz,
  onboarding_completed_at timestamptz,
  withdrawn_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT reviewer_study_participation_reviewer_study_unique
    UNIQUE (reviewer_id, study_id),
  CONSTRAINT reviewer_study_participation_status_check CHECK (
    participation_status IN ('onboarding', 'active', 'withdrawn', 'completed')
  ),
  CONSTRAINT reviewer_study_participation_acknowledgment_check CHECK (
    (
      participation_information_version IS NULL
      AND participation_acknowledged_at IS NULL
    )
    OR
    (
      participation_information_version IS NOT NULL
      AND btrim(participation_information_version) <> ''
      AND participation_acknowledged_at IS NOT NULL
    )
  ),
  CONSTRAINT reviewer_study_participation_status_timestamps_check CHECK (
    (participation_status = 'onboarding' AND withdrawn_at IS NULL)
    OR (
      participation_status = 'active'
      AND participation_acknowledged_at IS NOT NULL
      AND onboarding_completed_at IS NOT NULL
      AND withdrawn_at IS NULL
    )
    OR (
      participation_status = 'withdrawn'
      AND withdrawn_at IS NOT NULL
    )
    OR (
      participation_status = 'completed'
      AND participation_acknowledged_at IS NOT NULL
      AND onboarding_completed_at IS NOT NULL
      AND withdrawn_at IS NULL
    )
  )
);

-- Supports study roster/status queries. The UNIQUE constraint already indexes
-- reviewer_id first, so no redundant reviewer-only index is added.
CREATE INDEX reviewer_study_participation_study_status_idx
  ON public.reviewer_study_participation (study_id, participation_status);

-- participation_information_version is the trusted workflow's acknowledgment
-- signal. The trigger supplies the timestamp. onboarding_completed_at is also
-- accepted only as a transition signal and replaced with server now().
CREATE FUNCTION public.tafsiri_guard_reviewer_study_participation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.participation_status <> 'onboarding'
       OR NEW.participation_information_version IS NOT NULL
       OR NEW.participation_acknowledged_at IS NOT NULL
       OR NEW.onboarding_completed_at IS NOT NULL
       OR NEW.withdrawn_at IS NOT NULL THEN
      RAISE EXCEPTION 'new participation must begin onboarding without workflow timestamps';
    END IF;
    NEW.created_at := now();
    NEW.updated_at := now();
    RETURN NEW;
  END IF;

  IF NEW.reviewer_id IS DISTINCT FROM OLD.reviewer_id
     OR NEW.study_id IS DISTINCT FROM OLD.study_id THEN
    RAISE EXCEPTION 'participation reviewer and study are immutable';
  END IF;

  IF OLD.participation_status IN ('withdrawn', 'completed') THEN
    RAISE EXCEPTION 'withdrawn and completed participation records are immutable';
  END IF;

  IF NEW.participation_acknowledged_at IS DISTINCT FROM OLD.participation_acknowledged_at THEN
    RAISE EXCEPTION 'participation acknowledgment timestamp is server-controlled';
  END IF;
  IF NEW.onboarding_completed_at IS DISTINCT FROM OLD.onboarding_completed_at
     AND NOT (OLD.onboarding_completed_at IS NULL AND NEW.onboarding_completed_at IS NOT NULL) THEN
    RAISE EXCEPTION 'onboarding completion timestamp is server-controlled';
  END IF;
  IF NEW.withdrawn_at IS DISTINCT FROM OLD.withdrawn_at THEN
    RAISE EXCEPTION 'withdrawal timestamp is server-controlled';
  END IF;

  IF NEW.participation_information_version IS DISTINCT FROM OLD.participation_information_version THEN
    IF OLD.participation_information_version IS NOT NULL
       OR OLD.participation_acknowledged_at IS NOT NULL
       OR NEW.participation_information_version IS NULL
       OR btrim(NEW.participation_information_version) = '' THEN
      RAISE EXCEPTION 'participation acknowledgment is immutable and requires a nonblank version';
    END IF;
    NEW.participation_acknowledged_at := now();
  END IF;

  IF OLD.onboarding_completed_at IS NULL AND NEW.onboarding_completed_at IS NOT NULL THEN
    IF NEW.participation_acknowledged_at IS NULL THEN
      RAISE EXCEPTION 'participation acknowledgment is required before onboarding completion';
    END IF;
    NEW.onboarding_completed_at := now();
  END IF;

  IF NEW.participation_status IS DISTINCT FROM OLD.participation_status THEN
    IF OLD.participation_status = 'onboarding' AND NEW.participation_status = 'active' THEN
      IF NEW.participation_acknowledged_at IS NULL OR NEW.onboarding_completed_at IS NULL THEN
        RAISE EXCEPTION 'activation requires acknowledged and completed onboarding';
      END IF;
    ELSIF OLD.participation_status IN ('onboarding', 'active')
          AND NEW.participation_status = 'withdrawn' THEN
      NEW.withdrawn_at := now();
      UPDATE public.review_assignments AS assignment
      SET assignment_status = 'deactivated',
          completed_at = NULL,
          deactivated_at = now()
      FROM public.evaluation_items AS item
      WHERE assignment.evaluation_item_id = item.id
        AND assignment.reviewer_id = OLD.reviewer_id
        AND assignment.assignment_role = 'reviewer'
        AND assignment.assignment_status = 'active'
        AND item.study_id = OLD.study_id;
    ELSIF OLD.participation_status = 'active'
          AND NEW.participation_status = 'completed' THEN
      IF EXISTS (
        SELECT 1
        FROM public.review_assignments AS assignment
        JOIN public.evaluation_items AS item
          ON item.id = assignment.evaluation_item_id
        WHERE assignment.reviewer_id = OLD.reviewer_id
          AND assignment.assignment_role = 'reviewer'
          AND assignment.assignment_status = 'active'
          AND item.study_id = OLD.study_id
      ) OR NOT EXISTS (
        SELECT 1
        FROM public.review_assignments AS assignment
        JOIN public.evaluation_items AS item
          ON item.id = assignment.evaluation_item_id
        WHERE assignment.reviewer_id = OLD.reviewer_id
          AND assignment.assignment_role = 'reviewer'
          AND assignment.assignment_status = 'completed'
          AND item.study_id = OLD.study_id
      ) THEN
        RAISE EXCEPTION 'completion requires no active reviewer assignments and at least one completed assignment';
      END IF;
    ELSE
      RAISE EXCEPTION 'invalid participation transition from % to %',
        OLD.participation_status, NEW.participation_status;
    END IF;
  END IF;

  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Applies only when an assignment is or becomes a reviewer assignment.
-- Adjudicator assignments retain Migration 003/004 behavior.
CREATE FUNCTION public.tafsiri_guard_reviewer_assignment_eligibility()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.assignment_role = 'reviewer' AND NOT EXISTS (
    SELECT 1
    FROM public.reviewer_profiles AS profile
    JOIN public.evaluation_items AS item
      ON item.id = NEW.evaluation_item_id
    JOIN public.evaluation_studies AS study
      ON study.id = item.study_id
    JOIN public.reviewer_study_participation AS participation
      ON participation.reviewer_id = profile.id
     AND participation.study_id = study.id
     AND participation.participation_status = 'active'
    JOIN public.reviewer_dialect_expertise AS expertise
      ON expertise.reviewer_id = profile.id
     AND expertise.dialect_id = study.dialect_id
    WHERE profile.id = NEW.reviewer_id
      AND profile.is_active
  ) THEN
    RAISE EXCEPTION 'reviewer assignment requires active profile, active study participation, and matching dialect expertise';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER reviewer_study_participation_guard
  BEFORE INSERT OR UPDATE
  ON public.reviewer_study_participation
  FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_guard_reviewer_study_participation();

CREATE TRIGGER review_assignments_eligibility_guard
  BEFORE INSERT OR UPDATE OF reviewer_id, evaluation_item_id, assignment_role
  ON public.review_assignments
  FOR EACH ROW
  EXECUTE FUNCTION public.tafsiri_guard_reviewer_assignment_eligibility();

REVOKE ALL ON FUNCTION public.tafsiri_guard_reviewer_study_participation() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tafsiri_guard_reviewer_assignment_eligibility() FROM PUBLIC;

ALTER TABLE public.reviewer_study_participation ENABLE ROW LEVEL SECURITY;

CREATE POLICY reviewer_study_participation_own_read
  ON public.reviewer_study_participation
  FOR SELECT
  TO authenticated
  USING (reviewer_id = public.tafsiri_current_reviewer_id());

REVOKE ALL PRIVILEGES ON TABLE public.reviewer_study_participation
  FROM anon, authenticated;

GRANT SELECT ON TABLE public.reviewer_study_participation
  TO authenticated;

GRANT ALL PRIVILEGES ON TABLE public.reviewer_study_participation
  TO service_role;
