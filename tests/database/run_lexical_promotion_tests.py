"""Synthetic-only Migration 012 tests, fixed disposable container, no hosted URL.

Create tafsiri-m012-validation-db from the cached Supabase PostgreSQL image first.
Existing local stack is used ONLY for schema-only Auth/history bootstrap by the
Migration 011 harness. All data here are invented fixtures, not Luhya vocabulary.
"""
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import runpy
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = "tafsiri-m012-validation-db"
MIGRATION = next((ROOT / "supabase/migrations").glob("*_create_canonical_lexical_promotion_governance.sql"))
COUNT = 0


def sql(text, user="postgres", success=True):
    connection = ["-h", "127.0.0.1"] if user.startswith("m012_") else []
    p = subprocess.run(["docker", "exec", "-i", "-e", "PGPASSWORD=synthetic-test-only", CONTAINER, "psql", *connection, "-XqAt", "-U", user, "-d", "postgres", "-v", "ON_ERROR_STOP=1"],
                       input=text, text=True, encoding="utf-8", capture_output=True)
    if (p.returncode == 0) != success:
        raise AssertionError(p.stdout[-3000:] + p.stderr)
    return p.stdout.strip() if success else p.stderr


def q(value):
    return "'" + str(value).replace("'", "''") + "'"


def ident(n):
    return str(uuid.UUID(int=120000+n))


def check(label, condition):
    global COUNT
    assert condition, label
    COUNT += 1
    print("PASS:", label)


def command(p, action="dry_run", user="m012_proposer", decision=None):
    return json.loads(sql(f"SELECT lexical_governance.command({q(p['id'])}::uuid,{q(action)},{q(json.dumps(decision or {}))}::jsonb);", user))


def create(p):
    return sql(f"SELECT lexical_governance.create_proposal({q(json.dumps(p))}::jsonb);", "m012_proposer")


def fixture():
    sql(f"""
      CREATE ROLE m012_proposer LOGIN INHERIT PASSWORD 'synthetic-test-only'; CREATE ROLE m012_approver LOGIN INHERIT PASSWORD 'synthetic-test-only';
      CREATE ROLE m012_stranger LOGIN INHERIT PASSWORD 'synthetic-test-only';
      GRANT tafsiri_lexical_researcher TO m012_proposer,m012_approver,m012_stranger;
      INSERT INTO public.contributors(id,name) VALUES ('{ident(1)}','Invented proposer'),('{ident(2)}','Invented approver'),('{ident(3)}','Invented unauthorized reviewer');
      INSERT INTO lexical_governance.principals(login_name,contributor_id) VALUES ('m012_proposer','{ident(1)}'),('m012_approver','{ident(2)}'),('m012_stranger','{ident(3)}');
      INSERT INTO public.languages(id,name) VALUES ('{ident(4)}','SYNTHETIC language; not linguistic data');
      INSERT INTO public.dialects(id,name,language_id) VALUES ('{ident(5)}','SYNTHETIC Luwanga test scope','{ident(4)}'),('{ident(6)}','SYNTHETIC second variety','{ident(4)}');
      INSERT INTO public.contributor_roles(id,contributor_id,role_type_id,dialect_id,domain)
        SELECT '{ident(7)}','{ident(2)}',id,'{ident(5)}','LEXICAL' FROM public.contributor_role_types WHERE role_type_key='CANONICAL_APPROVER';
      INSERT INTO lexical_governance.authorities(id,contributor_role_id,dialect_id,operation_keys,competence_reference,valid_from,valid_until)
        VALUES ('{ident(8)}','{ident(7)}','{ident(5)}',ARRAY['insert:lexemes','insert:lexeme_forms','insert:lexical_senses','insert:lexical_sense_revisions',
        'insert:lexeme_dialects','insert:sense_dialects','insert:sense_concepts','insert:lexical_relationships','insert:form_relationships','insert:lexical_attestations','insert:lexical_linguistic_evidence',
        'set_current:lexemes','set_current:lexical_senses','dispute:lexical_senses','dispute:lexemes','dispute:sense_concepts'],
        'SYNTHETIC qualification reviewed by fixture owner',now()-interval '1 day',now()+interval '1 day');
      INSERT INTO public.sources(id,source_key,source_type,title) VALUES ('{ident(10)}','M012-SYNTHETIC','OTHER','Invented source for software tests');
      INSERT INTO public.source_versions(id,source_id,version_key) VALUES ('{ident(11)}','{ident(10)}','SYNTHETIC-1');
      INSERT INTO public.source_artifacts(id,artifact_key,checksum_algorithm,checksum,byte_size,media_type)
        VALUES ('{ident(12)}','M012-ARTIFACT','SHA256',repeat('a',64),1,'text/plain');
      INSERT INTO public.source_version_artifacts(source_version_id,source_artifact_id,artifact_role) VALUES ('{ident(11)}','{ident(12)}','SOURCE_REPRESENTATION');
      INSERT INTO public.source_import_batches(id,source_version_id,import_batch_key,artifact_checksum,checksum_algorithm,import_method,import_tool,import_tool_version)
        VALUES ('{ident(13)}','{ident(11)}','SYNTHETIC',repeat('a',64),'SHA256','SYNTHETIC','TEST','1');
      INSERT INTO public.source_rights(id,source_version_id,rights_status) VALUES ('{ident(14)}','{ident(11)}','PERMISSION_GRANTED');
      INSERT INTO public.source_use_policies(source_version_id,use_scope,decision,policy_version,policy_basis_reference,effective_at)
        SELECT '{ident(11)}',x,'ALLOWED','SYNTHETIC-1','Invented test permission',now()-interval '1 day' FROM unnest(ARRAY['INTERNAL_RESEARCH','HUMAN_REVIEW']) x;
      INSERT INTO public.source_use_policies(source_version_id,use_scope,decision,policy_version)
        SELECT '{ident(11)}',x,'UNKNOWN','SYNTHETIC-1' FROM unnest(ARRAY['MODEL_TRAINING','COMMERCIAL_API']) x;
      INSERT INTO public.source_entries(id,source_version_id,import_batch_id,original_entry_locator,original_form,original_gloss,raw_dialect_label,source_entry_checksum)
        VALUES ('{ident(15)}','{ident(11)}','{ident(13)}','test:1','SYNTHETIC_TOKEN_A','Invented sense A','SYNTHETIC_LABEL','synthetic-1'),
        ('{ident(16)}','{ident(11)}','{ident(13)}','test:2','SYNTHETIC_TOKEN_A','Invented contrary sense','SYNTHETIC_LABEL','synthetic-2');
      INSERT INTO public.linguistic_evidence(id,source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,verification_status,extraction_method,reviewed_by,reviewed_at)
        SELECT '{ident(17)}','{ident(11)}',id,'DIALECT','test:1','SYNTHETIC faithfully transcribed claim','HUMAN','VERIFIED','HUMAN_MANUAL','{ident(2)}',now() FROM public.linguistic_evidence_types LIMIT 1;
      INSERT INTO public.linguistic_evidence(id,source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,verification_status,extraction_method,reviewed_by,reviewed_at)
        SELECT '{ident(18)}','{ident(11)}',id,'DIALECT','test:2','SYNTHETIC conflicting interpretation','HUMAN','VERIFIED','HUMAN_MANUAL','{ident(2)}',now() FROM public.linguistic_evidence_types LIMIT 1;
      INSERT INTO public.linguistic_evidence_relations VALUES ('{ident(17)}','{ident(18)}','CONTRADICTS','Synthetic conflict',now());
      INSERT INTO public.linguistic_evidence_dialects(evidence_id,dialect_id,role) VALUES ('{ident(17)}','{ident(5)}','PRIMARY'),('{ident(18)}','{ident(5)}','PRIMARY');
      INSERT INTO public.source_dialect_mapping_assertions(source_version_id,raw_dialect_label,canonical_dialect_id,mapping_scope,authority,rationale,verification_status,policy_version,reviewed_by,reviewed_at)
        VALUES ('{ident(11)}','SYNTHETIC_LABEL','{ident(5)}','SOURCE_VERSION','Synthetic human authority','Synthetic exact scope','VERIFIED','SYNTHETIC-1','{ident(2)}',now());
      INSERT INTO public.concepts(id,concept_key,definition_en) VALUES ('{ident(19)}','M012-SYNTHETIC-CONCEPT','Invented concept');
    """)


