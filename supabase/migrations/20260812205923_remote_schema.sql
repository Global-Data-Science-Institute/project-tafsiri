-- Migration unit 1: schema_changes
-- Transaction mode: transactional
-- Boundary reason: default

DROP EXTENSION pg_net;

CREATE EXTENSION vector WITH SCHEMA public;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO anon;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO authenticated;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT DELETE, INSERT, SELECT, UPDATE ON TABLES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT, USAGE ON SEQUENCES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON ROUTINES TO service_role;

CREATE SEQUENCE public.luhya_dict_id_seq;

CREATE SEQUENCE public.luhya_dictionary_id_seq;

CREATE TABLE public.bible_books (
  id           uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  name_english text                        NOT NULL,
  name_luhya   text,
  book_number  integer                     NOT NULL,
  short_name   text                        NOT NULL,
  created_at   timestamp without time zone DEFAULT now()
);

ALTER TABLE public.bible_books
  ADD CONSTRAINT bible_books_pkey PRIMARY KEY (id);

GRANT ALL ON public.bible_books TO anon;

GRANT ALL ON public.bible_books TO authenticated;

GRANT ALL ON public.bible_books TO service_role;

CREATE TABLE public.bible_english_verses (
  id      uuid    DEFAULT extensions.uuid_generate_v4() NOT NULL,
  book_id uuid,
  chapter integer NOT NULL,
  verse   integer NOT NULL,
  text    text    NOT NULL
);

ALTER TABLE public.bible_english_verses
  ADD CONSTRAINT bible_english_verses_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.bible_books(id);

ALTER TABLE public.bible_english_verses
  ADD CONSTRAINT bible_english_verses_pkey PRIMARY KEY (id);

ALTER TABLE public.bible_english_verses
  ADD CONSTRAINT english_verse_unique UNIQUE (book_id, chapter, verse);

GRANT ALL ON public.bible_english_verses TO anon;

GRANT ALL ON public.bible_english_verses TO authenticated;

GRANT ALL ON public.bible_english_verses TO service_role;

CREATE TABLE public.bible_luhya_verses (
  id               uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  english_verse_id uuid                        NOT NULL,
  dialect_id       uuid                        NOT NULL,
  text             text                        NOT NULL,
  quality_score    numeric(3,2),
  is_validated     boolean                     DEFAULT false,
  notes            text,
  created_at       timestamp without time zone DEFAULT now()
);

ALTER TABLE public.bible_luhya_verses
  ADD CONSTRAINT bible_luhya_verses_english_verse_id_fkey FOREIGN KEY (english_verse_id) REFERENCES public.bible_english_verses(id);

ALTER TABLE public.bible_luhya_verses
  ADD CONSTRAINT bible_luhya_verses_pkey PRIMARY KEY (id);

ALTER TABLE public.bible_luhya_verses
  ADD CONSTRAINT luhya_verse_unique UNIQUE (english_verse_id, dialect_id);

GRANT ALL ON public.bible_luhya_verses TO anon;

GRANT ALL ON public.bible_luhya_verses TO authenticated;

GRANT ALL ON public.bible_luhya_verses TO service_role;

CREATE INDEX idx_luhya_verse_dialect ON public.bible_luhya_verses (dialect_id);

CREATE TABLE public.contributors (
  id         uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  name       text,
  email      text,
  created_at timestamp without time zone DEFAULT now()
);

ALTER TABLE public.contributors
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.contributors
  ADD CONSTRAINT contributors_pkey PRIMARY KEY (id);

GRANT ALL ON public.contributors TO anon;

GRANT ALL ON public.contributors TO authenticated;

GRANT ALL ON public.contributors TO service_role;

CREATE TABLE public.cultural_contexts (
  id                    uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  context_name          text                        NOT NULL,
  description           text,
  related_words         uuid[],
  cultural_significance text,
  dialect_id            uuid,
  created_at            timestamp without time zone DEFAULT now()
);

ALTER TABLE public.cultural_contexts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cultural_contexts
  ADD CONSTRAINT cultural_contexts_pkey PRIMARY KEY (id);

GRANT ALL ON public.cultural_contexts TO anon;

GRANT ALL ON public.cultural_contexts TO authenticated;

GRANT ALL ON public.cultural_contexts TO service_role;

CREATE POLICY "Public read access" ON public.cultural_contexts
  FOR SELECT
  USING (true);

CREATE TABLE public.dialect_aliases (
  id         uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
  name       text NOT NULL,
  dialect_id uuid NOT NULL
);

ALTER TABLE public.dialect_aliases
  ADD CONSTRAINT dialect_aliases_name_key UNIQUE (name);

