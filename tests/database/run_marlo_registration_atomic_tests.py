"""Local Postgres integration checks for Marlo Registration 001 atomicity."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from scripts.source_registry import prepare_marlo_registration as registration  # noqa: E402

CONTAINER = "supabase_db_project-tafsiri"


def psql(sql: str, expect_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-At"],
        input=sql, text=True, encoding="utf-8", capture_output=True, check=False,
    )
    if (result.returncode == 0) != expect_success:
        raise AssertionError(f"unexpected psql result {result.returncode}: {result.stdout}\n{result.stderr}")
    return result


def counts() -> str:
    return psql("SELECT concat_ws(',',(SELECT count(*) FROM sources),(SELECT count(*) FROM source_versions),(SELECT count(*) FROM source_artifacts),(SELECT count(*) FROM source_version_artifacts),(SELECT count(*) FROM source_artifact_acquisitions),(SELECT count(*) FROM source_rights),(SELECT count(*) FROM source_use_policies),(SELECT count(*) FROM source_artifact_sets),(SELECT count(*) FROM source_artifact_set_members));").stdout.strip()


def main() -> None:
    manifest = json.loads(registration.MANIFEST_PATH.read_text(encoding="utf-8"))
    baseline = counts()
    atomic = registration.execution_sql(manifest)
    prerequisite_lines = []
    for source in (x for x in manifest["source_actions"] if x["action"] == "REUSE"):
        source_id = registration.stable_id("integration-prerequisite", source["source_key"])
        version = next(x for x in manifest["version_actions"] if x["source_key"] == source["source_key"])
        version_id = registration.stable_id("integration-prerequisite-version", source["source_key"])
        q = registration._sql_literal
        prerequisite_lines.append(
            f"INSERT INTO sources(id,source_key,source_type,title) VALUES ('{source_id}',{q(source['source_key'])},{q(source['source_type'])},{q(source['title'])}) ON CONFLICT (source_key) DO NOTHING;"
        )
        prerequisite_lines.append(
            f"INSERT INTO source_versions(id,source_id,version_key,notes) SELECT '{version_id}',id,{q(version['version_key'])},{q(version['notes'])} FROM sources WHERE source_key={q(source['source_key'])} ON CONFLICT (source_id,version_key) DO NOTHING;"
        )
    prerequisites = "\n".join(prerequisite_lines)
    assertions = """
DO $assert$ BEGIN
 IF (SELECT count(*) FROM source_artifacts WHERE artifact_key LIKE 'ART_SHA256_%') <> 12 THEN RAISE EXCEPTION 'artifact count'; END IF;
 IF (SELECT count(*) FROM source_artifact_acquisitions WHERE acquisition_group_key='MARLO_SOURCE_PACKAGE_2026_001') <> 13 THEN RAISE EXCEPTION 'acquisition count'; END IF;
 IF (SELECT count(*) FROM source_use_policies WHERE policy_version='MARLO_REGISTRATION_001') <> 48 THEN RAISE EXCEPTION 'policy count'; END IF;
END $assert$;
"""
    # Success plus a second execution proves the same statement is idempotent.
    psql("BEGIN;\n" + prerequisites + "\n" + atomic + "\n" + atomic + "\n" + assertions + "\nROLLBACK;")
    assert counts() == baseline

    for point in ("mid", "late"):
        failed = psql("BEGIN;\n" + prerequisites + "\n" + registration.execution_sql(manifest, point), expect_success=False)
        assert "INJECTED" in failed.stderr
        assert counts() == baseline, f"{point} failure left partial rows"

    # A semantic mismatch is rejected and the surrounding transaction rolls back.
    conflict = psql("BEGIN;\n" + prerequisites + "\nUPDATE sources SET title='conflict' WHERE source_key='LUBUKUSU_ENGLISH_DICTIONARY_2008';\n" + atomic, expect_success=False)
    assert "CONFLICT: required source" in conflict.stderr
    assert counts() == baseline
    print("Marlo registration atomic integration checks passed")


if __name__ == "__main__":
    main()
