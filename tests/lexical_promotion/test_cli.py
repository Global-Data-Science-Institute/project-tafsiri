"""CLI transaction boundaries and quoting; authorization is tested in PostgreSQL."""
import runpy
from pathlib import Path

import pytest

CLI = runpy.run_path(str(Path(__file__).resolve().parents[2] / "scripts/lexical_promotion/promote.py"))


@pytest.mark.parametrize("action", ["create", "submit", "review", "approve", "execute", "reject", "withdraw", "dispute"])
def test_mutations_require_explicit_commit(action):
    with pytest.raises(ValueError, match="--commit"):
        CLI["build_sql"](action, "00000000-0000-0000-0000-000000000001")


@pytest.mark.parametrize("action", ["dry_run", "inspect"])
def test_read_actions_rollback_even_with_commit(action):
    sql = CLI["build_sql"](action, "00000000-0000-0000-0000-000000000001", commit=True)
    assert sql.endswith("ROLLBACK;")


def test_manifest_preview_rolls_back_draft_and_all_outputs():
    sql = CLI["build_sql"]("dry_run", manifest={"id": "fixture", "text": "quote'\\; $(); --"})
    assert sql.index("SET LOCAL standard_conforming_strings=on") < sql.index("create_proposal")
    assert "quote''\\\\; $(); --" in sql
    assert "create_proposal" in sql and "'dry_run'" in sql and sql.endswith("ROLLBACK;")


def test_mutation_commits_structured_failure_audit():
    assert CLI["build_sql"]("execute", "fixture", commit=True).endswith("COMMIT;")


def test_manifest_cannot_be_implicitly_created_during_approval():
    with pytest.raises(ValueError, match="only valid"):
        CLI["build_sql"]("approve", manifest={"id": "fixture"}, commit=True)