ALTER TABLE public.dialect_aliases
  ADD CONSTRAINT dialect_aliases_pkey PRIMARY KEY (id);

GRANT ALL ON public.dialect_aliases TO anon;

GRANT ALL ON public.dialect_aliases TO authenticated;

GRANT ALL ON public.dialect_aliases TO service_role;

CREATE TABLE public.dialect_variants (
  id               uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  concept_group_id uuid,
  word_id          uuid,
  dialect_id       uuid,
  usage_frequency  text,
  notes            text,
  created_at       timestamp without time zone DEFAULT now()
);

ALTER TABLE public.dialect_variants
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.dialect_variants
  ADD CONSTRAINT dialect_variants_pkey PRIMARY KEY (id);

GRANT ALL ON public.dialect_variants TO anon;

GRANT ALL ON public.dialect_variants TO authenticated;

GRANT ALL ON public.dialect_variants TO service_role;

CREATE INDEX idx_dialect_variants_concept ON public.dialect_variants (concept_group_id);

CREATE POLICY "Public read access" ON public.dialect_variants
  FOR SELECT
  USING (true);

CREATE TABLE public.dialects (
  id          uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  name        text                        NOT NULL,
  description text,
  language_id uuid,
  created_at  timestamp without time zone DEFAULT now()
);

ALTER TABLE public.dialects
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.dialects
  ADD CONSTRAINT dialects_name_key UNIQUE (name);

ALTER TABLE public.dialects
  ADD CONSTRAINT dialects_pkey PRIMARY KEY (id);

ALTER TABLE public.bible_luhya_verses
  ADD CONSTRAINT bible_luhya_verses_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.cultural_contexts
  ADD CONSTRAINT cultural_contexts_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.dialect_aliases
  ADD CONSTRAINT dialect_aliases_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.dialect_variants
  ADD CONSTRAINT dialect_variants_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

GRANT ALL ON public.dialects TO anon;

GRANT ALL ON public.dialects TO authenticated;

GRANT ALL ON public.dialects TO service_role;

CREATE POLICY "Allow read access to dialects" ON public.dialects
  FOR SELECT
  USING (true);

CREATE POLICY "Public read access" ON public.dialects
  FOR SELECT
  USING (true);

CREATE TABLE public.dictionary_entries (
  id                  uuid                     DEFAULT extensions.uuid_generate_v4() NOT NULL,
  dialect_id          uuid                     NOT NULL,
  word                text                     NOT NULL,
  word_normalized     text,
  part_of_speech      text,
  noun_class          text,
  english_definition  text                     NOT NULL,
  cultural_context    text,
  usage_notes         text,
  etymology           text,
  pronunciation_notes text,
  source_language     text,
  created_at          timestamp with time zone DEFAULT now(),
  updated_at          timestamp with time zone DEFAULT now()
);

ALTER TABLE public.dictionary_entries
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.dictionary_entries
  ADD CONSTRAINT dictionary_entries_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.dictionary_entries
  ADD CONSTRAINT dictionary_entries_pkey PRIMARY KEY (id);

ALTER TABLE public.dialect_variants
  ADD CONSTRAINT dialect_variants_word_id_fkey FOREIGN KEY (word_id) REFERENCES public.dictionary_entries(id);

GRANT ALL ON public.dictionary_entries TO anon;

GRANT ALL ON public.dictionary_entries TO authenticated;

GRANT ALL ON public.dictionary_entries TO service_role;

CREATE INDEX idx_dialect_word ON public.dictionary_entries (dialect_id, word);

CREATE INDEX idx_word_normalized ON public.dictionary_entries (word_normalized);

CREATE INDEX idx_word ON public.dictionary_entries (word);

CREATE INDEX idx_part_of_speech ON public.dictionary_entries (part_of_speech);

CREATE INDEX idx_noun_class ON public.dictionary_entries (noun_class);

CREATE INDEX idx_english_definition ON public.dictionary_entries USING gin (to_tsvector('english'::regconfig, english_definition));

CREATE INDEX idx_dictionary_search ON public.dictionary_entries
  USING gin
  (to_tsvector('english'::regconfig, (((COALESCE(word, ''::text) || ' '::text) || COALESCE(english_definition, ''::text)) || ' '::text) || COALESCE(cultural_context, ''::text)));

CREATE INDEX idx_cultural_search ON public.dictionary_entries USING gin (to_tsvector('english'::regconfig, COALESCE(cultural_context, ''::text)))
  WHERE cultural_context IS NOT NULL AND cultural_context <> ''::text;

CREATE INDEX idx_dialect_id ON public.dictionary_entries (dialect_id);

