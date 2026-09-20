import copy
import hashlib
import json
from pathlib import Path

import pytest

from scripts.evaluation import import_study as subject


ROOT = Path(__file__).parents[2]
SAMPLE = ROOT / "evaluation/candidate_generation/human_review_001.jsonl"
MANIFEST = ROOT / "evaluation/candidate_generation/human_review_001_manifest.json"
PIPELINE = ROOT / "artifacts/candidate_generation/pipeline_001.jsonl"


def rows(path):
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def write_jsonl(path, values):
    path.write_text("".join(json.dumps(value, ensure_ascii=False, sort_keys=True) + "\n" for value in values), encoding="utf-8")


def package(sample=SAMPLE, manifest=MANIFEST, pipeline=PIPELINE):
    return subject.build_package(sample, manifest, pipeline)


def altered_package_files(tmp_path, mutate_sample=None, mutate_pipeline=None, mutate_manifest=None):
    sample_rows, pipeline_rows = rows(SAMPLE), rows(PIPELINE)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if mutate_sample: mutate_sample(sample_rows)
    if mutate_pipeline: mutate_pipeline(pipeline_rows)
    sample_path, pipeline_path, manifest_path = tmp_path/"sample.jsonl",tmp_path/"pipeline.jsonl",tmp_path/"manifest.json"
    write_jsonl(sample_path,sample_rows); write_jsonl(pipeline_path,pipeline_rows)
    manifest["source_artifact_hash"] = hashlib.sha256(pipeline_path.read_bytes()).hexdigest()
    if mutate_manifest: mutate_manifest(manifest)
    manifest_path.write_text(json.dumps(manifest),encoding="utf-8")
    return sample_path,manifest_path,pipeline_path


def test_valid_frozen_150_record_package_passes():
    assert len(package().items) == 150


def test_149_records_fails(tmp_path):
    paths=altered_package_files(tmp_path,lambda x:x.pop())
    with pytest.raises(subject.ImportValidationError,match="expected 150"): package(*paths)


def test_duplicate_dictionary_id_fails(tmp_path):
    paths=altered_package_files(tmp_path,lambda x:x[1].update(dictionary_entry_id=x[0]["dictionary_entry_id"]))
    with pytest.raises(subject.ImportValidationError,match="duplicate dictionary_entry_id"): package(*paths)


def test_missing_dictionary_id_fails(tmp_path):
    paths=altered_package_files(tmp_path,lambda x:x[0].update(dictionary_entry_id=""))
    with pytest.raises(subject.ImportValidationError,match="missing dictionary_entry_id"): package(*paths)


def test_duplicate_item_number_fails(tmp_path):
    paths=altered_package_files(tmp_path,lambda x:x[1].update(sample_sequence=1))
    with pytest.raises(subject.ImportValidationError,match="duplicate item number"): package(*paths)


def test_wrong_item_order_fails(tmp_path):
    paths=altered_package_files(tmp_path,lambda x:x.reverse())
    with pytest.raises(subject.ImportValidationError,match="item numbers/order"): package(*paths)


def test_missing_pipeline_snapshot_fails(tmp_path):
    identifier=rows(SAMPLE)[0]["dictionary_entry_id"]
    paths=altered_package_files(tmp_path,mutate_pipeline=lambda x:x.__setitem__(slice(None),[r for r in x if r["dictionary_entry_id"]!=identifier]))
    with pytest.raises(subject.ImportValidationError,match="no matching Pipeline result"): package(*paths)


def test_pipeline_version_mismatch_fails(tmp_path):
    identifier=rows(SAMPLE)[0]["dictionary_entry_id"]
    def mutate(values): next(r for r in values if r["dictionary_entry_id"]==identifier)["evidence"]["pipeline_version"]="bad"
    paths=altered_package_files(tmp_path,mutate_pipeline=mutate)
    with pytest.raises(subject.ImportValidationError,match="pipeline version mismatch"): package(*paths)


def test_evidence_schema_mismatch_fails(tmp_path):
    paths=altered_package_files(tmp_path,mutate_manifest=lambda x:x.update(evidence_schema_version="bad"))
    with pytest.raises(subject.ImportValidationError,match="evidence schema mismatch"): package(*paths)


def test_source_artifact_hash_mismatch_fails(tmp_path):
    paths=altered_package_files(tmp_path,mutate_manifest=lambda x:x.update(source_artifact_hash="0"*64))
    with pytest.raises(subject.ImportValidationError,match="source artifact hash mismatch"): package(*paths)


def test_non_luwanga_record_fails(tmp_path):
    paths=altered_package_files(tmp_path,lambda x:x[0].update(dialect="Other"))
    with pytest.raises(subject.ImportValidationError,match="not Luwanga"): package(*paths)


def test_human_annotation_leakage_fails(tmp_path):
    paths=altered_package_files(tmp_path,lambda x:x[0].update(reviewer_decision="ACCEPT_SIMPLE"))
    with pytest.raises(subject.ImportValidationError,match="human annotation data"): package(*paths)


class FakeCursor:
    def __init__(self): self.query=""; self.row=0
    def __enter__(self): return self
    def __exit__(self,*args): return False
    def execute(self,query,params=None): self.query=query
    def fetchall(self): return [("dialect-id",)] if "dialects" in self.query else []
    def fetchone(self):
        if "evaluation_studies WHERE study_key" in self.query: return ("active",)
        return (0,)*8


class FakeConnection:
    def cursor(self): return FakeCursor()


def test_existing_study_key_prevents_duplicate_import():
    with pytest.raises(subject.ImportValidationError,match="already exists"):
        subject.validate_remote_state(FakeConnection(),package())


def test_snapshot_hashing_is_deterministic():
    assert subject.snapshot_hash({"b":2,"a":"é"}) == subject.snapshot_hash({"a":"é","b":2})


def test_same_package_produces_same_hashes():
    assert [(i.source_hash,i.pipeline_hash) for i in package().items] == [(i.source_hash,i.pipeline_hash) for i in package().items]


def test_different_snapshot_produces_different_hash():
    assert subject.snapshot_hash({"a":1}) != subject.snapshot_hash({"a":2})


def test_dry_run_manifest_is_zero_write(tmp_path):
    output=tmp_path/"manifest.json"; p=package(); subject.write_manifest(output,p)
    result=json.loads(output.read_text(encoding="utf-8"))
    assert result["zero_write_confirmation"] is True and result["item_count"] == 150


def test_execute_requires_exact_confirmation_before_database_use():
    with pytest.raises(subject.ImportValidationError,match="exact"):
        subject.execute_import(object(),package(),"wrong")


def test_snapshots_exclude_reviewer_and_annotation_fields():
    forbidden=set(subject.REVIEW_FIELDS)
    assert all(not forbidden.intersection(i.source_snapshot) and not forbidden.intersection(i.pipeline_snapshot) for i in package().items)


def test_import_sql_does_not_touch_canonical_or_reviewer_tables():
    source=Path(subject.__file__).read_text(encoding="utf-8")
    for table in ("concepts","concept_terms","dictionary_concept_candidates","translations","review_annotations","review_assignments","reviewer_profiles","evaluation_adjudications"):
        assert f"INSERT INTO public.{table}" not in source
