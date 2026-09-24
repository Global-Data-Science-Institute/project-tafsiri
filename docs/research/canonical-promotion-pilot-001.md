# Tafsiri Canonical Promotion Pilot 001

## Scope

Pilot 001 applies four governed canonical knowledge records to the staging Supabase project `gfhdwmqefotkljrltfnx`. It does not authorize runtime behavior, public serving, or production promotion. All four rules remain `PROVISIONAL` pending human canonical review.

The approved candidates and exact supporting evidence keys are recorded in `artifacts/linguistic_rules/canonical_promotion_pilot_001.json`. The human review surface is `artifacts/linguistic_rules/canonical_promotion_pilot_001_review.csv`.

## Determinism

Evidence-set checksums are SHA-256 hashes of the UTF-8 bytes of supporting evidence keys sorted lexicographically and joined with a single LF. Each Pilot 001 candidate has one supporting evidence key, so its checksum input has no separator. Promotion, rule, revision, link, condition, output, and authority UUIDs are UUIDv5 values in the utility's fixed Pilot 001 namespace.

The application utility checks the linked project ref, exact contributor identity, active taxonomy rows, canonical dialects, and `VERIFIED` evidence before writing. It applies the authority assignment and all four promotions in one explicit SQL transaction. An error rolls back the entire batch. Existing promotion identities are accepted only when their approved semantic fields match; changed content is rejected as a conflict.

## Usage

```powershell
$env:UV_CACHE_DIR='.uv-cache'
uv run python -m scripts.linguistic_rules.apply_promotion_pilot --validate
uv run python -m scripts.linguistic_rules.apply_promotion_pilot --dry-run
uv run python -m scripts.linguistic_rules.apply_promotion_pilot --execute --confirm-project-ref gfhdwmqefotkljrltfnx
```

Execution against any linked project other than staging is refused. The utility creates no RPC, database function, runtime record, serving projection, public view, policy, or grant.

## Workflow audit

Migration 009 stores the final promotion row rather than separate transition-history rows. Pilot promotions therefore move through `DRAFT`, `READY_FOR_REVIEW`, `APPROVED`, and `APPLIED` inside the same transaction and record that sequence in `transaction_reference`. Each created rule, revision, dialect link, evidence link, and condition is represented by a `CREATED` promotion output.

The bounded `CANONICAL_APPROVER` assignment covers only domain `CANONICAL_PROMOTION_PILOT_001`, begins on 2026-09-24, and ends on 2026-12-31. It grants no Bukusu or Luwanga dialect-specialist status.

## Staging execution verification

Pilot 001 was applied to staging on 2026-09-24. The verified result contains four `PROVISIONAL` rules, four revision-1 records, four `APPLIES_TO` dialect links, four `SUPPORTS` links to `VERIFIED` evidence, two conditions, four `APPLIED` promotions, eighteen `CREATED` outputs, and one bounded contributor-role assignment. Every current revision resolves to revision 1 and has a complete rule-to-source-locator audit chain.

A post-application dry run reported zero creates and zero conflicts for every governed object type. Live negative tests rejected changed semantic content under an existing idempotency key, mutation of an applied revision, a `SUPPORTS` link to non-verified evidence, and both zero and multiple `APPLIES_TO` links when activating a `DIALECT` rule. Test fixtures were removed in the same database statement.

Evidence remained at 110 total and 110 `VERIFIED`, with all provenance and extraction counts unchanged. Sources remained at 53 and use policies at 424. Reviewer and Auth counts remained unchanged. The pilot introduced no runtime table, serving projection, public view, grant, policy, function, or production record. A production read-only check confirmed zero canonical rules, promotions, and contributor-role assignments. The CLI link was restored to staging after that check.
