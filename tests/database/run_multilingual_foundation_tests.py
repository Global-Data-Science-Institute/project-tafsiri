"""Full synthetic replay in fixed disposable m013 container. No hosted URL."""
import json
from pathlib import Path
import runpy
import subprocess
from uuid import UUID

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = 'tafsiri-m013-validation-db'
COUNT = 0


def uid(n):
    return str(UUID(int=130000+n))


def sql(statement, user='postgres', success=True):
    tcp = ['-h','127.0.0.1'] if user.startswith('m013_') else []
    p = subprocess.run(['docker','exec','-i','-e','PGPASSWORD=synthetic-only',CONTAINER,
                        'psql',*tcp,'-XqAt','-U',user,'-d','postgres','-v','ON_ERROR_STOP=1'],
                       input=statement,text=True,encoding='utf-8',capture_output=True)
    assert (p.returncode == 0) == success, p.stderr + p.stdout[-3000:]
    return p.stdout.strip() if success else p.stderr


def check(label, condition):
    global COUNT
    assert condition, label
    COUNT += 1
    print('PASS:',label,flush=True)


def main():
    prior = runpy.run_path(str(ROOT/'tests/database/run_lexical_promotion_tests.py'))
    prior['main'].__globals__['CONTAINER'] = CONTAINER
    baseline = runpy.run_path(str(ROOT/'tests/database/run_lexical_core_replay_tests.py'))
    baseline['snapshot'].__globals__['CONTAINER'] = CONTAINER
    ddl = next((ROOT/'supabase/migrations').glob('*_multilingual_platform_foundation.sql')).read_text(encoding='utf-8')
    def install():
        before = baseline['snapshot']()
        sql('BEGIN;'+ddl+'SELECT 1/0; COMMIT;',success=False)
        check('013 failed migration rolls back schema and role',sql("SELECT to_regnamespace('language_registry') IS NULL AND NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='tafsiri_registry_reader')")=='t')
        check('013 failure preserves public baseline',baseline['snapshot']()==before)
        sql('BEGIN;'+ddl+'COMMIT;')
        # The only public snapshot delta is the additive evidence-scope enum.
        strip_scope=lambda value: '\n'.join(line for line in value.splitlines()
            if not any(name in line for name in ('|linguistic_evidence_scope_check|','|multilingual_evidence_scope|')))
        check('013 preserves existing identities data grants policies and other constraints',strip_scope(baseline['snapshot']())==strip_scope(before))
        check('013 adds no registry data or authority',sql('SELECT count(*) FROM language_registry.profiles')=='0')
    # Run all prior smoke/promotion/concurrency checks AFTER 013, while preserving
    # the smoke suites' empty-canonical precondition before synthetic promotion.
    prior['main'](after_migration=install)
    sql(f"""
      CREATE ROLE m013_reader LOGIN INHERIT PASSWORD 'synthetic-only';
      CREATE ROLE m013_other LOGIN INHERIT PASSWORD 'synthetic-only';
      GRANT tafsiri_registry_reader TO m013_reader,m013_other;
      INSERT INTO public.contributors(id,name) VALUES('{uid(50)}','SYNTHETIC registry curator');
      INSERT INTO public.languages(id,name) VALUES('{uid(1)}','SYNTHETIC unrelated A'),('{uid(2)}','SYNTHETIC unrelated B without varieties');
      INSERT INTO public.dialects(id,name,language_id) VALUES('{uid(21)}','SYNTHETIC variety A1','{uid(1)}'),('{uid(22)}','SYNTHETIC disputed variety',NULL);
      INSERT INTO language_registry.profiles(id,language_id,community_name,lifecycle,approval_reference,approved_by)
        VALUES('{uid(101)}','{uid(1)}','SYNTHETIC A','RESEARCH_ENABLED','SYNTHETIC approval','{uid(50)}'),
        ('{uid(102)}','{uid(2)}','SYNTHETIC B','REGISTERED','SYNTHETIC approval','{uid(50)}');
      INSERT INTO language_registry.profiles(id,dialect_id,community_name,approval_reference,approved_by)
        VALUES('{uid(121)}','{uid(21)}','SYNTHETIC A1','SYNTHETIC approval','{uid(50)}'),
        ('{uid(122)}','{uid(22)}','SYNTHETIC disputed','SYNTHETIC approval','{uid(50)}');
      INSERT INTO language_registry.classifications(subject_id,object_id,relationship,status,evidence_reference,reviewed_by,reviewed_at)
        VALUES('{uid(101)}','{uid(102)}','UNRELATED_TO','VERIFIED','SYNTHETIC classification','{uid(50)}',now()),
        ('{uid(122)}','{uid(101)}','VARIETY_OF','DISPUTED','SYNTHETIC uncertainty',NULL,NULL);
      INSERT INTO language_registry.names_codes(profile_id,kind,value,standard,standard_version,status,evidence_reference,reviewed_by,reviewed_at)
        VALUES('{uid(101)}','CODE','SYN-A','SYNTHETIC-STANDARD','1','VERIFIED','PRIVATE SYNTHETIC reference','{uid(50)}',now()),
        ('{uid(101)}','ALTERNATIVE_NAME','SYNTHETIC alias',NULL,NULL,'DISPUTED','PRIVATE SYNTHETIC reference',NULL,NULL);
      INSERT INTO language_registry.orthographies(id,profile_id,orthography_key,version,writing_system,script_standard,script_standard_version,direction,normalization,status,evidence_reference,reviewed_by,reviewed_at)
        VALUES('{uid(3)}','{uid(101)}','SYNTHETIC_ORTH','SYNTHETIC-v1','SYNTHETIC_SCRIPT','SYNTHETIC','1','LTR','PRESERVE','VERIFIED','PRIVATE SYNTHETIC reference','{uid(50)}',now()),
        ('{uid(30)}','{uid(101)}','SYNTHETIC_ORTH','SYNTHETIC-v2','SYNTHETIC_SCRIPT','SYNTHETIC','2','RTL','NFC','VERIFIED','PRIVATE SYNTHETIC reference','{uid(50)}',now());
      INSERT INTO language_registry.configurations(id,profile_id,configuration_key,version,orthography_id,content_sha256,approval_reference,approved_by)
        VALUES('{uid(40)}','{uid(101)}','SYNTHETIC_PROFILE',1,'{uid(3)}',repeat('a',64),'PRIVATE SYNTHETIC approval','{uid(50)}');
      INSERT INTO language_registry.access_grants(id,login_name,profile_id,approval_reference,valid_from,valid_until)
        VALUES('{uid(60)}','m013_reader','{uid(101)}','SYNTHETIC access',now()-interval '1 day',now()+interval '1 day');
    """)
    lookup = f"SELECT language_registry.lookup('language','{uid(1)}');"
    info = json.loads(sql(lookup,'m013_reader'))
    check('exact scoped approved lookup',info['id']==uid(1) and info['research_enabled'])
    check('multiple orthographies',len(info['orthographies'])==2)
    check('only verified names and codes',len(info['names_codes'])==1)
    check('no private evidence or reviewer identity in interface','PRIVATE' not in json.dumps(info) and uid(50) not in json.dumps(info))
    check('no inferred model or commercial availability',info['capabilities']==[])
    for user in ('anon','authenticated','service_role','m013_other'):
        error = sql(lookup,user,False) if user.startswith('m013_') else sql('SET ROLE '+user+';'+lookup,success=False)
        check('registry denial '+user, 'permission denied' in error or 'scope access denied' in error)
    for table in ('profiles','names_codes','classifications','orthographies','capabilities','configurations','access_grants','source_scopes','events'):
        check('no direct researcher access '+table,'permission denied' in sql(f'SELECT * FROM language_registry.{table}', 'm013_reader',False))
    check('cross-language denied','scope access denied' in sql(f"SELECT language_registry.lookup('language','{uid(2)}')",'m013_reader',False))
    check('parent does not grant variety','scope access denied' in sql(f"SELECT language_registry.lookup('variety','{uid(21)}')",'m013_reader',False))
    check('missing identity denied','identity required' in sql("SELECT language_registry.lookup('language',NULL)",'m013_reader',False))
    resolved=json.loads(sql(f"SELECT language_registry.resolve_configuration('language','{uid(1)}','SYNTHETIC_PROFILE',1)",'m013_reader'))
    check('exact configuration resolution',resolved['sha256']=='a'*64)
    check('unknown version no fallback','unavailable' in sql(f"SELECT language_registry.resolve_configuration('language','{uid(1)}','SYNTHETIC_PROFILE',2)",'m013_reader',False))
    check('duplicate identity rejected','duplicate key' in sql(f"INSERT INTO language_registry.profiles(language_id,community_name,approval_reference,approved_by) VALUES('{uid(1)}','SYNTHETIC','SYNTHETIC','{uid(50)}')",success=False))
    check('identity cannot move','immutable' in sql(f"UPDATE language_registry.profiles SET language_id='{uid(2)}' WHERE id='{uid(101)}'",success=False))
    check('missing identity rejected','check constraint' in sql(f"INSERT INTO language_registry.profiles(community_name,approval_reference,approved_by) VALUES('SYNTHETIC','SYNTHETIC','{uid(50)}')",success=False))
    check('classification does not mutate legacy parent',sql(f"SELECT language_id IS NULL FROM public.dialects WHERE id='{uid(22)}'")=='t')
    check('language with no varieties remains valid',sql(f"SELECT count(*) FROM public.dialects WHERE language_id='{uid(2)}'")=='0')
    sql(f"INSERT INTO language_registry.access_grants(login_name,profile_id,approval_reference,valid_from,valid_until) VALUES('m013_reader','{uid(122)}','SYNTHETIC',now()-interval '1 day',now()+interval '1 day')")
    check('disputed classification visible without resolution',json.loads(sql(f"SELECT language_registry.lookup('variety','{uid(22)}')",'m013_reader'))['classification_uncertain'])
    sql(f"INSERT INTO language_registry.capabilities(id,profile_id,capability,approval_reference,approved_by,valid_from,valid_until) VALUES('{uid(70)}','{uid(101)}','MODEL_EVALUATION_ELIGIBLE','SYNTHETIC independent decision','{uid(50)}',now()-interval '1 day',now()+interval '1 day')")
    check('independent capability only',json.loads(sql(lookup,'m013_reader'))['capabilities']==['MODEL_EVALUATION_ELIGIBLE'])
    sql(f"UPDATE language_registry.capabilities SET revoked_at=now() WHERE id='{uid(70)}'")
    check('revocation immediate',json.loads(sql(lookup,'m013_reader'))['capabilities']==[])
    check('revocation irreversible','immutable' in sql(f"UPDATE language_registry.capabilities SET revoked_at=NULL WHERE id='{uid(70)}'",success=False))
    sql(f"UPDATE language_registry.profiles SET lifecycle='SUSPENDED' WHERE id='{uid(101)}'")
    check('suspension stops config use','research not enabled' in sql(f"SELECT language_registry.resolve_configuration('language','{uid(1)}','SYNTHETIC_PROFILE',1)",'m013_reader',False))
    sql(f"UPDATE language_registry.profiles SET lifecycle='RESEARCH_ENABLED' WHERE id='{uid(101)}'")
    # Existing canonical path works before adopting new, undigested scope records.
    proposal=prior['proposal'](30000)
    prior['create'](proposal); prior['approve'](proposal)
    check('existing promotion unchanged after 013',prior['command'](proposal,'execute')['ok'])
    # Existing synthetic source identities from 012; no second ingestion system.
    olduid=prior['ident']
    sql(f"""
      INSERT INTO language_registry.source_scopes(source_version_id,source_entry_id,import_batch_id,component,locator,literal_label,language_id,status,evidence_reference,reviewed_by,reviewed_at)
        VALUES('{olduid(11)}','{olduid(15)}','{olduid(13)}','HEADWORD','test:1','SYNTHETIC A','{uid(1)}','VERIFIED','SYNTHETIC review','{uid(50)}',now()),
        ('{olduid(11)}','{olduid(15)}','{olduid(13)}','GLOSS','test:1','SYNTHETIC B','{uid(2)}','VERIFIED','SYNTHETIC review','{uid(50)}',now());
      INSERT INTO language_registry.source_scopes(source_version_id,component,locator,literal_label,status,evidence_reference)
        VALUES('{olduid(11)}','COMMENTARY','test:1','SYNTHETIC UNRESOLVED','UNRESOLVED','SYNTHETIC review');
    """)
    check('multilingual source components preserved',sql('SELECT count(DISTINCT language_id) FROM language_registry.source_scopes')=='2')
    check('unresolved label has no identity',sql("SELECT language_id IS NULL AND dialect_id IS NULL FROM language_registry.source_scopes WHERE status='UNRESOLVED'")=='t')
    check('unresolved cannot acquire identity','immutable' in sql(f"UPDATE language_registry.source_scopes SET language_id='{uid(1)}' WHERE status='UNRESOLVED'",success=False))
    check('wrong source version denied','version mismatch' in sql(f"INSERT INTO language_registry.source_scopes(source_version_id,source_entry_id,component,locator,literal_label,status,evidence_reference) VALUES('00000000-0000-4000-8000-000000009004','{olduid(15)}','HEADWORD','x','SYNTHETIC','UNRESOLVED','SYNTHETIC')",success=False))
    def language_evidence(ident, kind):
        return f"INSERT INTO public.linguistic_evidence(id,source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,extraction_method) SELECT '{uid(ident)}','{olduid(11)}',id,'{kind}','SYNTHETIC:{ident}','SYNTHETIC language evidence','HUMAN','HUMAN_MANUAL' FROM public.linguistic_evidence_types LIMIT 1;"
    def evidence_scope(ident, lang):
        return f"INSERT INTO language_registry.source_scopes(source_version_id,evidence_id,component,locator,literal_label,language_id,status,evidence_reference) VALUES('{olduid(11)}','{uid(ident)}','EVIDENCE','SYNTHETIC:{ident}','SYNTHETIC label','{uid(lang)}','PROPOSED','SYNTHETIC scope');"
    check('language evidence requires explicit language','evidence language scopes required' in sql(language_evidence(80,'LANGUAGE'),success=False))
    sql('BEGIN;'+language_evidence(80,'LANGUAGE')+evidence_scope(80,1)+'COMMIT;')
    check('language-only evidence without invented variety',sql(f"SELECT evidence_scope FROM public.linguistic_evidence WHERE id='{uid(80)}'")=='LANGUAGE')
    check('multilingual evidence requires multiple scopes','evidence language scopes required' in sql('BEGIN;'+language_evidence(81,'MULTILINGUAL')+evidence_scope(81,1)+'COMMIT;',success=False))
    sql('BEGIN;'+language_evidence(81,'MULTILINGUAL')+evidence_scope(81,1)+evidence_scope(81,2)+'COMMIT;')
    check('multilingual evidence explicit scopes',sql(f"SELECT count(*) FROM language_registry.source_scopes WHERE evidence_id='{uid(81)}'")=='2')
    check('verified evidence requires reviewed scopes','evidence language scopes required' in sql(f"UPDATE public.linguistic_evidence SET verification_status='VERIFIED',reviewed_by='{uid(50)}',reviewed_at=now() WHERE id='{uid(80)}'",success=False))
    sql(f"BEGIN; UPDATE language_registry.source_scopes SET status='VERIFIED',reviewed_by='{uid(50)}',reviewed_at=now() WHERE evidence_id='{uid(80)}'; UPDATE public.linguistic_evidence SET verification_status='VERIFIED',reviewed_by='{uid(50)}',reviewed_at=now() WHERE id='{uid(80)}'; COMMIT;")
    check('scope dispute cannot leave verified evidence unsupported','evidence language scopes required' in sql(f"UPDATE language_registry.source_scopes SET status='DISPUTED' WHERE evidence_id='{uid(80)}'",success=False))
    sql(f"BEGIN; UPDATE public.linguistic_evidence SET verification_status='DISPUTED' WHERE id='{uid(80)}'; UPDATE language_registry.source_scopes SET status='DISPUTED' WHERE evidence_id='{uid(80)}'; COMMIT;")
    check('disputed language evidence retained explicitly',sql(f"SELECT verification_status FROM public.linguistic_evidence WHERE id='{uid(80)}'")=='DISPUTED')
    check('audit decisions retained',int(sql('SELECT count(*) FROM language_registry.events'))>=20)
    check('audit deletion denied','immutable' in sql('DELETE FROM language_registry.events',success=False))
    check('audit truncate denied','immutable' in sql('TRUNCATE language_registry.events',success=False))
    sql(f"UPDATE language_registry.access_grants SET revoked_at=now() WHERE id='{uid(60)}'")
    check('access revocation immediate','scope access denied' in sql(lookup,'m013_reader',False))
    proposal=prior['proposal'](31000)
    try:
        prior['create'](proposal)
        raise AssertionError('new scopes accepted by old promotion policy')
    except AssertionError as exc:
        check('new scopes cannot silently bypass promotion digest','new reviewed promotion policy' in str(exc))
    lint=sql("""SELECT p.proname,c.level,c.message FROM pg_proc p
      CROSS JOIN LATERAL extensions.plpgsql_check_function_tb(p.oid::regprocedure) c
      WHERE p.pronamespace='language_registry'::regnamespace AND p.prorettype<>'trigger'::regtype;
      SELECT p.proname,c.level,c.message FROM pg_trigger t JOIN pg_proc p ON p.oid=t.tgfoid
      CROSS JOIN LATERAL extensions.plpgsql_check_function_tb(p.oid::regprocedure,t.tgrelid) c
      WHERE p.pronamespace='language_registry'::regnamespace;""")
    check('registry functions and trigger lint',not lint)
    print(f'PASS: {COUNT} multilingual database checks',flush=True)


if __name__ == '__main__':
    main()
