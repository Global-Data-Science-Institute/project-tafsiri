"""Rollback-only checks against the explicitly named isolated Studio database."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = 'supabase_db_tafsiri-studio-synthetic'

def sql(text, ok=True):
    result = subprocess.run(['docker','exec','-i',CONTAINER,'psql','-XqAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'], input=text, text=True, encoding='utf-8', capture_output=True)
    assert (result.returncode == 0) == ok, result.stderr + result.stdout[-1000:]
    return result.stdout.strip()

def main():
    for name in ['portal_implementation_002_smoke.sql','source_provenance_foundation_smoke.sql','linguistic_evidence_foundation_smoke.sql','scholarly_book_source_type_smoke.sql','canonical_linguistic_rule_governance_smoke.sql','source_artifact_foundation_smoke.sql','canonical_lexical_core_smoke.sql']:
        sql((ROOT/'tests/database'/name).read_text(encoding='utf-8'))
        print('PASS existing smoke:', name)
    tables=sql("SELECT tablename FROM pg_tables WHERE schemaname='data_studio' ORDER BY tablename").splitlines()
    for role in ['anon','authenticated','service_role']:
        for table in tables:
            sql(f'SET ROLE {role}; SELECT * FROM data_studio.{table};',ok=False)
        print('PASS direct private table denials:', role, len(tables))
    sql("SET ROLE anon; SELECT public.studio_state();",ok=False)
    sql("SET ROLE authenticated; SELECT public.studio_state();",ok=False)
    sql("SET ROLE authenticated; SELECT public.studio_ai_finish(gen_random_uuid(),'{}','forged',0,false);",ok=False)
    assert sql("SELECT public FROM storage.buckets WHERE id='studio-quarantine'")=='f'
    print('PASS anonymous, missing identity, forged AI completion and private bucket checks')
    assert sql("SELECT count(*) FROM public.lexemes")=='0'
    assert sql("SELECT count(*) FROM public.source_entries")=='0'
    print('PASS no automatic canonical/source ingestion')

if __name__=='__main__': main()
