# ADR-MULTI-001: Single reusable research pipeline

Date: 2026-11-19. Status: direction accepted in the project brief; implementation subject to the linked design and migration reviews.

## Context

Existing source, evidence, review and canonical governance already provide auditable boundaries. Separate language implementations would diverge in permissions and provenance.

## Decision

Extend the existing stages through versioned language configuration and typed scope metadata. Reuse existing registration, review and promotion services; adapters may differ by source format but target the same contracts.

## Alternatives and consequences

Reject a pipeline or database fork per language. Preserve frozen Pipeline 001 configuration and artifacts; new profiles require reproducibility and scope tests.

## Acceptance

A second hypothetical language must traverse the same source-entry, evidence and approval boundaries; unsupported profiles fail closed.

See the [architecture amendment](../../research/multilingual-architecture-amendment-001.md), [audit](../../research/multilingual-readiness-audit-001.md) and [validation matrix](../../research/multilingual-compatibility-validation-001.md). Next: [ADR-MULTI-002](adr-multilingual-002-language-variety-identity.md).
