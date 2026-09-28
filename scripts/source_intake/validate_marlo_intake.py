"""Validate the repository-safe Marlo source intake manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = ROOT / "config" / "sources" / "marlo_source_intake_001.json"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
USE_SCOPES = {"INTERNAL_RESEARCH", "HUMAN_REVIEW", "REVIEWER_DISPLAY", "PUBLIC_DISPLAY", "REDISTRIBUTION", "MODEL_TRAINING", "BENCHMARK_PUBLICATION", "COMMERCIAL_API"}
USE_DECISIONS = {"ALLOWED", "REVIEW_REQUIRED", "UNKNOWN", "PROHIBITED"}


def load_manifest(path: Path = DEFAULT_MANIFEST) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def spreadsheet_locator(artifact_key: str, sheet: str, row: int, column: str) -> str:
    return f"artifact:{artifact_key}/sheet:{sheet}/row:{row}/column:{column}"


def pdf_locator(artifact_key: str, part: int, pdf_page: int, printed_page: str | int, entry: int) -> str:
    return f"artifact:{artifact_key}/part:{part}/pdf-page:{pdf_page}/printed-page:{printed_page}/entry:{entry}"


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate(manifest: dict[str, Any], verify_local_files: bool = False) -> list[str]:
    errors: list[str] = []
    artifacts = manifest.get("artifacts", [])
    keys = [item.get("artifact_key") for item in artifacts]
    if len(keys) != len(set(keys)):
        errors.append("artifact keys must be unique")
    if manifest.get("database_writes") != 0:
        errors.append("database_writes must remain zero for this intake")

    by_key = {item.get("artifact_key"): item for item in artifacts}
    for item in artifacts:
        availability = item.get("availability")
        if availability == "PRESENT":
            checksum = item.get("sha256", "")
            if not SHA256_RE.fullmatch(checksum):
                errors.append(f"{item.get('artifact_key')}: invalid SHA-256")
            if not isinstance(item.get("byte_size"), int) or item["byte_size"] <= 0:
                errors.append(f"{item.get('artifact_key')}: invalid byte size")
            if verify_local_files:
                path = ROOT / manifest["inventory_root"] / item["original_filename"]
                if not path.is_file():
                    errors.append(f"{item.get('artifact_key')}: local file is missing")
                else:
                    if path.stat().st_size != item["byte_size"]:
                        errors.append(f"{item.get('artifact_key')}: byte size changed")
                    if file_sha256(path) != checksum:
                        errors.append(f"{item.get('artifact_key')}: checksum changed")
        elif availability != "MISSING_FROM_CURRENT_ARTIFACTS":
            errors.append(f"{item.get('artifact_key')}: unsupported availability")

        duplicate_of = item.get("duplicate_of")
        if duplicate_of:
            target = by_key.get(duplicate_of)
            if not target:
                errors.append(f"{item.get('artifact_key')}: duplicate target missing")
            elif (item.get("sha256"), item.get("byte_size")) != (target.get("sha256"), target.get("byte_size")):
                errors.append(f"{item.get('artifact_key')}: duplicate does not match target")

    source_keys = [item.get("source_key") for item in manifest.get("source_identities", [])]
    if len(source_keys) != len(set(source_keys)):
        errors.append("source identity keys must be unique")
    parts = [item for item in artifacts if item.get("source_key") == "NDANYI_NDANYI_2005_LULOGOOLI_DICTIONARY" and item.get("source_classification") == "NEW_INTELLECTUAL_WORK_COMPONENT"]
    if [item.get("component_sequence") for item in parts] != [1, 2, 3, 4, 5]:
        errors.append("Ndanyi components must be ordered 1 through 5")
    if sum(item.get("page_count", 0) for item in parts) != 141:
        errors.append("Ndanyi unique components must total 141 pages")

    scopes = manifest.get("rights_and_use_policy", {}).get("scopes", {})
    if set(scopes) != USE_SCOPES:
        errors.append("rights policy must cover all required use scopes")
    for scope, decision in scopes.items():
        if decision not in USE_DECISIONS:
            errors.append(f"{scope}: unsupported rights decision {decision}")

    expected_missing = {"WangaDictionary09012008.pdf", "Appleby1943dictionary.pdf", "Tura.xlsx"}
    recorded_missing = {item.get("original_filename") for item in artifacts if item.get("availability") == "MISSING_FROM_CURRENT_ARTIFACTS"}
    if recorded_missing != expected_missing:
        errors.append("missing artifact set does not match the intake request")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path, nargs="?", default=DEFAULT_MANIFEST)
    parser.add_argument("--verify-local-files", action="store_true")
    args = parser.parse_args()
    errors = validate(load_manifest(args.manifest), args.verify_local_files)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print(f"Validated {args.manifest}: no errors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
