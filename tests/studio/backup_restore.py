"""Rehearse a full synthetic DB restore in a new disposable local database.

Never targets hosted Postgres or drops/replaces the source database. Storage
object bytes are not in pg_dump; their separate restore remains a release gate.
"""
from pathlib import Path
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = 'supabase_db_tafsiri-studio-synthetic'


def run(*args, data=None):
    result = subprocess.run(['docker', 'exec', '-i', CONTAINER, *args],
                            input=data, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.decode('utf-8', errors='replace')[-3000:])
    return result.stdout


def sql(db, query):
    return run('psql', '-XqAt', '-U', 'postgres', '-d', db,
               '-v', 'ON_ERROR_STOP=1', data=query.encode()).strip()


def main():
    target = 'studio_restore_' + uuid.uuid4().hex
    archive = ROOT / '.studio-local' / 'synthetic-backup.dump'
    archive.parent.mkdir(exist_ok=True)
    checks = """
    SELECT 'contributions='||count(*) FROM data_studio.contributions;
    SELECT 'uploads='||count(*) FROM data_studio.uploads;
    SELECT 'rls='||count(*) FROM pg_tables WHERE schemaname='data_studio' AND rowsecurity;
    SELECT 'anon_schema='||has_schema_privilege('anon','data_studio','USAGE');
    SELECT 'authenticated_schema='||has_schema_privilege('authenticated','data_studio','USAGE');
    SELECT 'private_bucket='||NOT public FROM storage.buckets WHERE id='studio-quarantine';
    SELECT 'content_checksum='||md5(COALESCE(string_agg(id::text||content::text,'' ORDER BY id),'')) FROM data_studio.contributions;
    """
    before = sql('postgres', checks)
    archive.write_bytes(run('pg_dump', '-U', 'postgres', '-d', 'postgres', '-Fc'))
    run('createdb', '-U', 'postgres', target)
    try:
        run('pg_restore', '-U', 'supabase_admin', '-d', target, '--exit-on-error', data=archive.read_bytes())
        assert sql(target, checks) == before, 'Restored records, permissions or hashes differ'
        print('PASS synthetic database backup/restore: record counts, content checksum, RLS, grants and private bucket')
        print('Storage bytes and hosted recovery not covered by this database-only rehearsal.')
    finally:
        assert target.startswith('studio_restore_') and len(target) == 47
        run('dropdb', '-U', 'postgres', target)


if __name__ == '__main__':
    main()
