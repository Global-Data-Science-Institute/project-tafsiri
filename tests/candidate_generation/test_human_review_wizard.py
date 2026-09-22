import csv
import json
from pathlib import Path

import pytest

from evaluation.candidate_generation import wizard_app as app


@pytest.fixture
def isolated(tmp_path, monkeypatch):
    source = Path("evaluation/candidate_generation/human_review_001.jsonl")
    monkeypatch.setattr(app, "SOURCE", source)
    monkeypatch.setattr(app, "ANNOTATIONS", tmp_path / "human_review_001_annotations.jsonl")
    monkeypatch.setattr(app, "STATE", tmp_path / "human_review_001_state.json")
    monkeypatch.setattr(app, "BASE", tmp_path)
    return tmp_path, app.load_records()


def complete_annotation(identifier, note=""):
    return app.validate_annotation({
        "dictionary_entry_id": identifier,
        "reviewer_decision": "ACCEPT_SIMPLE",
        "reviewer_concept_label": "Test",
        "reviewer_definition": "Test definition",
        "reviewer_notes": note,
        "pipeline_bucket_correct": "YES",
        "pipeline_ambiguity_correct": "UNSURE",
    }, {identifier})


def test_frozen_source_has_150_unique_records():
    records = app.load_records()
    assert len(records) == 150
    assert len({record["dictionary_entry_id"] for record in records}) == 150


def test_notes_and_state_survive_restart(isolated):
    _, records = isolated
    identifier = records[0]["dictionary_entry_id"]
    annotation = complete_annotation(identifier, "Persistent Luwanga note")
    app.save_annotations({identifier: annotation})
    app.save_state({"reviewer": {"name": "Reviewer"}, "last_index": 36, "started_at": "start", "updated_at": "update"})
    assert app.read_annotations()[identifier]["reviewer_notes"] == "Persistent Luwanga note"
    assert app.read_state()["last_index"] == 36
    assert app.read_state()["reviewer"]["name"] == "Reviewer"


def test_required_completion_validation(isolated):
    _, records = isolated
    identifier = records[0]["dictionary_entry_id"]
    assert not app.completed({"dictionary_entry_id": identifier, "reviewer_decision": "ACCEPT_SIMPLE"})
    assert app.completed(complete_annotation(identifier))


def test_export_exactly_150_and_preserves_ids(isolated):
    base, records = isolated
    annotations = {r["dictionary_entry_id"]: complete_annotation(r["dictionary_entry_id"]) for r in records}
    state = {"reviewer": {"code": "R1"}, "last_index": 149, "started_at": "start", "updated_at": "update"}
    result = app.export_completed(records, annotations, state)
    exported = [json.loads(line) for line in (base / "human_review_001_completed.jsonl").read_text(encoding="utf-8").splitlines()]
    csv_rows = list(csv.DictReader((base / "human_review_001_completed.csv").open(encoding="utf-8", newline="")))
    assert len(exported) == len(csv_rows) == 150
    assert [r["dictionary_entry_id"] for r in exported] == [r["dictionary_entry_id"] for r in records]
    assert len(result["files"]) == 3


def test_export_refuses_incomplete(isolated):
    _, records = isolated
    with pytest.raises(ValueError, match="incomplete"):
        app.export_completed(records, {}, {})


def test_export_creates_versioned_backup(isolated):
    _, records = isolated
    annotations = {r["dictionary_entry_id"]: complete_annotation(r["dictionary_entry_id"]) for r in records}
    app.export_completed(records, annotations, {})
    result = app.export_completed(records, annotations, {})
    assert len(result["backups"]) == 3
    assert all(Path(path).exists() for path in result["backups"])


def test_start_over_backup_primitive(isolated):
    _, records = isolated
    identifier = records[0]["dictionary_entry_id"]
    app.save_annotations({identifier: complete_annotation(identifier)})
    backup = app.versioned_backup(app.ANNOTATIONS)
    assert backup and backup.exists()
    assert backup.read_bytes() == app.ANNOTATIONS.read_bytes()


def test_no_external_dependencies_or_supabase_calls():
    static = Path("evaluation/candidate_generation/wizard")
    content = "\n".join(path.read_text(encoding="utf-8") for path in static.iterdir() if path.is_file()).casefold()
    server = Path("evaluation/candidate_generation/wizard_app.py").read_text(encoding="utf-8").casefold()
    assert "supabase" not in content
    assert "https://" not in content
    assert "http://" not in content
    assert "urllib.request" not in server
    assert "import requests" not in server
    assert "supabase" not in server


def test_wizard_uses_single_active_record_renderer():
    script = Path("evaluation/candidate_generation/wizard/app.js").read_text(encoding="utf-8")
    assert "const r=data.records[index]" in script
    assert "Record ${index+1} of 150" in script
    assert "Save & Next" in script
    assert "Next Unreviewed" in script
