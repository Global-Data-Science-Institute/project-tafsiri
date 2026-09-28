from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import uuid
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
INTAKE_PATH = ROOT / "config/sources/marlo_source_intake_001.json"
MANIFEST_PATH = ROOT / "config/sources/marlo_source_registration_001.json"
STAGING_REF = "gfhdwmqefotkljrltfnx"
PRODUCTION_REF = "ydkookidvipqrwuilqeu"
NAMESPACE = uuid.UUID("65269e23-a33e-4e6d-bf31-f57e6ed88a58")
USE_SCOPES = (
    "INTERNAL_RESEARCH", "HUMAN_REVIEW", "REVIEWER_DISPLAY", "PUBLIC_DISPLAY",
    "REDISTRIBUTION", "MODEL_TRAINING", "BENCHMARK_PUBLICATION", "COMMERCIAL_API",
)


class RegistrationError(ValueError):
    pass


def stable_id(kind: str, key: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"marlo-registration-001:{kind}:{key}"))


def artifact_key(checksum: str) -> str:
    return "ART_SHA256_" + checksum[:24].upper()


def acquisition_key(checksum: str, filename: str) -> str:
    suffix = hashlib.sha256(filename.encode("utf-8")).hexdigest()[:10].upper()
    return f"ACQ_MARLO001_{checksum[:16].upper()}_{suffix}"


def canonical_digest(value: Any) -> str:
    encoded = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _source_templates() -> dict[str, dict[str, Any]]:
    return {
        "LUBUKUSU_ENGLISH_DICTIONARY_2008": {
            "action": "REUSE", "source_type": "DICTIONARY", "title": "Lubukusu-English Dictionary",
        },
        "WANGA_ENGLISH_DICTIONARY_2008": {
            "action": "REUSE", "source_type": "DICTIONARY", "title": "Luwanga-English Dictionary",
        },
        "APPLEBY_1943_LULUHYA_ENGLISH_VOCABULARY": {
            "action": "CREATE", "source_type": "LEXICON", "title": "A Luluhya-English Vocabulary",
            "authors_or_contributors": "L. L. Appleby", "publisher_or_institution": "C. M. S., Maseno, Kenya",
            "publication_year": 1943, "citation": "Appleby, L. L. 1943. A Luluhya-English Vocabulary. C. M. S., Maseno, Kenya.",
            "notes": "Historical vocabulary associated primarily with the Hanga grouping. Preserve its tentative scope and unresolved long-vowel, i/y, and u/w orthographic conventions; it is not generic modern pan-Luhya canonical truth.",
        },
        "FRIENDS_AFRICA_MISSION_1940_LURAGOLI_ENGLISH_VOCABULARY": {
            "action": "CREATE", "source_type": "LEXICON", "title": "Luragoli-English Vocabulary",
            "publisher_or_institution": "Friends Africa Mission Press", "publication_year": 1940,
            "citation": "Friends Africa Mission Press. 1940. Luragoli-English Vocabulary.",
            "notes": "Historical Luragoli-English vocabulary. Preserve the source's raw historical spelling and terminology; inspected front matter does not identify an individual author.",
        },
        "NDANYI_NDANYI_2005_LULOGOOLI_DICTIONARY": {
            "action": "CREATE", "source_type": "DICTIONARY", "title": "Amang’ana go Lulimi lwo Lulogooli",
            "authors_or_contributors": "Elisha Ugaada Ndanyi; Joseph Olindo Ndanyi", "publication_year": 2005,
            "citation": "Ndanyi, Elisha Ugaada and Joseph Olindo Ndanyi. 2005. Amang’ana go Lulimi lwo Lulogooli. ISBN 9966-7090-0-2.",
            "notes": "One intellectual work represented by five ordered scan components. Raw label Lulogooli is preserved; canonical Maragoli mapping remains unresolved pending expert confirmation.",
        },
        "MARLO_LUYIA_COMPARATIVE_DICTIONARY_WORKBOOK": {
            "action": "CREATE", "source_type": "DATASET", "title": "Luyia Comparative Dictionary Workbook",
            "authors_or_contributors": "Michael R. Marlo; Jacinta B. G. Marlo",
            "citation": "Marlo, Michael R. and Jacinta B. G. Marlo. Luyia comparative dictionary workbook. Working dataset, modified 2010-01-24.",
            "notes": "Source-provided cross-variety correspondences are not canonical equivalence assertions. Preserve raw labels Appleby, Kisa, Tsotso, Wanga, and Bukusu.",
        },
        "MARLO_IDAKHO_COMPARATIVE_WORKBOOK": {
            "action": "CREATE", "source_type": "DATASET", "title": "Idakho Comparative Workbook",
            "authors_or_contributors": "Michael R. Marlo; Jacinta B. G. Marlo",
            "citation": "Marlo, Michael R. and Jacinta B. G. Marlo. Idakho comparative workbook. Working dataset, modified 2010-01-24.",
            "notes": "Preserve Idakho_1 and Idakho_2 as distinct raw columns. Their intended linguistic distinction remains unresolved.",
        },
        "MARLO_TURA_LUTURA_COMPARATIVE_WORKBOOK": {
            "action": "CREATE", "source_type": "DATASET", "title": "Tura/Lutura Comparative Workbook",
            "authors_or_contributors": "Jacinta B. G. Marlo",
            "citation": "Marlo, Jacinta B. G. Tura/Lutura comparative workbook. Working dataset, modified 2010-01-24.",
            "notes": "Preserve Tura and Lutura as raw labels. Their canonical linguistic classification remains unresolved pending expert confirmation.",
        },
    }


