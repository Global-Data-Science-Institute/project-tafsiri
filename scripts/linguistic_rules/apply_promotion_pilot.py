"""Validate, plan, or atomically apply Canonical Promotion Pilot 001.

The utility deliberately uses the linked Supabase CLI connection and one SQL
transaction. It creates no database function or public API surface.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any

STAGING_REF = "gfhdwmqefotkljrltfnx"
PRODUCTION_REF = "ydkookidvipqrwuilqeu"
ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "artifacts/linguistic_rules/canonical_promotion_pilot_001.json"
EXTRACTION_PATH = ROOT / "artifacts/linguistic_evidence/extraction_001.jsonl"
REVIEW_PATH = ROOT / "artifacts/linguistic_rules/canonical_promotion_pilot_001_review.csv"
NAMESPACE = uuid.UUID("fa5f131a-59ea-4ba4-b92b-09a6bc54f922")


class PilotError(RuntimeError):
    pass


def checksum(keys: list[str]) -> str:
    return hashlib.sha256("\n".join(sorted(keys)).encode("utf-8")).hexdigest()


def stable_id(kind: str, key: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{kind}:{key}"))


def sql_literal(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (dict, list)):
        return sql_literal(json.dumps(value, ensure_ascii=False, sort_keys=True)) + "::jsonb"
    return "'" + str(value).replace("'", "''") + "'"


def load_and_validate() -> dict[str, Any]:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    extracted = {
        row["evidence_key"]: row
        for row in (json.loads(line) for line in EXTRACTION_PATH.read_text(encoding="utf-8").splitlines() if line.strip())
    }
    errors: list[str] = []
    candidates = manifest.get("candidates", [])
    if manifest.get("project_ref") != STAGING_REF:
        errors.append("manifest project_ref is not the staging project")
    if len(candidates) != 4:
        errors.append("manifest must contain exactly four candidates")
    expected_keys = {
        "LE001_ABCB2C63153BCC387A919A04",
        "LE001_C96884B0E4BCEB6B99AF0245",
        "LE001_B615C6C88A7506D3529CEA5B",
        "LE001_0D4EF03C6F050473B8EAE121",
    }
    actual_keys: set[str] = set()
    unique_fields = ("pilot_key", "promotion_key", "idempotency_key", "rule_key")
    for field in unique_fields:
        values = [c.get(field) for c in candidates]
        if len(values) != len(set(values)) or any(not v for v in values):
            errors.append(f"candidate {field} values must be present and unique")
    for candidate in candidates:
        keys = candidate.get("evidence_keys", [])
        actual_keys.update(keys)
        if len(keys) != 1 or keys[0] not in extracted:
            errors.append(f"{candidate.get('rule_key')}: exact Extraction 001 evidence key is missing")
        if candidate.get("evidence_set_checksum") != checksum(keys):
            errors.append(f"{candidate.get('rule_key')}: evidence checksum mismatch")
        if candidate.get("scope") != "DIALECT" or candidate.get("target_lifecycle") != "PROVISIONAL":
            errors.append(f"{candidate.get('rule_key')}: scope/lifecycle must be DIALECT/PROVISIONAL")
        if candidate.get("authority_policy") != "SINGLE_RESEARCHER_ALLOWED":
            errors.append(f"{candidate.get('rule_key')}: invalid pilot authority policy")
    if actual_keys != expected_keys:
        errors.append("manifest evidence set differs from the four approved pilot keys")
    if sum(len(c.get("conditions", [])) for c in candidates) != 2:
        errors.append("pilot must contain exactly two meaningful conditions")
    with REVIEW_PATH.open(encoding="utf-8", newline="") as handle:
        if len(list(csv.DictReader(handle))) != 4:
            errors.append("review CSV must contain exactly four candidates")
    if errors:
        raise PilotError("; ".join(errors))
    return manifest


def linked_ref() -> str:
    path = ROOT / "supabase/.temp/project-ref"
    if not path.exists():
        raise PilotError("Supabase CLI is not linked")
    return path.read_text(encoding="utf-8").strip()


def cli_path() -> Path:
    path = ROOT / "node_modules/.bin/supabase.cmd"
    if not path.exists():
        raise PilotError("local Supabase CLI is unavailable")
    return path


def run_sql(sql: str) -> dict[str, Any]:
    with tempfile.NamedTemporaryFile("w", suffix=".sql", encoding="utf-8", delete=False, dir=ROOT) as handle:
        handle.write(sql)
        sql_path = Path(handle.name)
    try:
        result = subprocess.run(
            [str(cli_path()), "db", "query", "--linked", "--file", str(sql_path)],
            cwd=ROOT, text=True, capture_output=True, encoding="utf-8", check=False,
        )
    finally:
        sql_path.unlink(missing_ok=True)
    if result.returncode:
        detail = "\n".join(part.strip() for part in (result.stderr, result.stdout) if part.strip())
        raise PilotError(detail)
    start = result.stdout.find("{")
    if start < 0:
        raise PilotError("Supabase CLI returned no JSON result")
    payload = json.loads(result.stdout[start:])
    rows = payload.get("rows", [])
    return rows[0] if rows else {}


def inspection_sql() -> str:
    return """
