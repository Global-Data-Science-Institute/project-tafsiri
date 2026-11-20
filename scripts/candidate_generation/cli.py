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
from .language_profile import LanguageProfile, build_scoped_candidate, load_profile, load_snapshot, validate_snapshot


def generate(entries, concepts, config):
    if isinstance(config, LanguageProfile):
        # Same corpus indexing, candidate loop, summary and export infrastructure.
        # Never run the legacy English/curated-key heuristics on new profiles.
        entries = validate_snapshot({'contract_version': 1, 'records': [e.record for e in entries]}, config)
        index = CorpusIndex(entries, normalizer=config.normalize)
        return [build_scoped_candidate(entry, index.signals_for(entry), config)
                for entry in index.entries], index
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
    result.add_argument("--language-profile", type=Path)
    result.add_argument("--input-snapshot", type=Path)
    return result


def main(argv=None) -> int:
    args = parser().parse_args(argv)
    if not args.dry_run:
        raise SystemExit("Pipeline 001 supports --dry-run only; no database write mode exists")
    if args.language_profile is not None:
        profile = load_profile(args.language_profile)
        if args.input_snapshot is None:
            raise SystemExit('--input-snapshot is required for an explicit language profile')
        protected = [Path('artifacts/candidate_generation').resolve(), Path('evaluation').resolve()]
        destination = args.output_dir.resolve()
        if any(destination == root or root in destination.parents for root in protected) or args.overwrite_local:
            raise SystemExit('profile runs require a fresh output location outside historical candidate/evaluation artifacts')
        # This CLI mode is deliberately synthetic-only until a rights-aware
        # private exporter and approved registry connection are integrated.
        if profile.values['evaluation']['split'] != 'SYNTHETIC':
            raise SystemExit('real research snapshots require a separately authorized private adapter')
        entries = load_snapshot(args.input_snapshot, profile)
        candidates, index = generate(entries, [], profile)
        metadata = RunMetadata(PIPELINE_VERSION, 'pipeline-scoped-evidence-v1', profile.config_hash,
                               datetime.now(timezone.utc).isoformat(), len(entries))
        summary = build_summary(candidates, metadata, index.repeated_form_group_count, [])
        export_all(args.output_dir, candidates, summary, False)
        return 0
    if args.input_snapshot is not None:
        raise SystemExit('--input-snapshot requires --language-profile; no Luwanga fallback')
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