def build_manifest() -> dict[str, Any]:
    intake = json.loads(INTAKE_PATH.read_text(encoding="utf-8"))
    templates = _source_templates()
    version_keys = {item["source_key"]: item["source_version_key"] for item in intake["artifacts"]}
    source_actions = []
    version_actions = []
    for source_key, values in templates.items():
        source = {"source_key": source_key, **values}
        if values["action"] == "CREATE":
            source["id"] = stable_id("source", source_key)
        source_actions.append(source)
        version_key = version_keys[source_key]
        version_actions.append({
            "action": values["action"], "source_key": source_key, "version_key": version_key,
            **({"id": stable_id("version", f"{source_key}:{version_key}")} if values["action"] == "CREATE" else {}),
            "checksum": None, "checksum_algorithm": None,
            "notes": "Exact binary identity is represented by Migration 010 artifacts; legacy source-version checksum fields remain NULL.",
        })

    unique: dict[str, dict[str, Any]] = {}
    for item in intake["artifacts"]:
        unique.setdefault(item["sha256"], item)
    artifact_actions = []
    for checksum, item in unique.items():
        artifact_actions.append({
            "action": "CREATE", "id": stable_id("artifact", checksum), "artifact_key": artifact_key(checksum),
            "checksum_algorithm": "SHA256", "checksum": checksum, "byte_size": item["byte_size"],
            "media_type": item["media_type"], "artifact_kind": "SOURCE_REPRESENTATION",
            "artifact_status": "REGISTERED", "page_count": item.get("page_count"),
            "workbook_sheet_count": len(item.get("sheets", [])) or None,
            "notes": "Exact bytes received in Michael Marlo Source Intake 001; registration does not establish copyright permission.",
        })

    multipart_source = "NDANYI_NDANYI_2005_LULOGOOLI_DICTIONARY"
    association_actions = []
    for checksum, item in unique.items():
        preferred = item["source_key"] != multipart_source
        association_actions.append({
            "action": "CREATE", "id": stable_id("association", f"{item['source_key']}:{item['source_version_key']}:{checksum}"),
            "source_key": item["source_key"], "version_key": item["source_version_key"],
            "artifact_key": artifact_key(checksum), "artifact_role": "RECEIVED_COPY", "is_preferred": preferred,
            "notes": "Preferred means Tafsiri processing/reference representation only; it conveys no linguistic or legal authority." if preferred else "Multipart component represented through the ordered artifact set; no single component is preferred for the version.",
        })

    acquisition_actions = []
    for item in intake["artifacts"]:
        acquisition_actions.append({
            "action": "CREATE", "id": stable_id("acquisition", f"{item['sha256']}:{item['original_filename']}"),
            "acquisition_key": acquisition_key(item["sha256"], item["original_filename"]),
            "artifact_key": artifact_key(item["sha256"]), "acquisition_type": "DIRECT_RESEARCHER_PROVISION",
            "acquired_at": "2026-04-14T00:00:00Z", "original_filename": item["original_filename"],
            "provider_contributor_id": None, "provider_name": "Professor Michael R. Marlo",
            "acquisition_channel": "EMAIL", "acquisition_group_key": "MARLO_SOURCE_PACKAGE_2026_001",
            "evidence_reference": "PRIVATE_CORRESPONDENCE_REVIEWED_NOT_COMMITTED",
            "notes": "Physical file receipt provenance only; private email contents are not stored.",
        })

    rights_actions = []
    policy_actions = []
    for source in source_actions:
        if source["action"] != "CREATE":
            continue
        source_key = source["source_key"]
        version_key = version_keys[source_key]
        rights_actions.append({
            "action": "CREATE", "id": stable_id("rights", f"{source_key}:{version_key}"),
            "source_key": source_key, "version_key": version_key, "rights_status": "UNKNOWN",
            "evidence_reference": "MARLO_SOURCE_INTAKE_001",
            "notes": "Direct provision establishes provenance, not permission or an open license.",
        })
        for scope in USE_SCOPES:
            policy_actions.append({
                "action": "CREATE", "id": stable_id("policy", f"{source_key}:{version_key}:{scope}"),
                "source_key": source_key, "version_key": version_key, "use_scope": scope,
                "decision": "UNKNOWN", "policy_version": "MARLO_REGISTRATION_001",
                "notes": "Permission remains unresolved; direct provision is not treated as authorization.",
            })

    set_key = "ASET_NDANYI_NDANYI_2005_MULTIPART_001"
    set_action = {
        "action": "CREATE", "id": stable_id("artifact_set", set_key), "artifact_set_key": set_key,
        "source_key": multipart_source, "version_key": version_keys[multipart_source],
        "set_type": "MULTIPART_DOCUMENT", "label": "Ndanyi & Ndanyi 2005 five-part scan",
        "notes": "One ordered representation of a single intellectual work; duplicate Part 5 is acquisition provenance only.",
    }
    member_actions = []
    parts = sorted((a for a in intake["artifacts"] if a.get("component_sequence")), key=lambda a: a["component_sequence"])
    for item in parts:
        sequence = item["component_sequence"]
        member_actions.append({
            "action": "CREATE", "id": stable_id("set_member", f"{set_key}:{sequence}"),
            "artifact_set_key": set_key, "source_key": multipart_source,
            "artifact_key": artifact_key(item["sha256"]), "sequence_number": sequence,
            "component_label": f"Part {sequence}",
        })

    contact_event_actions = [
        {"action": "DEFER", "event_key": "CONTACT_MARLO_PACKAGE_2026_04_14", "date": "2026-04-14", "kind": "MATERIAL_PROVISION"},
        {"action": "DEFER", "event_key": "CONTACT_MARLO_PACKAGE_2026_09_25", "date": "2026-09-25", "kind": "COLLABORATION_CONTACT"},
        {"action": "DEFER", "event_key": "CONTACT_MARLO_PACKAGE_2026_09_27", "date": "2026-09-27", "kind": "PROJECT_REPLY"},
    ]
    manifest = {
        "registration_key": "MARLO_SOURCE_REGISTRATION_001", "schema_version": 1,
        "intake_manifest": "config/sources/marlo_source_intake_001.json",
        "provider_strategy": "USE_PROVIDER_NAME_FOR_NOW",
        "contributor_recommendation": "USE_PROVIDER_NAME_FOR_NOW",
        "acquisition_group_key": "MARLO_SOURCE_PACKAGE_2026_001",
        "source_actions": source_actions, "version_actions": version_actions,
        "artifact_actions": artifact_actions, "association_actions": association_actions,
        "acquisition_actions": acquisition_actions, "location_actions": [],
        "rights_actions": rights_actions, "policy_actions": policy_actions,
        "artifact_set_actions": [set_action], "artifact_set_member_actions": member_actions,
        "contact_event_actions": contact_event_actions,
        "dialect_labels": intake["raw_labels"], "dialect_mapping_actions": [],
        "unresolved_questions": intake["unresolved_questions"] + [
            "Which durable portable private-archive references should be registered for these artifacts?",
            "Should Professor Michael R. Marlo receive a contributor identity through a separately governed onboarding step?",
            "How should package-level correspondence be represented without duplicating source-specific contact events?",
        ],
        "safety": {"import_batches": 0, "source_entries": 0, "lexical_or_canonical_records": 0, "database_writes_in_dry_run": 0},
    }
    semantic = {key: manifest[key] for key in (
        "source_actions", "version_actions", "artifact_actions", "association_actions", "acquisition_actions",
        "location_actions", "rights_actions", "policy_actions", "artifact_set_actions",
        "artifact_set_member_actions", "contact_event_actions", "dialect_mapping_actions",
    )}
    manifest["semantic_digest"] = canonical_digest(semantic)
    return manifest


