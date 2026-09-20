from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class PipelineConfig:
    values: dict[str, Any]
    concept_keys: dict[str, dict[str, Any]]
    contextual_markers: tuple[str, ...]
    config_hash: str


def _read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def load_config(config_dir: Path) -> PipelineConfig:
    pipeline = _read_json(config_dir / "pipeline_001.json")
    registry = _read_json(config_dir / "concept_key_registry.json")
    markers = _read_json(config_dir / "contextual_markers.json")
    canonical = json.dumps(
        {"pipeline": pipeline, "registry": registry, "markers": markers},
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return PipelineConfig(
        values=pipeline,
        concept_keys=registry["entries"],
        contextual_markers=tuple(markers["markers"]),
        config_hash=hashlib.sha256(canonical).hexdigest(),
    )
