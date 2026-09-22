from __future__ import annotations

import json
import urllib.parse
import urllib.request
from dataclasses import dataclass

from .models import ConceptRecord, DictionaryEntry


@dataclass(frozen=True)
class ReadOnlySupabaseClient:
    """GET-only REST adapter. Deliberately exposes no database write API."""

    url: str
    anon_key: str
    page_size: int = 1000

    def _get(self, table: str, params: dict[str, str]) -> list[dict]:
        query = urllib.parse.urlencode(params, safe="(),.*")
        request = urllib.request.Request(
            f"{self.url.rstrip('/')}/rest/v1/{table}?{query}",
            headers={"apikey": self.anon_key, "Authorization": f"Bearer {self.anon_key}"},
            method="GET",
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))

    def _get_all(self, table: str, select: str, filters: dict[str, str] | None = None) -> list[dict]:
        rows: list[dict] = []
        offset = 0
        while True:
            params = {"select": select, "order": "id.asc", "limit": str(self.page_size), "offset": str(offset)}
            if filters:
                params.update(filters)
            page = self._get(table, params)
            rows.extend(page)
            if len(page) < self.page_size:
                return rows
            offset += self.page_size

    def fetch_luwanga_entries(self) -> list[DictionaryEntry]:
        dialects = self._get(
            "dialects",
            {"select": "id,name,language_id,languages(name)", "name": "eq.Luwanga", "limit": "2"},
        )
        if len(dialects) != 1:
            raise RuntimeError(f"Expected exactly one Luwanga dialect, found {len(dialects)}")
        dialect = dialects[0]
        raw = self._get_all(
            "dictionary_entries",
            "id,dialect_id,word,word_normalized,part_of_speech,noun_class,english_definition,cultural_context,usage_notes,etymology",
            {"dialect_id": f"eq.{dialect['id']}"},
        )
        language = dialect.get("languages") or {}
        return [
            DictionaryEntry(
                id=row["id"], dialect_id=row["dialect_id"], dialect_name=dialect["name"],
                language_name=language.get("name"), word=row["word"],
                word_normalized=row.get("word_normalized"), part_of_speech=row.get("part_of_speech"),
                noun_class=row.get("noun_class"), english_definition=row["english_definition"],
                cultural_context=row.get("cultural_context"), usage_notes=row.get("usage_notes"),
                etymology=row.get("etymology"),
            ) for row in raw
        ]

    def fetch_concepts(self) -> list[ConceptRecord]:
        raw = self._get_all("concepts", "id,concept_key,definition_en,domain,subdomain")
        return [ConceptRecord(**row) for row in raw]
