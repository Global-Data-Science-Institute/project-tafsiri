-- Project Tafsiri Migration 004: correct the assigned-study RLS correlation.

DROP POLICY evaluation_studies_assigned_read
  ON public.evaluation_studies;

CREATE POLICY evaluation_studies_assigned_read
  ON public.evaluation_studies
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.evaluation_items AS assigned_item
      WHERE assigned_item.study_id = public.evaluation_studies.id
        AND public.tafsiri_has_item_assignment(assigned_item.id, NULL)
    )
  );