def proposal(seed=1000, dialect=5):
    def uid(n): return ident(seed+n)
    p = {"id": uid(0), "idempotency_key": f"SYNTHETIC-{seed}", "proposal_type": "CREATE", "proposal_version": 1,
         "policy_version": "LEXICAL_PROMOTION_001", "dialect_id": ident(dialect), "provenance_origin": "HUMAN",
         "contradiction_statement": "Invented conflicting interpretation disclosed for independent assessment.",
         "evidence": [{"source_entry_id": ident(15), "evidence_id": ident(17), "artifact_id": ident(12), "role": "SUPPORTS"},
                      {"source_entry_id": ident(16), "evidence_id": ident(18), "artifact_id": ident(12), "role": "CONTRADICTS"}], "operations": []}
    def add(table, data, action="insert", **kwargs):
        p["operations"].append({"table": table, "action": action, "data": data, **kwargs})
    add("lexemes", {"id": uid(1), "lexeme_key": f"SYNTHETIC-LEX-{seed}", "identity_dialect_id": ident(dialect)})
    add("lexeme_forms", {"id": uid(2), "form_key": f"SYNTHETIC-FORM-{seed}", "lexeme_id": uid(1), "representation_text": "SYNTHETIC_TOKEN_A", "representation_system": "ORTHOGRAPHIC", "form_role": "LEMMA", "dialect_id": ident(dialect)})
    add("lexical_senses", {"id": uid(3), "sense_key": f"SYNTHETIC-SENSE-{seed}", "lexeme_id": uid(1)})
    add("lexical_sense_revisions", {"id": uid(4), "sense_id": uid(3), "revision_number": 1, "definition": "Invented test meaning, not a translation", "definition_language_id": ident(4), "revision_reason": "Synthetic software test"})
    add("lexemes", {"id": uid(1), "current_lemma_form_id": uid(2)}, "set_current", expected={"current_lemma_form_id": None})
    add("lexical_senses", {"id": uid(3), "current_revision_id": uid(4)}, "set_current", expected={"current_revision_id": None})
    add("sense_concepts", {"id": uid(5), "sense_id": uid(3), "concept_id": ident(19), "rationale": "Invented mapping"})
    for i, (field, target, claim) in enumerate([("lexeme_id", 1, "LEXEME_IDENTITY"), ("form_id", 2, "FORM"), ("sense_revision_id", 4, "SENSE"), ("sense_concept_id", 5, "CONCEPT_MAPPING")]):
        add("lexical_attestations", {"id": uid(20+i), "attestation_key": f"SYNTHETIC-{seed}-AT-{i}", "source_entry_id": ident(15), field: uid(target), "claim_type": claim, "evidence_role": "SUPPORTS"})
    add("lexical_attestations", {"id": uid(25), "attestation_key": f"SYNTHETIC-{seed}-CONTRA", "source_entry_id": ident(16), "sense_revision_id": uid(4), "claim_type": "SENSE", "evidence_role": "CONTRADICTS"})
    add("lexical_linguistic_evidence", {"id": uid(26), "evidence_id": ident(17), "sense_revision_id": uid(4), "evidence_role": "OTHER"})
    return p


