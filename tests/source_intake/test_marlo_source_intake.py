from pathlib import Path

from scripts.source_intake.validate_marlo_intake import DEFAULT_MANIFEST, load_manifest, pdf_locator, spreadsheet_locator, validate


def test_manifest_is_internally_valid() -> None:
    assert validate(load_manifest()) == []


def test_package_is_complete_and_records_zero_database_writes() -> None:
    manifest = load_manifest()
    assert manifest["database_writes"] == 0
    assert manifest["status"] == "COMPLETE_AUDIT_READY_FOR_REVIEW"
    assert len(manifest["artifacts"]) == 13
    assert all(item["availability"] == "PRESENT" for item in manifest["artifacts"])
    assert len({item["sha256"] for item in manifest["artifacts"]}) == 12


def test_exact_duplicate_is_explicit() -> None:
    artifacts = {item["artifact_key"]: item for item in load_manifest()["artifacts"]}
    duplicate = artifacts["MARLO001_NDANYI_2005_LOGOORI_PART_5_DUPLICATE"]
    original = artifacts[duplicate["duplicate_of"]]
    assert duplicate["source_classification"] == "DUPLICATE_ARTIFACT"
    assert (duplicate["sha256"], duplicate["byte_size"]) == (original["sha256"], original["byte_size"])


def test_existing_source_matching_does_not_create_versions() -> None:
    sources = {item["source_key"]: item for item in load_manifest()["source_identities"]}
    assert sources["LUBUKUSU_ENGLISH_DICTIONARY_2008"]["classification"] == "EXISTING"
    assert sources["LUBUKUSU_ENGLISH_DICTIONARY_2008"]["new_source_version"] is False
    assert sources["WANGA_ENGLISH_DICTIONARY_2008"]["new_source_version"] is False
    assert sources["WANGA_ENGLISH_DICTIONARY_2008"]["artifact_identity"] == "SAME_VERSION_DIFFERENT_BINARY"


def test_new_artifacts_and_checksums_are_recorded() -> None:
    artifacts = {item["original_filename"]: item for item in load_manifest()["artifacts"]}
    assert artifacts["WangaDictionary09012008.pdf"]["sha256"] == "0483de7c6ccdbdcc7206a38dd39e2d74f01908010e1bf7a1b197959f76c1311d"
    assert artifacts["Appleby1943dictionary.pdf"]["sha256"] == "cef46056b2cbeb488c81d6fa8793d349b00c6f8be98ef577f949a0f0c0e9f6ba"
    assert artifacts["Tura.xlsx"]["sha256"] == "13a23808a219c74fc284b48c264f17c068f23f7e8d64667e754c599a70f98445"


def test_tura_workbook_structure_and_unresolved_mapping() -> None:
    manifest = load_manifest()
    tura = next(item for item in manifest["artifacts"] if item["original_filename"] == "Tura.xlsx")
    assert {sheet["name"]: sheet["meaningful_data_rows"] for sheet in tura["sheets"]} == {
        "AllData": 4575, "cuts": 910, "Sheet1": 0
    }
    assert tura["dialect_mapping_status"] == "EXPERT_CONFIRMATION_REQUIRED"


def test_locators_are_stable_and_source_specific() -> None:
    assert spreadsheet_locator("A", "AllData", 2, "Gloss") == "artifact:A/sheet:AllData/row:2/column:Gloss"
    assert pdf_locator("B", 3, 7, "unknown", 2) == "artifact:B/part:3/pdf-page:7/printed-page:unknown/entry:2"


def test_manifest_contains_no_local_absolute_paths() -> None:
    text = Path(DEFAULT_MANIFEST).read_text(encoding="utf-8")
    assert "C:\\Users\\" not in text
    assert ".env" not in text
    assert "Marlo-Amakobe-email.pdf" not in text
