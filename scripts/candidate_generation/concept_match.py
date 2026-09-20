from __future__ import annotations

from .models import ConceptRecord, ConceptSuggestion, DictionaryEntry
from .normalize import normalize_text


def suggest_existing(entry: DictionaryEntry, concepts: list[ConceptRecord], key_rule: dict | None) -> list[ConceptSuggestion]:
    suggestions: list[ConceptSuggestion] = []
    for concept in concepts:
        signals: list[str] = []
        score = 0.0
        if normalize_text(concept.definition_en) == normalize_text(entry.english_definition):
            score += 0.65
            signals.append("definition_equality")
        if key_rule and concept.concept_key == key_rule["concept_key"]:
            score += 0.25
            signals.append("curated_key_match")
        if key_rule and concept.domain and normalize_text(concept.domain) == normalize_text(key_rule.get("domain")):
            score += 0.10
            signals.append("domain_match")
        if score >= 0.65:
            suggestions.append(ConceptSuggestion(concept.id, concept.concept_key, min(round(score, 2), 0.99), tuple(signals)))
    return sorted(suggestions, key=lambda item: (-item.match_score, item.concept_key, item.concept_id))