def approve(p):
    r = command(p, "submit"); assert r["ok"], r
    r = command(p, "review", "m012_approver"); assert r["ok"], r
    digest = sql(f"SELECT evidence_digest FROM lexical_governance.proposals WHERE id={q(p['id'])};")
    r = command(p, "approve", "m012_approver", {"evidence_digest": digest, "source_fidelity_confirmed": True,
                                              "scope_assessment": "Synthetic exact scope reviewed", "contradiction_assessment": "Synthetic conflict retained, limited claim approved"})
    assert r["ok"], r


def denied(p, action, fragment, user="m012_proposer"):
    r = command(p, action, user)
    check(fragment, r.get("ok") is False and fragment in str(r))
    if action=='dry_run':
        assert r['planned_operations']==p['operations'] and r['evidence']==p['evidence'], 'failed dry run must still report the proposed plan'


def transactional_command(p, setup, action="execute"):
    # Owner changes are fixture-only and rolled back. SET SESSION AUTHORIZATION
    # here lets the test exercise the immutable login identity under that setup.
    statement = ("BEGIN;" + setup + "SET SESSION AUTHORIZATION m012_proposer;"
                 + f"SELECT lexical_governance.command('{p['id']}',{q(action)}); ROLLBACK;")
    return json.loads(sql(statement, "supabase_admin"))


