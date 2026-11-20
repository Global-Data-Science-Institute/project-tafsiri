"""Disposable-container replay/rollback/compatibility checks for Migration 011.

Requires a NEW cached supabase/postgres container named tafsiri-m011-validation-db.
Never accepts a hosted URL, never resets an existing Tafsiri database. The normal
CI stack runs the separate rollback-only smoke SQL after its own clean replay.
"""
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = "tafsiri-m011-validation-db"
MIGRATIONS = sorted((ROOT / "supabase/migrations").glob("*.sql"))
MIGRATION = next(p for p in MIGRATIONS if p.name.endswith("_create_multilingual_canonical_lexical_core.sql"))


def psql(sql, success=True, user="postgres"):
    result = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "psql", "-X", "-U", user, "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-At"],
        input=sql, text=True, encoding="utf-8", capture_output=True,
    )
    if (result.returncode == 0) != success:
        raise AssertionError(result.stdout[-3000:] + result.stderr)
    return result


def snapshot():
    # Stable values and privileges, excluding system objects changed by extensions.
    return psql("""
      SELECT jsonb_build_object('table',c.relname,'acl',c.relacl::text,'rls',c.relrowsecurity)
      FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relkind='r' ORDER BY c.relname;
      SELECT to_jsonb(t) FROM public.languages t ORDER BY id;
      SELECT to_jsonb(t) FROM public.dialects t ORDER BY id;
      SELECT to_jsonb(t) FROM public.sources t ORDER BY id;
      SELECT to_jsonb(t) FROM public.source_versions t ORDER BY id;
      SELECT to_jsonb(t) FROM public.source_rights t ORDER BY id;
      SELECT to_jsonb(t) FROM public.source_use_policies t ORDER BY id;
      SELECT id,concept_key,definition_en,domain,subdomain,notes,created_at,updated_at FROM public.concepts ORDER BY id;
      SELECT 'column|'||table_name||'|'||column_name||'|'||data_type||'|'||is_nullable||'|'||coalesce(column_default,'')
      FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name,ordinal_position;
      SELECT 'constraint|'||conrelid::regclass||'|'||conname||'|'||pg_get_constraintdef(oid)
      FROM pg_constraint WHERE connamespace='public'::regnamespace ORDER BY conrelid,conname;
      SELECT 'policy|'||schemaname||'|'||tablename||'|'||policyname||'|'||coalesce(qual,'')||'|'||coalesce(with_check,'')
      FROM pg_policies WHERE schemaname='public' ORDER BY tablename,policyname;
      SELECT 'defaults|'||defaclrole::regrole||'|'||defaclnamespace::regnamespace||'|'||defaclobjtype::text||'|'||defaclacl::text
      FROM pg_default_acl ORDER BY oid;
    """).stdout


