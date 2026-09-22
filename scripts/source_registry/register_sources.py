from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Any

SOURCE_TYPES = {"DICTIONARY", "LEXICON", "WEBSITE", "CORPUS", "BIBLE_EDITION", "PROVERB_COLLECTION", "FIELDWORK", "COMMUNITY_CONTRIBUTION", "DATASET", "OTHER"}
RIGHTS_STATUSES = {"OPEN_LICENSE", "PUBLIC_DOMAIN", "PERMISSION_GRANTED", "PUBLICLY_ACCESSIBLE_CITED", "CONTACTED_NO_RESPONSE", "RESTRICTED", "UNKNOWN"}
USE_SCOPES = {"INTERNAL_RESEARCH", "HUMAN_REVIEW", "REVIEWER_DISPLAY", "PUBLIC_DISPLAY", "REDISTRIBUTION", "MODEL_TRAINING", "BENCHMARK_PUBLICATION", "COMMERCIAL_API"}
DECISIONS = {"ALLOWED", "DISALLOWED", "REVIEW_REQUIRED", "UNKNOWN"}
WRITABLE_TABLES = {"sources", "source_versions", "source_rights", "source_use_policies", "source_contact_events", "source_dialect_mapping_assertions"}


class RegistryError(ValueError):
    pass


def load_manifest(path: Path) -> dict[str, Any]:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    profiles = manifest.get("policy_profiles", {})
    for source in manifest.get("sources", []):
        for version in source.get("versions", []):
            profile = version.pop("use_policy_profile", None)
            if profile:
                if profile not in profiles:
                    raise RegistryError(f"unknown policy profile: {profile}")
                version["use_policies"] = [dict(item) for item in profiles[profile]]
    return manifest


def validate_manifest(manifest: dict[str, Any]) -> dict[str, int]:
    errors: list[str] = []
    sources = manifest.get("sources")
    if not isinstance(sources, list) or not sources:
        raise RegistryError("manifest must contain a non-empty sources list")
    keys = [item.get("source_key") for item in sources]
    if any(not isinstance(key, str) or not key.strip() for key in keys):
        errors.append("every source_key must be non-blank")
    if len(keys) != len(set(keys)):
        errors.append("duplicate source_key")
    counts = Counter(sources=0, versions=0, rights=0, policies=0, contact_events=0, dialect_assertions=0, import_batches=0, source_entries=0)
    for source in sources:
        key = source.get("source_key", "<missing>")
        counts["sources"] += 1
        if source.get("source_type") not in SOURCE_TYPES:
            errors.append(f"{key}: invalid source_type")
        if not source.get("title") or not source.get("citation"):
            errors.append(f"{key}: title and citation are required")
        versions = source.get("versions") or []
        version_keys = [v.get("version_key") for v in versions]
        if not versions or len(version_keys) != len(set(version_keys)) or any(not v for v in version_keys):
            errors.append(f"{key}: versions must have unique non-blank keys")
        counts["versions"] += len(versions)
        for version in versions:
            rights = version.get("rights")
            if not rights or rights.get("rights_status") not in RIGHTS_STATUSES or not rights.get("evidence_reference"):
                errors.append(f"{key}/{version.get('version_key')}: valid rights status and evidence are required")
            else:
                counts["rights"] += 1
            policies = version.get("use_policies") or []
            scopes = [p.get("use_scope") for p in policies]
            if len(scopes) != len(set(scopes)):
                errors.append(f"{key}/{version.get('version_key')}: duplicate use scope")
            for policy in policies:
                if policy.get("use_scope") not in USE_SCOPES or policy.get("decision") not in DECISIONS:
                    errors.append(f"{key}/{version.get('version_key')}: invalid use policy")
                if policy.get("decision") != "UNKNOWN" and not (policy.get("policy_basis_reference") or policy.get("notes")):
                    errors.append(f"{key}/{version.get('version_key')}: non-UNKNOWN policy needs a basis")
            counts["policies"] += len(policies)
            for mapping in version.get("dialect_mappings") or []:
                if not mapping.get("raw_dialect_label") or not mapping.get("canonical_dialect_name"):
                    errors.append(f"{key}/{version.get('version_key')}: invalid dialect reference")
                if mapping.get("mapping_scope") != "SOURCE_VERSION":
                    errors.append(f"{key}/{version.get('version_key')}: registration mappings must use SOURCE_VERSION scope")
                if mapping.get("verification_status") not in {"UNVERIFIED", "IN_REVIEW", "VERIFIED", "REJECTED", "DISPUTED"}:
                    errors.append(f"{key}/{version.get('version_key')}: invalid mapping status")
                counts["dialect_assertions"] += 1
        events = source.get("contact_events") or []
        for event in events:
            if not event.get("contact_date"):
                errors.append(f"{key}: contact event has no substantiated date")
        counts["contact_events"] += len(events)
        if source.get("import_batches") or source.get("source_entries"):
            errors.append(f"{key}: registry 001 cannot contain imports or source entries")
    if errors:
        raise RegistryError("\n".join(errors))
    return dict(counts)


