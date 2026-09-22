from __future__ import annotations

import re
import unicodedata


_SPACE = re.compile(r"\s+")


def normalize_text(value: str | None) -> str:
    if not value:
        return ""
    return _SPACE.sub(" ", unicodedata.normalize("NFKC", value).strip()).casefold()


def pos_family(value: str | None) -> str:
    pos = normalize_text(value).rstrip(".,;")
    if pos.startswith("n"):
        return "noun"
    if pos.startswith("v"):
        return "verb"
    if pos.startswith("adj"):
        return "adjective"
    if pos.startswith("adv"):
        return "adverb"
    if pos.startswith("pron"):
        return "pronoun"
    return pos or "unknown"
