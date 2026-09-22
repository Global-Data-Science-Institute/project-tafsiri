import copy
from pathlib import Path

import pytest

from scripts.source_registry.register_sources import (
    RegistryError,
    RestClient,
    load_manifest,
    register,
    validate_manifest,
)


MANIFEST = Path("config/sources/source_registry_001.json")


class MemoryClient:
    def __init__(self):
        self.rows = {
            "dialects": [
                {"id": "dialect-luwanga", "name": "Luwanga"},
                {"id": "dialect-bukusu", "name": "Bukusu"},
            ]
        }
        self.writes = []
        self.sequence = 0

    def select(self, table, filters):
        rows = self.rows.get(table, [])
        result = []
        for row in rows:
            matches = True
            for key, expected in filters.items():
                if expected == "is.null":
                    matches &= row.get(key) is None
                else:
                    matches &= row.get(key) == expected
            if matches:
                result.append(copy.deepcopy(row))
        return result

    def insert(self, table, row):
        self.sequence += 1
        created = {"id": f"id-{self.sequence}", **copy.deepcopy(row)}
        self.rows.setdefault(table, []).append(created)
        self.writes.append((table, created))
        return copy.deepcopy(created)


def test_manifest_validation_and_expected_scope():
    counts = validate_manifest(load_manifest(MANIFEST))
    assert counts == {
        "sources": 7, "versions": 7, "rights": 7, "policies": 56,
        "contact_events": 0, "dialect_assertions": 2,
        "import_batches": 0, "source_entries": 0,
    }


def test_duplicate_source_rejected():
    manifest = load_manifest(MANIFEST)
    manifest["sources"].append(copy.deepcopy(manifest["sources"][0]))
    with pytest.raises(RegistryError, match="duplicate source_key"):
        validate_manifest(manifest)


@pytest.mark.parametrize(("field", "value", "message"), [
    ("rights_status", "MADE_UP", "valid rights status"),
    ("decision", "MAYBE", "invalid use policy"),
])
def test_invalid_rights_and_policy_rejected(field, value, message):
    manifest = load_manifest(MANIFEST)
    version = manifest["sources"][0]["versions"][0]
    if field == "rights_status":
        version["rights"][field] = value
    else:
        version["use_policies"][0][field] = value
    with pytest.raises(RegistryError, match=message):
        validate_manifest(manifest)


def test_invalid_dialect_reference_rejected_during_plan():
    manifest = load_manifest(MANIFEST)
    manifest["sources"][0]["versions"][0]["dialect_mappings"][0]["canonical_dialect_name"] = "Invented"
    with pytest.raises(RegistryError, match="invalid dialect reference"):
        register(manifest, MemoryClient(), execute=False)


def test_dry_run_writes_nothing():
    client = MemoryClient()
    changes = register(load_manifest(MANIFEST), client, execute=False)
    assert changes["sources"] == 7
    assert changes["source_entries"] == changes["import_batches"] == 0
    assert client.writes == []


def test_execute_is_idempotent_and_never_targets_lexical_tables():
    client = MemoryClient()
    first = register(load_manifest(MANIFEST), client, execute=True)
    second = register(load_manifest(MANIFEST), client, execute=True)
    assert first["sources"] == 7 and first["policies"] == 56
    assert not any(second.values())
    assert {table for table, _ in client.writes} <= {
        "sources", "source_versions", "source_rights",
        "source_use_policies", "source_dialect_mapping_assertions",
    }


def test_rest_client_write_guard_blocks_legacy_table():
    client = RestClient("http://example.invalid", "not-a-real-key")
    with pytest.raises(RegistryError, match="write guard"):
        client.insert("dictionary_entries", {"word": "forbidden"})
