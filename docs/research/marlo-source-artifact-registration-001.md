# Michael Marlo Source & Artifact Registration 001

This document records the zero-write registration plan derived from `config/sources/marlo_source_intake_001.json`. The persistence proposal is stored separately in `config/sources/marlo_source_registration_001.json`.

## Scope and safety

The plan reuses the registered Bukusu and Wanga 2008 intellectual works and versions, proposes six new works and versions, and registers exact file bytes through the Migration 010 artifact layer. It creates no import batch, source entry, lexical record, linguistic rule, dialect mapping, application user, or reviewer authority.

The utility `scripts/source_registry/prepare_marlo_registration.py` defaults to dry-run. Staging execution requires `--execute` and an exact `--confirm-project-ref`. Production additionally requires `--production-approved-registration-001`. Execution also requires a service-role URL and key matching the selected project. No execution mode was used during Registration 001 planning.

## Proposed registration

- Reuse two sources and two versions: `LUBUKUSU_ENGLISH_DICTIONARY_2008/DRAFT_2008_09_01` and `WANGA_ENGLISH_DICTIONARY_2008/PRELIMINARY_DRAFT_2008`.
- Create six sources and six versions for Appleby 1943, Friends 1940, Ndanyi & Ndanyi 2005, and the Luyia, Idakho, and Tura/Lutura workbooks.
- Register 12 unique SHA-256 artifact identities from 13 physical files.
- Create 12 version-artifact associations using `RECEIVED_COPY`.
- Preserve all 13 filenames as acquisitions in group `MARLO_SOURCE_PACKAGE_2026_001`.
- Create one `MULTIPART_DOCUMENT` set with five ordered Ndanyi members.
- Create six `UNKNOWN` rights records and 48 `UNKNOWN` policies across the eight governed use scopes.
- Create zero location rows until durable portable archive references are verified.
- Defer package-level contact events because the current table requires a source or version and duplicating the same correspondence across eight sources would misrepresent the event model.

## Identity and preferred representation

Artifact keys use `ART_SHA256_<24 uppercase hexadecimal characters>`, derived from exact content rather than filenames. The two Part 5 filenames resolve to the same artifact and separate acquisition identities.

The supplied Bukusu and Wanga files are proposed as preferred Tafsiri processing/reference representations because Migration 010 currently has no artifact rows. This preference carries no linguistic, canonical, copyright, or licensing authority. The four new single-artifact works also use a preferred representation. No Ndanyi component is individually preferred because all five components jointly represent the version.

The legacy `source_versions.checksum` and `checksum_algorithm` values remain `NULL`. Exact binary identity belongs to `source_artifacts`, particularly for multipart works and alternate binaries.

## Provider and correspondence

Acquisitions use the supported descriptive fallback `provider_name = Professor Michael R. Marlo`. No matching contributor exists in staging or production. The current recommendation is **USE PROVIDER_NAME FOR NOW**. A contributor identity should be considered later through governed onboarding if Professor Marlo participates in evidence review; source provision alone grants no reviewer or canonical authority.

The reviewed dates are retained as deferred package events without private email text:

- material provision: 2026-04-14
- collaboration contact: 2026-09-25
- Tafsiri reply: 2026-09-27

## Linguistic boundaries

Raw labels remain preserved in the intake and registration manifests. Registration creates no canonical dialect assertions. Tura/Lutura and Luragoli/Logoori/Lulogooli mappings remain unresolved pending expert confirmation. `Idakho_1` and `Idakho_2` remain distinct source columns. Workbook rows remain source-provided correspondences and do not become canonical equivalence claims.

## Dry-run result

Staging and production each resolve to 109 `CREATE`, four `REUSE`, and zero `CONFLICT` actions. Both report zero existing artifact-layer rows, zero import batches, zero source entries, and four unchanged canonical linguistic rules. The normalized semantic digest is:

`309bf88061db30cdd3fcc1e48c49c00ac4fa464db97aea969710cf4f7802a863`

No database write was executed.