select jsonb_build_object(
  'rules',(select count(*) from public.linguistic_rules),
  'revisions',(select count(*) from public.linguistic_rule_revisions),
  'dialect_links',(select count(*) from public.linguistic_rule_dialects),
  'conditions',(select count(*) from public.linguistic_rule_conditions),
  'evidence_links',(select count(*) from public.linguistic_rule_evidence),
  'promotions',(select count(*) from public.linguistic_rule_promotions),
  'outputs',(select count(*) from public.linguistic_rule_promotion_outputs),
  'supersessions',(select count(*) from public.linguistic_rule_supersessions),
  'roles',(select count(*) from public.contributor_roles),
  'evidence_total',(select count(*) from public.linguistic_evidence),
  'evidence_verified',(select count(*) from public.linguistic_evidence where verification_status='VERIFIED'),
  'pilot_promotions',(select coalesce(jsonb_agg(jsonb_build_object('promotion_key',promotion_key,'idempotency_key',idempotency_key,'status',status,'checksum',evidence_set_checksum,'statement',proposed_statement)), '[]'::jsonb) from public.linguistic_rule_promotions where promotion_key like 'PILOT001_%'),
  'pilot_roles',(select count(*) from public.contributor_roles cr join public.contributor_role_types rt on rt.id=cr.role_type_id where rt.role_type_key='CANONICAL_APPROVER' and cr.domain='CANONICAL_PROMOTION_PILOT_001')
) as state;
"""


def plan(manifest: dict[str, Any], state: dict[str, Any]) -> dict[str, int]:
    existing = {p["promotion_key"]: p for p in state.get("pilot_promotions", [])}
    conflicts = 0
    creates = 0
    for candidate in manifest["candidates"]:
        found = existing.get(candidate["promotion_key"])
        if found is None:
            creates += 1
        elif any((found["idempotency_key"] != candidate["idempotency_key"], found["checksum"] != candidate["evidence_set_checksum"], found["statement"] != candidate["canonical_statement"])):
            conflicts += 1
    conditions = sum(len(c["conditions"]) for c in manifest["candidates"] if c["promotion_key"] not in existing)
    return {
        "rules": creates, "revisions": creates, "dialect_links": creates,
        "evidence_links": creates, "conditions": conditions, "promotions": creates,
        "outputs": creates * 4 + conditions,
        "contributor_roles": 0 if state.get("pilot_roles") else 1,
        "conflicts": conflicts,
    }


def print_table(manifest: dict[str, Any]) -> None:
    headers = ("RULE KEY", "TYPE", "DIALECT", "EVIDENCE", "CONDITIONS", "TARGET", "POLICY")
    rows = [headers]
    for c in manifest["candidates"]:
        rows.append((c["rule_key"], c["canonical_rule_type"], c["canonical_dialect"], str(len(c["evidence_keys"])), str(len(c["conditions"])), c["target_lifecycle"], c["authority_policy"]))
    widths = [max(len(row[i]) for row in rows) for i in range(len(headers))]
    for index, row in enumerate(rows):
        print("  ".join(value.ljust(widths[i]) for i, value in enumerate(row)))
        if index == 0:
            print("  ".join("-" * width for width in widths))


def execution_sql(manifest: dict[str, Any]) -> str:
    authority = manifest["authority"]
    contributor_id = "96cc0709-359a-4683-9d26-bac6e49ff7f8"
    authority_id = stable_id("authority", manifest["pilot_key"])
    blocks: list[str] = ["BEGIN;", f"""
