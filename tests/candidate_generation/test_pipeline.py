import json

import pytest

from scripts.candidate_generation.ambiguity import analyze_ambiguity
from scripts.candidate_generation.bucket import classify
from scripts.candidate_generation.cli import generate
from scripts.candidate_generation.concept_keys import lookup_concept_key
from scripts.candidate_generation.corpus_index import CorpusIndex
from scripts.candidate_generation.export import build_summary, export_all
from scripts.candidate_generation.extract import ReadOnlySupabaseClient
from scripts.candidate_generation.models import DictionaryEntry, RunMetadata

from .conftest import entry


def classify_one(item, entries, config):
    index = CorpusIndex(entries)
    signals = index.signals_for(item)
    ambiguity = analyze_ambiguity(item, signals, config)
    return classify(item, signals, ambiguity, config), ambiguity


def test_normal_bucket_a(config):
    item = entry("1", "ameno", "teeth")
    result, _ = classify_one(item, [item], config)
    assert result.bucket == "A" and result.mapping_status == "proposed"


def test_bucket_a_without_concept_key(config):
    item = entry("1", "amachere", "leprosy")
    result, _ = classify_one(item, [item], config)
    assert result.bucket == "A"
    assert lookup_concept_key(item, config) is None


def test_bucket_b_broad_gloss(config):
    item = entry("1", "abundu", "place")
    result, _ = classify_one(item, [item], config)
    assert result.bucket == "B"


def test_repeated_lexical_form(config):
    rows = [entry("1", "ingwe", "leopard"), entry("2", "ingwe", "a plant")]
    for item in rows:
        result, ambiguity = classify_one(item, rows, config)
        assert result.bucket == "C"
        assert result.mapping_status == "needs_split"
        assert ambiguity.action == "polysemy"


@pytest.mark.parametrize(("definition", "flag"), [
    ("navel; debt", "semicolon_segments"),
    ("navel/debt", "slash_segments"),
    ("river bank or financial bank", "standalone_or"),
    ("blood, especially used for food", "contextual_language"),
])
def test_ambiguity_markers(config, definition, flag):
    item = entry("1", "test", definition)
    result, ambiguity = classify_one(item, [item], config)
    assert result.bucket == "C"
    assert flag in ambiguity.indicators


def test_incompatible_pos_reuse(config):
    rows = [entry("1", "amabeere", "milk", "n."), entry("2", "okhushera", "milk", "v.tr.")]
    for item in rows:
        result, ambiguity = classify_one(item, rows, config)
        assert result.bucket == "C"
        assert "incompatible_pos_reuse" in ambiguity.indicators


def test_registry_lookup_and_unknown(config):
    assert lookup_concept_key(entry("1", "ameno", "teeth"), config)["concept_key"] == "BODY_TEETH"
    assert lookup_concept_key(entry("2", "unknown", "leprosy"), config) is None


def test_deterministic_confidence_and_cap(config):
    item = entry("1", "ameno", "teeth", noun_class="cl. 6")
    first, _ = generate([item], [], config)
    second, _ = generate([item], [], config)
    assert first[0].confidence == second[0].confidence
    assert first[0].confidence <= 0.99


def test_evidence_serialization(config):
    item = entry("1", "ameno", "teeth")
    candidates, _ = generate([item], [], config)
    payload = json.loads(json.dumps(candidates[0].to_dict()))
    assert payload["concept_id"] is None
    assert payload["mapping_source"] == "rule_based"
    assert payload["evidence"]["proposal"]["confidence_is_calibrated_probability"] is False


def test_known_fixture_classification(config, known_entries):
    candidates, _ = generate(known_entries, [], config)
    by_id = {item.dictionary_entry_id: item for item in candidates}
    assert by_id["01"].evidence["classification"]["bucket"] == "A"
    assert by_id["02"].mapping_status == "proposed"
    assert by_id["03"].mapping_status == "proposed"
    for identifier in ("04", "05", "06", "07", "08", "09"):
        assert by_id[identifier].mapping_status == "needs_split"
        assert by_id[identifier].evidence["classification"]["ambiguity_action"] == "polysemy"


def test_deterministic_output(config, known_entries, tmp_path):
    candidates, index = generate(list(reversed(known_entries)), [], config)
    metadata = RunMetadata("0.1.0", "pipeline-001-evidence-v1", config.config_hash, "fixed", len(candidates))
    summary = build_summary(candidates, metadata, index.repeated_form_group_count, [])
    first = tmp_path / "first"; second = tmp_path / "second"
    export_all(first, candidates, summary, False)
    export_all(second, candidates, summary, False)
    for name in ("pipeline_001.jsonl", "pipeline_001.csv", "pipeline_001-summary.json"):
        assert (first / name).read_bytes() == (second / name).read_bytes()


def test_overwrite_local_safeguard(config, known_entries, tmp_path):
    candidates, index = generate(known_entries, [], config)
    metadata = RunMetadata("0.1.0", "pipeline-001-evidence-v1", config.config_hash, "fixed", len(candidates))
    summary = build_summary(candidates, metadata, index.repeated_form_group_count, [])
    export_all(tmp_path, candidates, summary, False)
    with pytest.raises(FileExistsError):
        export_all(tmp_path, candidates, summary, False)
    export_all(tmp_path, candidates, summary, True)


def test_no_database_write_api_exists():
    forbidden = {"insert", "upsert", "update", "delete", "rpc", "execute", "sql"}
    public_names = {name.casefold() for name in dir(ReadOnlySupabaseClient) if not name.startswith("_")}
    assert forbidden.isdisjoint(public_names)


def test_every_candidate_keeps_concept_id_null(config, known_entries):
    candidates, _ = generate(known_entries, [], config)
    assert all(item.concept_id is None for item in candidates)
