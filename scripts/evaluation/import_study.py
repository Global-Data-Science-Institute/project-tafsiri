from __future__ import annotations

import argparse
import hashlib
import json
import os
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


IMPORTER_VERSION = "study-import-001-v1"
STUDY_KEY = "HUMAN_EVALUATION_001_LUWANGA"
STUDY_TITLE = "Human Evaluation 001 — Luwanga Semantic Review"
EXPECTED_COUNT = 150
REVIEW_FIELDS = (
    "reviewer_decision", "reviewer_concept_label", "reviewer_definition",
    "reviewer_notes", "pipeline_bucket_correct", "pipeline_ambiguity_correct",
)
SOURCE_FIELDS = (
    "dictionary_entry_id", "word", "word_normalized", "english_definition",
    "part_of_speech", "noun_class", "dialect", "other_definitions_for_form",
)


class ImportValidationError(ValueError):
    pass


def canonical_json_bytes(value: dict[str, Any]) -> bytes:
    """RFC-8259 JSON encoded as UTF-8, sorted keys, compact separators, no ASCII escaping."""
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False,
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def snapshot_hash(value: dict[str, Any]) -> str:
    return sha256_bytes(canonical_json_bytes(value))


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


@dataclass(frozen=True)
class ImportItem:
    item_number: int
    dictionary_entry_id: str
    sampling_group: str
    source_snapshot: dict[str, Any]
    source_hash: str
    pipeline_snapshot: dict[str, Any]
    pipeline_hash: str


@dataclass(frozen=True)
class StudyPackage:
    metadata: dict[str, Any]
    items: tuple[ImportItem, ...]
    frozen_sample_sha256: str
    pipeline_artifact_sha256: str


