from __future__ import annotations

import re

from .models import AmbiguityResult, Classification, CorpusSignals, DictionaryEntry
from .normalize import normalize_text


_SIMPLE = re.compile(r"^[A-Za-z][A-Za-z' -]*$")


def classify(entry: DictionaryEntry, signals: CorpusSignals, ambiguity: AmbiguityResult, config) -> Classification:
    reasons: list[str] = []
    flags = list(ambiguity.flags)
    if ambiguity.indicators:
        return Classification("C", "needs_split", ambiguity.action, tuple(flags), ambiguity.indicators,
                              tuple(["AMBIGUITY_SIGNAL"] + [item.upper() for item in ambiguity.indicators]))

    definition = entry.english_definition.strip()
    broad = normalize_text(definition) in set(config.values["bucket_a"]["broad_glosses"])
    short = len(definition) <= config.values["bucket_a"]["max_definition_characters"] and len(definition.split()) <= config.values["bucket_a"]["max_definition_tokens"]
    simple = bool(_SIMPLE.fullmatch(definition))
    requirements = {
        "normalized_word_present": bool(normalize_text(entry.word_normalized)),
        "definition_present": bool(definition),
        "unique_form_meaning": signals.distinct_definition_count == 1,
        "short_definition": short,
        "simple_definition": simple,
        "part_of_speech_present": bool(normalize_text(entry.part_of_speech)),
        "compatible_definition_pos": not signals.incompatible_definition_pos,
        "not_broad_gloss": not broad,
    }
    flags.extend(name for name, passed in requirements.items() if passed)
    if all(requirements.values()):
        reasons.extend(("STRUCTURALLY_CLEAN", "NO_POLYSEMY_SIGNAL"))
        return Classification("A", "proposed", None, tuple(sorted(flags)), (), tuple(reasons))
    if broad:
        reasons.append("BROAD_GLOSS_REVIEW")
    if signals.same_definition_form_count > 1:
        reasons.append("DEFINITION_REUSED")
    reasons.append("QUICK_HUMAN_REVIEW")
    return Classification("B", "proposed", None, tuple(sorted(flags)), (), tuple(sorted(set(reasons))))
