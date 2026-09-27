import hashlib

import pytest

from scripts.linguistic_rules import apply_promotion_pilot as pilot


def test_manifest_is_exact_and_deterministic() -> None:
    manifest = pilot.load_and_validate()
    assert len(manifest["candidates"]) == 4
    assert sum(len(item["conditions"]) for item in manifest["candidates"]) == 2
    for item in manifest["candidates"]:
        normalized = "\n".join(sorted(item["evidence_keys"])).encode("utf-8")
        assert item["evidence_set_checksum"] == hashlib.sha256(normalized).hexdigest()


def test_empty_staging_plan_has_expected_counts() -> None:
    plan = pilot.plan(pilot.load_and_validate(), {"pilot_promotions": [], "pilot_roles": 0})
    assert plan == {
        "rules": 4,
        "revisions": 4,
        "dialect_links": 4,
        "evidence_links": 4,
        "conditions": 2,
        "promotions": 4,
        "outputs": 18,
        "contributor_roles": 1,
        "conflicts": 0,
    }


def test_production_execute_is_refused_before_sql(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(pilot, "linked_ref", lambda: pilot.PRODUCTION_REF)
    monkeypatch.setattr(pilot, "run_sql", lambda _sql: pytest.fail("SQL must not run"))
    with pytest.raises(pilot.PilotError, match=pilot.STAGING_REF):
        pilot.main(["--execute", "--confirm-project-ref", pilot.PRODUCTION_REF])


def test_production_mode_requires_both_guard_and_confirmation(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(pilot, "linked_ref", lambda: pilot.PRODUCTION_REF)
    monkeypatch.setattr(pilot, "run_sql", lambda _sql: pytest.fail("SQL must not run"))
    with pytest.raises(pilot.PilotError, match="confirm-project-ref"):
        pilot.main(["--execute", "--production-approved-pilot-001"])


def test_human_review_artifact_matches_immutable_inputs() -> None:
    manifest = pilot.load_and_validate(require_human_review=True)
    review = pilot.validate_human_review(manifest)
    assert review["approved_rule_count"] == 4
    assert review["runtime_approval"] is False
    assert review["production_promotion_approved"] is True


def test_changed_content_with_existing_key_is_conflict() -> None:
    manifest = pilot.load_and_validate()
    candidate = manifest["candidates"][0]
    state = {
        "pilot_roles": 1,
        "pilot_promotions": [{
            "promotion_key": candidate["promotion_key"],
            "idempotency_key": candidate["idempotency_key"],
            "checksum": candidate["evidence_set_checksum"],
            "statement": "changed semantic content",
            "status": "APPLIED",
        }],
    }
    assert pilot.plan(manifest, state)["conflicts"] == 1


def test_applied_plan_reports_reuse_without_creates() -> None:
    manifest = pilot.load_and_validate()
    state = {
        "conditions": 2,
        "outputs": 18,
        "pilot_roles": 1,
        "pilot_promotions": [{
            "promotion_key": item["promotion_key"],
            "idempotency_key": item["idempotency_key"],
            "checksum": item["evidence_set_checksum"],
            "statement": item["canonical_statement"],
            "status": "APPLIED",
        } for item in manifest["candidates"]],
    }
    result = pilot.plan(manifest, state)
    assert result["rules"] == result["outputs"] == result["conflicts"] == 0
    assert result["rules_reused"] == result["revisions_reused"] == 4
    assert result["conditions_reused"] == 2
    assert result["outputs_reused"] == 18
    assert result["contributor_roles_reused"] == 1


def test_execution_is_one_transaction_without_privileged_function() -> None:
    sql = pilot.execution_sql(pilot.load_and_validate())
    assert sql.startswith("DO $pilot$")
    assert sql.rstrip().endswith("$pilot$;")
    assert sql.count("DO $pilot$") == 1
    assert "CREATE FUNCTION" not in sql.upper()
    assert "SECURITY DEFINER" not in sql.upper()


def test_production_sql_records_reviewed_bounded_rationale() -> None:
    manifest = pilot.load_and_validate(require_human_review=True)
    sql = pilot.execution_sql(manifest, production=True, human_review=pilot.validate_human_review(manifest))
    assert "verified in staging" in sql
    assert "no runtime approval is granted" in sql
    assert "production transaction" in sql