def main():
    assert psql("SELECT to_regclass('public.languages') IS NULL;").stdout.strip() == "t", "Requires a fresh disposable container"
    # The image contains the initial Auth schema, before GoTrue's migrations.
    # Copy only the real schema (no users, tokens, data or credentials) from the
    # existing local Supabase stack, before replay creates foreign keys to it.
    auth_schema = subprocess.run(
        ["docker", "exec", "supabase_db_project-tafsiri", "pg_dump", "-U", "postgres", "-d", "postgres",
         "--schema-only", "--schema=auth", "--clean", "--if-exists", "--no-owner"],
        text=True, encoding="utf-8", capture_output=True, check=True,
    ).stdout
    psql(auth_schema, user="supabase_admin")
    history_schema = subprocess.run(
        ["docker", "exec", "supabase_db_project-tafsiri", "pg_dump", "-U", "postgres", "-d", "postgres",
         "--schema-only", "--schema=supabase_migrations", "--no-owner"],
        text=True, encoding="utf-8", capture_output=True, check=True,
    ).stdout
    psql(history_schema)
    # Supabase CLI enables pg_net in its bootstrap; the cached image alone does not.
    # Use the real extension so the historical baseline's DROP EXTENSION replays.
    psql("CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;")
    for path in MIGRATIONS:
        if path == MIGRATION:
            break
        version, name = path.stem.split("_", 1)
        assert version.isdigit() and all(c.isalnum() or c == '_' for c in name)
        psql("BEGIN;\n" + path.read_text(encoding="utf-8") +
             f"\nINSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('{version}','{name}');\nCOMMIT;")
    print("PASS: all eleven historical migration files replayed")
    psql("""
      INSERT INTO public.languages(id,name) VALUES('00000000-0000-4000-8000-000000009001','M011 legacy fixture');
      INSERT INTO public.dialects(id,name,language_id) VALUES('00000000-0000-4000-8000-000000009002','M011 legacy variety','00000000-0000-4000-8000-000000009001');
      INSERT INTO public.sources(id,source_key,source_type,title) VALUES('00000000-0000-4000-8000-000000009003','M011-LEGACY','OTHER','Synthetic legacy source');
      INSERT INTO public.source_versions(id,source_id,version_key) VALUES('00000000-0000-4000-8000-000000009004','00000000-0000-4000-8000-000000009003','LEGACY-V1');
      INSERT INTO public.source_rights(source_version_id,rights_status) VALUES('00000000-0000-4000-8000-000000009004','UNKNOWN');
      INSERT INTO public.source_use_policies(source_version_id,use_scope,decision,policy_version) VALUES('00000000-0000-4000-8000-000000009004','MODEL_TRAINING','UNKNOWN','M011-LEGACY');
      INSERT INTO public.concepts(concept_key,definition_en,notes) VALUES('M011-LEGACY','Synthetic old definition','Must not be relabeled');
    """)
    before = snapshot()
    ddl = MIGRATION.read_text(encoding="utf-8")
    # A late injected failure must roll back tables, columns, functions and grants.
    failure = psql("BEGIN;\n" + ddl + "\nSELECT 1/0;\nCOMMIT;", success=False)
    assert "division by zero" in failure.stderr, failure.stderr
    assert before == snapshot()
    assert psql("SELECT to_regclass('public.lexemes') IS NULL AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='concepts' AND column_name='sealed_at');").stdout.strip() == "t"
    print("PASS: injected failure leaves no partial migration or compatibility changes")
    psql("BEGIN;\n" + ddl + "\nROLLBACK;")
    assert before == snapshot()
    print("PASS: explicit migration rollback preserves baseline")
    psql("BEGIN;\n" + ddl + "\nCOMMIT;")
    version, name = MIGRATION.stem.split("_", 1)
    psql(f"INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('{version}','{name}');")
    after = snapshot()
    # Existing relation ACLs/RLS and all fixture values must be byte-identical.
    assert set(before.splitlines()).issubset(after.splitlines()), "Existing data, columns, constraints, policies or privileges changed"
    assert psql("SELECT num_nonnulls(lifecycle_status,verification_status,provenance_origin,current_revision_id,sealed_at,reviewed_by,reviewed_at)=0 FROM public.concepts WHERE concept_key='M011-LEGACY';").stdout.strip() == "t"
    print("PASS: successful migration preserves legacy data/grants and leaves metadata unclassified")
    result = psql((ROOT / "tests/database/canonical_lexical_core_smoke.sql").read_text(encoding="utf-8"))
    print(next(line for line in result.stdout.splitlines() if 'smoke assertions passed:' in line))
    # Only remove this runner's synthetic pre-migration fixtures, after proving
    # preservation. Older smoke suites assert globally empty rights tables.
    psql("""
      DELETE FROM public.source_use_policies WHERE source_version_id='00000000-0000-4000-8000-000000009004';
      DELETE FROM public.source_rights WHERE source_version_id='00000000-0000-4000-8000-000000009004';
      DELETE FROM public.source_versions WHERE id='00000000-0000-4000-8000-000000009004';
      DELETE FROM public.sources WHERE id='00000000-0000-4000-8000-000000009003';
      DELETE FROM public.dialects WHERE id='00000000-0000-4000-8000-000000009002';
      DELETE FROM public.languages WHERE id='00000000-0000-4000-8000-000000009001';
      DELETE FROM public.concepts WHERE concept_key='M011-LEGACY';
    """)
    for path in sorted((ROOT / "tests/database").glob("*smoke.sql")):
        if path.name != "canonical_lexical_core_smoke.sql":
            psql(path.read_text(encoding="utf-8"))
            print("PASS: existing " + path.name)
    lint = psql("""
      CREATE EXTENSION IF NOT EXISTS plpgsql_check WITH SCHEMA extensions;
      SELECT t.tgname, lint.level, lint.message
      FROM pg_trigger t JOIN pg_proc p ON p.oid=t.tgfoid
      CROSS JOIN LATERAL extensions.plpgsql_check_function_tb(p.oid::regprocedure,t.tgrelid) lint
      WHERE p.proname IN ('tafsiri_guard_lexical_record','tafsiri_lock_lexical_successor','tafsiri_check_lexical_successor')
        AND lint.level='error';
    """)
    assert not any('|' in line for line in lint.stdout.splitlines()), lint.stdout
    print("PASS: PL/pgSQL lint has no errors for every new trigger binding")
    atomic = runpy.run_path(str(ROOT / "tests/database/run_marlo_registration_atomic_tests.py"))
    atomic["psql"].__globals__["CONTAINER"] = CONTAINER
    atomic["main"]()


if __name__ == "__main__":
    main()
