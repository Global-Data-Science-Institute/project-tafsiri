"""Validate the Tafsiri scholarly literature registry."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

SOURCE_TYPES = {"JOURNAL_ARTICLE", "CONFERENCE_PAPER", "BOOK_CHAPTER", "BOOK", "GRAMMAR", "MASTERS_THESIS", "DOCTORAL_DISSERTATION", "TECHNICAL_REPORT", "DATASET", "CORPUS", "DICTIONARY", "FIELDWORK_ARCHIVE", "OTHER"}
AUTHORITY_TYPES = {"PEER_REVIEWED", "PUBLISHED_BOOK_CHAPTER", "DOCTORAL_DISSERTATION", "MASTERS_THESIS", "CONFERENCE_PROCEEDINGS", "INSTITUTIONAL_REPORT", "WORKING_PAPER", "UNKNOWN"}
TAGS = {"PHONETICS", "PHONOLOGY", "PRONUNCIATION", "GRAPHEME_TO_PHONEME", "TONE", "PROSODY", "ORTHOGRAPHY", "MORPHOLOGY", "MORPHOPHONOLOGY", "NOUN_CLASS", "AGREEMENT", "INFLECTION", "DERIVATION", "SYNTAX", "SEMANTICS", "PRAGMATICS", "IDEOPHONE", "LOANWORDS", "TERMINOLOGY", "TRANSLATION", "DIALECTOLOGY", "HISTORICAL_LINGUISTICS", "LEXICON", "EXAMPLE_SENTENCES", "INTERLINEAR_GLOSS", "SPEECH_AUDIO", "FIELD_DATA"}
VALUES = {"NONE", "LOW", "MEDIUM", "HIGH", "CRITICAL"}
PRIORITIES = {"CRITICAL", "HIGH", "MEDIUM", "LOW"}
AVAILABILITY = {"OPEN_FULL_TEXT", "PUBLIC_FULL_TEXT_UNCLEAR_LICENSE", "ABSTRACT_ONLY", "PAYWALLED", "METADATA_ONLY", "UNAVAILABLE"}
LICENSES = {"CC_BY_4_0", "CC_BY_SA", "CC_BY_NC", "PUBLIC_DOMAIN", "OTHER_OPEN_LICENSE", "COPYRIGHT_RESTRICTED", "LICENSE_UNKNOWN"}
PRIVATE_PATTERN = re.compile(r"(?:api[_-]?key|service[_-]?role|password|secret|bearer\s+|[\w.+-]+@[\w.-]+)", re.I)


def valid_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def validate_registry(data: dict) -> list[str]:
    errors: list[str] = []
    sources = data.get("sources", [])
    if data.get("source_count") != len(sources): errors.append("source_count does not match sources")
    keys, dois, title_year = set(), set(), set()
    for i, source in enumerate(sources):
        prefix = f"sources[{i}]"
        key = source.get("source_key")
        if not key or key in keys: errors.append(f"{prefix}: duplicate or missing source_key")
        keys.add(key)
        if source.get("source_type") not in SOURCE_TYPES: errors.append(f"{prefix}: invalid source_type")
        if source.get("authority_type") not in AUTHORITY_TYPES: errors.append(f"{prefix}: invalid authority_type")
        if not set(source.get("relevance_tags", [])).issubset(TAGS): errors.append(f"{prefix}: invalid relevance tag")
        if source.get("pronunciation_value") not in VALUES or source.get("grammar_value") not in VALUES: errors.append(f"{prefix}: invalid value classification")
        if source.get("priority") not in PRIORITIES: errors.append(f"{prefix}: invalid priority")
        if source.get("availability") not in AVAILABILITY: errors.append(f"{prefix}: invalid availability")
        if source.get("license_status") not in LICENSES: errors.append(f"{prefix}: invalid license")
        if not source.get("source_reported_varieties"): errors.append(f"{prefix}: missing source-reported variety")
        for url in [source.get("primary_url", ""), *source.get("alternate_urls", [])]:
            if not valid_url(url): errors.append(f"{prefix}: invalid URL {url!r}")
        doi = (source.get("doi") or "").casefold().strip()
        if doi and doi in dois: errors.append(f"{prefix}: duplicate DOI")
        dois.add(doi) if doi else None
        norm_title = re.sub(r"\W+", " ", source.get("title", "").casefold()).strip()
        identity = (norm_title, source.get("year"))
        if identity in title_year: errors.append(f"{prefix}: duplicate normalized title/year")
        title_year.add(identity)
        safe_blob = json.dumps({k:v for k,v in source.items() if k not in {"primary_url","alternate_urls"}}, ensure_ascii=False)
        if PRIVATE_PATTERN.search(safe_blob): errors.append(f"{prefix}: secret or private contact pattern")
    return errors


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "config/linguistic_sources/literature_registry_001.json")
    data = json.loads(path.read_text(encoding="utf-8"))
    errors = validate_registry(data)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"validated {len(data['sources'])} literature sources")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
