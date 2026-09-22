import json
from pathlib import Path

from scripts.source_reconciliation.validate_literature_registry import validate_registry

REGISTRY = Path("config/linguistic_sources/literature_registry_001.json")


def test_literature_registry_is_valid() -> None:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    assert data["source_count"] >= 30
    assert validate_registry(data) == []


def test_literature_registry_serialization_is_deterministic() -> None:
    raw = REGISTRY.read_text(encoding="utf-8")
    data = json.loads(raw)
    assert raw == json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def test_inventory_has_dialect_and_domain_diversity() -> None:
    sources = json.loads(REGISTRY.read_text(encoding="utf-8"))["sources"]
    dialects = {d for source in sources for d in source["candidate_tafsiri_dialects"]}
    tags = {tag for source in sources for tag in source["relevance_tags"]}
    assert len(dialects) >= 12
    assert {"PHONETICS", "PHONOLOGY", "TONE", "MORPHOLOGY", "SYNTAX", "SEMANTICS", "LOANWORDS", "TERMINOLOGY"} <= tags
    assert "IDEOHONE" not in tags


def test_inventory_contains_no_embedded_artifacts_or_private_contacts() -> None:
    sources = json.loads(REGISTRY.read_text(encoding="utf-8"))["sources"]
    assert all(source["artifact"] is None for source in sources)
    assert "@" not in REGISTRY.read_text(encoding="utf-8")
