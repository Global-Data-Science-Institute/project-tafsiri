from __future__ import annotations

import json
from pathlib import Path

import pytest

from scripts.source_registry import prepare_marlo_registration as registration


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "config/sources/marlo_source_registration_001.json"


def load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def empty_remote_state(manifest: dict) -> dict:
    existing_sources = []
    existing_versions = []
    ids = {
        "LUBUKUSU_ENGLISH_DICTIONARY_2008": "staging-or-production-bukusu-id",
        "WANGA_ENGLISH_DICTIONARY_2008": "staging-or-production-wanga-id",
    }
    for source in manifest["source_actions"]:
        if source["action"] == "REUSE":
            existing_sources.append({
                "id": ids[source["source_key"]], "source_key": source["source_key"],
                "source_type": source["source_type"], "title": source["title"],
            })
    for version in manifest["version_actions"]:
        if version["action"] == "REUSE":
            existing_versions.append({
                "id": "version-" + version["source_key"], "source_key": version["source_key"],
                "version_key": version["version_key"], "checksum": None, "checksum_algorithm": None,
            })
    return {
        "migration_010": 1, "sources": existing_sources, "versions": existing_versions,
        "artifacts": [], "associations": [], "acquisitions": [], "rights": [], "policies": [],
        "sets": [], "members": [],
        "artifact_table_counts": {"artifacts": 0, "associations": 0, "acquisitions": 0, "locations": 0, "sets": 0, "members": 0},
        "import_batches": 0, "source_entries": 0, "linguistic_rules": 4,
    }


def test_manifest_validates_expected_registration_counts() -> None:
    # Source binaries are intentionally ignored and absent from CI; their local
    # byte sizes and SHA-256 values are verified by the utility's default CLI
    # validation before a live dry run.
    counts = registration.validate_manifest(load_manifest(), verify_files=False)
    assert counts == {
        "sources_create": 6, "sources_reuse": 2, "versions_create": 6, "versions_reuse": 2,
        "artifacts": 12, "associations": 12, "acquisitions": 13, "rights": 6,
        "policies": 48, "artifact_sets": 1, "set_members": 5,
    }


def test_bukusu_and_wanga_reuse_existing_sources_and_versions() -> None:
    manifest = load_manifest()
    reused_sources = {x["source_key"] for x in manifest["source_actions"] if x["action"] == "REUSE"}
    reused_versions = {(x["source_key"], x["version_key"]) for x in manifest["version_actions"] if x["action"] == "REUSE"}
    assert reused_sources == {"LUBUKUSU_ENGLISH_DICTIONARY_2008", "WANGA_ENGLISH_DICTIONARY_2008"}
    assert reused_versions == {
        ("LUBUKUSU_ENGLISH_DICTIONARY_2008", "DRAFT_2008_09_01"),
        ("WANGA_ENGLISH_DICTIONARY_2008", "PRELIMINARY_DRAFT_2008"),
    }


def test_six_new_source_identities_and_null_legacy_version_checksums() -> None:
    manifest = load_manifest()
    assert sum(x["action"] == "CREATE" for x in manifest["source_actions"]) == 6
    assert sum(x["action"] == "CREATE" for x in manifest["version_actions"]) == 6
    assert all(x["checksum"] is None and x["checksum_algorithm"] is None for x in manifest["version_actions"])


def test_twelve_unique_checksums_and_wanga_alternate_binary() -> None:
    manifest = load_manifest()
    checksums = [x["checksum"] for x in manifest["artifact_actions"]]
    assert len(checksums) == len(set(checksums)) == 12
    wanga = [x for x in manifest["association_actions"] if x["source_key"] == "WANGA_ENGLISH_DICTIONARY_2008"]
    assert len(wanga) == 1
    artifact = next(x for x in manifest["artifact_actions"] if x["artifact_key"] == wanga[0]["artifact_key"])
    assert artifact["checksum"] == "0483de7c6ccdbdcc7206a38dd39e2d74f01908010e1bf7a1b197959f76c1311d"


def test_duplicate_part_five_is_one_artifact_and_two_acquisitions() -> None:
    manifest = load_manifest()
    rows = [x for x in manifest["acquisition_actions"] if "Part5" in x["original_filename"]]
    assert len(rows) == 2
    assert len({x["artifact_key"] for x in rows}) == 1
    assert len({x["acquisition_key"] for x in rows}) == 2


def test_thirteen_original_filenames_are_preserved() -> None:
    filenames = [x["original_filename"] for x in load_manifest()["acquisition_actions"]]
    assert len(filenames) == len(set(filenames)) == 13


def test_ndanyi_has_five_ordered_members_without_a_preferred_component() -> None:
    manifest = load_manifest()
    assert [x["sequence_number"] for x in manifest["artifact_set_member_actions"]] == [1, 2, 3, 4, 5]
    ndanyi = [x for x in manifest["association_actions"] if x["source_key"] == "NDANYI_NDANYI_2005_LULOGOOLI_DICTIONARY"]
    assert len(ndanyi) == 5
    assert not any(x["is_preferred"] for x in ndanyi)


def test_new_rights_and_policies_never_infer_permission() -> None:
    manifest = load_manifest()
    assert len(manifest["rights_actions"]) == 6
    assert {x["rights_status"] for x in manifest["rights_actions"]} == {"UNKNOWN"}
    assert len(manifest["policy_actions"]) == 48
    assert {x["decision"] for x in manifest["policy_actions"]} == {"UNKNOWN"}


def test_unresolved_dialect_mappings_and_locations_remain_deferred() -> None:
    manifest = load_manifest()
    assert manifest["dialect_mapping_actions"] == []
    assert manifest["location_actions"] == []
    questions = " ".join(manifest["unresolved_questions"])
    assert "Tura/Lutura" in questions
    assert "durable portable" in questions


def test_dry_run_plan_is_idempotent_and_has_no_import_or_entry_actions() -> None:
    manifest = load_manifest()
    state = empty_remote_state(manifest)
    first = registration.plan(manifest, state)
    second = registration.plan(manifest, state)
    assert first == second
    assert first["semantic_digest"] == manifest["semantic_digest"]
    assert first["totals"] == {"CREATE": 109, "REUSE": 4}
    assert first["conflicts"] == []
    assert first["safety"]["import_batches"] == 0
    assert first["safety"]["source_entries"] == 0


def test_default_cli_path_is_dry_run_and_performs_no_write(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    manifest = load_manifest()
    monkeypatch.setattr(registration, "validate_manifest", lambda value: {})
    monkeypatch.setattr(registration, "cli_query", lambda project_ref, sql: empty_remote_state(manifest))
    monkeypatch.setattr(registration, "execute", lambda *args, **kwargs: pytest.fail("default dry-run attempted execution"))
    assert registration.main([]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["status"] == "DRY_RUN"
    assert payload["plan"]["totals"] == {"CREATE": 109, "REUSE": 4}


def test_production_execution_requires_explicit_approval(monkeypatch: pytest.MonkeyPatch) -> None:
    manifest = load_manifest()
    monkeypatch.setattr(registration, "validate_manifest", lambda value: {})
    monkeypatch.setattr(registration, "cli_query", lambda project_ref, sql: empty_remote_state(manifest))
    with pytest.raises(registration.RegistrationError, match="production execution requires"):
        registration.main([
            "--project-ref", registration.PRODUCTION_REF, "--execute",
            "--confirm-project-ref", registration.PRODUCTION_REF,
        ])
