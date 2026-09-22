from __future__ import annotations

from dataclasses import asdict

from . import EVIDENCE_SCHEMA_VERSION, PIPELINE_VERSION
from .models import AmbiguityResult, Candidate, Classification, CorpusSignals, DictionaryEntry


def build_candidate(entry: DictionaryEntry, signals: CorpusSignals, ambiguity: AmbiguityResult,
                    classification: Classification, key_rule: dict | None, suggestions: list,
                    confidence: float, confidence_components: list[str], config_hash: str) -> Candidate:
    proposal_key = key_rule["concept_key"] if key_rule else None
    evidence = {
        "schema_version": EVIDENCE_SCHEMA_VERSION,
        "pipeline_version": PIPELINE_VERSION,
        "config_hash": config_hash,
        "source": {
            "dictionary_entry_id": entry.id, "word": entry.word,
            "word_normalized": entry.word_normalized, "english_definition": entry.english_definition,
            "part_of_speech": entry.part_of_speech, "noun_class": entry.noun_class,
            "dialect_id": entry.dialect_id, "dialect_name": entry.dialect_name,
            "language_name": entry.language_name,
        },
        "classification": {
            "bucket": classification.bucket, "mapping_status": classification.mapping_status,
            "ambiguity_action": classification.ambiguity_action,
            "heuristic_flags": list(classification.heuristic_flags),
            "ambiguity_indicators": list(classification.ambiguity_indicators),
            "ambiguity_segments": list(ambiguity.segments),
            "repeated_form_count": signals.repeated_form_count,
            "distinct_definition_count": signals.distinct_definition_count,
            "same_definition_form_count": signals.same_definition_form_count,
        },
        "proposal": {
            "proposed_concept_key": proposal_key,
            "proposed_definition_en": entry.english_definition.strip(),
            "domain": key_rule.get("domain") if key_rule else None,
            "heuristic_confidence": confidence,
            "confidence_components": confidence_components,
            "confidence_is_calibrated_probability": False,
        },
        "existing_concept_suggestions": [asdict(item) for item in suggestions],
        "reason_codes": list(classification.reason_codes),
    }
    return Candidate(entry.id, None, proposal_key, entry.english_definition.strip(), "rule_based",
                     confidence, classification.mapping_status, evidence)
