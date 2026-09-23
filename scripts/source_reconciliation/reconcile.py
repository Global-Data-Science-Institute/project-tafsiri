"""Build safe lineage crosswalks without writing to a database.

Inputs are local artifact and legacy-row exports. The module deliberately has
no database write client; production extraction is a separate SELECT-only step.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Mapping, Sequence


MATCH_CLASSES = (
    "EXACT",
    "NORMALIZATION_ONLY",
    "PUNCTUATION_FORMATTING",
    "GLOSS_FORMATTING",
    "POS_NORMALIZATION",
    "TONE_DIACRITIC_DIFFERENCE",
    "POSSIBLE_TRANSFORMATION",
    "NO_SOURCE_MATCH",
    "AMBIGUOUS_MATCH",
)

MOJIBAKE_MARKERS = ("\u00c3", "\u00c2", "\u00e2\u20ac", "\ufffd")
PUNCTUATION_TRANSLATION = str.maketrans(
    {"’": "'", "‘": "'", "`": "'", "“": '"', "”": '"', "–": "-", "—": "-"}
)
POS_EQUIVALENTS = {
    "n": "noun",
    "n.": "noun",
    "noun": "noun",
    "v": "verb",
    "v.": "verb",
    "verb": "verb",
    "adj": "adjective",
    "adj.": "adjective",
    "adjective": "adjective",
    "adv": "adverb",
    "adv.": "adverb",
    "adverb": "adverb",
}


@dataclass(frozen=True)
class Entry:
    locator: str
    form: str
    gloss: str = ""
    pos: str = ""
    noun_class: str = ""
    page: str = ""


@dataclass
class Reconciliation:
    crosswalk: list[dict[str, object]] = field(default_factory=list)
    artifact_unmatched: list[str] = field(default_factory=list)
    counts: Counter[str] = field(default_factory=Counter)
    duplicate_artifact_keys: int = 0


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def safe_text_hash(value: str) -> str:
    return hashlib.sha256(normalize_text(value).encode("utf-8")).hexdigest()


def normalize_text(value: object) -> str:
    return " ".join(unicodedata.normalize("NFC", str(value or "")).split())


def normalize_punctuation(value: object) -> str:
    return normalize_text(value).translate(PUNCTUATION_TRANSLATION)


def normalize_gloss(value: object) -> str:
    text = normalize_punctuation(value).casefold()
    text = re.sub(r"\s*([,;:/()])\s*", r"\1", text)
    return re.sub(r"[.;]+$", "", text)


def normalize_form(value: object) -> str:
    return normalize_punctuation(value).casefold()


def secondary_search_form(value: object) -> str:
    """Accent-insensitive lookup key that leaves the source value untouched."""
    decomposed = unicodedata.normalize("NFD", normalize_form(value))
    return unicodedata.normalize("NFC", "".join(ch for ch in decomposed if not unicodedata.combining(ch)))


def normalize_pos(value: object) -> str:
    text = normalize_text(value).casefold()
    return POS_EQUIVALENTS.get(text, text.rstrip("."))


def encoding_findings(values: Iterable[object]) -> dict[str, int]:
    findings: Counter[str] = Counter()
    for value in values:
        text = str(value or "")
        for marker in MOJIBAKE_MARKERS:
            if marker in text:
                findings[marker] += 1
        if text != unicodedata.normalize("NFC", text):
            findings["NON_NFC"] += 1
        if re.search(r"\s{2,}|[\t\r]", text):
            findings["UNUSUAL_WHITESPACE"] += 1
    return dict(sorted(findings.items()))


def classify_pair(artifact: Entry, legacy: Entry) -> str:
    raw_a = (artifact.form, artifact.gloss, artifact.pos)
    raw_l = (legacy.form, legacy.gloss, legacy.pos)
    if raw_a == raw_l:
        return "EXACT"
    normalized_a = tuple(normalize_text(v) for v in raw_a)
    normalized_l = tuple(normalize_text(v) for v in raw_l)
    if normalized_a == normalized_l:
        return "NORMALIZATION_ONLY"
    punct_a = tuple(normalize_punctuation(v).casefold() for v in raw_a)
    punct_l = tuple(normalize_punctuation(v).casefold() for v in raw_l)
    if punct_a == punct_l:
        return "PUNCTUATION_FORMATTING"
    if normalize_form(artifact.form) == normalize_form(legacy.form):
        if normalize_gloss(artifact.gloss) == normalize_gloss(legacy.gloss):
            if normalize_text(artifact.gloss) != normalize_text(legacy.gloss):
                return "GLOSS_FORMATTING"
            if normalize_pos(artifact.pos) == normalize_pos(legacy.pos):
                if normalize_text(artifact.pos) != normalize_text(legacy.pos):
                    return "POS_NORMALIZATION"
        return "POSSIBLE_TRANSFORMATION"
    if secondary_search_form(artifact.form) == secondary_search_form(legacy.form):
        return "TONE_DIACRITIC_DIFFERENCE"
    return "NO_SOURCE_MATCH"


def reconcile_entries(
    artifacts: Sequence[Entry],
    legacy_rows: Sequence[Entry],
    *,
    historical_table: str,
    dialect_raw_label: str,
    source_version: str,
) -> Reconciliation:
    by_form: dict[str, list[int]] = defaultdict(list)
    by_secondary_form: dict[str, list[int]] = defaultdict(list)
    for index, entry in enumerate(artifacts):
        by_form[normalize_form(entry.form)].append(index)
        by_secondary_form[secondary_search_form(entry.form)].append(index)
    duplicate_count = sum(len(indexes) - 1 for indexes in by_form.values() if len(indexes) > 1)
    used: set[int] = set()
    result = Reconciliation(duplicate_artifact_keys=duplicate_count)

    for legacy in sorted(legacy_rows, key=lambda row: row.locator):
        candidates = by_form.get(normalize_form(legacy.form), [])
        if not candidates:
            candidates = by_secondary_form.get(secondary_search_form(legacy.form), [])
        if not candidates:
            match_class = "NO_SOURCE_MATCH"
            candidate = None
            confidence = "LOW"
        else:
            ranked = sorted((classify_pair(artifacts[i], legacy), i) for i in candidates)
            priority = {name: i for i, name in enumerate(MATCH_CLASSES)}
            ranked.sort(key=lambda item: (priority[item[0]], artifacts[item[1]].locator))
            best_class = ranked[0][0]
            best = [i for cls, i in ranked if cls == best_class]
            if len(best) > 1:
                match_class = "AMBIGUOUS_MATCH"
                candidate = None
                confidence = "LOW"
            else:
                match_class = best_class
                candidate = artifacts[best[0]]
                used.add(best[0])
                confidence = "HIGH" if match_class in {"EXACT", "NORMALIZATION_ONLY", "PUNCTUATION_FORMATTING", "GLOSS_FORMATTING", "POS_NORMALIZATION"} else "MEDIUM"
        result.counts[match_class] += 1
        result.crosswalk.append(
            {
                "historical_table": historical_table,
                "historical_row_id": legacy.locator,
                "source_artifact_locator": candidate.locator if candidate else None,
                "source_form_hash": safe_text_hash(legacy.form),
                "match_class": match_class,
                "transformation_class": match_class if match_class not in {"EXACT", "NO_SOURCE_MATCH", "AMBIGUOUS_MATCH"} else None,
                "dialect_raw_label": dialect_raw_label,
                "proposed_source_version": source_version,
                "confidence_category": confidence,
                "notes": "Multiple equally ranked artifact entries" if match_class == "AMBIGUOUS_MATCH" else None,
            }
        )
    result.artifact_unmatched = [entry.locator for i, entry in enumerate(artifacts) if i not in used]
    return result


def load_entries(path: Path, field_map: Mapping[str, str]) -> list[Entry]:
    if path.suffix.casefold() == ".csv":
        with path.open("r", encoding="utf-8-sig", newline="") as stream:
            rows = list(csv.DictReader(stream))
    else:
        with path.open("r", encoding="utf-8-sig") as stream:
            rows = json.load(stream)
    return [
        Entry(
            locator=str(row.get(field_map["locator"], "")),
            form=str(row.get(field_map["form"], "") or ""),
            gloss=str(row.get(field_map.get("gloss", ""), "") or ""),
            pos=str(row.get(field_map.get("pos", ""), "") or ""),
            noun_class=str(row.get(field_map.get("noun_class", ""), "") or ""),
        )
        for row in rows
    ]


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_jsonl(path: Path, rows: Iterable[Mapping[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as stream:
        for row in rows:
            stream.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--legacy", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--table", required=True)
    parser.add_argument("--dialect", required=True)
    parser.add_argument("--source-version", required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    standard = {"locator": "locator", "form": "form", "gloss": "gloss", "pos": "pos", "noun_class": "noun_class"}
    artifacts = load_entries(args.artifact, standard)
    legacy = load_entries(args.legacy, standard)
    result = reconcile_entries(artifacts, legacy, historical_table=args.table, dialect_raw_label=args.dialect, source_version=args.source_version)
    write_jsonl(args.output, result.crosswalk)
    print(json.dumps({"counts": dict(result.counts), "artifact_unmatched": len(result.artifact_unmatched), "duplicate_artifact_keys": result.duplicate_artifact_keys}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