DO $$
DECLARE v_contributor uuid; v_role_type uuid;
BEGIN
  SELECT id INTO STRICT v_contributor FROM public.contributors WHERE lower(name)=lower({sql_literal(authority['contributor_name'])}) AND lower(email)=lower({sql_literal(authority['contributor_email'])});
  IF v_contributor <> {sql_literal(contributor_id)}::uuid THEN RAISE EXCEPTION 'resolved contributor identity changed'; END IF;
  SELECT id INTO STRICT v_role_type FROM public.contributor_role_types WHERE role_type_key='CANONICAL_APPROVER' AND is_active;
  IF EXISTS (SELECT 1 FROM public.contributor_roles WHERE id={sql_literal(authority_id)}::uuid) THEN
    IF NOT EXISTS (SELECT 1 FROM public.contributor_roles WHERE id={sql_literal(authority_id)}::uuid AND contributor_id=v_contributor AND role_type_id=v_role_type AND dialect_id IS NULL AND domain={sql_literal(authority['domain'])} AND valid_from={sql_literal(authority['valid_from'])}::timestamptz AND valid_until={sql_literal(authority['valid_until'])}::timestamptz AND revoked_at IS NULL) THEN RAISE EXCEPTION 'CONFLICT: pilot authority identity has changed semantic content'; END IF;
  ELSE
    INSERT INTO public.contributor_roles(id,contributor_id,role_type_id,dialect_id,domain,valid_from,valid_until,granted_by,notes) VALUES ({sql_literal(authority_id)}::uuid,v_contributor,v_role_type,NULL,{sql_literal(authority['domain'])},{sql_literal(authority['valid_from'])}::timestamptz,{sql_literal(authority['valid_until'])}::timestamptz,v_contributor,{sql_literal(authority['notes'])});
  END IF;
END $$;
"""]
    for candidate in manifest["candidates"]:
        key = candidate["rule_key"]
        promo_id = stable_id("promotion", candidate["promotion_key"])
        rule_id = stable_id("rule", key)
        revision_id = stable_id("revision", key + ":1")
        dialect_link_id = stable_id("dialect", key + ":1")
        evidence_link_id = stable_id("evidence", key + ":" + candidate["evidence_keys"][0])
        condition_ids = [stable_id("condition", key + f":{i}") for i, _ in enumerate(candidate["conditions"])]
        conditions_summary = "; ".join(c["condition_statement"] for c in candidate["conditions"]) or None
        blocks.append(f"""
