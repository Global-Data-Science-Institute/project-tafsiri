# ADR-MULTI-004: Govern cross-language semantic relationships

Date: 2026-11-19. Status: direction accepted in the project brief; implementation subject to the linked design and migration reviews.

## Context

Concepts may be shared, but a gloss match is not proof of interchangeable meanings.

## Decision

Retain optional reviewed sense-to-concept mappings. Cross-language relationships require endpoint-qualified review, evidence, rationale, context and dispute history. Cognates/borrowings remain separate identities.

## Alternatives and consequences

Reject English-as-universal-semantics and automatic translation equivalence. One current verified concept per sense remains the foundation constraint; richer sense relations require a later reviewed extension.

## Acceptance

Two senses sharing a concept do not automatically generate a translation pair or training example; partial/uncertain relationships remain unapproved.

See the [architecture amendment](../../research/multilingual-architecture-amendment-001.md), [audit](../../research/multilingual-readiness-audit-001.md) and [validation matrix](../../research/multilingual-compatibility-validation-001.md). Next: [ADR-MULTI-005](adr-multilingual-005-reviewer-authority.md).
