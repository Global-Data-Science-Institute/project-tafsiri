from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from scripts.linguistic_evidence.register_evidence import ALIASES, evidence_key, load_records
from scripts.source_registry.register_sources import RegistryError, RestClient

EVIDENCE_PATH = Path("artifacts/linguistic_evidence/extraction_001.jsonl")
COMPLETED_PATH = Path("artifacts/linguistic_evidence/extraction_001_review_completed.csv")
REVIEW_PATH = Path("artifacts/linguistic_evidence/extraction_001_human_review.json")
WRITABLE = {"contributors", "linguistic_evidence"}


class ReviewClient:
    def __init__(self, inner: RestClient): self.inner = inner
    def select(self, table: str, filters: dict[str, Any]): return self.inner.select(table, filters)
    def insert(self, table: str, row: dict[str, Any]):
        if table not in WRITABLE: raise RegistryError(f"review write guard rejected table: {table}")
        return self.inner._request("POST", table, body=row, extra={"Prefer": "return=representation"})[0]
    def update_evidence(self, evidence_id: str, row: dict[str, Any]):
        if set(row) != {"verification_status", "reviewed_by", "reviewed_at"}:
            raise RegistryError("review update attempted to change non-review fields")
        result=self.inner._request("PATCH", "linguistic_evidence", params={"id":f"eq.{evidence_id}"}, body=row, extra={"Prefer":"return=representation"})
        if len(result) != 1: raise RegistryError(f"evidence update did not affect exactly one row: {evidence_id}")
        return result[0]


def _sha(path: Path) -> str: return hashlib.sha256(path.read_bytes()).hexdigest()
def _norm(value: str | None) -> str: return " ".join((value or "").casefold().split())


def load_review() -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]]]:
    manifest=json.loads(REVIEW_PATH.read_text(encoding="utf-8")); evidence=load_records(EVIDENCE_PATH)
    with COMPLETED_PATH.open(encoding="utf-8-sig",newline="") as f: decisions=list(csv.DictReader(f))
    errors=[]
    if manifest.get("review_batch_key") != "TAFSIRI_HUMAN_SCHOLARLY_REVIEW_001": errors.append("unexpected review batch")
    if manifest.get("reviewed_evidence_count") != 110 or len(evidence) != 110 or len(decisions) != 110: errors.append("review must target exactly 110 rows")
    if len({r["evidence_key"] for r in evidence}) != 110: errors.append("duplicate extraction evidence keys")
    if {r.get("reviewer_decision") for r in decisions} != {"VERIFIED"}: errors.append("every completed decision must be VERIFIED")
    if {r["evidence_key"] for r in decisions} != {r["evidence_key"] for r in evidence}: errors.append("completed review does not match extraction keys")
    if manifest.get("source_extraction_manifest_sha256") != _sha(Path("artifacts/linguistic_evidence/extraction_001_manifest.json")): errors.append("extraction manifest checksum mismatch")
    if manifest.get("review_csv_sha256") != _sha(Path("artifacts/linguistic_evidence/extraction_001_review.csv")): errors.append("source review CSV checksum mismatch")
    if manifest.get("completed_review_csv_sha256") != _sha(COMPLETED_PATH): errors.append("completed review CSV checksum mismatch")
    by_key={r["evidence_key"]:r for r in evidence}
    for d in decisions:
        r=by_key[d["evidence_key"]]
        expected={"source_key":r["source_key"],"source_locator":r["source_locator"],"evidence_type":r["evidence_type"],"tafsiri_summary":r["summary"],"verification_status":"UNVERIFIED"}
        if any(d.get(k) != v for k,v in expected.items()): errors.append(f"{d['evidence_key']}: completed CSV rewrote extraction content")
    if errors: raise RegistryError("\n".join(errors))
    return manifest,evidence,decisions


def resolve_reviewer(client: ReviewClient, manifest: dict[str, Any], execute: bool) -> tuple[dict[str, Any], str]:
    wanted=manifest["reviewer"]; all_rows=client.select("contributors",{})
    email=[r for r in all_rows if _norm(r.get("email")) == _norm(wanted["email"])]
    if len(email)>1: raise RegistryError("multiple contributors match normalized reviewer email")
    if email:
        row=email[0]
        if _norm(row.get("name")) != _norm(wanted["name"]): raise RegistryError("reviewer email exists with conflicting name")
        return row,"reused"
    names=[r for r in all_rows if _norm(r.get("name")) == _norm(wanted["name"])]
    if len(names)>1: raise RegistryError("multiple contributors match normalized reviewer name")
    if names:
        row=names[0]
        if row.get("email") and _norm(row["email"]) != _norm(wanted["email"]): raise RegistryError("reviewer name exists with conflicting email")
        if not row.get("email"): raise RegistryError("existing name-only contributor requires explicit reconciliation")
        return row,"reused"
    return (client.insert("contributors",wanted) if execute else {"id":"planned:reviewer",**wanted}),"created"


