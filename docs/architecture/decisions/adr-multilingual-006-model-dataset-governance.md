# ADR-MULTI-006: Model and dataset governance

Date: 2026-11-19. Status: direction accepted in the project brief; implementation subject to the linked design and migration reviews.

## Context

Reviewed evidence and canonical knowledge are not training licenses or proven model quality.

## Decision

Require immutable provenance-rich dataset manifests, explicit rights and consent checks, leakage-controlled splits, reproducible experiment records and independent release decisions.

## Alternatives and consequences

Reject automatic training export from imported/reviewed data and premature production model selection. Start with approved Luwanga research; no new training orchestration now.

## Acceptance

Unknown/expired training permission blocks export; evaluation artifacts remain held out; a model without scope-specific validation cannot be released for that scope.

See the [architecture amendment](../../research/multilingual-architecture-amendment-001.md), [audit](../../research/multilingual-readiness-audit-001.md) and [validation matrix](../../research/multilingual-compatibility-validation-001.md). Next: [ADR-MULTI-007](adr-multilingual-007-research-commercial-boundary.md).
