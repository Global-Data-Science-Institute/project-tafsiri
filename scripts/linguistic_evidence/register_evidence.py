from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from scripts.source_registry.register_sources import RegistryError, RestClient

WRITABLE_TABLES = {
    "linguistic_evidence", "linguistic_evidence_dialects",
    "linguistic_evidence_notations", "grapheme_phoneme_evidence",
    "linguistic_examples", "linguistic_example_tiers",
    "linguistic_evidence_relations",
}
SCOPES = {"DIALECT", "MULTI_DIALECT_COMPARATIVE", "PROTO_LANGUAGE", "FAMILY_GENERALIZATION"}
NOTATION_TYPES = {"IPA_PHONEMIC", "IPA_PHONETIC", "ORTHOGRAPHIC", "H_L_TONE", "AUTOSEGMENTAL", "FEATURE_DESCRIPTION", "OTHER"}
DISPLAY_POLICIES = {"RESEARCH_ONLY", "REVIEWER_ALLOWED", "PUBLIC_ALLOWED", "UNKNOWN"}
TIER_TYPES = {"ORTHOGRAPHY", "SEGMENTATION", "MORPHEME_GLOSS", "WORD_GLOSS", "FREE_TRANSLATION", "PHONEMIC", "PHONETIC", "TONE", "OTHER"}
G2P_TYPES = {"GRAPHEME_PHONEME_RULE", "ALLOPHONIC_RULE"}
ALIASES = {
    "lubukusu": "Bukusu", "bukusu": "Bukusu", "luwanga": "Luwanga", "wanga": "Luwanga",
    "lwisukha": "Isukha", "isukha": "Isukha", "lwidakho": "Idakho", "idakho": "Idakho",
    "lukisa": "Kisa", "kisa": "Kisa", "lumarama": "Marama", "olumarama": "Marama", "marama": "Marama",
    "llogoori": "Maragoli", "lulogooli": "Maragoli", "maragoli": "Maragoli",
    "lutiriki": "Tiriki", "tiriki": "Tiriki", "lunyore": "Lunyore", "lusamia": "Samia", "lusaamia": "Samia",
    "tachoni": "Tachoni", "nyala-west": "Nyala",
}


def normalized_summary(value: str) -> str:
    return re.sub(r"\s+", " ", value.casefold()).strip()


def evidence_key(record: dict[str, Any]) -> str:
    identity = "|".join((record["source_key"], record["source_version"], record["source_locator"], record["evidence_type"], normalized_summary(record["summary"])))
    return "LE001_" + hashlib.sha256(identity.encode("utf-8")).hexdigest()[:24].upper()


