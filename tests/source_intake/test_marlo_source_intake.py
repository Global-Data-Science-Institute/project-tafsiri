from pathlib import Path

from scripts.source_intake.validate_marlo_intake import DEFAULT_MANIFEST, load_manifest, pdf_locator, spreadsheet_locator, validate


def test_manifest_is_internally_valid() -> None:
    assert validate(load_manifest()) == []


def test_package_records_missing_files_and_zero_database_writes() -> None:
    manifest = load_manifest()
    assert manifest["database_writes"] == 0
    assert manifest["status"] == "INCOMPLETE_INPUT_PACKAGE"
    missing = {item["original_filename"] for item in manifest["artifacts"] if item["availability"] == "MISSING_FROM_CURRENT_ARTIFACTS"}
    assert missing == {"WangaDictionary09012008.pdf", "Appleby1943dictionary.pdf", "Tura.xlsx"}


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


def test_locators_are_stable_and_source_specific() -> None:
    assert spreadsheet_locator("A", "AllData", 2, "Gloss") == "artifact:A/sheet:AllData/row:2/column:Gloss"
    assert pdf_locator("B", 3, 7, "unknown", 2) == "artifact:B/part:3/pdf-page:7/printed-page:unknown/entry:2"


def test_manifest_contains_no_local_absolute_paths() -> None:
    text = Path(DEFAULT_MANIFEST).read_text(encoding="utf-8")
    assert "C:\\Users\\" not in text
    assert ".env" not in text