def _nonblank(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def build_package(sample_path: Path, manifest_path: Path, pipeline_path: Path) -> StudyPackage:
    manifest = load_json(manifest_path)
    sample = load_jsonl(sample_path)
    pipeline_rows = load_jsonl(pipeline_path)
    errors: list[str] = []

    pipeline_sha = sha256_bytes(pipeline_path.read_bytes())
    if pipeline_sha != manifest.get("source_artifact_hash"):
        errors.append("source artifact hash mismatch")
    if len(sample) != EXPECTED_COUNT:
        errors.append(f"expected {EXPECTED_COUNT} records, found {len(sample)}")

    pipeline_by_id: dict[str, dict[str, Any]] = {}
    for row in pipeline_rows:
        identifier = row.get("dictionary_entry_id")
        if identifier in pipeline_by_id:
            errors.append(f"duplicate Pipeline dictionary_entry_id: {identifier}")
        pipeline_by_id[identifier] = row

    ids = [row.get("dictionary_entry_id") for row in sample]
    sequences = [row.get("sample_sequence") for row in sample]
    if any(not _nonblank(identifier) for identifier in ids):
        errors.append("missing dictionary_entry_id")
    if len(set(ids)) != len(ids):
        errors.append("duplicate dictionary_entry_id")
    if len(set(sequences)) != len(sequences):
        errors.append("duplicate item number")
    if sequences != list(range(1, len(sample) + 1)) or sequences != list(range(1, EXPECTED_COUNT + 1)):
        errors.append("item numbers/order must be exactly 1-150 in frozen file order")
    actual_groups = dict(Counter(row.get("sample_group") for row in sample))
    if actual_groups != manifest.get("sample_counts_by_group"):
        errors.append("sampling-group counts differ from frozen manifest")
    actual_buckets = dict(Counter(row.get("bucket") for row in sample))
    if actual_buckets != manifest.get("sample_counts_by_pipeline_bucket"):
        errors.append("Pipeline bucket counts differ from frozen manifest")

    manifest_pipeline_version = manifest.get("pipeline_version")
    manifest_schema_version = manifest.get("evidence_schema_version")
    manifest_config_hash = manifest.get("configuration_hash")
    items: list[ImportItem] = []
    for position, row in enumerate(sample, 1):
        identifier = row.get("dictionary_entry_id")
        if row.get("dialect") != "Luwanga":
            errors.append(f"record {position} is not Luwanga")
        if any(row.get(field) not in (None, "", []) for field in REVIEW_FIELDS):
            errors.append(f"record {position} contains human annotation data")
        pipeline = pipeline_by_id.get(identifier)
        if pipeline is None:
            errors.append(f"record {position} has no matching Pipeline result")
            continue
        evidence = pipeline.get("evidence") or {}
        source = evidence.get("source") or {}
        classification = evidence.get("classification") or {}
        proposal = evidence.get("proposal") or {}
        if evidence.get("pipeline_version") != manifest_pipeline_version:
            errors.append(f"record {position} pipeline version mismatch")
        if evidence.get("schema_version") != manifest_schema_version:
            errors.append(f"record {position} evidence schema mismatch")
        if evidence.get("config_hash") != manifest_config_hash:
            errors.append(f"record {position} configuration hash mismatch")
        comparisons = {
            "word": source.get("word"), "word_normalized": source.get("word_normalized"),
            "english_definition": source.get("english_definition"),
            "part_of_speech": source.get("part_of_speech"), "noun_class": source.get("noun_class"),
            "dialect": source.get("dialect_name"), "bucket": classification.get("bucket"),
            "mapping_status": pipeline.get("mapping_status"),
            "ambiguity_action": classification.get("ambiguity_action"),
            "heuristic_confidence": proposal.get("heuristic_confidence"),
            "proposed_concept_key": pipeline.get("proposed_concept_key"),
            "heuristic_flags": classification.get("heuristic_flags"),
            "ambiguity_indicators": classification.get("ambiguity_indicators"),
            "reason_codes": evidence.get("reason_codes"),
            "repeated_form_count": classification.get("repeated_form_count"),
            "distinct_definition_count": classification.get("distinct_definition_count"),
            "same_definition_form_count": classification.get("same_definition_form_count"),
        }
        for key, pipeline_value in comparisons.items():
            if row.get(key) != pipeline_value:
                errors.append(f"record {position} frozen sample/Pipeline mismatch: {key}")

        source_snapshot = {field: row.get(field) for field in SOURCE_FIELDS}
        pipeline_snapshot = {
            "dictionary_entry_id": identifier,
            "bucket": classification.get("bucket"),
            "mapping_status": pipeline.get("mapping_status"),
            "mapping_source": pipeline.get("mapping_source"),
            "ambiguity_action": classification.get("ambiguity_action"),
            "ambiguity_segments": classification.get("ambiguity_segments"),
            "heuristic_confidence": proposal.get("heuristic_confidence"),
            "confidence_components": proposal.get("confidence_components"),
            "confidence_is_calibrated_probability": proposal.get("confidence_is_calibrated_probability"),
            "proposed_concept_key": pipeline.get("proposed_concept_key"),
            "proposed_definition_en": pipeline.get("proposed_definition_en"),
            "heuristic_flags": classification.get("heuristic_flags"),
            "ambiguity_indicators": classification.get("ambiguity_indicators"),
            "reason_codes": evidence.get("reason_codes"),
            "repeated_form_count": classification.get("repeated_form_count"),
            "distinct_definition_count": classification.get("distinct_definition_count"),
            "same_definition_form_count": classification.get("same_definition_form_count"),
            "existing_concept_suggestions": evidence.get("existing_concept_suggestions"),
            "pipeline_version": evidence.get("pipeline_version"),
            "evidence_schema_version": evidence.get("schema_version"),
            "configuration_hash": evidence.get("config_hash"),
        }
        if not isinstance(source_snapshot, dict) or not isinstance(pipeline_snapshot, dict):
            errors.append(f"record {position} snapshot is not a JSON object")
        items.append(ImportItem(
            item_number=position, dictionary_entry_id=identifier,
            sampling_group=row.get("sample_group"), source_snapshot=source_snapshot,
            source_hash=snapshot_hash(source_snapshot), pipeline_snapshot=pipeline_snapshot,
            pipeline_hash=snapshot_hash(pipeline_snapshot),
        ))

    if errors:
        raise ImportValidationError("; ".join(dict.fromkeys(errors)))
    metadata = {
        "study_key": STUDY_KEY, "title": STUDY_TITLE,
        "description": "Frozen 150-item Human Evaluation 001 study for independent Luwanga semantic review.",
        "dialect": "Luwanga", "pipeline_version": manifest_pipeline_version,
        "evidence_schema_version": manifest_schema_version,
        "configuration_hash": manifest_config_hash,
        "source_artifact_hash": pipeline_sha, "initial_status": "draft",
    }
    return StudyPackage(metadata, tuple(items), sha256_bytes(sample_path.read_bytes()), pipeline_sha)


def validate_remote_state(connection: Any, package: StudyPackage) -> str:
    with connection.cursor() as cursor:
        cursor.execute("SELECT id FROM public.dialects WHERE lower(name)=lower(%s)", (package.metadata["dialect"],))
        dialects = cursor.fetchall()
        if len(dialects) != 1:
            raise ImportValidationError(f"expected one Luwanga dialect, found {len(dialects)}")
        cursor.execute("SELECT study_status FROM public.evaluation_studies WHERE study_key=%s", (STUDY_KEY,))
        existing = cursor.fetchone()
        if existing:
            raise ImportValidationError(f"study key already exists with status {existing[0]}")
        cursor.execute("SELECT id::text FROM public.dictionary_entries WHERE id = ANY(%s::uuid[])", ([item.dictionary_entry_id for item in package.items],))
        found = {row[0] for row in cursor.fetchall()}
        missing = sorted({item.dictionary_entry_id for item in package.items} - found)
        if missing:
            raise ImportValidationError(f"missing dictionary IDs: {', '.join(missing)}")
        cursor.execute("SELECT (SELECT count(*) FROM public.evaluation_studies),(SELECT count(*) FROM public.evaluation_items),(SELECT count(*) FROM public.evaluation_item_pipeline_snapshots),(SELECT count(*) FROM public.reviewer_profiles),(SELECT count(*) FROM public.reviewer_dialect_expertise),(SELECT count(*) FROM public.review_assignments),(SELECT count(*) FROM public.review_annotations),(SELECT count(*) FROM public.evaluation_adjudications)")
        counts = cursor.fetchone()
        if any(counts):
            raise ImportValidationError(f"evaluation tables are not in expected empty pre-import state: {counts}")
        return str(dialects[0][0])


def execute_import(connection: Any, package: StudyPackage, confirmation: str) -> None:
    if confirmation != STUDY_KEY:
        raise ImportValidationError("--execute requires the exact --confirm-study-key value")
    # psycopg transaction context rolls back automatically on every validation failure.
    with connection.transaction(), connection.cursor() as cursor:
        dialect_id = validate_remote_state(connection, package)
        cursor.execute("INSERT INTO public.evaluation_studies(study_key,title,description,dialect_id,pipeline_version,evidence_schema_version,configuration_hash,source_artifact_hash,study_status) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'draft') RETURNING id", (STUDY_KEY, package.metadata["title"], package.metadata["description"], dialect_id, package.metadata["pipeline_version"], package.metadata["evidence_schema_version"], package.metadata["configuration_hash"], package.metadata["source_artifact_hash"]))
        study_id = cursor.fetchone()[0]
        for item in package.items:
            cursor.execute("INSERT INTO public.evaluation_items(study_id,item_number,dictionary_entry_id,source_snapshot,source_hash,sampling_group) VALUES (%s,%s,%s,%s::jsonb,%s,%s) RETURNING id", (study_id,item.item_number,item.dictionary_entry_id,canonical_json_bytes(item.source_snapshot).decode(),item.source_hash,item.sampling_group))
            item_id = cursor.fetchone()[0]
            cursor.execute("INSERT INTO public.evaluation_item_pipeline_snapshots(evaluation_item_id,pipeline_snapshot,pipeline_hash) VALUES (%s,%s::jsonb,%s)", (item_id,canonical_json_bytes(item.pipeline_snapshot).decode(),item.pipeline_hash))
        cursor.execute("SELECT count(*) FROM public.evaluation_items WHERE study_id=%s", (study_id,))
        if cursor.fetchone()[0] != EXPECTED_COUNT: raise ImportValidationError("inserted item count mismatch")
        cursor.execute("SELECT count(*) FROM public.evaluation_item_pipeline_snapshots p JOIN public.evaluation_items i ON i.id=p.evaluation_item_id WHERE i.study_id=%s", (study_id,))
        if cursor.fetchone()[0] != EXPECTED_COUNT: raise ImportValidationError("inserted pipeline snapshot count mismatch")
        cursor.execute("UPDATE public.evaluation_studies SET study_status='active' WHERE id=%s", (study_id,))


def manifest_dict(package: StudyPackage, generated_at: str | None = None) -> dict[str, Any]:
    return {
        "importer_version": IMPORTER_VERSION,
        "generation_timestamp": generated_at or datetime.now(timezone.utc).isoformat(),
        "zero_write_confirmation": True,
        "study": package.metadata,
        "frozen_sample_sha256": package.frozen_sample_sha256,
        "pipeline_source_artifact_sha256": package.pipeline_artifact_sha256,
        "item_count": len(package.items), "pipeline_snapshot_count": len(package.items),
        "sampling_group_counts": dict(sorted(Counter(i.sampling_group for i in package.items).items())),
        "pipeline_bucket_counts": dict(sorted(Counter(i.pipeline_snapshot["bucket"] for i in package.items).items())),
        "human_reviewer_data_imported": 0, "reviewer_profiles_created": 0,
        "assignments_imported": 0, "annotations_imported": 0, "adjudications_imported": 0,
        "items": [{"item_number": i.item_number, "dictionary_entry_id": i.dictionary_entry_id, "sampling_group": i.sampling_group, "source_hash": i.source_hash, "pipeline_hash": i.pipeline_hash} for i in package.items],
    }


def write_manifest(path: Path, package: StudyPackage) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest_dict(package), ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def _connect(database_url: str):
    try:
        import psycopg
    except ImportError as error:
        raise RuntimeError("database validation/execution requires psycopg 3; credentials are read only from TAFSIRI_DATABASE_URL") from error
    return psycopg.connect(database_url)


def dry_run_report(package: StudyPackage) -> dict[str, Any]:
    result = manifest_dict(package)
    result["would_import"] = {"study_rows": 1, "evaluation_items": len(package.items), "pipeline_snapshots": len(package.items), "initial_status": "draft", "final_status_after_integrity_validation": "active"}
    return result


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate and transactionally import a frozen Tafsiri evaluation study")
    parser.add_argument("--sample", type=Path, default=Path("evaluation/candidate_generation/human_review_001.jsonl"))
    parser.add_argument("--manifest", type=Path, default=Path("evaluation/candidate_generation/human_review_001_manifest.json"))
    parser.add_argument("--pipeline", type=Path, default=Path("artifacts/candidate_generation/pipeline_001.jsonl"))
    parser.add_argument("--output-manifest", type=Path, default=Path("evaluation/imports/human_evaluation_001_import_manifest.json"))
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--validate", action="store_true")
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--execute", action="store_true")
    parser.add_argument("--validate-database", action="store_true")
    parser.add_argument("--confirm-study-key")
    args = parser.parse_args(argv)
    package = build_package(args.sample, args.manifest, args.pipeline)
    if args.execute and args.confirm_study_key != STUDY_KEY:
        raise ImportValidationError("--execute requires the exact --confirm-study-key value")
    database_url = os.environ.get("TAFSIRI_DATABASE_URL")
    if args.validate_database or args.execute:
        if not database_url: raise ImportValidationError("TAFSIRI_DATABASE_URL is required for database access")
        with _connect(database_url) as connection:
            if args.execute: execute_import(connection, package, args.confirm_study_key or "")
            else: validate_remote_state(connection, package); connection.rollback()
    if args.dry_run:
        write_manifest(args.output_manifest, package)
        print(json.dumps(dry_run_report(package), ensure_ascii=False, sort_keys=True, indent=2))
    else:
        print(f"validated {len(package.items)} frozen records")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