class RestClient:
    def __init__(self, url: str, key: str):
        self.url = url.rstrip("/") + "/rest/v1"
        self.headers = {"apikey": key, "Authorization": f"Bearer {key}"}

    def select(self, table: str, filters: dict[str, Any]) -> list[dict[str, Any]]:
        params = {"select": "*", **{k: str(v) if str(v).startswith(("is.", "eq.", "in.")) else f"eq.{v}" for k, v in filters.items()}}
        return self._request("GET", table, params=params)

    def insert(self, table: str, row: dict[str, Any]) -> dict[str, Any]:
        if table not in WRITABLE_TABLES:
            raise RegistryError(f"write guard rejected table: {table}")
        result = self._request("POST", table, body=row, extra={"Prefer": "return=representation"})
        return result[0]

    def _request(self, method: str, table: str, params: dict[str, Any] | None = None, body: dict[str, Any] | None = None, extra: dict[str, str] | None = None):
        url = f"{self.url}/{table}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        headers = {**self.headers, **(extra or {})}
        data = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request) as response:
                return json.loads(response.read() or b"[]")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")
            raise RegistryError(f"{method} {table} failed ({exc.code}): {detail}") from exc


def _managed_equal(existing: dict[str, Any], desired: dict[str, Any]) -> bool:
    return all(existing.get(key) == value for key, value in desired.items())


def _one_or_none(rows: list[dict[str, Any]], label: str) -> dict[str, Any] | None:
    if len(rows) > 1:
        raise RegistryError(f"conflicting duplicate rows for {label}")
    return rows[0] if rows else None