def extended_checks(p):
    # Boundary: membership, caller claims, and service keys cannot supply authority.
    for role in ("anon", "authenticated", "service_role"):
        error = sql(f"SET ROLE {role}; SELECT lexical_governance.command('{p['id']}');", success=False)
        check(role + " cannot call private promotion", "permission denied" in error)
    for table in ("principals", "authorities", "proposals", "events", "outputs"):
        error = sql(f"SELECT * FROM lexical_governance.{table};", "m012_stranger", success=False)
        check("private " + table, "permission denied" in error)
    error = sql(f"INSERT INTO lexical_governance.authorities(contributor_role_id) VALUES ('{ident(7)}');", "m012_approver", success=False)
    check("approver cannot expand qualification", "permission denied" in error)
    error = sql(f"SELECT lexical_governance.apply_operations(p,'{ident(2)}') FROM lexical_governance.proposals p;", "m012_approver", success=False)
    check("internal engine not callable", "permission denied" in error)
    error = sql(f"SET ROLE service_role; UPDATE public.lexemes SET lifecycle_status='DISPUTED';", success=False)
    check("service direct canonical write denied", "permission denied" in error)
    error = sql(f"SET ROLE service_role; UPDATE public.concepts SET provenance_origin='HUMAN' WHERE id='{ident(19)}';", success=False)
    check("service cannot adopt legacy concepts", "concept governance requires" in error)
    error = sql(f"SELECT set_config('request.jwt.claim.sub','{ident(2)}',false); SET SESSION AUTHORIZATION m012_approver;", "m012_proposer", success=False)
    check("login identity cannot be forged", "permission denied" in error)
    denied(p, "inspect", "missing current scoped authority", "m012_stranger")
    check("unauthorized attempt auditable", sql("SELECT count(*)>0 FROM lexical_governance.events WHERE action='FAILED_INSPECT';") == "t")
    draft = proposal(2000); create(draft)
    denied(draft, "approve", "illegal action")
    denied(draft, "execute", "illegal action")
    command(draft, "submit")
    denied(draft, "review", "independent canonical approver required")
    check("withdraw remains auditable", command(draft, "withdraw")["ok"])
    denied(draft, "submit", "illegal action")
    check("create identical request idempotent", create(draft) == draft["id"])
    changed = {**draft, "proposal_version": 2}
    check("idempotency collision rejects changed request", "different content" in sql(f"SELECT lexical_governance.create_proposal({q(json.dumps(changed))});", "m012_proposer", False))
    negative = proposal(3000); create(negative); approve(negative)
    mutations = [
        (f"UPDATE public.linguistic_evidence SET verification_status='UNVERIFIED' WHERE id='{ident(17)}';", "human verification"),
        (f"UPDATE public.source_rights SET rights_status='UNKNOWN' WHERE id='{ident(14)}';", "source rights"),
        (f"UPDATE public.source_rights SET expires_at=now()-interval '1 hour' WHERE id='{ident(14)}';", "source rights"),
        ("UPDATE public.source_use_policies SET decision='DISALLOWED' WHERE use_scope='INTERNAL_RESEARCH';", "permissions required"),
        (f"UPDATE public.source_dialect_mapping_assertions SET verification_status='DISPUTED' WHERE source_version_id='{ident(11)}';", "unresolved or conflicting"),
        (f"UPDATE public.source_artifacts SET artifact_status='QUARANTINED' WHERE id='{ident(12)}';", "lineage mismatch"),
        (f"UPDATE public.linguistic_evidence SET notes='changed after review' WHERE id='{ident(17)}';", "checksum changed"),
        (f"UPDATE lexical_governance.authorities SET revoked_at=now() WHERE id='{ident(8)}';", "scoped authority"),
        (f"UPDATE public.contributor_roles SET revoked_at=now() WHERE id='{ident(7)}';", "scoped authority"),
        (f"UPDATE public.contributor_roles SET valid_until=now()-interval '1 second',valid_from=now()-interval '2 days' WHERE id='{ident(7)}';", "scoped authority"),
        ("UPDATE lexical_governance.principals SET revoked_at=now() WHERE login_name='m012_approver';", "login revoked"),
    ]
    for setup, message in mutations:
        r = transactional_command(negative, setup)
        check("execution revalidates " + message, not r["ok"] and message in str(r))
    # A late uniqueness failure after earlier inserts must leave no partial rows.
    setup = f"INSERT INTO public.lexeme_forms(form_key,lexeme_id,representation_text,representation_system,form_role,provenance_origin) VALUES('SYNTHETIC-FORM-3000','{ident(1001)}','SYNTHETIC CONFLICT','ORTHOGRAPHIC','OTHER','HUMAN');"
    r = transactional_command(negative, setup)
    check("late failure rolls back entire proposal", not r["ok"] and r["sqlstate"] == "23505")
    check("no partial canonical/output records", sql(f"SELECT NOT EXISTS(SELECT 1 FROM public.lexemes WHERE id='{ident(3001)}') AND NOT EXISTS(SELECT 1 FROM lexical_governance.outputs WHERE proposal_id='{negative['id']}');") == "t")
    # Failure audit survives a real committed invocation (not a test rollback).
    invalid = proposal(4000); invalid["evidence"] = invalid["evidence"][:1]; create(invalid)
    denied(invalid, "submit", "contradictory/alternative evidence omitted")
    check("failed submission audit persists", sql(f"SELECT count(*)=1 FROM lexical_governance.events WHERE proposal_id='{invalid['id']}' AND action='FAILED_SUBMIT';") == "t")
    # Structural ownership and scope errors run the real schema constraints.
    for seed, change, fragment in [
        (5000, lambda x: x["operations"][0]["data"].update(identity_dialect_id=ident(6)), "scope mismatch"),
        (6000, lambda x: x["operations"][1]["data"].update(dialect_id=ident(6)), "scope expansion"),
        (7000, lambda x: x["operations"][5]["data"].update(current_revision_id=ident(1004)), "foreign key"),
        (8000, lambda x: x["operations"][0]["data"].update(verification_status="VERIFIED"), "managed fields"),
    ]:
        x = proposal(seed); change(x); create(x); denied(x, "dry_run", fragment)
    x = proposal(9000, 6); create(x)
    denied(x, "dry_run", "incompatible linguistic scope")
    denied(x, "review", "scoped authority", "m012_approver")
    # Approval digest must be explicitly acknowledged, not just valid server-side.
    x = proposal(10000); create(x); command(x, "submit"); command(x, "review", "m012_approver")
    r = command(x, "approve", "m012_approver", {"evidence_digest": "0"*64})
    check("approver must acknowledge exact evidence and assessments", not r["ok"] and "explicit reviewed digest" in str(r))
    r = command(x, "reject", "m012_approver", {"reason": "Synthetic rejection"})
    check("rejection retained", r["ok"] and command(x, "inspect")["proposal"]["state"] == "REJECTED")
    # Same spelling within a scope never collapses stable lexical identities.
    x = proposal(11000); create(x); approve(x); check("homograph executes independently", command(x, "execute")["ok"])
    check("homographs distinct", sql("SELECT count(DISTINCT lexeme_id)=2 FROM public.lexeme_forms WHERE representation_text='SYNTHETIC_TOKEN_A';") == "t")
    for seed, form_role, spelling in ((12000,"HISTORICAL","SYNTHETIC_OLD_SPELLING"),(13000,"BORROWED","SYNTHETIC_BORROWED_TERM"),(14000,"OTHER","ORIGINAL_TECHNICAL_TERM")):
        x=proposal(seed); x["operations"][1]["data"].update(form_role=form_role,representation_text=spelling)
        x['operations']=[op for op in x['operations'] if not (op['table']=='lexemes' and op['action']=='set_current')]
        create(x); approve(x); check("synthetic " + form_role + " preserves supplied form", command(x,"execute")["ok"])
    check("missing equivalent does not invent lexical text", sql(f"SELECT representation_text FROM public.lexeme_forms WHERE id='{ident(14002)}';") == "ORIGINAL_TECHNICAL_TERM")
    check("sealed meaning cannot be rewritten", "sealed lexical content" in sql(f"UPDATE public.lexical_sense_revisions SET definition='overwrite' WHERE id='{ident(1004)}';", success=False))
    revision_checks()
    authority_and_scope_checks()
    concurrency_checks()


