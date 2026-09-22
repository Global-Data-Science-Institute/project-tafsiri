from __future__ import annotations

import csv
import json
from collections import Counter
from pathlib import Path

from .models import Candidate, RunMetadata


OUTPUT_NAMES = ("pipeline_001.jsonl", "pipeline_001.csv", "pipeline_001-summary.json")


def ensure_outputs_available(output_dir: Path, overwrite_local: bool) -> None:
    existing = [output_dir / name for name in OUTPUT_NAMES if (output_dir / name).exists()]
    if existing and not overwrite_local:
        raise FileExistsError("Refusing to overwrite local artifacts: " + ", ".join(str(path) for path in existing))


def build_summary(candidates: list[Candidate], metadata: RunMetadata, repeated_groups: int,
                  validation_errors: list[str]) -> dict:
    buckets = Counter(item.evidence["classification"]["bucket"] for item in candidates)
    statuses = Counter(item.mapping_status for item in candidates)
    ambiguity = Counter(flag for item in candidates for flag in item.evidence["classification"]["ambiguity_indicators"])
    bands = Counter()
    for item in candidates:
        value = item.confidence
        bands["0.90-0.99" if value >= .9 else "0.75-0.89" if value >= .75 else "0.50-0.74" if value >= .5 else "below_0.50"] += 1
    keyed = sum(item.proposed_concept_key is not None for item in candidates)
    return {
        "metadata": metadata.__dict__, "total_records": len(candidates),
        "bucket_counts": dict(sorted(buckets.items())), "status_counts": dict(sorted(statuses.items())),
        "confidence_bands": dict(sorted(bands.items())), "ambiguity_flags": dict(sorted(ambiguity.items())),
        "repeated_form_groups": repeated_groups, "proposed_concept_key_count": keyed,
        "records_without_safe_concept_keys": len(candidates) - keyed,
        "existing_concept_match_count": sum(bool(item.evidence["existing_concept_suggestions"]) for item in candidates),
        "validation_errors": validation_errors,
    }


def export_all(output_dir: Path, candidates: list[Candidate], summary: dict, overwrite_local: bool) -> None:
    ensure_outputs_available(output_dir, overwrite_local)
    output_dir.mkdir(parents=True, exist_ok=True)
    with (output_dir / OUTPUT_NAMES[0]).open("w", encoding="utf-8", newline="\n") as handle:
        for candidate in candidates:
            handle.write(json.dumps(candidate.to_dict(), ensure_ascii=False, sort_keys=True) + "\n")
    with (output_dir / OUTPUT_NAMES[1]).open("w", encoding="utf-8", newline="") as handle:
        fields = ["dictionary_entry_id", "concept_id", "proposed_concept_key", "proposed_definition_en", "mapping_source", "confidence", "mapping_status", "evidence"]
        writer = csv.DictWriter(handle, fieldnames=fields); writer.writeheader()
        for candidate in candidates:
            row = candidate.to_dict(); row["evidence"] = json.dumps(row["evidence"], ensure_ascii=False, sort_keys=True)
            writer.writerow(row)
    (output_dir / OUTPUT_NAMES[2]).write_text(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
