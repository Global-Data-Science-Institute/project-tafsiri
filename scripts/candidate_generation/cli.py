from __future__ import annotations

import argparse
import os
from datetime import datetime, timezone
from pathlib import Path

from . import EVIDENCE_SCHEMA_VERSION, PIPELINE_VERSION
from .ambiguity import analyze_ambiguity
from .bucket import classify
from .concept_keys import lookup_concept_key
from .concept_match import suggest_existing
from .confidence import heuristic_confidence
from .config import load_config
from .corpus_index import CorpusIndex
from .evidence import build_candidate
from .export import build_summary, export_all
from .extract import ReadOnlySupabaseClient
from .models import RunMetadata


def generate(entries, concepts, config):
    index = CorpusIndex(entries); candidates = []
    for entry in index.entries:
        signals = index.signals_for(entry)
        ambiguity = analyze_ambiguity(entry, signals, config)
        classification = classify(entry, signals, ambiguity, config)
        key_rule = lookup_concept_key(entry, config)
        suggestions = suggest_existing(entry, concepts, key_rule)
        score, components = heuristic_confidence(entry, signals, ambiguity, classification, key_rule, suggestions, config)
        candidates.append(build_candidate(entry, signals, ambiguity, classification, key_rule, suggestions, score, components, config.config_hash))
    return candidates, index


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Project Tafsiri Pipeline 001 (read-only)")
    result.add_argument("--dry-run", action="store_true", help="Required; database writes do not exist")
    result.add_argument("--overwrite-local", action="store_true", help="Overwrite local artifacts only")
    result.add_argument("--output-dir", type=Path, default=Path("artifacts/candidate_generation"))
    result.add_argument("--config-dir", type=Path, default=Path("config/candidate_generation"))
    return result


def main(argv=None) -> int:
    args = parser().parse_args(argv)
    if not args.dry_run:
        raise SystemExit("Pipeline 001 supports --dry-run only; no database write mode exists")
    url = os.environ.get("SUPABASE_URL") or os.environ.get("NEXT_PUBLIC_SUPABASE_URL")
    key = os.environ.get("SUPABASE_ANON_KEY") or os.environ.get("NEXT_PUBLIC_SUPABASE_ANON_KEY")
    if not url or not key:
        raise SystemExit("Set SUPABASE_URL and SUPABASE_ANON_KEY using public read-only credentials")
    config = load_config(args.config_dir)
    client = ReadOnlySupabaseClient(url, key)
    extraction_timestamp = datetime.now(timezone.utc).isoformat()
    entries = client.fetch_luwanga_entries()
    concepts = client.fetch_concepts()
    candidates, index = generate(entries, concepts, config)
    metadata = RunMetadata(PIPELINE_VERSION, EVIDENCE_SCHEMA_VERSION, config.config_hash, extraction_timestamp, len(entries))
    summary = build_summary(candidates, metadata, index.repeated_form_group_count, [])
    export_all(args.output_dir, candidates, summary, args.overwrite_local)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