def revision_checks():
    p=proposal(18000); p['proposal_type']='REVISE'
    p['operations']=[
        {'table':'lexical_sense_revisions','action':'insert','data':{'id':ident(18004),'sense_id':ident(1003),'revision_number':2,'definition':'SYNTHETIC revised meaning','definition_language_id':ident(4),'revision_reason':'Independent synthetic review'}},
        {'table':'lexical_senses','action':'set_current','data':{'id':ident(1003),'current_revision_id':ident(18004)},'expected':{'current_revision_id':ident(1004)}},
    ]
    for i, ev in enumerate(p['evidence']):
        p['operations'].append({'table':'lexical_attestations','action':'insert','data':{'id':ident(18020+i),'attestation_key':f'SYNTHETIC-REV2-{i}','source_entry_id':ev['source_entry_id'],'sense_revision_id':ident(18004),'claim_type':'SENSE','evidence_role':ev['role']}})
    create(p); approve(p)
    rival=proposal(19000); rival['proposal_type']='REVISE'
    rival['operations']=json.loads(json.dumps(p['operations']).replace(ident(18004),ident(19004)).replace(ident(18020),ident(19020)).replace(ident(18021),ident(19021)).replace('SYNTHETIC-REV2','SYNTHETIC-RIVAL'))
    rival['operations'][0]['data']['revision_number']=3
    create(rival); approve(rival)
    check('new immutable meaning revision executes', command(p,'execute')['ok'])
    denied(rival,'execute','stale canonical revision')
    check('old meaning retained and new pointer set', sql(f"SELECT (SELECT definition FROM public.lexical_sense_revisions WHERE id='{ident(1004)}')='Invented test meaning, not a translation' AND (SELECT current_revision_id FROM public.lexical_senses WHERE id='{ident(1003)}')='{ident(18004)}'::uuid;")=='t')
    check('stale revision insertion rolled back',sql(f"SELECT NOT EXISTS(SELECT 1 FROM public.lexical_sense_revisions WHERE id='{ident(19004)}');")=='t')
    # A distinct sense uses the same lexeme; no overwrite or forced concept merge.
    p=proposal(20000); p['operations']=[op for op in p['operations'] if op['table'] not in ('lexemes','lexeme_forms') and not (op['table']=='lexical_attestations' and ('lexeme_id' in op['data'] or 'form_id' in op['data']))]
    p['operations'][0]['data']['lexeme_id']=ident(1001)
    create(p); approve(p); check('multiple independent senses supported', command(p,'execute')['ok'])
    check('two senses retain shared lexical parent',sql(f"SELECT count(*)=2 FROM public.lexical_senses WHERE lexeme_id='{ident(1001)}';")=='t')
    p=proposal(21000); p['proposal_type']='DISPUTE'; p['operations']=[{'table':'lexical_senses','action':'dispute','data':{'id':ident(1003)},'expected':{'verification_status':'VERIFIED'}}]
    for i,ev in enumerate(p['evidence']):
        p['operations'].append({'table':'lexical_attestations','action':'insert','data':{'id':ident(21020+i),'attestation_key':f'SYNTHETIC-DISPUTE-{i}','source_entry_id':ev['source_entry_id'],'sense_revision_id':ident(18004),'claim_type':'SENSE','evidence_role':ev['role']}})
    create(p); approve(p); check('disputed interpretation separately governed',command(p,'execute')['ok'])
    r=command(p,'dispute','m012_approver',{'reason':'Synthetic dispute of decision'})
    check('post-execution dispute preserves decision and outputs',r['ok'] and command(p,'inspect')['proposal']['approved_by']==ident(2) and len(command(p,'inspect')['outputs'])==3)
    for table in ('events','outputs','proposals'):
        message='proposal history cannot be deleted' if table=='proposals' else 'governance history is append-only'
        check('immutable '+table, message in sql(f'DELETE FROM lexical_governance.{table};',success=False))


