from pathlib import Path

from scripts.source_reconciliation.reconcile import (
    Entry,
    classify_pair,
    encoding_findings,
    reconcile_entries,
    secondary_search_form,
    sha256_file,
    write_json,
)


def test_artifact_hashing(tmp_path: Path) -> None:
    artifact = tmp_path / "artifact"
    artifact.write_bytes(b"tafsiri\n")
    assert sha256_file(artifact) == "412420249030477fb65a8bd9fe51690936f873d7cd23341b4fe0695c117d48bc"


def test_exact_and_formatting_classification() -> None:
    assert classify_pair(Entry("a", "word", "gloss", "n."), Entry("1", "word", "gloss", "n.")) == "EXACT"
    assert classify_pair(Entry("a", "word", "one; two", "n."), Entry("1", "word", "one ; two.", "noun")) == "GLOSS_FORMATTING"


def test_pos_normalization() -> None:
    assert classify_pair(Entry("a", "word", "gloss", "n."), Entry("1", "word", "gloss", "noun")) == "POS_NORMALIZATION"


def test_tone_preserving_and_secondary_comparison() -> None:
    assert classify_pair(Entry("p", "khúúkholá", "do", "v"), Entry("1", "khuukhola", "do", "v")) == "TONE_DIACRITIC_DIFFERENCE"
    assert secondary_search_form("khúúkholá") == "khuukhola"
    assert Entry("p", "khúúkholá").form == "khúúkholá"


def test_ambiguous_row_matching_and_duplicate_detection() -> None:
    result = reconcile_entries(
        [Entry("p1", "word", "first"), Entry("p2", "word", "second")],
        [Entry("9", "word", "third")],
        historical_table="luhya_dict",
        dialect_raw_label="Wanga",
        source_version="PRELIMINARY_DRAFT_2008",
    )
    assert result.counts == {"AMBIGUOUS_MATCH": 1}
    assert result.duplicate_artifact_keys == 1


def test_exception_reporting() -> None:
    result = reconcile_entries(
        [Entry("p1", "present")],
        [Entry("10", "absent")],
        historical_table="luhya_dict",
        dialect_raw_label="Wanga",
        source_version="PRELIMINARY_DRAFT_2008",
    )
    assert result.counts["NO_SOURCE_MATCH"] == 1
    assert result.artifact_unmatched == ["p1"]


def test_encoding_detection() -> None:
    findings = encoding_findings(["bad \u00c3\u0082 value", "e\u0301", "two  spaces"])
    assert findings["\u00c3"] == 1
    assert findings["NON_NFC"] == 1
    assert findings["UNUSUAL_WHITESPACE"] == 1


def test_deterministic_output(tmp_path: Path) -> None:
    first = tmp_path / "first.json"
    second = tmp_path / "second.json"
    value = {"z": 1, "a": [2, 3]}
    write_json(first, value)
    write_json(second, value)
    assert first.read_bytes() == second.read_bytes()


def test_has_no_database_write_capability() -> None:
    source = "\n".join(Path(path).read_text(encoding="utf-8").casefold() for path in (
        "scripts/source_reconciliation/reconcile.py", "scripts/source_reconciliation/lubukusu_pdf.py"
    ))
    for verb in ("insert into", "update public.", "delete from", "requests.post", "requests.patch"):
        assert verb not in source
