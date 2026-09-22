from __future__ import annotations

from collections import defaultdict

from .models import CorpusSignals, DictionaryEntry
from .normalize import normalize_text, pos_family


class CorpusIndex:
    def __init__(self, entries: list[DictionaryEntry]):
        self.entries = sorted(entries, key=lambda item: item.id)
        self.by_form: dict[tuple[str, str], list[DictionaryEntry]] = defaultdict(list)
        self.by_definition: dict[str, list[DictionaryEntry]] = defaultdict(list)
        for entry in self.entries:
            form = normalize_text(entry.word_normalized or entry.word)
            self.by_form[(entry.dialect_id, form)].append(entry)
            self.by_definition[normalize_text(entry.english_definition)].append(entry)

    def signals_for(self, entry: DictionaryEntry) -> CorpusSignals:
        form_rows = self.by_form[(entry.dialect_id, normalize_text(entry.word_normalized or entry.word))]
        definition_rows = self.by_definition[normalize_text(entry.english_definition)]
        distinct_definitions = {normalize_text(row.english_definition) for row in form_rows}
        definition_forms = {normalize_text(row.word_normalized or row.word) for row in definition_rows}
        pos_families = {pos_family(row.part_of_speech) for row in definition_rows}
        return CorpusSignals(
            repeated_form_count=len(form_rows),
            distinct_definition_count=len(distinct_definitions),
            same_definition_form_count=len(definition_forms),
            incompatible_definition_pos=len(pos_families - {"unknown"}) > 1,
        )

    @property
    def repeated_form_group_count(self) -> int:
        return sum(1 for rows in self.by_form.values() if len({normalize_text(r.english_definition) for r in rows}) > 1)