def authority_and_scope_checks():
    p=proposal(22000); create(p); approve(p)
    expired=f"UPDATE lexical_governance.authorities SET revoked_at=now() WHERE id='{ident(8)}'; INSERT INTO lexical_governance.authorities(contributor_role_id,dialect_id,operation_keys,competence_reference,valid_from,valid_until) SELECT contributor_role_id,dialect_id,operation_keys,'SYNTHETIC EXPIRED',now()-interval '2 days',now()-interval '1 day' FROM lexical_governance.authorities WHERE id='{ident(8)}';"
    r=transactional_command(p,expired)
    check('expired competence qualification denied',not r['ok'] and 'scoped authority' in str(r))
    r=transactional_command(p,f"UPDATE public.contributor_roles SET domain='OTHER' WHERE id='{ident(7)}';")
    check('research role domain checked',not r['ok'] and 'scoped authority' in str(r))
    r=transactional_command(p,f"UPDATE public.linguistic_evidence_dialects SET dialect_id='{ident(6)}' WHERE evidence_id='{ident(17)}';")
    check('classification cannot expand evidence scope',not r['ok'] and 'incompatible linguistic scope' in str(r))
    # Independent source lineage and qualifications for the second variety.
    sql(f"""
      INSERT INTO public.contributor_roles(id,contributor_id,role_type_id,dialect_id,domain)
        SELECT '{ident(30)}','{ident(2)}',role_type_id,'{ident(6)}','LEXICAL' FROM public.contributor_roles WHERE id='{ident(7)}';
      INSERT INTO lexical_governance.authorities(contributor_role_id,dialect_id,operation_keys,competence_reference,valid_from,valid_until)
        SELECT '{ident(30)}','{ident(6)}',operation_keys,'SYNTHETIC independently reviewed second variety',valid_from,valid_until FROM lexical_governance.authorities WHERE id='{ident(8)}';
      INSERT INTO public.source_versions(id,source_id,version_key) VALUES ('{ident(31)}','{ident(10)}','SYNTHETIC-VARIETY-2');
      INSERT INTO public.source_version_artifacts(source_version_id,source_artifact_id,artifact_role) VALUES ('{ident(31)}','{ident(12)}','SOURCE_REPRESENTATION');
      INSERT INTO public.source_import_batches(id,source_version_id,import_batch_key,artifact_checksum,checksum_algorithm,import_method,import_tool,import_tool_version)
        VALUES ('{ident(33)}','{ident(31)}','SYNTHETIC',repeat('a',64),'SHA256','SYNTHETIC','TEST','1');
      INSERT INTO public.source_rights(source_version_id,rights_status) VALUES ('{ident(31)}','PERMISSION_GRANTED');
      INSERT INTO public.source_use_policies(source_version_id,use_scope,decision,policy_version,policy_basis_reference,effective_at)
        SELECT '{ident(31)}',x,'ALLOWED','SYNTHETIC','Synthetic permission',now()-interval '1 day' FROM unnest(ARRAY['INTERNAL_RESEARCH','HUMAN_REVIEW']) x;
      INSERT INTO public.source_entries(id,source_version_id,import_batch_id,original_entry_locator,original_form,raw_dialect_label,source_entry_checksum)
        VALUES ('{ident(35)}','{ident(31)}','{ident(33)}','test:1','SYNTHETIC_TOKEN_A','SYNTHETIC_SECOND_LABEL','test-second');
      INSERT INTO public.linguistic_evidence(id,source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,verification_status,extraction_method,reviewed_by,reviewed_at)
        SELECT '{ident(37)}','{ident(31)}',evidence_type_id,'DIALECT','test:1','SYNTHETIC second variety claim','HUMAN','VERIFIED','HUMAN_MANUAL','{ident(2)}',now() FROM public.linguistic_evidence WHERE id='{ident(17)}';
      INSERT INTO public.linguistic_evidence_dialects(evidence_id,dialect_id,role) VALUES ('{ident(37)}','{ident(6)}','PRIMARY');
      INSERT INTO public.source_dialect_mapping_assertions(source_version_id,raw_dialect_label,canonical_dialect_id,mapping_scope,authority,rationale,verification_status,policy_version,reviewed_by,reviewed_at)
        VALUES ('{ident(31)}','SYNTHETIC_SECOND_LABEL','{ident(6)}','SOURCE_VERSION','Synthetic authority','Synthetic exact second scope','VERIFIED','SYNTHETIC','{ident(2)}',now());
    """)
    p=proposal(23000,6); p['evidence']=[{'source_entry_id':ident(35),'evidence_id':ident(37),'artifact_id':ident(12),'role':'SUPPORTS'}]
    p['operations']=[op for op in p['operations'] if op['data'].get('evidence_role')!='CONTRADICTS']
    for op in p['operations']:
        if 'source_entry_id' in op['data']: op['data']['source_entry_id']=ident(35)
        if 'evidence_id' in op['data']: op['data']['evidence_id']=ident(37)
    create(p); approve(p); check('second variety same spelling independently approved',command(p,'execute')['ok'])
    check('same spelling preserves distinct variety identities',sql("SELECT count(DISTINCT l.identity_dialect_id)=2 FROM public.lexemes l JOIN public.lexeme_forms f ON f.lexeme_id=l.id WHERE f.representation_text='SYNTHETIC_TOKEN_A';")=='t')
    p=proposal(24000); p['proposal_type']='ASSERT'
    p['operations']=[
        {'table':'lexeme_dialects','action':'insert','data':{'id':ident(24001),'lexeme_id':ident(1001),'dialect_id':ident(5),'role':'PRIMARY'}},
        {'table':'sense_dialects','action':'insert','data':{'id':ident(24002),'sense_id':ident(20003),'dialect_id':ident(5),'role':'APPLIES_TO'}},
        {'table':'lexical_relationships','action':'insert','data':{'id':ident(24003),'source_lexeme_id':ident(1001),'target_lexeme_id':ident(11001),'relationship_type':'DERIVED_FROM'}},
        {'table':'form_relationships','action':'insert','data':{'id':ident(24004),'source_form_id':ident(1002),'target_form_id':ident(11002),'relationship_type':'BORROWED_FORM'}},
    ]
    for i,(field,target) in enumerate([('lexical_relationship_id',24003),('form_relationship_id',24004)]):
        p['operations'].append({'table':'lexical_attestations','action':'insert','data':{'id':ident(24020+i),'attestation_key':f'SYNTHETIC-REL-{i}','source_entry_id':ident(15),field:ident(target),'claim_type':'RELATIONSHIP','evidence_role':'SUPPORTS'}})
    p['operations'].append({'table':'lexical_attestations','action':'insert','data':{'id':ident(24025),'attestation_key':'SYNTHETIC-REL-CONTRA','source_entry_id':ident(16),'lexical_relationship_id':ident(24003),'claim_type':'RELATIONSHIP','evidence_role':'CONTRADICTS'}})
    create(p); approve(p); check('dialect scope and lexical/form relationships governed',command(p,'execute')['ok'])
    # This is a new relationship to a different variety, not a duplicate row.
    p=proposal(25000); p['operations'][0]['data']['identity_dialect_id']=ident(5)
    p['operations'].insert(7,{'table':'lexical_relationships','action':'insert','data':{'id':ident(25050),'source_lexeme_id':ident(25001),'target_lexeme_id':ident(23001),'relationship_type':'BORROWED_FROM'}})
    create(p); denied(p,'dry_run','cross-scope relationship')
    # Definer functions must never flush a caller-owned deferred trigger.
    pending=proposal(26000); create(pending)
    trap=f"""BEGIN;
      CREATE TEMP TABLE caller_trap(x integer);
      CREATE FUNCTION pg_temp.caller_trap() RETURNS trigger LANGUAGE plpgsql AS $f$ BEGIN RAISE EXCEPTION 'caller trigger executed as %',current_user; END $f$;
      CREATE CONSTRAINT TRIGGER caller_deferred AFTER INSERT ON caller_trap DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION pg_temp.caller_trap();
      INSERT INTO caller_trap VALUES(1);
      SELECT lexical_governance.command('{pending['id']}','dry_run'); ROLLBACK;"""
    check('caller deferred triggers not executed with definer privileges',json.loads(sql(trap,'m012_proposer'))['ok'])
    sql(f"""
      INSERT INTO public.source_entries(id,source_version_id,import_batch_id,original_entry_locator,original_form,raw_dialect_label,source_entry_checksum)
        VALUES ('{ident(38)}','{ident(11)}','{ident(13)}','test:unresolved','SYNTHETIC_UNRESOLVED','UNRESOLVED_TEST_LABEL','unresolved-test');
      INSERT INTO public.linguistic_evidence(id,source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,verification_status,extraction_method,reviewed_by,reviewed_at)
        SELECT '{ident(39)}','{ident(11)}',evidence_type_id,'DIALECT','test:unresolved','SYNTHETIC unresolved label','HUMAN','VERIFIED','HUMAN_MANUAL','{ident(2)}',now() FROM public.linguistic_evidence WHERE id='{ident(17)}';
      INSERT INTO public.linguistic_evidence_dialects(evidence_id,dialect_id,role) VALUES ('{ident(39)}','{ident(5)}','PRIMARY');
    """)
    p=proposal(27000); p['evidence']=[{'source_entry_id':ident(38),'evidence_id':ident(39),'artifact_id':ident(12),'role':'SUPPORTS'}]
    create(p); denied(p,'dry_run','unresolved or conflicting source variety label')
    check('unresolved source label retained literally',sql(f"SELECT raw_dialect_label FROM public.source_entries WHERE id='{ident(38)}';")=='UNRESOLVED_TEST_LABEL')
    # Exact language authority is independent of the dialect's parent language.
    sql(f"""
      INSERT INTO public.source_entries(id,source_version_id,import_batch_id,original_entry_locator,original_form,source_entry_checksum)
        VALUES ('{ident(40)}','{ident(11)}','{ident(13)}','test:language','SYNTHETIC_LANGUAGE_TOKEN','language-test');
      INSERT INTO public.linguistic_evidence(id,source_version_id,evidence_type_id,evidence_scope,source_locator,summary,provenance_origin,verification_status,extraction_method,reviewed_by,reviewed_at)
        SELECT '{ident(41)}','{ident(11)}',evidence_type_id,'DIALECT','test:language','SYNTHETIC exact language assessment required','HUMAN','VERIFIED','HUMAN_MANUAL','{ident(2)}',now() FROM public.linguistic_evidence WHERE id='{ident(17)}';
    """)
    p=proposal(28000); p.pop('dialect_id'); p['language_id']=ident(4); p['language_scope_rationale']='Synthetic independent exact language assessment, not dialect inheritance.'
    p['evidence']=[{'source_entry_id':ident(40),'evidence_id':ident(41),'artifact_id':ident(12),'role':'SUPPORTS'}]
    p['operations']=[op for op in p['operations'] if op['data'].get('evidence_role')!='CONTRADICTS']
    p['operations'][0]['data'].pop('identity_dialect_id'); p['operations'][0]['data']['language_id']=ident(4)
    p['operations'][1]['data'].pop('dialect_id')
    for op in p['operations']:
        if 'source_entry_id' in op['data']: op['data']['source_entry_id']=ident(40)
        if 'evidence_id' in op['data']: op['data']['evidence_id']=ident(41)
    create(p); command(p,'submit'); denied(p,'review','scoped authority','m012_approver')
    sql(f"""INSERT INTO public.contributor_roles(id,contributor_id,role_type_id,domain)
        SELECT '{ident(42)}','{ident(2)}',role_type_id,'LEXICAL' FROM public.contributor_roles WHERE id='{ident(7)}';
      INSERT INTO lexical_governance.authorities(contributor_role_id,language_id,operation_keys,competence_reference,valid_from,valid_until)
        SELECT '{ident(42)}','{ident(4)}',operation_keys,'SYNTHETIC independent language qualification',valid_from,valid_until FROM lexical_governance.authorities WHERE id='{ident(8)}';""")
    check('explicit language authority permits review',command(p,'review','m012_approver')['ok'])
    digest=command(p,'inspect')['proposal']['evidence_digest']
    check('language approval independent of classification',command(p,'approve','m012_approver',{'evidence_digest':digest,'source_fidelity_confirmed':True,'scope_assessment':p['language_scope_rationale'],'contradiction_assessment':'No known contradiction in this synthetic evidence'})['ok'])
    check('exact language proposal executes',command(p,'execute')['ok'])


