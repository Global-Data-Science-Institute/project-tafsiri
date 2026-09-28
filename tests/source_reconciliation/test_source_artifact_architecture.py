from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / "docs" / "research" / "source-artifact-acquisition-architecture-001.md"


def test_architecture_preserves_core_boundaries_and_safety() -> None:
    text = DOC.read_text(encoding="utf-8")
    for required in (
        "source_artifacts",
        "source_version_artifacts",
        "source_artifact_acquisitions",
        "source_artifact_locations",
        "source_artifact_sets",
        "source_artifact_set_members",
        "source_import_batches.source_artifact_id",
        "zero production writes",
        "zero staging writes",
    ):
        assert required in text


def test_architecture_covers_all_required_adrs() -> None:
    text = DOC.read_text(encoding="utf-8")
    for number in range(21, 29):
        assert f"ADR-0{number}" in text


def test_architecture_requires_global_content_identity_and_no_speculative_backfill() -> None:
    text = DOC.read_text(encoding="utf-8")
    assert "global unique key is `(checksum_algorithm, checksum)`" in text
    assert "No automatic backfill is allowed" in text
    assert "one `source_artifacts` row" in text
    assert "two acquisition rows" in text


def test_migration_010_has_not_been_created() -> None:
    migrations = list((ROOT / "supabase" / "migrations").glob("*.sql"))
    assert not any("artifact" in path.stem.lower() for path in migrations)
