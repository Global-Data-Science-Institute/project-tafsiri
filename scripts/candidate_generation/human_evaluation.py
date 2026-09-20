from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import random
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path


SEED = 20260813
TARGET_WORDS = (
    "ameno", "amaatsi", "amatsi", "likofi", "ingwe", "okhufwa",
    "libafu", "induli", "okhubala", "okhuluma",
)
REVIEW_DECISIONS = ("ACCEPT_SIMPLE", "ACCEPT_VARIANT", "SPLIT_SENSES", "NEEDS_EXPERT")
OUTPUT_NAMES = (
    "human_review_001.csv", "human_review_001.jsonl",
    "human_review_001_instructions.md", "human_review_001_manifest.json",
    "human_review_001.html",
)


def load_source(path: Path) -> tuple[list[dict], str]:
    content = path.read_bytes()
    rows = [json.loads(line) for line in content.decode("utf-8").splitlines() if line.strip()]
    return rows, hashlib.sha256(content).hexdigest()


def _source(row: dict) -> dict:
    return row["evidence"]["source"]


def _classification(row: dict) -> dict:
    return row["evidence"]["classification"]


def _pick_first(rows: list[dict], used: set[str], predicate) -> dict:
    eligible = sorted((r for r in rows if r["dictionary_entry_id"] not in used and predicate(r)), key=lambda r: r["dictionary_entry_id"])
    if not eligible:
        raise ValueError("Required edge-case category is unavailable")
    used.add(eligible[0]["dictionary_entry_id"])
    return eligible[0]


def select_sample(rows: list[dict], seed: int = SEED) -> list[tuple[str, dict]]:
    if len({row["dictionary_entry_id"] for row in rows}) != len(rows):
        raise ValueError("Source artifact contains duplicate dictionary_entry_id values")
    used: set[str] = set()
    targeted: list[dict] = []
    for word in TARGET_WORDS:
        matches = sorted((r for r in rows if _source(r)["word"] == word), key=lambda r: r["dictionary_entry_id"])
        if not matches:
            raise ValueError(f"Required targeted word is unavailable: {word}")
        for row in matches:
            if row["dictionary_entry_id"] not in used:
                used.add(row["dictionary_entry_id"]); targeted.append(row)

    extra_rules = (
        lambda r: "slash_segments" in _classification(r)["ambiguity_indicators"],
        lambda r: "compound_part_of_speech" in _classification(r)["ambiguity_indicators"],
        lambda r: "standalone_or" in _classification(r)["ambiguity_indicators"],
        lambda r: _classification(r)["same_definition_form_count"] > 1
                  and _classification(r)["distinct_definition_count"] == 1
                  and bool(_source(r).get("noun_class")),
    )
    for predicate in extra_rules:
        if len(targeted) >= 20:
            break
        targeted.append(_pick_first(rows, used, predicate))
    if len(targeted) != 20:
        raise ValueError(f"Expected 20 targeted records, found {len(targeted)}")

    rng = random.Random(seed)
    selected: list[tuple[str, dict]] = [("targeted_edge", row) for row in targeted]
    for bucket, count in (("A", 40), ("B", 40), ("C", 50)):
        eligible = sorted((r for r in rows if _classification(r)["bucket"] == bucket and r["dictionary_entry_id"] not in used), key=lambda r: r["dictionary_entry_id"])
        if len(eligible) < count:
            raise ValueError(f"Bucket {bucket} has {len(eligible)} eligible rows; {count} required")
        chosen = rng.sample(eligible, count)
        for row in chosen:
            used.add(row["dictionary_entry_id"])
            selected.append((f"bucket_{bucket}", row))
    return selected