def concurrency_checks():
    # Hold the first real execution open. The second must wait, then observe the
    # committed state under a fresh READ COMMITTED snapshot.
    p=proposal(15000); create(p); approve(p)
    with ThreadPoolExecutor(max_workers=2) as pool:
        first=pool.submit(sql, f"BEGIN; SELECT lexical_governance.command('{p['id']}','execute'); SELECT pg_sleep(2); COMMIT;", "m012_proposer")
        deadline=time.monotonic()+10
        while sql("SELECT count(*) FROM pg_stat_activity WHERE usename='m012_proposer' AND wait_event='PgSleep';")=='0':
            assert time.monotonic()<deadline, 'first execution did not reach its hold barrier'
            time.sleep(0.05)
        second=pool.submit(command,p,"execute")
        while sql("SELECT count(*) FROM pg_stat_activity WHERE usename='m012_proposer' AND wait_event='advisory';")=='0':
            assert not second.done() and time.monotonic()<deadline, 'second execution did not block on lock'
            time.sleep(0.05)
        check("concurrent duplicate waits for execution lock", not second.done())
        r1=first.result(); r2=second.result()
    check("concurrent duplicate exactly once", '"ok": true' in r1 and r2.get("idempotent") is True)
    a=proposal(16000); b=proposal(17000)
    b["operations"][0]["data"]["lexeme_key"]=a["operations"][0]["data"]["lexeme_key"]
    create(a); approve(a); create(b); approve(b)
    with ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(lambda p: command(p,"execute"),[a,b]))
    check("conflicting promotions one success one atomic failure", sum(r["ok"] for r in results)==1 and any(r.get("sqlstate")=="23505" for r in results))
    check("conflict audit retained", sql(f"SELECT count(*)=1 FROM lexical_governance.events WHERE proposal_id IN ('{a['id']}','{b['id']}') AND action='FAILED_EXECUTE';") == "t")
    error=sql(f"BEGIN ISOLATION LEVEL REPEATABLE READ; SELECT lexical_governance.command('{p['id']}');", "m012_proposer",False)
    check("unsupported isolation fails closed", "READ COMMITTED" in error)


