from __future__ import annotations

from .models import AmbiguityResult, Classification, CorpusSignals, DictionaryEntry


def heuristic_confidence(entry: DictionaryEntry, signals: CorpusSignals, ambiguity: AmbiguityResult,
                         classification: Classification, key_rule: dict | None, suggestions: list, config) -> tuple[float, list[str]]:
    score = config.values["confidence"]["base"]
    components: list[str] = []
    def apply(name: str, condition: bool) -> None:
        nonlocal score
        if condition:
            score += config.values["confidence"]["components"][name]
            components.append(name)
    apply("unique_normalized_form", signals.repeated_form_count == 1)
    apply("short_single_sense", "short_definition" in classification.heuristic_flags)
    apply("stable_pos", bool(entry.part_of_speech) and "compound_part_of_speech" not in ambiguity.indicators)
    apply("curated_key_match", key_rule is not None)
    apply("unique_definition", signals.same_definition_form_count == 1)
    apply("existing_concept_suggestion", bool(suggestions))
    apply("noun_class_evidence", bool(entry.noun_class))
    apply("repeated_form_multiple_definitions", "repeated_form_multiple_definitions" in ambiguity.indicators)
    apply("sense_punctuation", any(x in ambiguity.indicators for x in ("semicolon_segments", "slash_segments", "standalone_or")))
    apply("contextual_definition", any(x in ambiguity.indicators for x in ("contextual_language", "long_commentary_definition")))
    apply("incompatible_pos", "incompatible_pos_reuse" in ambiguity.indicators)
    apply("definition_reused", signals.same_definition_form_count > 1)
    apply("broad_gloss", "BROAD_GLOSS_REVIEW" in classification.reason_codes)
    return min(max(round(score, 2), 0.0), 0.99), components
