from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from scripts.source_registry.register_sources import RegistryError, RestClient

SOURCE_TYPES = {"JOURNAL_ARTICLE", "ACADEMIC_PAPER", "BOOK_CHAPTER", "THESIS", "DISSERTATION", "CONFERENCE_PAPER", "TECHNICAL_REPORT", "BOOK"}
TYPE_MAP = {"DOCTORAL_DISSERTATION": "DISSERTATION", "MASTERS_THESIS": "THESIS"}
AUTHORITIES = {"PEER_REVIEWED", "PUBLISHED_BOOK_CHAPTER", "DOCTORAL_DISSERTATION", "MASTERS_THESIS", "CONFERENCE_PROCEEDINGS", "INSTITUTIONAL_REPORT", "WORKING_PAPER", "BOOK", "OTHER", "UNKNOWN"}
AVAILABILITY = {"OPEN_FULL_TEXT", "PUBLIC_FULL_TEXT_UNCLEAR_LICENSE", "ABSTRACT_ONLY", "PAYWALLED", "METADATA_ONLY", "UNAVAILABLE"}
LICENSES = {"LICENSE_UNKNOWN", "COPYRIGHT_RESTRICTED", "CC_BY_4_0", "CC_BY_NC", "OTHER_OPEN_LICENSE"}
USE_SCOPES = ("INTERNAL_RESEARCH", "HUMAN_REVIEW", "REVIEWER_DISPLAY", "PUBLIC_DISPLAY", "REDISTRIBUTION", "MODEL_TRAINING", "BENCHMARK_PUBLICATION", "COMMERCIAL_API")
WRITABLE_TABLES = {"sources", "source_versions", "source_scholarly_metadata", "source_identifiers", "source_access_locations", "source_variety_mentions", "source_rights", "source_use_policies"}
EVIDENCE_TABLES = {"linguistic_evidence", "linguistic_evidence_dialects", "linguistic_evidence_notations", "grapheme_phoneme_evidence", "linguistic_examples", "linguistic_example_tiers", "linguistic_evidence_relations"}
POLICY_VERSION = "LITERATURE_REGISTRATION_001"

ALIASES = {
    "bukusu": "Bukusu", "lubukusu": "Bukusu", "wanga": "Luwanga", "luwanga": "Luwanga",
    "llogoori": "Maragoli", "logoori": "Maragoli", "maragoli": "Maragoli", "lulogooli": "Maragoli",
    "tiriki": "Tiriki", "lutiriki": "Tiriki", "marachi": "Marachi", "lumarachi": "Marachi",
    "samia": "Samia", "saamia": "Samia", "lusamia": "Samia", "olusamia": "Samia",
    "khayo": "Khayo", "lukhayo": "Khayo", "olukhayo": "Khayo", "kisa": "Kisa", "lukisa": "Kisa",
    "marama": "Marama", "lumarama": "Marama", "olumarama": "Marama", "nyala-west": "Nyala",
    "lunyala": "Nyala", "olunyala": "Nyala", "lunyore": "Lunyore", "tsotso": "Tsotso", "lutsotso": "Tsotso",
    "idakho": "Idakho", "lwitakho": "Idakho", "lwidakho": "Idakho", "isukha": "Isukha", "lwisukha": "Isukha",
    "tachoni": "Tachoni", "lukabras": "Lukabras",
}


class GuardedClient:
    def __init__(self, inner: RestClient): self.inner = inner
    def select(self, table: str, filters: dict[str, Any]): return self.inner.select(table, filters)
    def insert(self, table: str, row: dict[str, Any]):
        if table not in WRITABLE_TABLES or table in EVIDENCE_TABLES:
            raise RegistryError(f"write guard rejected table: {table}")
        # RestClient's older allowlist intentionally excludes Migration 007 tables.
        return self.inner._request("POST", table, body=row, extra={"Prefer": "return=representation"})[0]