def validate_manifest(manifest: dict[str, Any], verify_files: bool = True) -> dict[str, int]:
    errors: list[str] = []
    intake = json.loads(INTAKE_PATH.read_text(encoding="utf-8"))
    artifacts = manifest.get("artifact_actions", [])
    acquisitions = manifest.get("acquisition_actions", [])
    if len(intake.get("artifacts", [])) != 13: errors.append("intake must contain 13 physical files")
    if len(artifacts) != 12 or len({a.get("checksum") for a in artifacts}) != 12: errors.append("registration must contain 12 unique artifacts")
    if len(acquisitions) != 13 or len({a.get("original_filename") for a in acquisitions}) != 13: errors.append("registration must contain 13 acquisition filenames")
    if len(manifest.get("source_actions", [])) != 8: errors.append("registration must resolve eight sources")
    if sum(a.get("action") == "CREATE" for a in manifest.get("source_actions", [])) != 6: errors.append("registration must create six sources")
    if sum(a.get("action") == "REUSE" for a in manifest.get("source_actions", [])) != 2: errors.append("registration must reuse two sources")
    if len(manifest.get("association_actions", [])) != 12: errors.append("registration must contain 12 associations")
    if len(manifest.get("artifact_set_member_actions", [])) != 5: errors.append("Ndanyi set must contain five members")
    if [m.get("sequence_number") for m in manifest.get("artifact_set_member_actions", [])] != [1, 2, 3, 4, 5]: errors.append("Ndanyi ordering must be 1..5")
    if len(manifest.get("rights_actions", [])) != 6 or any(r.get("rights_status") != "UNKNOWN" for r in manifest.get("rights_actions", [])): errors.append("six new UNKNOWN rights rows are required")
    if len(manifest.get("policy_actions", [])) != 48 or any(p.get("decision") != "UNKNOWN" for p in manifest.get("policy_actions", [])): errors.append("48 UNKNOWN use-policy rows are required")
    if manifest.get("location_actions") != [] or manifest.get("dialect_mapping_actions") != []: errors.append("locations and dialect mappings must remain deferred")
    if any(v.get("checksum") is not None or v.get("checksum_algorithm") is not None for v in manifest.get("version_actions", [])): errors.append("legacy version checksums must remain NULL")
    duplicate = [a for a in acquisitions if "Part5" in a.get("original_filename", "")]
    if len(duplicate) != 2 or len({a.get("artifact_key") for a in duplicate}) != 1: errors.append("duplicate Part 5 must resolve to one artifact")
    semantic = {key: manifest[key] for key in (
        "source_actions", "version_actions", "artifact_actions", "association_actions", "acquisition_actions",
        "location_actions", "rights_actions", "policy_actions", "artifact_set_actions",
        "artifact_set_member_actions", "contact_event_actions", "dialect_mapping_actions",
    )}
    if manifest.get("semantic_digest") != canonical_digest(semantic): errors.append("semantic digest mismatch")
    if verify_files:
        intake_by_name = {a["original_filename"]: a for a in intake["artifacts"]}
        for name, item in intake_by_name.items():
            path = ROOT / "artifacts" / name
            if not path.is_file(): errors.append(f"missing artifact file: {name}"); continue
            if path.stat().st_size != item["byte_size"]: errors.append(f"byte-size mismatch: {name}")
            if hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]: errors.append(f"checksum mismatch: {name}")
    if errors: raise RegistrationError("; ".join(errors))
    return {
        "sources_create": 6, "sources_reuse": 2, "versions_create": 6, "versions_reuse": 2,
        "artifacts": 12, "associations": 12, "acquisitions": 13, "rights": 6,
        "policies": 48, "artifact_sets": 1, "set_members": 5,
    }


