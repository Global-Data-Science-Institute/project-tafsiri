-- Additive security change. No records, historical migrations or research
-- ownership are rewritten. See remediation-001.md for the consumer inventory.
BEGIN;
DO $$
DECLARE relation text;
BEGIN
  FOREACH relation IN ARRAY ARRAY[
    'bible_books','bible_english_verses','bible_luhya_verses','dialect_aliases',
    'knowledge_base_entries','luhya_dict','luhya_dictionary','luhya_kb',
    'luhya_proverbs','pronoun_examples','pronouns','proverb_contributors',
    'proverbs','submission_rate_limits','suspicious_activity','translations',
    'submissions','contributors'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',relation);
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon, authenticated',relation);
  END LOOP;
END $$;
DROP POLICY "Allow insert submissions" ON public.submissions;
DROP POLICY "Allow read submissions" ON public.submissions;
REVOKE ALL ON SEQUENCE public.luhya_dict_id_seq,public.luhya_dictionary_id_seq FROM PUBLIC,anon,authenticated;

-- Registry-linked linguistic reference rows remain read-only. Raw imported
-- corpora have no publication/rights predicate and stay privileged-only.
GRANT SELECT ON public.dialect_aliases,public.pronouns,public.pronoun_examples TO anon,authenticated;
CREATE POLICY reference_alias_read ON public.dialect_aliases FOR SELECT TO anon,authenticated
 USING (EXISTS (SELECT 1 FROM public.dialects d WHERE d.id=dialect_id));
CREATE POLICY reference_pronoun_read ON public.pronouns FOR SELECT TO anon,authenticated
 USING (EXISTS (SELECT 1 FROM public.dialects d WHERE d.id=dialect_id));
CREATE POLICY reference_pronoun_example_read ON public.pronoun_examples FOR SELECT TO anon,authenticated
 USING (EXISTS (SELECT 1 FROM public.pronouns p WHERE p.id=pronoun_id));

-- Existing explicit public read policies remain; remove unnecessary write ACLs.
REVOKE INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER ON
 public.languages,public.dialects,public.cultural_contexts,public.dialect_variants,
 public.dictionary_entries,public.grammar_patterns,public.prompts,
 public.pronunciations,public.usage_examples,public.verb_forms,public.word_relationships
 FROM PUBLIC,anon,authenticated;
-- Do not disclose speaker identity through SELECT *; views use these columns.
REVOKE SELECT ON public.pronunciations FROM PUBLIC,anon,authenticated;
GRANT SELECT(id,word_id,audio_file_url,dialect_id,phonetic_transcription,quality_rating,created_at)
 ON public.pronunciations TO anon,authenticated;

ALTER VIEW public.word_details SET (security_invoker=true);
ALTER VIEW public.cultural_terms SET (security_invoker=true);
ALTER VIEW public.language_words SET (security_invoker=true);
ALTER VIEW public.pronoun_comparison SET (security_invoker=true);
ALTER VIEW public.pronoun_details SET (security_invoker=true);
ALTER VIEW public.dialect_comparisons SET (security_invoker=true);
REVOKE ALL ON public.word_details,public.cultural_terms,public.language_words,
 public.pronoun_comparison,public.pronoun_details,public.dialect_comparisons FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.word_details,public.cultural_terms,public.language_words,
 public.pronoun_comparison,public.pronoun_details,public.dialect_comparisons TO anon,authenticated;

-- Own-user contribution intake remains untrusted and cannot set moderator fields.
REVOKE ALL ON public.user_contributions FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.user_contributions TO authenticated;
GRANT INSERT(user_id,contribution_type,target_id,content) ON public.user_contributions TO authenticated;

-- Reviewer predicates retain authenticated use; triggers do not need client EXECUTE.
REVOKE EXECUTE ON FUNCTION public.tafsiri_current_reviewer_id(),
 public.tafsiri_has_item_assignment(uuid,text),public.tafsiri_owns_assignment(uuid,text),
 public.tafsiri_reviewer_pipeline_access(uuid),public.tafsiri_adjudicator_can_read_annotation(uuid)
 FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.tafsiri_current_reviewer_id(),
 public.tafsiri_has_item_assignment(uuid,text),public.tafsiri_owns_assignment(uuid,text),
 public.tafsiri_reviewer_pipeline_access(uuid),public.tafsiri_adjudicator_can_read_annotation(uuid)
 TO authenticated;
REVOKE EXECUTE ON FUNCTION public.tafsiri_guard_review_annotation(),
 public.tafsiri_guard_reviewer_study_participation() FROM PUBLIC,anon,authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