CREATE INDEX idx_dialect_noun_class ON public.dictionary_entries (dialect_id, noun_class);

CREATE INDEX idx_dialect_pos ON public.dictionary_entries (dialect_id, part_of_speech);

CREATE POLICY "Public read access" ON public.dictionary_entries
  FOR SELECT
  USING (true);

CREATE TABLE public.grammar_patterns (
  id            uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  pattern_name  text                        NOT NULL,
  description   text,
  examples      text[],
  related_words uuid[],
  dialect_id    uuid,
  language_id   uuid,
  created_at    timestamp without time zone DEFAULT now()
);

ALTER TABLE public.grammar_patterns
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.grammar_patterns
  ADD CONSTRAINT grammar_patterns_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.grammar_patterns
  ADD CONSTRAINT grammar_patterns_pkey PRIMARY KEY (id);

GRANT ALL ON public.grammar_patterns TO anon;

GRANT ALL ON public.grammar_patterns TO authenticated;

GRANT ALL ON public.grammar_patterns TO service_role;

CREATE POLICY "Public read access" ON public.grammar_patterns
  FOR SELECT
  USING (true);

CREATE TABLE public.knowledge_base_entries (
  id           uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  type         text                        NOT NULL,
  source_table text                        NOT NULL,
  source_id    uuid                        NOT NULL,
  language_id  uuid                        NOT NULL,
  dialect_id   uuid,
  reference    text,
  content      text                        NOT NULL,
  embedding    public.vector(1536),
  created_at   timestamp without time zone DEFAULT now()
);

ALTER TABLE public.knowledge_base_entries
  ADD CONSTRAINT knowledge_base_entries_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.knowledge_base_entries
  ADD CONSTRAINT knowledge_base_entries_pkey PRIMARY KEY (id);

GRANT ALL ON public.knowledge_base_entries TO anon;

GRANT ALL ON public.knowledge_base_entries TO authenticated;

GRANT ALL ON public.knowledge_base_entries TO service_role;

CREATE INDEX idx_knowledge_embedding ON public.knowledge_base_entries USING ivfflat (embedding public.vector_cosine_ops)
  WITH (lists='100');

CREATE TABLE public.languages (
  id         uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  name       text                        NOT NULL,
  iso_code   text,
  created_at timestamp without time zone DEFAULT now()
);

ALTER TABLE public.languages
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.languages
  ADD CONSTRAINT languages_iso_code_key UNIQUE (iso_code);

ALTER TABLE public.languages
  ADD CONSTRAINT languages_pkey PRIMARY KEY (id);

ALTER TABLE public.dialects
  ADD CONSTRAINT dialects_language_id_fkey FOREIGN KEY (language_id) REFERENCES public.languages(id);

ALTER TABLE public.grammar_patterns
  ADD CONSTRAINT grammar_patterns_language_id_fkey FOREIGN KEY (language_id) REFERENCES public.languages(id);

ALTER TABLE public.knowledge_base_entries
  ADD CONSTRAINT knowledge_base_entries_language_id_fkey FOREIGN KEY (language_id) REFERENCES public.languages(id);

GRANT ALL ON public.languages TO anon;

GRANT ALL ON public.languages TO authenticated;

GRANT ALL ON public.languages TO service_role;

CREATE POLICY "Allow read access to languages" ON public.languages
  FOR SELECT
  USING (true);

CREATE POLICY "Public read access" ON public.languages
  FOR SELECT
  USING (true);

CREATE TABLE public.luhya_dict (
  id                 bigint                   DEFAULT nextval('public.luhya_dict_id_seq'::regclass) NOT NULL,
  luhya_word         text                     NOT NULL,
  english            text,
  dialect            text,
  pos                text,
  notes              text,
  source             text,
  created_at         timestamp with time zone DEFAULT now(),
  source_language_id uuid,
  target_language_id uuid,
  dialect_id         uuid
);

ALTER SEQUENCE public.luhya_dict_id_seq OWNED BY public.luhya_dict.id;

GRANT ALL ON SEQUENCE public.luhya_dict_id_seq TO anon;

GRANT ALL ON SEQUENCE public.luhya_dict_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.luhya_dict_id_seq TO service_role;

ALTER TABLE public.luhya_dict
  ADD CONSTRAINT luhya_dict_pkey PRIMARY KEY (id);

GRANT ALL ON public.luhya_dict TO anon;

GRANT ALL ON public.luhya_dict TO authenticated;

GRANT ALL ON public.luhya_dict TO service_role;

CREATE INDEX idx_luhya_dict_english ON public.luhya_dict (english);

CREATE INDEX idx_luhya_dict_word ON public.luhya_dict (luhya_word);

