from __future__ import annotations

from .models import DictionaryEntry
from .normalize import normalize_text, pos_family


def lookup_concept_key(entry: DictionaryEntry, config) -> dict | None:
    rule = config.concept_keys.get(normalize_text(entry.english_definition))
    if not rule:
        return None
    compatible = rule.get("compatible_pos")
    if compatible and pos_family(entry.part_of_speech) not in compatible:
        return None
    return rule
