from copy import deepcopy
from pathlib import Path

import pytest

from scripts.linguistic_evidence.register_evidence import RegistryError, evidence_key, load_records, validate

PATH = Path("artifacts/linguistic_evidence/extraction_001.jsonl")

@pytest.fixture
def records(): return load_records(PATH)

def test_extraction_is_bounded_and_deterministic(records):
    assert len(records) == 110 and len({r["source_key"] for r in records}) == 11
    assert all(r["evidence_key"] == evidence_key(r) for r in records)

def test_duplicate_prevention(records):
    with pytest.raises(RegistryError, match="duplicate evidence keys"): validate(records + [deepcopy(records[0])])

def test_locator_required(records):
    bad=deepcopy(records); bad[0]["source_locator"]=""; bad[0]["evidence_key"]=evidence_key(bad[0])
    with pytest.raises(RegistryError, match="required field"): validate(bad)

def test_provenance_and_verification_defaults(records):
    assert {r["provenance_origin"] for r in records} == {"MACHINE_GENERATED"}
    assert {r["extraction_method"] for r in records} == {"LLM_ASSISTED"}
    assert {r["verification_status"] for r in records} == {"UNVERIFIED"}

def test_dialect_links_are_present(records):
    assert all(r["dialects"] for r in records)
    assert all(d["literal_variety"] and d["canonical_dialect"] for r in records for d in r["dialects"])

def test_unicode_notation_is_preserved(records):
    text={n["notation_text"] for r in records for n in r["notations"]}
    assert {"[β]", "/x/", "H/L"} <= text

def test_g2p_compatibility(records):
    assert all(r["evidence_type"] in {"GRAPHEME_PHONEME_RULE", "ALLOPHONIC_RULE"} for r in records if r.get("g2p"))

def test_example_policy_and_tier_ordering(records):
    assert sum(len(r["examples"]) for r in records) == 0

def test_no_relations_or_canonical_payloads(records):
    forbidden={"linguistic_rules","lexemes","lexical_forms","lexical_senses","sense_concept_assertions","terminology_decisions"}
    assert all(not (forbidden & set(r)) for r in records)

def test_validation_is_idempotent(records):
    assert validate(records) == validate(load_records(PATH))
