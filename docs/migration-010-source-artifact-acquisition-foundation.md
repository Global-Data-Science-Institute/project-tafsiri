# Migration 010 — Source Artifact & Acquisition Foundation

Migration file: `20260928015644_create_source_artifact_foundation.sql`.

## Scope

Migration 010 implements the approved Source Artifact & Acquisition Architecture 001 without registering data. It adds six deny-by-default governance tables:

- `source_artifacts`
- `source_version_artifacts`
- `source_artifact_acquisitions`
- `source_artifact_locations`
- `source_artifact_sets`
- `source_artifact_set_members`

It also adds nullable `source_import_batches.source_artifact_id`. Existing Migration 006 artifact snapshot fields remain unchanged, and no historical batch is backfilled.

## Final implementation decisions

Artifact identity is globally unique by normalized `(checksum_algorithm, checksum)`. Migration 010 initially accepts only `SHA256` and rejects any digest that is not exactly 64 lowercase hexadecimal characters. `checksum_algorithm`, `checksum`, `byte_size`, and `media_type` are protected by a narrowly scoped `SECURITY INVOKER` trigger with an empty search path and no client execution privilege.

Artifact status is limited to `REGISTERED` and `QUARANTINED`. Availability belongs to artifact locations, so `AVAILABLE` and `MISSING` are not artifact identity states. Copyright and allowed uses remain in `source_rights` and `source_use_policies` at source-version level.

The many-to-many `source_version_artifacts` table allows two different Wanga binaries to represent one intellectual version. Its partial unique index permits at most one preferred Tafsiri representation per version. Preferred status grants no canonical, legal, or licensing authority.

Acquisitions preserve repeat receipt and filename aliases without duplicating artifact identity. Direct researcher provision requires either a contributor reference or a nonblank descriptive provider name. Acquisition rows never change rights or use policies.

Locations use portable references and reject Windows absolute paths, POSIX absolute paths, and `file:` URIs. One artifact may have private and public locations, with at most one primary retrieval location.

Artifact sets and members support the five ordered Ndanyi components. Composite foreign keys require every member to be associated with the set's source version. Workbook sections and generalized derivation lineage remain deferred.

Import batches may link to an artifact only through an artifact/version association matching the batch source version. A second guarded check requires the historical batch checksum snapshot to equal the registered artifact checksum while accepting the existing `SHA-256` spelling as equivalent to canonical `SHA256`. Existing batches remain valid with `NULL`; reconciliation requires separately authorized proof by checksum.

## Security

All six tables enable RLS and grant no privileges to `PUBLIC`, `anon`, or `authenticated`. Only `service_role` receives administrative table privileges. The Reviewer Portal receives no access, and no public policy or RPC is created.

## Testing

`tests/database/source_artifact_foundation_smoke.sql` runs in a transaction and rolls back all fixtures. It verifies checksum format and uniqueness, immutable identity fields, alternate binaries, duplicate acquisitions and filenames, provider validation, locations, multipart ordering, batch/version consistency, rights independence, RLS, privileges, and helper-function security.

Migration 010 inserts no source, version, artifact, acquisition, location, set, import, entry, rights, evidence, lexical, reviewer, or canonical-rule data.