def load_manifest() -> dict[str, Any]:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def sql_array(values: list[str]) -> str:
    return "ARRAY[" + ",".join("'" + value.replace("'", "''") + "'" for value in values) + "]::text[]"


def inspection_sql(manifest: dict[str, Any]) -> str:
    source_keys = sql_array([a["source_key"] for a in manifest["source_actions"]])
    checksums = sql_array([a["checksum"] for a in manifest["artifact_actions"]])
    acquisition_keys = sql_array([a["acquisition_key"] for a in manifest["acquisition_actions"]])
    set_keys = sql_array([a["artifact_set_key"] for a in manifest["artifact_set_actions"]])
    return f"""select json_build_object(
      'migration_010',(select count(*) from supabase_migrations.schema_migrations where version='20260928015644'),
      'sources',(select coalesce(json_agg(to_jsonb(s)),'[]'::json) from public.sources s where source_key=any({source_keys})),
      'versions',(select coalesce(json_agg(to_jsonb(v)||jsonb_build_object('source_key',s.source_key)),'[]'::json) from public.source_versions v join public.sources s on s.id=v.source_id where s.source_key=any({source_keys})),
      'artifacts',(select coalesce(json_agg(to_jsonb(a)),'[]'::json) from public.source_artifacts a where checksum=any({checksums})),
      'associations',(select coalesce(json_agg(to_jsonb(a)||jsonb_build_object('source_key',s.source_key,'version_key',v.version_key,'artifact_key',x.artifact_key)),'[]'::json) from public.source_version_artifacts a join public.source_versions v on v.id=a.source_version_id join public.sources s on s.id=v.source_id join public.source_artifacts x on x.id=a.source_artifact_id where x.checksum=any({checksums})),
      'acquisitions',(select coalesce(json_agg(to_jsonb(a)),'[]'::json) from public.source_artifact_acquisitions a where acquisition_key=any({acquisition_keys})),
      'rights',(select coalesce(json_agg(to_jsonb(r)||jsonb_build_object('source_key',s.source_key,'version_key',v.version_key)),'[]'::json) from public.source_rights r join public.source_versions v on v.id=r.source_version_id join public.sources s on s.id=v.source_id where s.source_key=any({source_keys}) and r.superseded_at is null),
      'policies',(select coalesce(json_agg(to_jsonb(p)||jsonb_build_object('source_key',s.source_key,'version_key',v.version_key)),'[]'::json) from public.source_use_policies p join public.source_versions v on v.id=p.source_version_id join public.sources s on s.id=v.source_id where s.source_key=any({source_keys}) and p.superseded_at is null),
      'sets',(select coalesce(json_agg(to_jsonb(a)||jsonb_build_object('source_key',s.source_key,'version_key',v.version_key)),'[]'::json) from public.source_artifact_sets a join public.source_versions v on v.id=a.source_version_id join public.sources s on s.id=v.source_id where artifact_set_key=any({set_keys})),
      'members',(select coalesce(json_agg(to_jsonb(m)||jsonb_build_object('artifact_set_key',a.artifact_set_key,'artifact_key',x.artifact_key)),'[]'::json) from public.source_artifact_set_members m join public.source_artifact_sets a on a.id=m.artifact_set_id join public.source_artifacts x on x.id=m.source_artifact_id where a.artifact_set_key=any({set_keys})),
      'artifact_table_counts',json_build_object('artifacts',(select count(*) from public.source_artifacts),'associations',(select count(*) from public.source_version_artifacts),'acquisitions',(select count(*) from public.source_artifact_acquisitions),'locations',(select count(*) from public.source_artifact_locations),'sets',(select count(*) from public.source_artifact_sets),'members',(select count(*) from public.source_artifact_set_members)),
      'import_batches',(select count(*) from public.source_import_batches),
      'source_entries',(select count(*) from public.source_entries),
      'linguistic_rules',(select count(*) from public.linguistic_rules)
    ) as state"""