def review_record(group: str, sequence: int, row: dict, definitions_by_form: dict[tuple[str, str], list[str]]) -> dict:
    source = _source(row); classification = _classification(row); proposal = row["evidence"]["proposal"]
    form_key = (source["dialect_id"], source["word_normalized"] or source["word"])
    other = [value for value in definitions_by_form[form_key] if value != source["english_definition"]]
    return {
        "sample_sequence": sequence,
        "sample_group": group,
        "dictionary_entry_id": row["dictionary_entry_id"],
        "word": source["word"], "word_normalized": source["word_normalized"],
        "english_definition": source["english_definition"], "part_of_speech": source["part_of_speech"],
        "noun_class": source["noun_class"], "dialect": source["dialect_name"],
        "bucket": classification["bucket"], "mapping_status": row["mapping_status"],
        "ambiguity_action": classification["ambiguity_action"],
        "heuristic_confidence": proposal["heuristic_confidence"],
        "proposed_concept_key": row["proposed_concept_key"],
        "heuristic_flags": classification["heuristic_flags"],
        "ambiguity_indicators": classification["ambiguity_indicators"],
        "reason_codes": row["evidence"]["reason_codes"],
        "repeated_form_count": classification["repeated_form_count"],
        "distinct_definition_count": classification["distinct_definition_count"],
        "same_definition_form_count": classification["same_definition_form_count"],
        "other_definitions_for_form": other,
        "reviewer_decision": "", "reviewer_concept_label": "", "reviewer_definition": "",
        "reviewer_notes": "", "pipeline_bucket_correct": "", "pipeline_ambiguity_correct": "",
    }


def validate(records: list[dict]) -> list[str]:
    errors: list[str] = []
    if len(records) != 150: errors.append(f"Expected 150 records, found {len(records)}")
    if len({r['dictionary_entry_id'] for r in records}) != 150: errors.append("Sample dictionary_entry_id values are not unique")
    groups = Counter(r["sample_group"] for r in records)
    expected = {"bucket_A": 40, "bucket_B": 40, "bucket_C": 50, "targeted_edge": 20}
    if dict(groups) != expected: errors.append(f"Unexpected group counts: {dict(groups)}")
    if any(r["reviewer_decision"] for r in records): errors.append("Reviewer decisions were pre-populated")
    if any(r["reviewer_decision"] not in ("", *REVIEW_DECISIONS) for r in records): errors.append("Invalid reviewer decision")
    return errors


def _serializable(record: dict) -> dict:
    return record


def write_outputs(output_dir: Path, records: list[dict], manifest: dict) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for name in OUTPUT_NAMES:
        if (output_dir / name).exists():
            raise FileExistsError(f"Refusing to overwrite existing evaluation file: {output_dir / name}")
    with (output_dir / OUTPUT_NAMES[0]).open("w", encoding="utf-8", newline="") as handle:
        fields = list(records[0])
        writer = csv.DictWriter(handle, fieldnames=fields); writer.writeheader()
        for record in records:
            row = record.copy()
            for field in ("heuristic_flags", "ambiguity_indicators", "reason_codes", "other_definitions_for_form"):
                row[field] = json.dumps(row[field], ensure_ascii=False)
            writer.writerow(row)
    with (output_dir / OUTPUT_NAMES[1]).open("w", encoding="utf-8", newline="\n") as handle:
        for record in records:
            handle.write(json.dumps(_serializable(record), ensure_ascii=False, sort_keys=True) + "\n")
    (output_dir / OUTPUT_NAMES[3]).write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (output_dir / OUTPUT_NAMES[2]).write_text(instructions_text(manifest), encoding="utf-8")
    (output_dir / OUTPUT_NAMES[4]).write_text(html_text(records), encoding="utf-8")


def instructions_text(manifest: dict) -> str:
    return f"""# Tafsiri Human Evaluation 001

This is a local review package generated from Pipeline 001 dry-run output. It does not communicate with Supabase.

## Reviewer decisions

- `ACCEPT_SIMPLE`: The entry represents a sufficiently clear single sense.
- `ACCEPT_VARIANT`: The entry is best treated as a spelling, dialect, noun-class, or grammatical variant of a shared concept.
- `SPLIT_SENSES`: The entry or lexical form contains multiple semantic senses that must remain separate.
- `NEEDS_EXPERT`: Available evidence is insufficient; defer to a qualified Luwanga reviewer.

Leave reviewer fields blank until a human has reviewed the row. For `pipeline_bucket_correct` and `pipeline_ambiguity_correct`, enter `TRUE`, `FALSE`, or leave blank when undecided.

Do not infer a generalized Luhya form from this Luwanga corpus. Do not invent a term where no verified equivalent exists. Reviewer edits remain local evaluation annotations and are not verified training data.

## Reproduction

- Fixed seed: `{manifest['random_seed']}`
- Pipeline: `{manifest['pipeline_version']}`
- Evidence schema: `{manifest['evidence_schema_version']}`
- Source SHA-256: `{manifest['source_artifact_hash']}`
"""


