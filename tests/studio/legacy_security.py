"""Local-only SQL role regressions; every mutation is rolled back."""
from database_checks import sql

PRIVATE = ['bible_books','bible_english_verses','bible_luhya_verses','knowledge_base_entries',
           'luhya_dict','luhya_dictionary','luhya_kb','luhya_proverbs','proverb_contributors',
           'proverbs','submission_rate_limits','suspicious_activity','translations','submissions','contributors']
PUBLIC = ['dialect_aliases','pronouns','pronoun_examples']
VIEWS = ['word_details','cultural_terms','language_words','pronoun_comparison','pronoun_details','dialect_comparisons']
for role in ['anon','authenticated']:
    for table in PRIVATE + PUBLIC:
        for statement in [f'INSERT INTO public.{table} DEFAULT VALUES', f'UPDATE public.{table} SET id=id' if table != 'proverb_contributors' else 'UPDATE public.proverb_contributors SET code=code', f'DELETE FROM public.{table}']:
            sql(f'BEGIN; SET LOCAL ROLE {role}; {statement}; ROLLBACK;', ok=False)
        if table in PRIVATE:
            sql(f'BEGIN; SET LOCAL ROLE {role}; SELECT * FROM public.{table}; ROLLBACK;', ok=False)
        else:
            sql(f'BEGIN; SET LOCAL ROLE {role}; SELECT * FROM public.{table}; ROLLBACK;')
    for view in VIEWS:
        sql(f'BEGIN; SET LOCAL ROLE {role}; SELECT * FROM public.{view}; ROLLBACK;')
    # Invoker views must fail if the caller cannot read their base table.
    for view, base in [('word_details','dictionary_entries'),('cultural_terms','dictionary_entries'),
                       ('language_words','dictionary_entries'),('dialect_comparisons','dialect_variants'),
                       ('pronoun_details','pronouns'),('pronoun_comparison','pronouns')]:
        sql(f'BEGIN; REVOKE SELECT ON public.{base} FROM {role}; SET LOCAL ROLE {role}; SELECT * FROM public.{view}; ROLLBACK;', ok=False)
    print('PASS legacy SQL CRUD, restricted reads, invoker views:', role)
assert sql("SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' AND NOT c.relrowsecurity") == '0'
assert sql("SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prosecdef AND has_function_privilege('anon',p.oid,'EXECUTE')") == '0'
assert sql("SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='v' AND NOT coalesce(c.reloptions @> ARRAY['security_invoker=true'],false)") == '0'
print('PASS no public tables without RLS, no definer views, no anonymous definer RPC grants')

# Positive controls must contain rows: an empty successful SELECT is insufficient.
# Rollback-only synthetic reference rows; no genuine vocabulary or promotion.
from uuid import uuid4
language, dialect, word, pronoun, example, alias, hidden = [str(uuid4()) for _ in range(7)]
seed = f"""BEGIN;
INSERT INTO public.languages(id,name) VALUES('{language}','SYNTHETIC reference language');
INSERT INTO public.dialects(id,name,language_id) VALUES('{dialect}','SYNTHETIC reference dialect','{language}');
INSERT INTO public.dictionary_entries(id,dialect_id,word,english_definition,cultural_context)
VALUES('{word}','{dialect}','SYNTHETIC_REFERENCE','SYNTHETIC','SYNTHETIC');
INSERT INTO public.dialect_variants(word_id,dialect_id) VALUES('{word}','{dialect}');
INSERT INTO public.pronouns(id,pronoun_text,person,number,dialect_id)
VALUES('{pronoun}','SYNTHETIC_REFERENCE',1,'singular','{dialect}'),('{hidden}','SYNTHETIC_DENIED',1,'singular',NULL);
INSERT INTO public.pronoun_examples(id,pronoun_id,luhya_example,english_translation)
VALUES('{example}','{pronoun}','SYNTHETIC','SYNTHETIC');
INSERT INTO public.dialect_aliases(id,name,dialect_id) VALUES('{alias}','SYNTHETIC_ALIAS','{dialect}');
"""
for role in ['anon','authenticated']:
    query = seed + f'SET LOCAL ROLE {role};\n'
    for table, identity in [('dialect_aliases',alias),('pronouns',pronoun),('pronoun_examples',example),
                            ('word_details',word),('cultural_terms',word),('language_words',word),('pronoun_details',pronoun)]:
        query += f"SELECT count(*) FROM public.{table} WHERE id='{identity}';\n"
    query += "SELECT count(*) FROM public.dialect_comparisons WHERE word='SYNTHETIC_REFERENCE';\n"
    query += "SELECT count(*) FROM public.pronoun_comparison WHERE dialect_forms LIKE '%SYNTHETIC_REFERENCE%';\n"
    query += f"SELECT count(*) FROM public.pronoun_details WHERE id='{hidden}';\nROLLBACK;"
    assert sql(query).splitlines() == ['1'] * 9 + ['0']
print('PASS populated public reference/view reads and denied base row hidden through invoker view')