def load_records(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def validate(records: list[dict[str, Any]]) -> dict[str, int]:
    errors: list[str] = []
    keys: list[str] = []
    for i, row in enumerate(records, 1):
        label = row.get("evidence_key", f"line {i}")
        required = ("source_key", "source_version", "source_locator", "summary", "evidence_type", "evidence_scope")
        if any(not str(row.get(k, "")).strip() for k in required): errors.append(f"{label}: required field is blank")
        expected = evidence_key(row)
        if row.get("evidence_key") != expected: errors.append(f"{label}: deterministic key should be {expected}")
        keys.append(row.get("evidence_key", ""))
        if row.get("evidence_scope") not in SCOPES: errors.append(f"{label}: invalid scope")
        if row.get("provenance_origin") != "MACHINE_GENERATED": errors.append(f"{label}: provenance must remain MACHINE_GENERATED")
        if row.get("extraction_method") != "LLM_ASSISTED": errors.append(f"{label}: extraction must remain LLM_ASSISTED")
        if row.get("verification_status") != "UNVERIFIED": errors.append(f"{label}: initial status must be UNVERIFIED")
        if row.get("g2p") and row.get("evidence_type") not in G2P_TYPES: errors.append(f"{label}: incompatible G2P child")
        for n, notation in enumerate(row.get("notations", [])):
            if notation.get("notation_type") not in NOTATION_TYPES or not notation.get("notation_text"): errors.append(f"{label}: invalid notation {n}")
        for x, example in enumerate(row.get("examples", [])):
            if example.get("display_policy") not in DISPLAY_POLICIES: errors.append(f"{label}: invalid example policy {x}")
            orders = [t.get("tier_order") for t in example.get("tiers", [])]
            if orders != sorted(orders) or len(orders) != len(set(orders)): errors.append(f"{label}: invalid tier ordering")
            if any(t.get("tier_type") not in TIER_TYPES for t in example.get("tiers", [])): errors.append(f"{label}: invalid tier type")
    if len(keys) != len(set(keys)): errors.append("duplicate evidence keys")
    if errors: raise RegistryError("\n".join(errors))
    return {"records": len(records), "unique_keys": len(set(keys))}


class GuardedClient:
    def __init__(self, inner: RestClient): self.inner = inner
    def select(self, table: str, filters: dict[str, Any]): return self.inner.select(table, filters)
    def insert(self, table: str, row: dict[str, Any]):
        if table not in WRITABLE_TABLES: raise RegistryError(f"write guard rejected table: {table}")
        return self.inner._request("POST", table, body=row, extra={"Prefer": "return=representation"})[0]


def _same(current: dict[str, Any], desired: dict[str, Any]) -> bool:
    def canonical(value: Any) -> Any:
        # PostgREST serializes UTC timestamps with +00:00 even when input used Z.
        if isinstance(value, str) and value.endswith("Z"):
            return value[:-1] + "+00:00"
        return value
    return all(canonical(current.get(k)) == canonical(v) for k, v in desired.items())


def register(records: list[dict[str, Any]], client: Any, execute: bool) -> dict[str, int]:
    validate(records)
    counts = Counter(evidence=0, dialect_links=0, notations=0, g2p=0, examples=0, tiers=0, relations=0, duplicates=0, conflicts=0)
    sources = {r["source_key"]: r for r in client.select("sources", {})}
    types = {r["evidence_type_key"]: r for r in client.select("linguistic_evidence_types", {"is_active": True})}
    dialects = {r["name"].casefold(): r for r in client.select("dialects", {})}
    resolved: dict[str, dict[str, Any]] = {}
    # Complete reference preflight before the first possible write.
    for row in records:
        key = row["evidence_key"]; source = sources.get(row["source_key"])
        if not source: raise RegistryError(f"{key}: source is not registered")
        versions = client.select("source_versions", {"source_id": source["id"], "version_key": row["source_version"]})
        if len(versions) != 1: raise RegistryError(f"{key}: source version does not resolve uniquely")
        if row["evidence_type"] not in types: raise RegistryError(f"{key}: evidence type is not active")
        links=[]
        for link in row.get("dialects", []):
            canonical = ALIASES.get(link["canonical_dialect"].casefold(), link["canonical_dialect"])
            dialect = dialects.get(canonical.casefold())
            if not dialect: raise RegistryError(f"{key}: unresolved dialect {canonical}")
            mentions = client.select("source_variety_mentions", {"source_version_id": versions[0]["id"], "literal_variety_name": link["literal_variety"]})
            if len(mentions) != 1: raise RegistryError(f"{key}: literal variety does not resolve uniquely: {link['literal_variety']}")
            links.append((link, dialect, mentions[0]))
        resolved[key]={"version":versions[0],"type":types[row["evidence_type"]],"links":links}
    evidence_ids: dict[str, str] = {}
    for row in records:
        key=row["evidence_key"]; rr=resolved[key]
        desired={"source_version_id":rr["version"]["id"],"evidence_type_id":rr["type"]["id"],"evidence_scope":row["evidence_scope"],"source_locator":row["source_locator"],"summary":row["summary"],"provenance_origin":"MACHINE_GENERATED","verification_status":"UNVERIFIED","extraction_method":"LLM_ASSISTED","extractor_version":row["extractor_version"],"tool_or_model":row["tool_or_model"],"prompt_version":row["prompt_version"],"extracted_at":row["extracted_at"],"notes":f"Extraction 001 key: {key}"}
        existing=client.select("linguistic_evidence", {"source_version_id":desired["source_version_id"],"source_locator":desired["source_locator"],"evidence_type_id":desired["evidence_type_id"]})
        matches=[x for x in existing if normalized_summary(x.get("summary", "")) == normalized_summary(row["summary"])]
        if len(matches)>1: raise RegistryError(f"{key}: duplicate database identity")
        if matches:
            if not _same(matches[0],desired): raise RegistryError(f"{key}: CONFLICT with existing evidence")
            ev=matches[0]; counts["duplicates"]+=1
        else:
            counts["evidence"]+=1; ev=client.insert("linguistic_evidence",desired) if execute else {"id":f"planned:{key}"}
        evidence_ids[key]=ev["id"]
        eid=ev["id"]
        def ensure(table: str, desired_child: dict[str, Any], filters: dict[str, Any], counter: str):
            current=[] if str(eid).startswith("planned:") else client.select(table,filters)
            if len(current)>1 or (current and not _same(current[0],desired_child)): raise RegistryError(f"{key}: CONFLICT in {table}")
            if not current:
                counts[counter]+=1
                if execute: client.insert(table,desired_child)
        for link,dialect,mention in rr["links"]:
            d={"evidence_id":eid,"dialect_id":dialect["id"],"role":link["role"],"source_variety_mention_id":mention["id"]}
            ensure("linguistic_evidence_dialects",d,{"evidence_id":eid,"dialect_id":dialect["id"],"role":link["role"]},"dialect_links")
        for idx,n in enumerate(row.get("notations", [])):
            d={"evidence_id":eid,"notation_type":n["notation_type"],"notation_text":n["notation_text"],"order_index":idx,**({"label":n["label"]} if n.get("label") else {})}
            ensure("linguistic_evidence_notations",d,{"evidence_id":eid,"order_index":idx},"notations")
        if row.get("g2p"):
            d={"evidence_id":eid,**row["g2p"]}; ensure("grapheme_phoneme_evidence",d,{"evidence_id":eid},"g2p")
        for idx,ex in enumerate(row.get("examples", [])):
            d={k:v for k,v in {"evidence_id":eid,"source_locator":ex["source_locator"],"example_type":ex["example_type"],"source_text":ex.get("source_text"),"free_translation":ex.get("free_translation"),"display_policy":ex["display_policy"],"order_index":idx}.items() if v is not None}
            ensure("linguistic_examples",d,{"evidence_id":eid,"order_index":idx},"examples")
    # Relations are deliberately absent in Extraction 001 unless explicitly documented.
    return dict(counts)


def main(argv: list[str] | None = None) -> int:
    p=argparse.ArgumentParser(); p.add_argument("--input",type=Path,default=Path("artifacts/linguistic_evidence/extraction_001.jsonl"))
    modes=p.add_mutually_exclusive_group(required=True); modes.add_argument("--validate",action="store_true"); modes.add_argument("--dry-run",action="store_true"); modes.add_argument("--execute",action="store_true")
    p.add_argument("--project-ref"); p.add_argument("--confirm-project-ref"); a=p.parse_args(argv)
    records=load_records(a.input)
    if a.validate: print(json.dumps({"status":"VALID","counts":validate(records)},sort_keys=True)); return 0
    if not a.project_ref: p.error("--project-ref is required")
    if a.execute and a.confirm_project_ref != a.project_ref: p.error("--execute requires matching --confirm-project-ref")
    url=os.environ.get("SUPABASE_URL"); secret=os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_SECRET_KEY")
    if not url or not secret or a.project_ref not in url: raise RegistryError("matching SUPABASE_URL and service role/secret key are required")
    result=register(records,GuardedClient(RestClient(url,secret)),a.execute)
    print(json.dumps({"status":"EXECUTED" if a.execute else "DRY_RUN","project_ref":a.project_ref,"changes":result},sort_keys=True)); return 0


if __name__ == "__main__":
    try: raise SystemExit(main())
    except RegistryError as exc: print(f"ERROR: {exc}",file=sys.stderr); raise SystemExit(1)