CREATE INDEX idx_luhya_dict_dialect ON public.luhya_dict (dialect);

CREATE TABLE public.luhya_dictionary (
  id                  bigint                   DEFAULT nextval('public.luhya_dictionary_id_seq'::regclass) NOT NULL,
  luhya_word          text                     NOT NULL,
  english_translation text,
  dialect             text,
  part_of_speech      text,
  source_url          text,
  created_at          timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.luhya_dictionary_id_seq OWNED BY public.luhya_dictionary.id;

GRANT ALL ON SEQUENCE public.luhya_dictionary_id_seq TO anon;

GRANT ALL ON SEQUENCE public.luhya_dictionary_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.luhya_dictionary_id_seq TO service_role;

ALTER TABLE public.luhya_dictionary
  ADD CONSTRAINT luhya_dictionary_pkey PRIMARY KEY (id);

ALTER TABLE public.luhya_dictionary
  ADD CONSTRAINT luhya_dictionary_source_url_key UNIQUE (source_url);

GRANT ALL ON public.luhya_dictionary TO anon;

GRANT ALL ON public.luhya_dictionary TO authenticated;

GRANT ALL ON public.luhya_dictionary TO service_role;

CREATE INDEX idx_luhya_word ON public.luhya_dictionary (luhya_word);

CREATE INDEX idx_english ON public.luhya_dictionary (english_translation);

CREATE TABLE public.luhya_kb (
  id            uuid                     DEFAULT gen_random_uuid() NOT NULL,
  luhya_text    text                     NOT NULL,
  english_text  text,
  swahili_text  text,
  dialect_id    uuid,
  dialect_name  text,
  domain        text                     NOT NULL,
  subdomain     text,
  pos           text,
  quality_score numeric(3,2),
  is_validated  boolean                  DEFAULT false,
  notes         text,
  source_table  text                     NOT NULL,
  source_id     text,
  created_at    timestamp with time zone DEFAULT now()
);

ALTER TABLE public.luhya_kb
  ADD CONSTRAINT luhya_kb_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.luhya_kb
  ADD CONSTRAINT luhya_kb_pkey PRIMARY KEY (id);

GRANT ALL ON public.luhya_kb TO anon;

GRANT ALL ON public.luhya_kb TO authenticated;

GRANT ALL ON public.luhya_kb TO service_role;

CREATE INDEX idx_kb_dialect ON public.luhya_kb (dialect_id);

CREATE INDEX idx_kb_validated ON public.luhya_kb (is_validated);

CREATE INDEX idx_kb_source ON public.luhya_kb (source_table);

CREATE INDEX idx_kb_domain ON public.luhya_kb (DOMAIN);

CREATE TABLE public.luhya_proverbs (
  id                   uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  number               integer                     NOT NULL,
  luhya_text           text                        NOT NULL,
  english_text         text                        NOT NULL,
  source_code          text,
  source_person        text,
  sub_tribes           text[],
  alternative_versions jsonb,
  cultural_notes       text,
  topic_category       text,
  difficulty_level     text                        DEFAULT 'intermediate'::text,
  is_approved          boolean                     DEFAULT true,
  created_at           timestamp without time zone DEFAULT now()
);

ALTER TABLE public.luhya_proverbs
  ADD CONSTRAINT luhya_proverbs_number_key UNIQUE (number);

ALTER TABLE public.luhya_proverbs
  ADD CONSTRAINT luhya_proverbs_pkey PRIMARY KEY (id);

GRANT ALL ON public.luhya_proverbs TO anon;

GRANT ALL ON public.luhya_proverbs TO authenticated;

GRANT ALL ON public.luhya_proverbs TO service_role;

CREATE INDEX idx_proverbs_source ON public.luhya_proverbs (source_code);

CREATE INDEX idx_proverbs_topic ON public.luhya_proverbs (topic_category);

CREATE INDEX idx_proverbs_difficulty ON public.luhya_proverbs (difficulty_level);

CREATE TABLE public.prompts (
  id              uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  text            text                        NOT NULL,
  source_language text                        DEFAULT 'en'::text,
  topic           text,
  created_at      timestamp without time zone DEFAULT now()
);

ALTER TABLE public.prompts
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.prompts
  ADD CONSTRAINT prompts_pkey PRIMARY KEY (id);

GRANT ALL ON public.prompts TO anon;

GRANT ALL ON public.prompts TO authenticated;

GRANT ALL ON public.prompts TO service_role;

CREATE POLICY "Allow read access to prompts" ON public.prompts
  FOR SELECT
  USING (true);

CREATE TABLE public.pronoun_examples (
  id                  uuid                     DEFAULT gen_random_uuid() NOT NULL,
  pronoun_id          uuid,
  luhya_example       text                     NOT NULL,
  english_translation text                     NOT NULL,
  example_type        text                     DEFAULT 'sentence'::text,
  created_at          timestamp with time zone DEFAULT now()
);

ALTER TABLE public.pronoun_examples
  ADD CONSTRAINT pronoun_examples_example_type_check CHECK (example_type = ANY (ARRAY['sentence'::text, 'phrase'::text, 'possessive'::text]));

ALTER TABLE public.pronoun_examples
  ADD CONSTRAINT pronoun_examples_pkey PRIMARY KEY (id);

GRANT ALL ON public.pronoun_examples TO anon;

GRANT ALL ON public.pronoun_examples TO authenticated;

GRANT ALL ON public.pronoun_examples TO service_role;

CREATE INDEX idx_pronoun_examples_pronoun_id ON public.pronoun_examples (pronoun_id);

CREATE TABLE public.pronouns (
  id           uuid                     DEFAULT gen_random_uuid() NOT NULL,
  pronoun_text text                     NOT NULL,
  person       integer                  NOT NULL,
  number       text                     NOT NULL,
  pronoun_type text                     DEFAULT 'subject'::text,
  dialect_id   uuid,
  notes        text,
  created_at   timestamp with time zone DEFAULT now()
);

ALTER TABLE public.pronouns
  ADD CONSTRAINT pronouns_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.pronouns
  ADD CONSTRAINT pronouns_number_check CHECK (number = ANY (ARRAY['singular'::text, 'plural'::text]));

ALTER TABLE public.pronouns
  ADD CONSTRAINT pronouns_person_check CHECK (person = ANY (ARRAY[1, 2, 3]));

ALTER TABLE public.pronouns
  ADD CONSTRAINT pronouns_pkey PRIMARY KEY (id);

ALTER TABLE public.pronoun_examples
  ADD CONSTRAINT pronoun_examples_pronoun_id_fkey FOREIGN KEY (pronoun_id) REFERENCES public.pronouns(id) ON DELETE CASCADE;

ALTER TABLE public.pronouns
  ADD CONSTRAINT pronouns_pronoun_type_check CHECK (pronoun_type = ANY (ARRAY['subject'::text, 'object'::text, 'possessive'::text]));

GRANT ALL ON public.pronouns TO anon;

GRANT ALL ON public.pronouns TO authenticated;

GRANT ALL ON public.pronouns TO service_role;

CREATE INDEX idx_pronouns_dialect_person_number ON public.pronouns (dialect_id, person, number, pronoun_type);

CREATE TABLE public.pronunciations (
  id                     uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  word_id                uuid,
  audio_file_url         text,
  speaker_info           text,
  dialect_id             uuid,
  phonetic_transcription text,
  quality_rating         integer,
  created_at             timestamp without time zone DEFAULT now()
);

ALTER TABLE public.pronunciations
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.pronunciations
  ADD CONSTRAINT pronunciations_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.pronunciations
  ADD CONSTRAINT pronunciations_pkey PRIMARY KEY (id);

ALTER TABLE public.pronunciations
  ADD CONSTRAINT pronunciations_quality_rating_check CHECK (quality_rating >= 1 AND quality_rating <= 5);

ALTER TABLE public.pronunciations
  ADD CONSTRAINT pronunciations_word_id_fkey FOREIGN KEY (word_id) REFERENCES public.dictionary_entries(id);

GRANT ALL ON public.pronunciations TO anon;

GRANT ALL ON public.pronunciations TO authenticated;

GRANT ALL ON public.pronunciations TO service_role;

CREATE INDEX idx_pronunciations_dialect ON public.pronunciations (dialect_id);

CREATE INDEX idx_pronunciations_word ON public.pronunciations (word_id);

CREATE POLICY "Public read access" ON public.pronunciations
  FOR SELECT
  USING (true);

CREATE TABLE public.proverb_contributors (
  code        text NOT NULL,
  full_name   text NOT NULL,
  description text
);

ALTER TABLE public.proverb_contributors
  ADD CONSTRAINT proverb_contributors_pkey PRIMARY KEY (code);

GRANT ALL ON public.proverb_contributors TO anon;

GRANT ALL ON public.proverb_contributors TO authenticated;

GRANT ALL ON public.proverb_contributors TO service_role;

CREATE TABLE public.proverbs (
  id                  uuid                     DEFAULT gen_random_uuid() NOT NULL,
  luhya_text          text                     NOT NULL,
  swahili_translation text,
  french_translation  text,
  english_translation text,
  meaning             text,
  biblical_reference  text,
  biblical_text       text,
  dialect_id          uuid,
  created_at          timestamp with time zone DEFAULT now()
);

ALTER TABLE public.proverbs
  ADD CONSTRAINT proverbs_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.proverbs
  ADD CONSTRAINT proverbs_pkey PRIMARY KEY (id);

GRANT ALL ON public.proverbs TO anon;

GRANT ALL ON public.proverbs TO authenticated;

GRANT ALL ON public.proverbs TO service_role;

CREATE INDEX idx_proverbs_dialect_id ON public.proverbs (dialect_id);

CREATE TABLE public.submission_rate_limits (
  id               uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  ip_address       inet                        NOT NULL,
  submission_count integer                     DEFAULT 1,
  first_submission timestamp without time zone DEFAULT now(),
  last_submission  timestamp without time zone DEFAULT now(),
  is_blocked       boolean                     DEFAULT false,
  created_at       timestamp without time zone DEFAULT now()
);

ALTER TABLE public.submission_rate_limits
  ADD CONSTRAINT submission_rate_limits_pkey PRIMARY KEY (id);

GRANT ALL ON public.submission_rate_limits TO anon;

GRANT ALL ON public.submission_rate_limits TO authenticated;

GRANT ALL ON public.submission_rate_limits TO service_role;

CREATE TABLE public.submissions (
  id                      uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  prompt_id               uuid,
  dialect_id              uuid,
  luhya_text              text                        NOT NULL,
  audio_url               text,
  contributor_name        text,
  created_at              timestamp without time zone DEFAULT now(),
  ip_address              inet,
  user_agent              text,
  submission_time_seconds integer,
  browser_fingerprint     text,
  is_verified             boolean                     DEFAULT false,
  needs_review            boolean                     DEFAULT false
);

ALTER TABLE public.submissions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.submissions
  ADD CONSTRAINT submissions_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.submissions
  ADD CONSTRAINT submissions_pkey PRIMARY KEY (id);

ALTER TABLE public.submissions
  ADD CONSTRAINT submissions_prompt_id_fkey FOREIGN KEY (prompt_id) REFERENCES public.prompts(id);

GRANT ALL ON public.submissions TO anon;

GRANT ALL ON public.submissions TO authenticated;

GRANT ALL ON public.submissions TO service_role;

CREATE POLICY "Allow insert submissions" ON public.submissions
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow read submissions" ON public.submissions
  FOR SELECT
  USING (true);

CREATE TABLE public.suspicious_activity (
  id            uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  ip_address    inet,
  activity_type text,
  details       jsonb,
  created_at    timestamp without time zone DEFAULT now()
);

ALTER TABLE public.suspicious_activity
  ADD CONSTRAINT suspicious_activity_pkey PRIMARY KEY (id);

GRANT ALL ON public.suspicious_activity TO anon;

GRANT ALL ON public.suspicious_activity TO authenticated;

GRANT ALL ON public.suspicious_activity TO service_role;

CREATE TABLE public.translations (
  id                 uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  original_text      text                        NOT NULL,
  translated_text    text                        NOT NULL,
  source_language_id uuid                        NOT NULL,
  target_language_id uuid                        NOT NULL,
  dialect_id         uuid,
  file_source        text,
  created_at         timestamp without time zone DEFAULT now()
);

ALTER TABLE public.translations
  ADD CONSTRAINT translations_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.translations
  ADD CONSTRAINT translations_pkey PRIMARY KEY (id);

ALTER TABLE public.translations
  ADD CONSTRAINT translations_source_language_id_fkey FOREIGN KEY (source_language_id) REFERENCES public.languages(id);

ALTER TABLE public.translations
  ADD CONSTRAINT translations_target_language_id_fkey FOREIGN KEY (target_language_id) REFERENCES public.languages(id);

GRANT ALL ON public.translations TO anon;

GRANT ALL ON public.translations TO authenticated;

GRANT ALL ON public.translations TO service_role;

CREATE INDEX idx_translations_dialect ON public.translations (dialect_id);

CREATE INDEX idx_translations_original_text ON public.translations (original_text);

CREATE INDEX idx_translations_source_language ON public.translations (source_language_id);

CREATE INDEX idx_translations_target_language ON public.translations (target_language_id);

CREATE TABLE public.usage_examples (
  id                    uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  word_id               uuid,
  phrase                text                        NOT NULL,
  english_translation   text                        NOT NULL,
  context               text,
  cultural_significance text,
  dialect_id            uuid,
  created_at            timestamp without time zone DEFAULT now()
);

ALTER TABLE public.usage_examples
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.usage_examples
  ADD CONSTRAINT usage_examples_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.usage_examples
  ADD CONSTRAINT usage_examples_pkey PRIMARY KEY (id);

ALTER TABLE public.usage_examples
  ADD CONSTRAINT usage_examples_word_id_fkey FOREIGN KEY (word_id) REFERENCES public.dictionary_entries(id);

GRANT ALL ON public.usage_examples TO anon;

GRANT ALL ON public.usage_examples TO authenticated;

GRANT ALL ON public.usage_examples TO service_role;

CREATE INDEX idx_usage_examples_word ON public.usage_examples (word_id);

CREATE POLICY "Public read access" ON public.usage_examples
  FOR SELECT
  USING (true);

CREATE TABLE public.user_contributions (
  id                uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  user_id           uuid,
  contribution_type text,
  target_id         uuid,
  content           jsonb,
  status            text                        DEFAULT 'pending'::text,
  moderator_notes   text,
  created_at        timestamp without time zone DEFAULT now()
);

ALTER TABLE public.user_contributions
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_contributions
  ADD CONSTRAINT user_contributions_pkey PRIMARY KEY (id);

GRANT ALL ON public.user_contributions TO anon;

GRANT ALL ON public.user_contributions TO authenticated;

GRANT ALL ON public.user_contributions TO service_role;

CREATE POLICY "Authenticated users can contribute" ON public.user_contributions
  FOR INSERT
  TO authenticated
  WITH CHECK ((auth.uid() = user_id));

CREATE POLICY "Users can see their own contributions" ON public.user_contributions
  FOR SELECT
  TO authenticated
  USING ((auth.uid() = user_id));

CREATE TABLE public.verb_forms (
  id                  uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  base_word_id        uuid,
  form_type           text,
  conjugated_form     text                        NOT NULL,
  english_translation text,
  usage_example       text,
  dialect_id          uuid,
  created_at          timestamp without time zone DEFAULT now()
);

ALTER TABLE public.verb_forms
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.verb_forms
  ADD CONSTRAINT verb_forms_base_word_id_fkey FOREIGN KEY (base_word_id) REFERENCES public.dictionary_entries(id);

ALTER TABLE public.verb_forms
  ADD CONSTRAINT verb_forms_dialect_id_fkey FOREIGN KEY (dialect_id) REFERENCES public.dialects(id);

ALTER TABLE public.verb_forms
  ADD CONSTRAINT verb_forms_pkey PRIMARY KEY (id);

GRANT ALL ON public.verb_forms TO anon;

GRANT ALL ON public.verb_forms TO authenticated;

GRANT ALL ON public.verb_forms TO service_role;

CREATE INDEX idx_verb_forms_base ON public.verb_forms (base_word_id);

CREATE POLICY "Public read access" ON public.verb_forms
  FOR SELECT
  USING (true);

CREATE TABLE public.word_relationships (
  id                uuid                        DEFAULT extensions.uuid_generate_v4() NOT NULL,
  source_word_id    uuid,
  target_word_id    uuid,
  relationship_type text,
  notes             text,
  created_at        timestamp without time zone DEFAULT now()
);

ALTER TABLE public.word_relationships
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.word_relationships
  ADD CONSTRAINT word_relationships_pkey PRIMARY KEY (id);

ALTER TABLE public.word_relationships
  ADD CONSTRAINT word_relationships_source_word_id_fkey FOREIGN KEY (source_word_id) REFERENCES public.dictionary_entries(id);

ALTER TABLE public.word_relationships
  ADD CONSTRAINT word_relationships_target_word_id_fkey FOREIGN KEY (target_word_id) REFERENCES public.dictionary_entries(id);

GRANT ALL ON public.word_relationships TO anon;

GRANT ALL ON public.word_relationships TO authenticated;

GRANT ALL ON public.word_relationships TO service_role;

CREATE INDEX idx_word_relationships_source ON public.word_relationships (source_word_id);

CREATE INDEX idx_word_relationships_target ON public.word_relationships (target_word_id);

CREATE POLICY "Public read access" ON public.word_relationships
  FOR SELECT
  USING (true);

CREATE VIEW public.cultural_terms AS SELECT de.id,
    de.word,
    de.english_definition,
    de.cultural_context,
    d.name AS dialect_name,
    l.name AS language_name,
    de.created_at
   FROM ((public.dictionary_entries de
     JOIN public.dialects d ON ((de.dialect_id = d.id)))
     JOIN public.languages l ON ((d.language_id = l.id)))
  WHERE ((de.cultural_context IS NOT NULL) AND (de.cultural_context <> ''::text))
  ORDER BY de.word;

GRANT ALL ON public.cultural_terms TO anon;

GRANT ALL ON public.cultural_terms TO authenticated;

GRANT ALL ON public.cultural_terms TO service_role;

CREATE VIEW public.dialect_comparisons AS SELECT dv.concept_group_id,
    de.word,
    de.english_definition,
    de.cultural_context,
    d.name AS dialect_name,
    l.name AS language_name,
    dv.usage_frequency,
    dv.notes
   FROM (((public.dialect_variants dv
     JOIN public.dictionary_entries de ON ((dv.word_id = de.id)))
     JOIN public.dialects d ON ((dv.dialect_id = d.id)))
     JOIN public.languages l ON ((d.language_id = l.id)))
  ORDER BY dv.concept_group_id, d.name;

GRANT ALL ON public.dialect_comparisons TO anon;

GRANT ALL ON public.dialect_comparisons TO authenticated;

GRANT ALL ON public.dialect_comparisons TO service_role;

CREATE VIEW public.language_words AS SELECT de.id,
    de.word,
    de.word_normalized,
    de.english_definition,
    de.part_of_speech,
    de.noun_class,
    de.cultural_context,
    de.usage_notes,
    de.etymology,
    de.source_language,
    d.name AS dialect_name,
    l.name AS language_name,
    l.iso_code,
    de.created_at,
    de.updated_at
   FROM ((public.dictionary_entries de
     JOIN public.dialects d ON ((de.dialect_id = d.id)))
     JOIN public.languages l ON ((d.language_id = l.id)));

GRANT ALL ON public.language_words TO anon;

GRANT ALL ON public.language_words TO authenticated;

GRANT ALL ON public.language_words TO service_role;

CREATE VIEW public.pronoun_details AS SELECT p.id,
    p.pronoun_text,
    p.person,
    p.number,
    p.pronoun_type,
    p.notes,
    d.name AS dialect_name,
    pe.luhya_example,
    pe.english_translation,
    pe.example_type,
    p.created_at
   FROM ((public.pronouns p
     LEFT JOIN public.dialects d ON ((p.dialect_id = d.id)))
     LEFT JOIN public.pronoun_examples pe ON ((p.id = pe.pronoun_id)));

CREATE VIEW public.pronoun_comparison AS SELECT person,
    number,
    pronoun_type,
    string_agg(DISTINCT ((dialect_name || ': '::text) || pronoun_text), ', '::text ORDER BY ((dialect_name || ': '::text) || pronoun_text)) AS dialect_forms
   FROM public.pronoun_details
  GROUP BY person, number, pronoun_type
  ORDER BY person, number, pronoun_type;

GRANT ALL ON public.pronoun_comparison TO anon;

GRANT ALL ON public.pronoun_comparison TO authenticated;

GRANT ALL ON public.pronoun_comparison TO service_role;

GRANT ALL ON public.pronoun_details TO anon;

GRANT ALL ON public.pronoun_details TO authenticated;

GRANT ALL ON public.pronoun_details TO service_role;

CREATE VIEW public.word_details AS SELECT de.id,
    de.word,
    de.word_normalized,
    de.part_of_speech,
    de.noun_class,
    de.english_definition,
    de.cultural_context,
    de.usage_notes,
    de.etymology,
    de.pronunciation_notes,
    de.source_language,
    d.name AS dialect_name,
    l.name AS language_name,
    l.iso_code,
    array_agg(DISTINCT p.audio_file_url) FILTER (WHERE (p.audio_file_url IS NOT NULL)) AS audio_files,
    array_agg(DISTINCT p.phonetic_transcription) FILTER (WHERE (p.phonetic_transcription IS NOT NULL)) AS phonetic_transcriptions,
    array_agg(DISTINCT ((ue.phrase || ' → '::text) || ue.english_translation)) FILTER (WHERE (ue.phrase IS NOT NULL)) AS usage_examples,
    array_agg(DISTINCT (((vf.conjugated_form || ' ('::text) || vf.form_type) || ')'::text)) FILTER (WHERE (vf.conjugated_form IS NOT NULL)) AS verb_forms
   FROM (((((public.dictionary_entries de
     JOIN public.dialects d ON ((de.dialect_id = d.id)))
     JOIN public.languages l ON ((d.language_id = l.id)))
     LEFT JOIN public.pronunciations p ON ((de.id = p.word_id)))
     LEFT JOIN public.usage_examples ue ON ((de.id = ue.word_id)))
     LEFT JOIN public.verb_forms vf ON ((de.id = vf.base_word_id)))
  GROUP BY de.id, d.name, l.name, l.iso_code;

GRANT ALL ON public.word_details TO anon;

GRANT ALL ON public.word_details TO authenticated;

GRANT ALL ON public.word_details TO service_role;