def apply_review(client: ReviewClient, execute: bool) -> dict[str, int]:
    manifest,records,_=load_review(); reviewer,contributor_action=resolve_reviewer(client,manifest,execute)
    sources={r["source_key"]:r for r in client.select("sources",{})}; types={r["id"]:r for r in client.select("linguistic_evidence_types",{})}
    dialects={r["id"]:r for r in client.select("dialects",{})}; versions={r["id"]:r for r in client.select("source_versions",{})}
    mentions={r["id"]:r for r in client.select("source_variety_mentions",{})}
    all_evidence=client.select("linguistic_evidence",{})
    if len(all_evidence) != 110: raise RegistryError(f"precheck expected 110 evidence rows; found {len(all_evidence)}")
    db_by_key={}
    for row in all_evidence:
        note=row.get("notes") or ""
        if note.startswith("Extraction 001 key: "): db_by_key[note.removeprefix("Extraction 001 key: ")]=row
    if set(db_by_key) != {r["evidence_key"] for r in records}: raise RegistryError("database Extraction 001 key set differs from reviewed batch")
    links=client.select("linguistic_evidence_dialects",{}); notations=client.select("linguistic_evidence_notations",{}); g2ps=client.select("grapheme_phoneme_evidence",{})
    counts=Counter(contributors_created=contributor_action=="created",contributors_reused=contributor_action=="reused",evidence_updates=0,reviewed_reused=0,conflicts=0,content_changes=0)
    source_by_id={v["id"]:k for k,v in sources.items()}
    for record in records:
        key=record["evidence_key"]; db=db_by_key[key]; version=versions[db["source_version_id"]]
        expected_parent={"source_key":record["source_key"],"source_version":record["source_version"],"evidence_type":record["evidence_type"],"evidence_scope":record["evidence_scope"],"source_locator":record["source_locator"],"summary":record["summary"],"provenance_origin":"MACHINE_GENERATED","extraction_method":"LLM_ASSISTED","extractor_version":record["extractor_version"],"tool_or_model":record["tool_or_model"],"prompt_version":record["prompt_version"],"extracted_at":record["extracted_at"]}
        actual_parent={"source_key":source_by_id[version["source_id"]],"source_version":version["version_key"],"evidence_type":types[db["evidence_type_id"]]["evidence_type_key"],**{k:db[k] for k in ("evidence_scope","source_locator","summary","provenance_origin","extraction_method","extractor_version","tool_or_model","prompt_version","extracted_at")}}
        if actual_parent["extracted_at"].endswith("+00:00"): actual_parent["extracted_at"]=actual_parent["extracted_at"][:-6]+"Z"
        if actual_parent != expected_parent: raise RegistryError(f"{key}: evidence content differs from reviewed extraction")
        actual_links={(dialects[x["dialect_id"]]["name"],mentions[x["source_variety_mention_id"]]["literal_variety_name"],x["role"]) for x in links if x["evidence_id"]==db["id"]}
        expected_links={(ALIASES.get(x["canonical_dialect"].casefold(),x["canonical_dialect"]),x["literal_variety"],x["role"]) for x in record["dialects"]}
        if actual_links != expected_links: raise RegistryError(f"{key}: dialect links differ")
        actual_not=[(x["notation_type"],x["notation_text"],x.get("label")) for x in sorted((n for n in notations if n["evidence_id"]==db["id"]),key=lambda x:x["order_index"])]
        expected_not=[(x["notation_type"],x["notation_text"],x.get("label")) for x in record["notations"]]
        if actual_not != expected_not: raise RegistryError(f"{key}: notations differ")
        actual_g=[x for x in g2ps if x["evidence_id"]==db["id"]]
        if bool(actual_g) != bool(record.get("g2p")) or (actual_g and any(actual_g[0].get(k)!=v for k,v in record["g2p"].items())): raise RegistryError(f"{key}: G2P child differs")
        if db["verification_status"] == "UNVERIFIED" and db.get("reviewed_by") is None and db.get("reviewed_at") is None:
            counts["evidence_updates"]+=1
            if execute: client.update_evidence(db["id"],{"verification_status":"VERIFIED","reviewed_by":reviewer["id"],"reviewed_at":manifest["review_completed_at"]})
        elif db["verification_status"]=="VERIFIED" and db.get("reviewed_by")==reviewer["id"] and db.get("reviewed_at","").replace("+00:00","Z")==manifest["review_completed_at"]:
            counts["reviewed_reused"]+=1
        else: raise RegistryError(f"{key}: conflicting review state")
    return {k:int(v) for k,v in counts.items()}


def main(argv: list[str] | None=None) -> int:
    p=argparse.ArgumentParser(); modes=p.add_mutually_exclusive_group(required=True); modes.add_argument("--validate",action="store_true"); modes.add_argument("--dry-run",action="store_true"); modes.add_argument("--execute",action="store_true")
    p.add_argument("--project-ref"); p.add_argument("--confirm-project-ref"); a=p.parse_args(argv)
    if a.validate: manifest,records,decisions=load_review(); print(json.dumps({"status":"VALID","reviewed":len(records),"decisions":len(decisions)},sort_keys=True)); return 0
    if not a.project_ref: p.error("--project-ref is required")
    if a.execute and a.confirm_project_ref != a.project_ref: p.error("--execute requires matching --confirm-project-ref")
    url=os.environ.get("SUPABASE_URL"); secret=os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_SECRET_KEY")
    if not url or not secret or a.project_ref not in url: raise RegistryError("matching SUPABASE_URL and service role/secret key are required")
    result=apply_review(ReviewClient(RestClient(url,secret)),a.execute)
    print(json.dumps({"status":"EXECUTED" if a.execute else "DRY_RUN","project_ref":a.project_ref,"changes":result},sort_keys=True)); return 0

if __name__=="__main__":
    try: raise SystemExit(main())
    except RegistryError as exc: print(f"ERROR: {exc}",file=sys.stderr); raise SystemExit(1)