def main():
    deadline=time.monotonic()+60
    while subprocess.run(['docker','exec',CONTAINER,'pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True).returncode:
        if time.monotonic()>deadline: raise RuntimeError('disposable database did not become ready')
        time.sleep(0.2)
    baseline = runpy.run_path(str(ROOT / "tests/database/run_lexical_core_replay_tests.py"))
    baseline["main"].__globals__["CONTAINER"] = CONTAINER
    baseline["main"]()
    ddl = MIGRATION.read_text(encoding="utf-8")
    sql("BEGIN;" + ddl + "SELECT 1/0; COMMIT;", success=False)
    check("012 migration failure rolls back schema and role", sql("SELECT to_regnamespace('lexical_governance') IS NULL AND NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='tafsiri_lexical_researcher');") == "t")
    sql("BEGIN;" + ddl + "COMMIT;")
    # Existing suites run against the hardened 011+012 schema, before fixtures.
    for path in sorted((ROOT / "tests/database").glob("*smoke.sql")):
        sql(path.read_text(encoding="utf-8"))
        check("post-012 regression " + path.name, True)
    atomic=runpy.run_path(str(ROOT / 'tests/database/run_marlo_registration_atomic_tests.py'))
    atomic['psql'].__globals__['CONTAINER']=CONTAINER
    atomic['main']()
    fixture()
    p = proposal(); create(p)
    dry = command(p); check("dry run simulates all operations", dry["ok"] and len(dry["operations"]) == 13)
    check("dry run reports missing independent approval", not dry["executable"] and bool(dry["missing_approvals"]))
    check("dry run leaves no canonical rows or output audit", sql("SELECT (SELECT count(*) FROM public.lexemes)=0 AND (SELECT count(*) FROM lexical_governance.outputs)=0;") == "t")
    approve(p)
    check("approval alone leaves canonical empty", sql("SELECT count(*) FROM public.lexemes;") == "0")
    check("approved dry run executable", command(p)["executable"])
    r = command(p, "execute"); check("valid promotion executes", r["ok"])
    check("repeat is idempotent", command(p, "execute")["idempotent"])
    check("exact outputs retained", sql(f"SELECT count(*) FROM lexical_governance.outputs WHERE proposal_id='{p['id']}';") == "13")
    check("contrary attestation preserved", sql("SELECT count(*) FROM public.lexical_attestations WHERE evidence_role='CONTRADICTS';") == "1")
    check("training and commercial remain unknown", sql("SELECT bool_and(decision='UNKNOWN') FROM public.source_use_policies WHERE use_scope IN ('MODEL_TRAINING','COMMERCIAL_API');") == "t")
    extended_checks(p)
    lint=sql("""SELECT p.proname,c.level,c.message FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        CROSS JOIN LATERAL extensions.plpgsql_check_function_tb(p.oid::regprocedure) c
        WHERE n.nspname='lexical_governance' AND p.prorettype<>'trigger'::regtype;
        SELECT p.proname,c.level,c.message FROM pg_trigger t JOIN pg_proc p ON p.oid=t.tgfoid
        CROSS JOIN LATERAL extensions.plpgsql_check_function_tb(p.oid::regprocedure,t.tgrelid) c
        WHERE p.pronamespace='lexical_governance'::regnamespace OR p.proname='tafsiri_guard_concept_governance';""")
    check('all new functions and trigger bindings lint without warnings',not lint)
    sys.path.insert(0,str(ROOT / 'tests/database'))
    import run_lexical_core_concurrency_tests as core_races
    core_races.CONTAINER=CONTAINER
    core_races.psql.__globals__['CONTAINER']=CONTAINER
    core_races.main()
    print(f"PASS: {COUNT} promotion checks")


if __name__ == "__main__":
    main()
