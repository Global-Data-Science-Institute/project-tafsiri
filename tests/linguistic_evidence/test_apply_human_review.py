from copy import deepcopy

import pytest

from scripts.linguistic_evidence.apply_human_review import ReviewClient, load_review, resolve_reviewer
from scripts.source_registry.register_sources import RegistryError


class FakeClient:
    def __init__(self, contributors): self.contributors=contributors; self.inserted=[]
    def select(self, table, filters): return self.contributors if table == "contributors" else []
    def insert(self, table, row):
        self.inserted.append((table,row)); return {"id":"new-reviewer",**row}


def manifest():
    return {"reviewer":{"name":"Dr. Moody Amakobe","email":"moody.amakobe@gdsi.institute"}}


def test_review_artifacts_target_exact_batch():
    review,evidence,decisions=load_review()
    assert review["reviewed_evidence_count"] == len(evidence) == len(decisions) == 110
    assert {d["evidence_key"] for d in decisions} == {e["evidence_key"] for e in evidence}


def test_every_decision_is_verified():
    _,_,decisions=load_review(); assert {d["reviewer_decision"] for d in decisions} == {"VERIFIED"}


def test_contributor_created_once_when_absent():
    client=FakeClient([]); row,action=resolve_reviewer(client,manifest(),True)
    assert action == "created" and row["id"] == "new-reviewer" and len(client.inserted) == 1


def test_contributor_reused_by_normalized_email():
    existing={"id":"reviewer","name":"Dr. Moody Amakobe","email":" MOODY.AMAKOBE@GDSI.INSTITUTE "}
    row,action=resolve_reviewer(FakeClient([existing]),manifest(),False)
    assert action == "reused" and row["id"] == "reviewer"


def test_duplicate_contributor_is_rejected():
    rows=[{"id":str(i),"name":"Dr. Moody Amakobe","email":"moody.amakobe@gdsi.institute"} for i in range(2)]
    with pytest.raises(RegistryError,match="multiple contributors"): resolve_reviewer(FakeClient(rows),manifest(),False)


def test_conflicting_identity_is_rejected():
    rows=[{"id":"x","name":"Another Person","email":"moody.amakobe@gdsi.institute"}]
    with pytest.raises(RegistryError,match="conflicting name"): resolve_reviewer(FakeClient(rows),manifest(),False)


def test_provenance_is_preserved_in_extraction():
    _,evidence,_=load_review()
    assert {r["provenance_origin"] for r in evidence} == {"MACHINE_GENERATED"}
    assert {r["extraction_method"] for r in evidence} == {"LLM_ASSISTED"}


def test_review_timestamp_and_reviewer_are_required():
    review,_,_=load_review()
    assert review["review_completed_at"].endswith("Z")
    assert review["reviewer"]["name"] and review["reviewer"]["email"]


def test_update_guard_allows_only_review_metadata():
    class Inner: pass
    with pytest.raises(RegistryError,match="non-review fields"):
        ReviewClient(Inner()).update_evidence("id",{"verification_status":"VERIFIED","summary":"changed"})


def test_review_payload_has_no_canonical_writes():
    _,evidence,_=load_review()
    forbidden={"linguistic_rules","lexemes","lexical_forms","lexical_senses","sense_concept_assertions","terminology_decisions"}
    assert all(not (forbidden & set(row)) for row in evidence)