def html_text(records: list[dict]) -> str:
    cards = []
    for record in records:
        def esc(value): return html.escape("" if value is None else str(value))
        flags = ", ".join(record["ambiguity_indicators"] or record["heuristic_flags"])
        others = "<li>None</li>" if not record["other_definitions_for_form"] else "".join(f"<li>{esc(x)}</li>" for x in record["other_definitions_for_form"])
        cards.append(f"""<article><h2>{record['sample_sequence']}. {esc(record['word'])}</h2>
<p class=definition>{esc(record['english_definition'])}</p>
<dl><dt>Group</dt><dd>{esc(record['sample_group'])}</dd><dt>POS</dt><dd>{esc(record['part_of_speech'])}</dd><dt>Noun class</dt><dd>{esc(record['noun_class'])}</dd><dt>Bucket/status</dt><dd>{esc(record['bucket'])} / {esc(record['mapping_status'])}</dd><dt>Confidence</dt><dd>{record['heuristic_confidence']:.2f}</dd><dt>Flags</dt><dd>{esc(flags)}</dd></dl>
<h3>Other definitions for repeated form</h3><ul>{others}</ul>
<div class=review><label>Decision <select><option></option>{''.join(f'<option>{x}</option>' for x in REVIEW_DECISIONS)}</select></label><label>Concept label <input></label><label>Reviewer definition <textarea></textarea></label><label>Notes <textarea></textarea></label><label>Bucket correct? <select><option></option><option>TRUE</option><option>FALSE</option></select></label><label>Ambiguity correct? <select><option></option><option>TRUE</option><option>FALSE</option></select></label></div></article>""")
    return """<!doctype html><meta charset=utf-8><title>Tafsiri Human Evaluation 001</title><style>body{font:16px system-ui;max-width:1000px;margin:auto;padding:2rem;background:#f5f2ea;color:#222}article{background:white;border:1px solid #ccc;border-radius:8px;padding:1.2rem;margin:1rem 0}.definition{font-size:1.15rem}dl{display:grid;grid-template-columns:10rem 1fr;gap:.3rem}dt{font-weight:700}.review{display:grid;gap:.7rem;border-top:1px solid #ddd;padding-top:1rem}.review label{display:grid;gap:.2rem}input,textarea,select{font:inherit;padding:.4rem}textarea{min-height:4rem}</style><h1>Tafsiri Human Evaluation 001</h1><p>Local static review aid. It sends no data anywhere. Record decisions in the CSV/JSONL master files; fields here are not persisted.</p>""" + "".join(cards)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path("artifacts/candidate_generation/pipeline_001.jsonl"))
    parser.add_argument("--summary", type=Path, default=Path("artifacts/candidate_generation/pipeline_001-summary.json"))
    parser.add_argument("--output-dir", type=Path, default=Path("evaluation/candidate_generation"))
    parser.add_argument("--seed", type=int, default=SEED)
    args = parser.parse_args(argv)
    rows, source_hash = load_source(args.source)
    source_summary = json.loads(args.summary.read_text(encoding="utf-8"))
    definitions_by_form: dict[tuple[str, str], list[str]] = defaultdict(list)
    for row in rows:
        source = _source(row); key = (source["dialect_id"], source["word_normalized"] or source["word"])
        if source["english_definition"] not in definitions_by_form[key]: definitions_by_form[key].append(source["english_definition"])
    selected = select_sample(rows, args.seed)
    records = [review_record(group, index, row, definitions_by_form) for index, (group, row) in enumerate(selected, 1)]
    errors = validate(records)
    if errors: raise ValueError("; ".join(errors))
    manifest = {
        "sample_size": len(records), "sample_counts_by_group": dict(Counter(r["sample_group"] for r in records)),
        "sample_counts_by_pipeline_bucket": dict(Counter(r["bucket"] for r in records)),
        "pipeline_version": source_summary["metadata"]["pipeline_version"],
        "evidence_schema_version": source_summary["metadata"]["evidence_schema_version"],
        "configuration_hash": source_summary["metadata"]["config_hash"],
        "source_artifact": str(args.source), "source_artifact_hash": source_hash,
        "random_seed": args.seed, "generation_timestamp": datetime.now(timezone.utc).isoformat(),
        "validation_errors": [], "reviewer_decision_values": list(REVIEW_DECISIONS),
    }
    write_outputs(args.output_dir, records, manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
