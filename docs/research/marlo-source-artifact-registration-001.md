# Michael Marlo Source & Artifact Registration 001

This document records the zero-write registration plan derived from `config/sources/marlo_source_intake_001.json`. The persistence proposal is stored separately in `config/sources/marlo_source_registration_001.json`.

## Scope and safety

The plan reuses the registered Bukusu and Wanga 2008 intellectual works and versions, proposes six new works and versions, and registers exact file bytes through the Migration 010 artifact layer. It creates no import batch, source entry, lexical record, linguistic rule, dialect mapping, application user, or reviewer authority.

The utility `scripts/source_registry/prepare_marlo_registration.py` defaults to dry-run. Staging execution requires `--execute` and an exact `--confirm-project-ref`. Production additionally requires `--production-approved-registration-001`. No execution mode was used during Registration 001 planning.

Execution sends one PostgreSQL `DO` statement through the trusted, linked Supabase CLI. The statement takes a transaction-scoped advisory lock, resolves every manifest identity, rejects semantic conflicts, and creates missing rows. PostgreSQL commits the complete statement on success and rolls back every row on any failure. It creates no stored function, RPC, grant, or RLS change. Repeating the statement reuses the same identities and creates zero additional rows.

Dry-run remains a separate read-only inspection and planning path. Execution is allowed only for the approved semantic digest shown below. Local database integration tests cover successful execution, a second idempotent execution, mid and late injected failures, semantic conflict rejection, and full rollback.

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

## Staging registration

**STAGING REGISTRATION COMPLETE — 2026-09-28**

The approved registration was executed against staging project `gfhdwmqefotkljrltfnx` through the trusted atomic SQL path. The pre-write plan was 109 `CREATE`, four `REUSE`, and zero `CONFLICT`, with semantic digest `309bf88061db30cdd3fcc1e48c49c00ac4fa464db97aea969710cf4f7802a863`. The transaction committed successfully. Its immediate post-write plan was zero `CREATE`, 113 `REUSE`, and zero `CONFLICT`, with the same digest.

Staging now contains 59 sources, 59 versions, 12 artifacts, 12 version-artifact associations, 13 acquisitions, one artifact set, and five ordered set members. The duplicate Ndanyi Part 5 remains one artifact represented by two acquisition records and one set member. Seven associations are preferred representations; none of the five Ndanyi components is individually preferred.

Six new rights rows and 48 new use-policy rows were created. Every new rights status and policy decision is `UNKNOWN`; no `OPEN_LICENSE` right or `ALLOWED` policy was inferred. The existing Bukusu and Wanga sources, versions, rights, and policies were reused without modification.

Production project `ydkookidvipqrwuilqeu` remained read-only and retained its pre-registration baseline. Registration created no artifact locations, contact events, import batches, source entries, dialect assertions, concepts, concept terms, dictionary entries, translations, linguistic evidence, linguistic rules, or promotions. The four existing canonical rules remain `PROVISIONAL`.

Tura/Lutura, Luragoli/Logoori/Lulogooli, and the intended distinction between `Idakho_1` and `Idakho_2` remain unresolved. Permission and durable archive-location questions also remain unresolved. The machine-readable staging execution record is `artifacts/source_registration/marlo_source_registration_001_staging.json`; it contains no private correspondence.

The post-registration Supabase Security and Performance Advisor gate passed. No new Security `ERROR`/`WARN` or Performance `WARN`/`ERROR` finding was attributable to Migration 010 or the Marlo registration. Artifact-layer notices were informational only, and historical findings were unchanged.

## Production registration

**PRODUCTION REGISTRATION COMPLETE — 2026-09-28**

Following human review by Dr. Moody Amakobe, the approved registration was replicated atomically to production project `ydkookidvipqrwuilqeu`. The pre-write plan was 109 `CREATE`, four `REUSE`, and zero `CONFLICT`; the immediate post-write plan was zero `CREATE`, 113 `REUSE`, and zero `CONFLICT`. Both used the approved semantic digest `309bf88061db30cdd3fcc1e48c49c00ac4fa464db97aea969710cf4f7802a863` and match the normalized staging registration.

Production now contains the same 12 artifact identities, 12 version-artifact associations, 13 acquisitions, and ordered five-member Ndanyi artifact set as staging. Six rights rows and 48 use-policy rows were added, all `UNKNOWN`. No open license or allowed-use decision was inferred from direct provision.

This is provenance and artifact registration only. It performed no lexical import and created no source entries, canonical lexical data, linguistic evidence, linguistic rules, promotions, runtime behavior, artifact locations, contact events, or dialect assertions. The four existing canonical rules remain `PROVISIONAL`. Tura/Lutura, Luragoli/Logoori/Lulogooli, `Idakho_1`/`Idakho_2`, workbook row semantics, permissions, and durable archive locations remain unresolved.

The human approval record is `artifacts/source_registration/marlo_source_registration_001_human_review.json`. The production execution record is `artifacts/source_registration/marlo_source_registration_001_production.json`. Neither record contains private correspondence.

The production Supabase Security and Performance Advisor gate passed. No new Security `ERROR`/`WARN` or Performance `WARN`/`ERROR` finding was attributable to the registration or Migration 010 artifact layer. Artifact-layer findings were informational only; unchanged historical production findings remain outside this registration scope.
