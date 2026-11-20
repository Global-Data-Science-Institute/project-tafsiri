"""Direct-DB lexical research CLI. Dry-run by default; credentials stay in libpq.

Use PGSERVICE/PGPASSFILE for a separately provisioned individual database login.
No service key, user UUID, JWT, or session setting can supply approval identity.
This script does not provision accounts, migrate databases or grant authority.
"""
import argparse
import json
from pathlib import Path
import subprocess


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def build_sql(action, proposal=None, manifest=None, decision=None, commit=False):
    if action != "dry_run" and action != "inspect" and not commit:
        raise ValueError("State-changing actions require --commit")
    if manifest is not None:
        if action not in ("create", "dry_run"):
            raise ValueError("--manifest is only valid for create or dry_run")
        proposal = manifest["id"]
        create = "SELECT lexical_governance.create_proposal(" + literal(json.dumps(manifest)) + "::jsonb);\n"
    else:
        create = ""
    if not proposal:
        raise ValueError("--proposal or --manifest is required")
    if action == "create" and manifest is None:
        raise ValueError("create requires --manifest")
    command = "" if action == "create" else (
        "SELECT lexical_governance.command(" + literal(proposal) + "::uuid," + literal(action)
        + "," + literal(json.dumps(decision or {})) + "::jsonb);\n"
    )
    # Commit structured failures from mutation commands to retain failure audits.
    # Both inspect and dry_run roll back, including temporary draft proposals.
    return "BEGIN ISOLATION LEVEL READ COMMITTED;\nSET LOCAL standard_conforming_strings=on;\n" + create + command + (
        "COMMIT;" if commit and action not in ("dry_run", "inspect") else "ROLLBACK;"
    )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action", default="dry_run", choices=["dry_run", "inspect", "create", "submit", "review", "approve", "execute", "reject", "withdraw", "dispute"])
    parser.add_argument("--proposal")
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--decision", type=Path)
    parser.add_argument("--commit", action="store_true")
    args = parser.parse_args(argv)
    try:
        sql = build_sql(args.action, args.proposal,
                        json.loads(args.manifest.read_text(encoding="utf-8")) if args.manifest else None,
                        json.loads(args.decision.read_text(encoding="utf-8")) if args.decision else None,
                        args.commit)
    except (ValueError, KeyError) as exc:
        parser.error(str(exc))
    process = subprocess.run(["psql", "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-v", "standard_conforming_strings=on"],
                             input=sql, text=True, encoding="utf-8", capture_output=True)
    if process.returncode:
        print(process.stderr)
        return process.returncode
    print(process.stdout.strip())
    for line in process.stdout.splitlines():
        if line.startswith("{") and json.loads(line).get("ok") is False:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
