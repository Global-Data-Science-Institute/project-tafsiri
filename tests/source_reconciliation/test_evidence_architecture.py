import json
from pathlib import Path


DOC = Path("docs/research/linguistic-evidence-architecture-001.md")
REGISTRY = Path("config/linguistic_sources/literature_registry_001.json")


def test_architecture_preserves_required_boundaries() -> None:
    text = DOC.read_text(encoding="utf-8")
    for statement in (
        "Evidence never becomes canonical merely because",
        "Do not create `linguistic_rules` in Migration 007",
        "RAG chunks are retrieval projections",
        "Production writes: **ZERO**",
    ):
        assert statement in text


def test_first_extraction_batch_references_inventory_sources() -> None:
    text = DOC.read_text(encoding="utf-8")
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    keys = {source["source_key"] for source in registry["sources"]}
    batch_section = text.split("## 29. First extraction batch", 1)[1].split("## 30.", 1)[0]
    batch_lines = [
        line
        for line in batch_section.splitlines()
        if line.startswith(tuple(f"{i}. `" for i in range(1, 12)))
    ]
    batch_keys = {line.split("`")[1] for line in batch_lines}
    assert len(batch_keys) == 11
    assert batch_keys <= keys


def test_migration_007_scope_is_design_only() -> None:
    text = DOC.read_text(encoding="utf-8")
    assert "Migration 007, **Linguistic Literature & Evidence Foundation**" in text
    assert "Defer canonical rules" in text
    assert not Path("supabase/migrations/20260923000000_linguistic_literature_evidence_foundation.sql").exists()