def cli_query(project_ref: str, sql: str) -> dict[str, Any]:
    cli = ROOT / "node_modules/.bin/supabase.cmd"
    if not cli.exists(): raise RegistrationError("local Supabase CLI is unavailable")
    with tempfile.NamedTemporaryFile("w", suffix=".sql", encoding="utf-8", delete=False, dir=ROOT) as handle:
        handle.write(sql); path = Path(handle.name)
    try:
        result = subprocess.run([str(cli), "db", "query", "--linked", "--project-ref", project_ref, "--file", str(path)], cwd=ROOT, text=True, capture_output=True, encoding="utf-8", check=False)
    finally:
        path.unlink(missing_ok=True)
    if result.returncode: raise RegistrationError("\n".join(x.strip() for x in (result.stderr, result.stdout) if x.strip()))
    start = result.stdout.find("{")
    if start < 0: raise RegistrationError("Supabase CLI returned no JSON")
    payload = json.loads(result.stdout[start:])
    rows = payload.get("rows", [])
    return rows[0].get("state", {}) if rows else {}


def _match(existing: dict[str, Any], desired: dict[str, Any], fields: tuple[str, ...]) -> bool:
    return all(existing.get(field) == desired.get(field) for field in fields)


def plan(manifest: dict[str, Any], state: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Counter[str]] = {}
    specs = [
        ("sources", "source_actions", lambda x: x["source_key"], ("source_type", "title")),
        ("versions", "version_actions", lambda x: (x["source_key"], x["version_key"]), ("checksum", "checksum_algorithm")),
        ("artifacts", "artifact_actions", lambda x: x["checksum"], ("artifact_key", "checksum_algorithm", "checksum", "byte_size", "media_type", "artifact_kind", "artifact_status")),
        ("associations", "association_actions", lambda x: (x["source_key"], x["version_key"], x["artifact_key"]), ("artifact_role", "is_preferred")),
        ("acquisitions", "acquisition_actions", lambda x: x["acquisition_key"], ("acquisition_type", "original_filename", "provider_name", "acquisition_channel", "acquisition_group_key")),
        ("rights", "rights_actions", lambda x: (x["source_key"], x["version_key"]), ("rights_status",)),
        ("policies", "policy_actions", lambda x: (x["source_key"], x["version_key"], x["use_scope"]), ("decision", "policy_version")),
        ("sets", "artifact_set_actions", lambda x: x["artifact_set_key"], ("set_type", "label")),
        ("members", "artifact_set_member_actions", lambda x: (x["artifact_set_key"], x["sequence_number"]), ("artifact_key", "component_label")),
    ]
    conflicts: list[str] = []
    for state_key, manifest_key, identity, fields in specs:
        existing = {identity(row): row for row in state.get(state_key, [])}
        counter: Counter[str] = Counter()
        for desired in manifest[manifest_key]:
            found = existing.get(identity(desired))
            expected = desired.get("action", "CREATE")
            if found is None:
                if expected == "REUSE": counter["CONFLICT"] += 1; conflicts.append(f"missing required reuse: {manifest_key}/{identity(desired)}")
                else: counter["CREATE"] += 1
            elif _match(found, desired, fields): counter["REUSE"] += 1
            else: counter["CONFLICT"] += 1; conflicts.append(f"semantic conflict: {manifest_key}/{identity(desired)}")
        result[manifest_key] = counter
    totals = Counter()
    for counter in result.values(): totals.update(counter)
    return {
        "categories": {key: dict(value) for key, value in result.items()}, "totals": dict(totals),
        "conflicts": conflicts, "semantic_digest": manifest["semantic_digest"],
        "safety": {"import_batches": state.get("import_batches"), "source_entries": state.get("source_entries"), "linguistic_rules": state.get("linguistic_rules")},
        "artifact_table_counts": state.get("artifact_table_counts"),
    }


