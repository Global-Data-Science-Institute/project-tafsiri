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
    with pytest.raises(pilot.PilotError, match="staging-only"):
        pilot.main(["--execute", "--confirm-project-ref", pilot.PRODUCTION_REF])


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


def test_execution_is_one_transaction_without_privileged_function() -> None:
    sql = pilot.execution_sql(pilot.load_and_validate())
    assert sql.startswith("DO $pilot$")
    assert sql.rstrip().endswith("$pilot$;")
    assert sql.count("DO $pilot$") == 1
    assert "CREATE FUNCTION" not in sql.upper()
    assert "SECURITY DEFINER" not in sql.upper()