DO $$
DECLARE v_type uuid; v_dialect uuid; v_evidence uuid; v_contributor uuid; v_new boolean := false;
BEGIN
  SELECT id INTO STRICT v_type FROM public.linguistic_rule_types WHERE rule_type_key={sql_literal(candidate['canonical_rule_type'])} AND is_active;
  SELECT id INTO STRICT v_dialect FROM public.dialects WHERE name={sql_literal(candidate['canonical_dialect'])};
  SELECT id INTO STRICT v_contributor FROM public.contributors WHERE lower(name)=lower({sql_literal(authority['contributor_name'])}) AND lower(email)=lower({sql_literal(authority['contributor_email'])});
  SELECT id INTO STRICT v_evidence FROM public.linguistic_evidence WHERE notes={sql_literal('Extraction 001 key: ' + candidate['evidence_keys'][0])} AND verification_status='VERIFIED';
  IF EXISTS (SELECT 1 FROM public.linguistic_rule_promotions WHERE id={sql_literal(promo_id)}::uuid OR promotion_key={sql_literal(candidate['promotion_key'])} OR idempotency_key={sql_literal(candidate['idempotency_key'])}) THEN
    IF NOT EXISTS (SELECT 1 FROM public.linguistic_rule_promotions WHERE id={sql_literal(promo_id)}::uuid AND promotion_key={sql_literal(candidate['promotion_key'])} AND idempotency_key={sql_literal(candidate['idempotency_key'])} AND action='CREATE_RULE' AND status='APPLIED' AND proposed_rule_type_id=v_type AND proposed_scope='DIALECT' AND proposed_statement={sql_literal(candidate['canonical_statement'])} AND evidence_set_checksum={sql_literal(candidate['evidence_set_checksum'])} AND authority_policy='SINGLE_RESEARCHER_ALLOWED' AND target_rule_id={sql_literal(rule_id)}::uuid) THEN RAISE EXCEPTION 'CONFLICT: promotion identity reused with changed semantic content: %', {sql_literal(candidate['promotion_key'])}; END IF;
  ELSE
    v_new := true;
    INSERT INTO public.linguistic_rule_promotions(id,promotion_key,action,status,proposed_rule_type_id,proposed_scope,proposed_statement,evidence_set_checksum,policy_version,risk_class,authority_policy,requested_by,requested_at,reason,idempotency_key)
    VALUES({sql_literal(promo_id)}::uuid,{sql_literal(candidate['promotion_key'])},'CREATE_RULE','DRAFT',v_type,'DIALECT',{sql_literal(candidate['canonical_statement'])},{sql_literal(candidate['evidence_set_checksum'])},{sql_literal(manifest['policy_version'])},{sql_literal(candidate['risk_class'])},'SINGLE_RESEARCHER_ALLOWED',v_contributor,{sql_literal(authority['valid_from'])}::timestamptz,{sql_literal(candidate['rationale'])},{sql_literal(candidate['idempotency_key'])});
    UPDATE public.linguistic_rule_promotions SET status='READY_FOR_REVIEW' WHERE id={sql_literal(promo_id)}::uuid;
    UPDATE public.linguistic_rule_promotions SET status='APPROVED',approved_by=v_contributor,approved_at={sql_literal(authority['valid_from'])}::timestamptz WHERE id={sql_literal(promo_id)}::uuid;
    INSERT INTO public.linguistic_rules(id,rule_key,rule_type_id,lifecycle_status,created_by_promotion_id) VALUES({sql_literal(rule_id)}::uuid,{sql_literal(key)},v_type,'PROVISIONAL',{sql_literal(promo_id)}::uuid);
    UPDATE public.linguistic_rule_promotions SET target_rule_id={sql_literal(rule_id)}::uuid WHERE id={sql_literal(promo_id)}::uuid;
    INSERT INTO public.linguistic_rule_revisions(id,rule_id,revision_number,canonical_statement,scope,conditions_summary,reason,policy_version,created_by_promotion_id,effective_at) VALUES({sql_literal(revision_id)}::uuid,{sql_literal(rule_id)}::uuid,1,{sql_literal(candidate['canonical_statement'])},'DIALECT',{sql_literal(conditions_summary)},{sql_literal(candidate['rationale'])},{sql_literal(manifest['policy_version'])},{sql_literal(promo_id)}::uuid,{sql_literal(authority['valid_from'])}::timestamptz);
    INSERT INTO public.linguistic_rule_dialects(id,rule_revision_id,dialect_id,role,notes) VALUES({sql_literal(dialect_link_id)}::uuid,{sql_literal(revision_id)}::uuid,v_dialect,'APPLIES_TO','Canonical dialect scope for Pilot 001.');
    INSERT INTO public.linguistic_rule_evidence(id,rule_revision_id,evidence_id,evidence_role,notes) VALUES({sql_literal(evidence_link_id)}::uuid,{sql_literal(revision_id)}::uuid,v_evidence,'SUPPORTS',{sql_literal('Approved evidence key: ' + candidate['evidence_keys'][0])});