class RestClient:
    def __init__(self, url: str, key: str):
        self.base = url.rstrip("/") + "/rest/v1"; self.headers = {"apikey": key, "Authorization": f"Bearer {key}"}
    def insert(self, table: str, row: dict[str, Any]) -> None:
        data = json.dumps(row, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(f"{self.base}/{table}", data=data, method="POST", headers={**self.headers, "Content-Type": "application/json", "Prefer": "return=minimal"})
        try:
            with urllib.request.urlopen(request): pass
        except urllib.error.HTTPError as exc:
            raise RegistrationError(f"insert {table} failed: {exc.read().decode('utf-8','replace')}") from exc


def execute(manifest: dict[str, Any], state: dict[str, Any], client: RestClient) -> None:
    planned = plan(manifest, state)
    if planned["conflicts"]: raise RegistrationError("execution refused because conflicts exist")
    sources = {row["source_key"]: row["id"] for row in state["sources"]}
    for item in manifest["source_actions"]:
        if item["source_key"] not in sources:
            row = {k: v for k, v in item.items() if k not in {"action"} and v is not None}; client.insert("sources", row); sources[item["source_key"]] = item["id"]
    versions = {(row["source_key"], row["version_key"]): row["id"] for row in state["versions"]}
    for item in manifest["version_actions"]:
        key = (item["source_key"], item["version_key"])
        if key not in versions:
            row = {k: v for k, v in item.items() if k not in {"action", "source_key"} and v is not None}; row["source_id"] = sources[item["source_key"]]; client.insert("source_versions", row); versions[key] = item["id"]
    artifacts = {row["checksum"]: row["id"] for row in state["artifacts"]}
    artifact_keys = {}
    for item in manifest["artifact_actions"]:
        if item["checksum"] not in artifacts:
            row = {k: v for k, v in item.items() if k != "action" and v is not None}; client.insert("source_artifacts", row); artifacts[item["checksum"]] = item["id"]
        artifact_keys[item["artifact_key"]] = artifacts[item["checksum"]]
    existing_assoc = {(r["source_key"],r["version_key"],r["artifact_key"]) for r in state["associations"]}
    for item in manifest["association_actions"]:
        key=(item["source_key"],item["version_key"],item["artifact_key"])
        if key not in existing_assoc:
            client.insert("source_version_artifacts", {"id":item["id"],"source_version_id":versions[key[:2]],"source_artifact_id":artifact_keys[item["artifact_key"]],"artifact_role":item["artifact_role"],"is_preferred":item["is_preferred"],"notes":item["notes"]})
    existing_acq={r["acquisition_key"] for r in state["acquisitions"]}
    for item in manifest["acquisition_actions"]:
        if item["acquisition_key"] not in existing_acq:
            row={k:v for k,v in item.items() if k not in {"action","artifact_key"} and v is not None}; row["source_artifact_id"]=artifact_keys[item["artifact_key"]]; client.insert("source_artifact_acquisitions",row)
    existing_rights={(r["source_key"],r["version_key"]) for r in state["rights"]}
    for item in manifest["rights_actions"]:
        key=(item["source_key"],item["version_key"])
        if key not in existing_rights:
            client.insert("source_rights", {"id":item["id"],"source_version_id":versions[key],"rights_status":item["rights_status"],"evidence_reference":item["evidence_reference"],"notes":item["notes"]})
    existing_policies={(r["source_key"],r["version_key"],r["use_scope"]) for r in state["policies"]}
    for item in manifest["policy_actions"]:
        key=(item["source_key"],item["version_key"],item["use_scope"])
        if key not in existing_policies:
            client.insert("source_use_policies", {"id":item["id"],"source_version_id":versions[key[:2]],"use_scope":item["use_scope"],"decision":item["decision"],"policy_version":item["policy_version"],"notes":item["notes"]})
    sets={r["artifact_set_key"]:r["id"] for r in state["sets"]}
    for item in manifest["artifact_set_actions"]:
        if item["artifact_set_key"] not in sets:
            client.insert("source_artifact_sets", {"id":item["id"],"artifact_set_key":item["artifact_set_key"],"source_version_id":versions[(item["source_key"],item["version_key"])],"set_type":item["set_type"],"label":item["label"],"notes":item["notes"]}); sets[item["artifact_set_key"]]=item["id"]
    existing_members={(r["artifact_set_key"],r["sequence_number"]) for r in state["members"]}
    for item in manifest["artifact_set_member_actions"]:
        key=(item["artifact_set_key"],item["sequence_number"])
        if key not in existing_members:
            source_key=next(s["source_key"] for s in manifest["artifact_set_actions"] if s["artifact_set_key"]==item["artifact_set_key"]); version_key=next(s["version_key"] for s in manifest["artifact_set_actions"] if s["artifact_set_key"]==item["artifact_set_key"])
            client.insert("source_artifact_set_members", {"id":item["id"],"artifact_set_id":sets[item["artifact_set_key"]],"source_version_id":versions[(source_key,version_key)],"source_artifact_id":artifact_keys[item["artifact_key"]],"sequence_number":item["sequence_number"],"component_label":item["component_label"]})


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Prepare or apply Michael Marlo Source Registration 001; defaults to dry-run.")
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument("--write-manifest", action="store_true")
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("--project-ref", choices=(STAGING_REF, PRODUCTION_REF), default=STAGING_REF)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--confirm-project-ref")
    parser.add_argument("--production-approved-registration-001", action="store_true")
    args = parser.parse_args(argv)
    if args.write_manifest:
        manifest=build_manifest(); MANIFEST_PATH.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8"); print(json.dumps({"status":"WRITTEN","path":str(MANIFEST_PATH),"semantic_digest":manifest["semantic_digest"]},sort_keys=True)); return 0
    manifest=json.loads(args.manifest.read_text(encoding="utf-8")); counts=validate_manifest(manifest)
    if args.validate: print(json.dumps({"status":"VALID","counts":counts,"semantic_digest":manifest["semantic_digest"]},sort_keys=True)); return 0
    state=cli_query(args.project_ref,inspection_sql(manifest)); planned=plan(manifest,state)
    output={"status":"EXECUTE" if args.execute else "DRY_RUN","project_ref":args.project_ref,"plan":planned}
    print(json.dumps(output,ensure_ascii=False,sort_keys=True))
    if planned["conflicts"]: raise RegistrationError("CONFLICT: registration identities differ from the manifest")
    if not args.execute: return 0
    if args.confirm_project_ref != args.project_ref: raise RegistrationError("--execute requires matching --confirm-project-ref")
    if args.project_ref == PRODUCTION_REF and not args.production_approved_registration_001: raise RegistrationError("production execution requires --production-approved-registration-001")
    url=os.environ.get("SUPABASE_URL"); key=os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key or args.project_ref not in url: raise RegistrationError("matching SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for execution")
    execute(manifest,state,RestClient(url,key)); print(json.dumps({"status":"EXECUTED","project_ref":args.project_ref},sort_keys=True)); return 0


if __name__ == "__main__":
    try: raise SystemExit(main())
    except RegistrationError as exc: print(f"ERROR: {exc}",file=sys.stderr); raise SystemExit(1)