def register(manifest: dict[str, Any], client: Any, execute: bool) -> dict[str, int]:
    validate_manifest(manifest)
    changes = Counter(sources=0, versions=0, rights=0, policies=0, contact_events=0, dialect_assertions=0, import_batches=0, source_entries=0)
    dialects = {row["name"]: row["id"] for row in client.select("dialects", {})}
    for item in manifest["sources"]:
        source_row = {k: item.get(k) for k in ("source_key", "source_type", "title", "authors_or_contributors", "publisher_or_institution", "publication_year", "citation", "primary_url", "rights_holder", "default_register", "notes") if item.get(k) is not None}
        current = _one_or_none(client.select("sources", {"source_key": item["source_key"]}), item["source_key"])
        if current and not _managed_equal(current, source_row):
            raise RegistryError(f"conflicting existing source: {item['source_key']}")
        if not current:
            changes["sources"] += 1
            current = client.insert("sources", source_row) if execute else {"id": f"planned:{item['source_key']}"}
        source_id = current["id"]
        for version in item["versions"]:
            version_row = {k: version.get(k) for k in ("version_key", "edition_label", "version_label", "publication_date", "release_date", "canonical_url", "citation_override", "checksum", "checksum_algorithm", "notes") if version.get(k) is not None}
            version_row["source_id"] = source_id
            existing_version = None if str(source_id).startswith("planned:") else _one_or_none(client.select("source_versions", {"source_id": source_id, "version_key": version["version_key"]}), f"{item['source_key']}/{version['version_key']}")
            if existing_version and not _managed_equal(existing_version, version_row):
                raise RegistryError(f"conflicting existing version: {item['source_key']}/{version['version_key']}")
            if not existing_version:
                changes["versions"] += 1
                existing_version = client.insert("source_versions", version_row) if execute else {"id": f"planned:{item['source_key']}:{version['version_key']}"}
            version_id = existing_version["id"]
            rights_row = {**version["rights"], "source_version_id": version_id}
            existing_rights = None if str(version_id).startswith("planned:") else _one_or_none(client.select("source_rights", {"source_version_id": version_id, "superseded_at": "is.null"}), f"rights {version_id}")
            if existing_rights and not _managed_equal(existing_rights, rights_row):
                raise RegistryError(f"conflicting existing rights: {item['source_key']}")
            if not existing_rights:
                changes["rights"] += 1
                if execute: client.insert("source_rights", rights_row)
            for policy in version.get("use_policies", []):
                policy_row = {**policy, "source_version_id": version_id, "policy_version": manifest["policy_version"]}
                existing_policy = None if str(version_id).startswith("planned:") else _one_or_none(client.select("source_use_policies", {"source_version_id": version_id, "use_scope": policy["use_scope"], "superseded_at": "is.null"}), f"policy {version_id}/{policy['use_scope']}")
                if existing_policy and not _managed_equal(existing_policy, policy_row):
                    raise RegistryError(f"conflicting existing policy: {item['source_key']}/{policy['use_scope']}")
                if not existing_policy:
                    changes["policies"] += 1
                    if execute: client.insert("source_use_policies", policy_row)
            for mapping in version.get("dialect_mappings", []):
                dialect_id = dialects.get(mapping["canonical_dialect_name"])
                if not dialect_id:
                    raise RegistryError(f"invalid dialect reference: {mapping['canonical_dialect_name']}")
                mapping_row = {k: v for k, v in mapping.items() if k != "canonical_dialect_name"}
                mapping_row.update(source_version_id=version_id, canonical_dialect_id=dialect_id, policy_version=manifest["policy_version"])
                existing_mapping = None if str(version_id).startswith("planned:") else _one_or_none(client.select("source_dialect_mapping_assertions", {"source_version_id": version_id, "raw_dialect_label": mapping["raw_dialect_label"], "mapping_scope": "SOURCE_VERSION", "superseded_at": "is.null"}), f"mapping {version_id}/{mapping['raw_dialect_label']}")
                if existing_mapping and not _managed_equal(existing_mapping, mapping_row):
                    raise RegistryError(f"conflicting existing mapping: {item['source_key']}/{mapping['raw_dialect_label']}")
                if not existing_mapping:
                    changes["dialect_assertions"] += 1
                    if execute: client.insert("source_dialect_mapping_assertions", mapping_row)
    return dict(changes)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=Path("config/sources/source_registry_001.json"))
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--validate", action="store_true")
    modes.add_argument("--dry-run", action="store_true")
    modes.add_argument("--execute", action="store_true")
    parser.add_argument("--project-ref")
    parser.add_argument("--confirm-project-ref")
    args = parser.parse_args(argv)
    manifest = load_manifest(args.manifest)
    counts = validate_manifest(manifest)
    if args.validate:
        print(json.dumps({"status": "VALID", "manifest_counts": counts}, sort_keys=True))
        return 0
    if not args.project_ref:
        parser.error("--project-ref is required for dry-run and execute")
    if args.execute and args.confirm_project_ref != args.project_ref:
        parser.error("--execute requires matching --confirm-project-ref")
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    local_target = args.project_ref == "local" and ("127.0.0.1" in (url or "") or "localhost" in (url or ""))
    if not url or not key or (not local_target and args.project_ref not in url):
        raise RegistryError("SUPABASE_URL and matching SUPABASE_SERVICE_ROLE_KEY are required")
    changes = register(manifest, RestClient(url, key), execute=args.execute)
    print(json.dumps({"status": "EXECUTED" if args.execute else "DRY_RUN", "project_ref": args.project_ref, "changes": changes}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RegistryError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