""")
        for idx, condition in enumerate(candidate["conditions"]):
            blocks.append(f"    INSERT INTO public.linguistic_rule_conditions(id,rule_revision_id,condition_type,condition_statement,structured_value,order_index,is_negated) VALUES({sql_literal(condition_ids[idx])}::uuid,{sql_literal(revision_id)}::uuid,{sql_literal(condition['condition_type'])},{sql_literal(condition['condition_statement'])},{sql_literal(condition['structured_value'])},{condition['order_index']},{sql_literal(condition['is_negated'])});\n")
        outputs = [
            ("RULE", "rule_id", rule_id), ("REVISION", "revision_id", revision_id),
            ("DIALECT_LINK", "dialect_link_id", dialect_link_id), ("EVIDENCE_LINK", "evidence_link_id", evidence_link_id),
        ] + [("CONDITION", "condition_id", cid) for cid in condition_ids]
        for idx, (otype, column, target_id) in enumerate(outputs):
            blocks.append(f"    INSERT INTO public.linguistic_rule_promotion_outputs(id,promotion_id,output_type,output_action,{column},order_index) VALUES({sql_literal(stable_id('output', candidate['promotion_key'] + ':' + str(idx)))}::uuid,{sql_literal(promo_id)}::uuid,'{otype}','CREATED',{sql_literal(target_id)}::uuid,{idx});\n")
        blocks.append(f"""    UPDATE public.linguistic_rules SET current_revision_id={sql_literal(revision_id)}::uuid WHERE id={sql_literal(rule_id)}::uuid;
    UPDATE public.linguistic_rule_promotions SET status='APPLIED',applied_at={sql_literal(authority['valid_from'])}::timestamptz,transaction_reference='DRAFT -> READY_FOR_REVIEW -> APPROVED -> APPLIED; atomic Pilot 001 transaction' WHERE id={sql_literal(promo_id)}::uuid;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.linguistic_rules r JOIN public.linguistic_rule_revisions rv ON rv.id=r.current_revision_id AND rv.rule_id=r.id JOIN public.linguistic_rule_dialects d ON d.rule_revision_id=rv.id AND d.role='APPLIES_TO' JOIN public.linguistic_rule_evidence e ON e.rule_revision_id=rv.id AND e.evidence_role='SUPPORTS' WHERE r.id={sql_literal(rule_id)}::uuid AND r.lifecycle_status='PROVISIONAL' AND rv.revision_number=1 AND d.dialect_id=v_dialect AND e.evidence_id=v_evidence) THEN RAISE EXCEPTION 'Pilot output traceability mismatch: %', {sql_literal(key)}; END IF;
END $$;
""")
    # `supabase db query` sends one prepared statement. A single DO statement is
    # also one PostgreSQL transaction, so any exception rolls back the batch.
    nested = "\n".join(blocks[1:]).replace("DO $$", "").replace("END $$;", "END;")
    return "DO $pilot$\nBEGIN\n" + nested + "\nEND\n$pilot$;\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--validate", action="store_true")
    modes.add_argument("--dry-run", action="store_true")
    modes.add_argument("--execute", action="store_true")
    parser.add_argument("--confirm-project-ref")
    args = parser.parse_args(argv)
    manifest = load_and_validate()
    if args.validate:
        print(json.dumps({"status": "VALID", "candidates": 4, "evidence_links": 4, "conditions": 2, "outputs": 18}, sort_keys=True))
        return 0
    ref = linked_ref()
    if ref != STAGING_REF:
        raise PilotError(f"Pilot 001 is staging-only; linked project {ref!r} is refused")
    if args.execute and args.confirm_project_ref != STAGING_REF:
        raise PilotError(f"--execute requires --confirm-project-ref {STAGING_REF}")
    state = run_sql(inspection_sql()).get("state", {})
    planned = plan(manifest, state)
    print_table(manifest)
    print(json.dumps({"project_ref": ref, "mode": "EXECUTE" if args.execute else "DRY_RUN", "planned_changes": planned}, sort_keys=True))
    if planned["conflicts"]:
        raise PilotError("CONFLICT: an existing promotion identity has changed semantic content")
    if not args.execute:
        return 0
    result = run_sql(execution_sql(manifest))
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PilotError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
