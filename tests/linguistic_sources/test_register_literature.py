import copy
import json
from pathlib import Path

import pytest

from scripts.linguistic_sources.register_literature import (
    EVIDENCE_TABLES, RegistryError, desired, main, normalized_doi, register,
    validate_manifest,
)

MANIFEST = Path("config/linguistic_sources/literature_registry_001.json")


class FakeClient:
    def __init__(self):
        self.tables = {name: [] for name in (
            "sources", "source_versions", "source_scholarly_metadata", "source_identifiers",
            "source_access_locations", "source_variety_mentions", "source_rights", "source_use_policies",
        )}
        names = sorted({d for item in json.loads(MANIFEST.read_text(encoding="utf-8"))["sources"] for d in item["candidate_tafsiri_dialects"]})
        self.tables["dialects"] = [{"id": f"dialect-{i}", "name": name} for i, name in enumerate(names)]
        self.writes = []

    def select(self, table, filters):
        rows = self.tables.get(table, [])
        def match(row):
            for key, value in filters.items():
                if value == "is.null":
                    if row.get(key) is not None: return False
                elif row.get(key) != value: return False
            return True
        return [copy.deepcopy(row) for row in rows if match(row)]

    def insert(self, table, row):
        assert table not in EVIDENCE_TABLES
        saved = {"id": f"{table}-{len(self.tables[table])+1}", **copy.deepcopy(row)}
        self.tables[table].append(saved); self.writes.append(table)
        return copy.deepcopy(saved)


def manifest(): return json.loads(MANIFEST.read_text(encoding="utf-8"))


def test_manifest_accepts_all_46_sources_and_supported_types():
    counts = validate_manifest(manifest())
    assert counts["inventory_sources"] == 46
    assert counts["eligible_sources"] == counts["versions"] == counts["scholarly_metadata"] == 46
    assert counts["validation_issues"] == 8
    assert counts["policies"] == 368


def test_source_keys_and_version_keys_are_stable():
    data = manifest()
    first = [(x["source_key"], desired(x)["version"]["version_key"]) for x in data["sources"]]
    second = [(x["source_key"], desired(x)["version"]["version_key"]) for x in data["sources"]]
    assert first == second and len(set(first)) == 46


def test_duplicate_doi_and_title_year_are_rejected():
    data = manifest(); data["sources"][1]["doi"] = data["sources"][0].get("doi") or "10.1/example"; data["sources"][0]["doi"] = "10.1/example"
    with pytest.raises(RegistryError, match="duplicate DOI"): validate_manifest(data)
    data = manifest(); data["sources"][1]["title"] = data["sources"][0]["title"]; data["sources"][1]["year"] = data["sources"][0]["year"]
    with pytest.raises(RegistryError, match="title/year"): validate_manifest(data)


def test_doi_normalization():
    assert normalized_doi("HTTPS://DOI.ORG/10.1234/ABC") == "10.1234/abc"


def test_all_metadata_structures_are_idempotent_and_evidence_is_untouched():
    client = FakeClient(); data = manifest()
    first = register(data, client, execute=True)
    assert first["sources"] == first["versions"] == first["scholarly_metadata"] == first["rights"] == 46
    assert first["use_policies"] == 368 and first["skipped"] == 0
    assert not EVIDENCE_TABLES.intersection(client.writes)
    second = register(data, client, execute=False)
    assert all(value == 0 for key, value in second.items() if key not in {"duplicates_reused", "skipped"})
    assert second["duplicates_reused"] == 46 and second["skipped"] == 0


def test_conflicting_existing_source_stops_registration():
    client = FakeClient(); data = manifest(); d = desired(data["sources"][0])["source"]
    client.tables["sources"].append({"id": "existing", **d, "title": "Different title"})
    with pytest.raises(RegistryError, match="CONFLICT source"): register(data, client, execute=False)


def test_duplicate_database_title_year_stops_before_writes():
    client = FakeClient(); data = manifest(); first = data["sources"][0]
    client.tables["sources"].append({"id":"other","source_key":"OTHER_KEY","title":first["title"],"publication_year":first["year"]})
    with pytest.raises(RegistryError, match="duplicate title/year"): register(data, client, execute=True)
    assert client.writes == []


def test_missing_candidate_dialect_stops_before_writes():
    client = FakeClient(); client.tables["dialects"] = []
    with pytest.raises(RegistryError, match="unknown candidate dialect"): register(manifest(), client, execute=True)
    assert client.writes == []


def test_execute_requires_exact_project_confirmation():
    with pytest.raises(SystemExit) as exc: main(["--execute", "--project-ref", "production"])
    assert exc.value.code == 2
