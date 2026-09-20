from __future__ import annotations

from dataclasses import asdict, dataclass, field
from typing import Any


@dataclass(frozen=True)
class DictionaryEntry:
    id: str
    dialect_id: str
    dialect_name: str
    language_name: str | None
    word: str
    word_normalized: str | None
    part_of_speech: str | None
    noun_class: str | None
    english_definition: str
    cultural_context: str | None = None
    usage_notes: str | None = None
    etymology: str | None = None


@dataclass(frozen=True)
class ConceptRecord:
    id: str
    concept_key: str
    definition_en: str
    domain: str | None = None
    subdomain: str | None = None


@dataclass(frozen=True)
class CorpusSignals:
    repeated_form_count: int
    distinct_definition_count: int
    same_definition_form_count: int
    incompatible_definition_pos: bool


@dataclass(frozen=True)
class AmbiguityResult:
    indicators: tuple[str, ...] = ()
    flags: tuple[str, ...] = ()
    segments: tuple[str, ...] = ()
    action: str | None = None


@dataclass(frozen=True)
class Classification:
    bucket: str
    mapping_status: str
    ambiguity_action: str | None
    heuristic_flags: tuple[str, ...]
    ambiguity_indicators: tuple[str, ...]
    reason_codes: tuple[str, ...]


@dataclass(frozen=True)
class ConceptSuggestion:
    concept_id: str
    concept_key: str
    match_score: float
    signals: tuple[str, ...]


@dataclass(frozen=True)
class Candidate:
    dictionary_entry_id: str
    concept_id: None
    proposed_concept_key: str | None
    proposed_definition_en: str
    mapping_source: str
    confidence: float
    mapping_status: str
    evidence: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class RunMetadata:
    pipeline_version: str
    evidence_schema_version: str
    config_hash: str
    extraction_timestamp: str
    input_row_count: int


@dataclass
class ValidationReport:
    errors: list[str] = field(default_factory=list)
