"""Real two-session SQL-08/SQL-13 races; synthetic disposable container only.

Run after run_lexical_core_replay_tests.py. Fixtures commit for cross-session
visibility and are discarded with the dedicated test container, never deleted
through the canonical API. No connection URLs or live database targets accepted.
"""
import subprocess
import time
from run_lexical_core_replay_tests import CONTAINER, psql


def session(name):
    return subprocess.Popen(
        ["docker", "exec", "-i", CONTAINER, "psql", "-X", "-qAt", "-U", "postgres", "-d", "postgres",
         "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=verbose"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, encoding="utf-8", bufsize=1,
    )


def finish(process):
    process.stdin.close()
    process.stdin = None
    out, err = process.communicate(timeout=15)
    return process.returncode, out, err


def race(label, first, second, expected_state=None):
    a, b = session("a"), session("b")
    try:
        a.stdin.write("SET application_name='m011-race-a'; BEGIN;\n" + first + "\nSELECT 'A_READY';\n")
        a.stdin.flush()
        # psql emits this only after A holds the conflicting row/index/advisory lock.
        assert a.stdout.readline().strip() == "A_READY", "session A failed before barrier"
        b.stdin.write("SET application_name='m011-race-b'; BEGIN;\n" + second + "\nCOMMIT;\n")
        b.stdin.flush()
        deadline = time.monotonic() + 10
        blocked = False
        while time.monotonic() < deadline:
            blocked = psql("SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE application_name='m011-race-b' AND wait_event_type='Lock');").stdout.strip() == "t"
            if blocked or b.poll() is not None:
                break
            time.sleep(0.05)
        assert blocked, "session B did not wait for the conflicting transaction"
        a.stdin.write("COMMIT;\n")
        a.stdin.flush()
        assert finish(a)[0] == 0
        code, out, err = finish(b)
        if expected_state:
            assert code != 0 and expected_state in err, out + err
        else:
            assert code == 0, out + err
        print("PASS: " + label)
    finally:
        for process in (a, b):
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)


def main():
    psql("""
      INSERT INTO public.languages(id,name) VALUES('10000000-0000-4000-8000-000000000001','M011 race language');
      INSERT INTO public.contributors(id,name) VALUES('10000000-0000-4000-8000-000000000002','M011 race reviewer');
      INSERT INTO public.lexemes(id,lexeme_key,language_id,provenance_origin) VALUES
        ('10000000-0000-4000-8000-000000000011','M011-RACE-L1','10000000-0000-4000-8000-000000000001','HUMAN'),
        ('10000000-0000-4000-8000-000000000012','M011-RACE-L2','10000000-0000-4000-8000-000000000001','HUMAN');
      INSERT INTO public.lexical_senses(id,sense_key,lexeme_id,provenance_origin) VALUES
        ('10000000-0000-4000-8000-000000000020','M011-RACE-S1','10000000-0000-4000-8000-000000000011','HUMAN');
      INSERT INTO public.concepts(id,concept_key,definition_en) VALUES
        ('10000000-0000-4000-8000-000000000031','M011-RACE-C1','Synthetic race concept 1'),
        ('10000000-0000-4000-8000-000000000032','M011-RACE-C2','Synthetic race concept 2');
      INSERT INTO public.sense_concepts(id,sense_id,concept_id,provenance_origin,rationale) VALUES
        ('10000000-0000-4000-8000-000000000041','10000000-0000-4000-8000-000000000020','10000000-0000-4000-8000-000000000031','HUMAN','fixture'),
        ('10000000-0000-4000-8000-000000000042','10000000-0000-4000-8000-000000000020','10000000-0000-4000-8000-000000000032','HUMAN','fixture');
      INSERT INTO public.lexeme_forms(id,form_key,lexeme_id,representation_text,representation_system,form_role,provenance_origin) VALUES
        ('10000000-0000-4000-8000-000000000051','M011-RACE-F1','10000000-0000-4000-8000-000000000011','fixture 1','ORTHOGRAPHIC','LEMMA','HUMAN'),
        ('10000000-0000-4000-8000-000000000052','M011-RACE-F2','10000000-0000-4000-8000-000000000011','fixture 2','ORTHOGRAPHIC','LEMMA','HUMAN');
    """)
    base = "UPDATE public.sense_concepts SET mapping_status='VERIFIED',reviewed_by='10000000-0000-4000-8000-000000000002',reviewed_at=now() WHERE id="
    race("SQL-08 concurrent verified mappings serialize and reject duplicate",
         base + "'10000000-0000-4000-8000-000000000041';",
         base + "'10000000-0000-4000-8000-000000000042';", "23505")
    race("SQL-08 concurrent current pointers serialize on the parent",
         "UPDATE public.lexemes SET current_lemma_form_id='10000000-0000-4000-8000-000000000051' WHERE lexeme_key='M011-RACE-L1';",
         "UPDATE public.lexemes SET current_lemma_form_id='10000000-0000-4000-8000-000000000052' WHERE lexeme_key='M011-RACE-L1';")
    assert psql("SELECT current_lemma_form_id='10000000-0000-4000-8000-000000000052' FROM public.lexemes WHERE lexeme_key='M011-RACE-L1';").stdout.strip() == "t"
    race("SQL-13 concurrent successor cycle rejected at commit",
         "UPDATE public.lexemes SET lifecycle_status='SUPERSEDED',superseded_by='10000000-0000-4000-8000-000000000012' WHERE lexeme_key='M011-RACE-L1';",
         "UPDATE public.lexemes SET lifecycle_status='SUPERSEDED',superseded_by='10000000-0000-4000-8000-000000000011' WHERE lexeme_key='M011-RACE-L2';", "23514")
    result = psql("BEGIN ISOLATION LEVEL REPEATABLE READ; UPDATE public.lexemes SET lifecycle_status='SUPERSEDED',superseded_by='10000000-0000-4000-8000-000000000011' WHERE lexeme_key='M011-RACE-L2'; COMMIT;", success=False)
    assert "require READ COMMITTED or SERIALIZABLE" in result.stderr
    print("PASS: SQL-13 repeatable-read successor edits fail closed")


if __name__ == "__main__":
    main()