def load_manifest(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def normalized_doi(value: str) -> str:
    value = value.strip()
    value = re.sub(r"^https?://(?:dx\.)?doi\.org/", "", value, flags=re.I)
    return value.lower()


def mapped_type(item: dict[str, Any]) -> str:
    return TYPE_MAP.get(item["source_type"], item["source_type"])


def version_key(item: dict[str, Any]) -> str:
    prefix = {"DISSERTATION": "DISSERTATION", "THESIS": "THESIS", "CONFERENCE_PAPER": "CONFERENCE_VERSION"}.get(mapped_type(item), "PUBLICATION")
    return f"{prefix}_{item['year']}" if isinstance(item.get("year"), int) else f"{prefix}_UNDATED_METADATA"


def validation_issues(manifest: dict[str, Any]) -> list[str]:
    issues=[]
    for item in manifest.get("sources", []):
        if not isinstance(item.get("year"), int): issues.append(f"{item.get('source_key')}: publication year is missing")
        if not item.get("authors") or item.get("authors") == ["Unknown"]: issues.append(f"{item.get('source_key')}: author metadata is unresolved")
    return issues


def validate_manifest(manifest: dict[str, Any]) -> dict[str, int]:
    errors: list[str] = []
    sources = manifest.get("sources")
    if manifest.get("source_count") != 46 or not isinstance(sources, list) or len(sources) != 46:
        errors.append("manifest must declare and contain exactly 46 sources")
        sources = sources or []
    keys = [x.get("source_key") for x in sources]
    if len(keys) != len(set(keys)) or any(not x for x in keys): errors.append("source keys must be stable, unique, and non-blank")
    dois, title_year = [], []
    for item in sources:
        key = item.get("source_key", "<missing>")
        if mapped_type(item) not in SOURCE_TYPES: errors.append(f"{key}: unsupported source type {item.get('source_type')}")
        if item.get("authority_type") not in AUTHORITIES: errors.append(f"{key}: invalid authority_type")
        if item.get("availability") not in AVAILABILITY: errors.append(f"{key}: invalid availability")
        if item.get("license_status") not in LICENSES: errors.append(f"{key}: invalid license_status")
        if not item.get("title"): errors.append(f"{key}: title is required")
        if isinstance(item.get("year"), int): title_year.append((re.sub(r"\W+", " ", item.get("title", "").casefold()).strip(), item.get("year")))
        if item.get("doi"): dois.append(normalized_doi(item["doi"]))
        art = item.get("artifact")
        if art and (not re.fullmatch(r"[0-9a-fA-F]{64}", art.get("sha256", "")) or not isinstance(art.get("bytes"), int)): errors.append(f"{key}: invalid artifact checksum metadata")
    if len(dois) != len(set(dois)): errors.append("duplicate DOI identity")
    duplicates = [x for x, n in Counter(title_year).items() if n > 1]
    if duplicates: errors.append(f"duplicate normalized title/year identity: {duplicates}")
    if errors: raise RegistryError("\n".join(errors))
    eligible=len(sources)
    return {"inventory_sources": len(sources), "eligible_sources": eligible, "validation_issues": len(validation_issues(manifest)), "versions": eligible, "scholarly_metadata": eligible, "rights": eligible, "policies": eligible * len(USE_SCOPES)}


def citation(item: dict[str, Any]) -> str:
    parts=["; ".join(item["authors"])]
    if isinstance(item.get("year"),int): parts.append(str(item["year"]))
    parts.extend([item["title"], item.get("publication")])
    return ". ".join(x for x in parts if x).strip()+"."


def rights(item: dict[str, Any]) -> dict[str, Any]:
    status = item["license_status"]
    row: dict[str, Any] = {"rights_status": "UNKNOWN", "evidence_reference": "Literature Inventory 001 license classification.", "notes": f"Inventory classification: {status}. Availability is recorded independently."}
    if status == "COPYRIGHT_RESTRICTED": row["rights_status"] = "RESTRICTED"
    if status in {"CC_BY_4_0", "CC_BY_NC", "OTHER_OPEN_LICENSE"}:
        row["rights_status"] = "OPEN_LICENSE"
        row["license_identifier"] = {"CC_BY_4_0": "CC-BY-4.0", "CC_BY_NC": "CC-BY-NC", "OTHER_OPEN_LICENSE": "OTHER_OPEN_LICENSE"}[status]
    return row


def policies(item: dict[str, Any]) -> list[dict[str, Any]]:
    license_status = item["license_status"]
    result = []
    for scope in USE_SCOPES:
        decision = "UNKNOWN"
        basis = None
        if scope == "INTERNAL_RESEARCH":
            decision, basis = "ALLOWED", "Literature Registration 001 permits internal bibliographic research with preserved provenance."
        elif license_status == "CC_BY_4_0":
            decision, basis = "ALLOWED", "Inventory records CC BY 4.0; attribution and license conditions apply."
        elif license_status == "CC_BY_NC":
            decision, basis = (("DISALLOWED", "Inventory records a noncommercial license.") if scope == "COMMERCIAL_API" else ("REVIEW_REQUIRED", "CC BY-NC conditions require use-specific review."))
        elif license_status == "OTHER_OPEN_LICENSE":
            decision, basis = "REVIEW_REQUIRED", "Inventory records an open license without a normalized identifier; terms require review."
        elif license_status == "COPYRIGHT_RESTRICTED":
            decision, basis = (("DISALLOWED", "Inventory records copyright restriction and no permission.") if scope in {"PUBLIC_DISPLAY", "REDISTRIBUTION", "COMMERCIAL_API"} else ("REVIEW_REQUIRED", "Copyright-controlled use requires review."))
        row = {"use_scope": scope, "decision": decision, "policy_version": POLICY_VERSION}
        if basis: row["policy_basis_reference"] = basis
        result.append(row)
    return result


def location_type(url: str) -> str:
    host = urlparse(url).hostname or ""
    if "zenodo" in host: return "ZENODO"
    if "researchgate" in host: return "RESEARCHGATE"
    if "academia.edu" in host: return "ACADEMIA"
    if any(x in host for x in ("repository", "ir-library", "erepository", "etd.", "scholarspace", "publikationen")): return "INSTITUTIONAL_REPOSITORY"
    if "doi.org" in host: return "PUBLISHER"
    return "OTHER"


def desired(item: dict[str, Any]) -> dict[str, Any]:
    source = {"source_key": item["source_key"], "source_type": mapped_type(item), "title": item["title"], "authors_or_contributors": "; ".join(item["authors"]), "publisher_or_institution": item.get("publication"), "publication_year": item.get("year"), "citation": citation(item), "primary_url": item.get("primary_url"), "notes": item.get("notes")}
    source = {k:v for k,v in source.items() if v is not None}
    version = {"version_key": version_key(item), "version_label": f"published {item['year']}" if isinstance(item.get("year"),int) else "undated metadata record", "canonical_url": item.get("primary_url"), "notes": "Year-level publication identity; no exact date asserted." if isinstance(item.get("year"),int) else "Publication year is unresolved in Literature Inventory 001; no date is asserted."}
    version = {k:v for k,v in version.items() if v is not None}
    meta = {"authority_type": item["authority_type"], "publication_title": item.get("publication"), "peer_reviewed": True if item["authority_type"] == "PEER_REVIEWED" else None, "language_of_publication": "English", "notes": item.get("notes")}
    if item["authority_type"] in {"DOCTORAL_DISSERTATION", "MASTERS_THESIS"}:
        meta["institution"] = item.get("publication"); meta["degree_type"] = "Doctoral dissertation" if item["authority_type"] == "DOCTORAL_DISSERTATION" else "Master's thesis"
    meta = {k:v for k,v in meta.items() if v is not None}
    identifiers = []
    if item.get("doi"):
        doi = normalized_doi(item["doi"]); identifiers.append({"identifier_type": "ZENODO_DOI" if doi.startswith("10.5281/zenodo.") else "DOI", "identifier_value": doi, "canonical_url": f"https://doi.org/{doi}", "is_primary": True, "verification_status": "VERIFIED"})
    if item.get("isbn"): identifiers.append({"identifier_type": "ISBN", "identifier_value": item["isbn"], "is_primary": not identifiers, "verification_status": "VERIFIED"})
    urls = [item.get("primary_url"), *(item.get("alternate_urls") or [])]
    locations = []
    for i, url in enumerate(x for x in urls if x):
        row = {"url": url, "location_type": location_type(url), "host": urlparse(url).hostname, "is_primary": i == 0, "availability": item["availability"], "downloadable": bool(item.get("downloadable_pdf"))}
        if i == 0 and item.get("artifact"):
            art=item["artifact"]; row.update(artifact_filename=art.get("filename"), artifact_sha256=art.get("sha256"), artifact_bytes=art.get("bytes"))
        locations.append({k:v for k,v in row.items() if v is not None})
    candidates = {ALIASES.get(x.casefold(), x): x for x in item.get("candidate_tafsiri_dialects", [])}
    mentions=[]
    for literal in item.get("source_reported_varieties", []):
        canonical=ALIASES.get(literal.casefold())
        row={"literal_variety_name":literal,"mention_scope":"METADATA","mapping_status":"UNMAPPED"}
        if canonical in candidates: row.update(candidate_name=candidates[canonical], mapping_status="CANDIDATE", rationale="Candidate Tafsiri dialect link supplied by Literature Inventory 001; linguistic verification remains pending.")
        mentions.append(row)
    return {"source":source,"version":version,"metadata":meta,"identifiers":identifiers,"locations":locations,"mentions":mentions,"rights":rights(item),"policies":policies(item)}


def _equal(existing: dict[str, Any], row: dict[str, Any]) -> bool: return all(existing.get(k) == v for k,v in row.items())
def _one(rows: list[dict[str, Any]], label: str):
    if len(rows)>1: raise RegistryError(f"conflicting duplicate rows: {label}")
    return rows[0] if rows else None


def register(manifest: dict[str, Any], client: Any, execute: bool) -> dict[str, int]:
    validate_manifest(manifest)
    changes=Counter(sources=0,versions=0,scholarly_metadata=0,identifiers=0,access_locations=0,variety_mentions=0,rights=0,use_policies=0,duplicates_reused=0,conflicts=0,skipped=0)
    dialects={r["name"].casefold():r for r in client.select("dialects",{})}
    # Complete reference and identity preflight before the first possible write.
    for item in manifest["sources"]:
        d=desired(item); key=item["source_key"]
        current=client.select("sources",{"source_key":key})
        if not current and isinstance(item.get("year"),int):
            same_identity=client.select("sources",{"title":item["title"],"publication_year":item["year"]})
            if same_identity: raise RegistryError(f"CONFLICT duplicate title/year identity for {key}: {same_identity[0].get('source_key')}")
        for mention in d["mentions"]:
            candidate=mention.get("candidate_name")
            if candidate:
                canon=ALIASES.get(candidate.casefold(),candidate)
                if candidate.casefold() not in dialects and canon.casefold() not in dialects:
                    raise RegistryError(f"unknown candidate dialect {candidate} for {key}")
    for item in manifest["sources"]:
        d=desired(item); key=item["source_key"]
        cur=_one(client.select("sources",{"source_key":key}),key)
        if cur and not _equal(cur,d["source"]): raise RegistryError(f"CONFLICT source {key}")
        if not cur:
            changes["sources"]+=1; cur=client.insert("sources",d["source"]) if execute else {"id":f"planned:{key}"}
        else: changes["duplicates_reused"]+=1
        sid=cur["id"]; vr={**d["version"],"source_id":sid}
        ver=None if str(sid).startswith("planned:") else _one(client.select("source_versions",{"source_id":sid,"version_key":vr["version_key"]}),f"version {key}")
        if ver and not _equal(ver,vr): raise RegistryError(f"CONFLICT version {key}")
        if not ver: changes["versions"]+=1; ver=client.insert("source_versions",vr) if execute else {"id":f"planned:{key}:version"}
        vid=ver["id"]
        def ensure(table,label,row,filters,counter):
            existing=None if str(vid).startswith("planned:") else _one(client.select(table,filters),label)
            if existing and not _equal(existing,row): raise RegistryError(f"CONFLICT {label}")
            if not existing:
                changes[counter]+=1
                if execute: client.insert(table,row)
        ensure("source_scholarly_metadata",f"metadata {key}",{**d["metadata"],"source_version_id":vid},{"source_version_id":vid},"scholarly_metadata")
        for row in d["identifiers"]:
            full={**row,"source_version_id":vid}; ensure("source_identifiers",f"identifier {key}/{row['identifier_type']}",full,{"identifier_type":row["identifier_type"],"identifier_value":row["identifier_value"]},"identifiers")
        for row in d["locations"]:
            full={**row,"source_version_id":vid}; ensure("source_access_locations",f"location {key}/{row['url']}",full,{"source_version_id":vid,"url":row["url"]},"access_locations")
        for desired_mention in d["mentions"]:
            row=dict(desired_mention); candidate=row.pop("candidate_name",None); full={**row,"source_version_id":vid}
            if candidate:
                dialect=dialects.get(candidate.casefold())
                if not dialect:
                    # Inventory labels can be established aliases of the canonical registry names.
                    canon=ALIASES.get(candidate.casefold(),candidate); dialect=dialects.get(canon.casefold())
                if not dialect: raise RegistryError(f"unknown candidate dialect {candidate} for {key}")
                full["candidate_dialect_id"]=dialect["id"]
            ensure("source_variety_mentions",f"variety {key}/{row['literal_variety_name']}",full,{"source_version_id":vid,"literal_variety_name":row["literal_variety_name"],"mention_scope":"METADATA"},"variety_mentions")
        ensure("source_rights",f"rights {key}",{**d["rights"],"source_version_id":vid},{"source_version_id":vid,"superseded_at":"is.null"},"rights")
        for row in d["policies"]:
            full={**row,"source_version_id":vid}; ensure("source_use_policies",f"policy {key}/{row['use_scope']}",full,{"source_version_id":vid,"use_scope":row["use_scope"],"superseded_at":"is.null"},"use_policies")
    return dict(changes)


def main(argv: list[str] | None=None) -> int:
    p=argparse.ArgumentParser(); p.add_argument("--manifest",type=Path,default=Path("config/linguistic_sources/literature_registry_001.json"))
    modes=p.add_mutually_exclusive_group(required=True); modes.add_argument("--validate",action="store_true"); modes.add_argument("--dry-run",action="store_true"); modes.add_argument("--execute",action="store_true")
    p.add_argument("--project-ref"); p.add_argument("--confirm-project-ref"); a=p.parse_args(argv)
    manifest=load_manifest(a.manifest); counts=validate_manifest(manifest)
    if a.validate: print(json.dumps({"status":"VALID_WITH_ISSUES" if validation_issues(manifest) else "VALID","manifest_counts":counts,"issues":validation_issues(manifest)},sort_keys=True)); return 0
    if not a.project_ref: p.error("--project-ref is required")
    if a.execute and a.confirm_project_ref != a.project_ref: p.error("--execute requires matching --confirm-project-ref")
    url=os.environ.get("SUPABASE_URL"); key=os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_SECRET_KEY")
    if not url or not key or a.project_ref not in url: raise RegistryError("matching SUPABASE_URL and service role/secret key are required")
    result=register(manifest,GuardedClient(RestClient(url,key)),a.execute)
    print(json.dumps({"status":"EXECUTED" if a.execute else "DRY_RUN","project_ref":a.project_ref,"changes":result},sort_keys=True)); return 0

if __name__=="__main__":
    try: raise SystemExit(main())
    except RegistryError as exc: print(f"ERROR: {exc}",file=sys.stderr); raise SystemExit(1)
