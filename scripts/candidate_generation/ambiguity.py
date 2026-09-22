from __future__ import annotations

import re

from .models import AmbiguityResult, CorpusSignals, DictionaryEntry
from .normalize import normalize_text


_STANDALONE_OR = re.compile(r"\bor\b", re.IGNORECASE)
_COMPOUND_POS = re.compile(r"[/,;]|\band\b", re.IGNORECASE)


def analyze_ambiguity(entry: DictionaryEntry, signals: CorpusSignals, config) -> AmbiguityResult:
    definition = entry.english_definition
    normalized = normalize_text(definition)
    indicators: list[str] = []
    flags: list[str] = []
    segments: list[str] = []

    if signals.distinct_definition_count > 1:
        indicators.append("repeated_form_multiple_definitions")
    if ";" in definition:
        indicators.append("semicolon_segments")
        segments.extend(part.strip() for part in definition.split(";") if part.strip())
    if "/" in definition:
        indicators.append("slash_segments")
        segments.extend(part.strip() for part in definition.split("/") if part.strip())
    if _STANDALONE_OR.search(definition):
        indicators.append("standalone_or")
    matched_markers = [marker for marker in config.contextual_markers if marker in normalized]
    if matched_markers or "(" in definition or ")" in definition:
        indicators.append("contextual_language")
        flags.extend(f"context_marker:{marker}" for marker in matched_markers)
    if len(definition) > config.values["ambiguity"]["long_definition_characters"]:
        indicators.append("long_commentary_definition")
    if entry.part_of_speech and _COMPOUND_POS.search(entry.part_of_speech):
        indicators.append("compound_part_of_speech")
    if signals.incompatible_definition_pos:
        indicators.append("incompatible_pos_reuse")

    indicators = sorted(set(indicators))
    if "repeated_form_multiple_definitions" in indicators:
        action = "polysemy"
    elif any(item in indicators for item in ("semicolon_segments", "slash_segments", "standalone_or")):
        action = "likely_split"
    elif any(item in indicators for item in ("contextual_language", "long_commentary_definition")):
        action = "contextual_review"
    elif indicators:
        action = "review_sense"
    else:
        action = None
    return AmbiguityResult(tuple(indicators), tuple(sorted(set(flags))), tuple(dict.fromkeys(segments)), action)
