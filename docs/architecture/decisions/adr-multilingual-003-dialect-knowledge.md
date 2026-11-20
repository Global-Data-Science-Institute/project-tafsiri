# ADR-MULTI-003: Preserve dialect-specific knowledge

Date: 2026-11-19. Status: direction accepted in the project brief; implementation subject to the linked design and migration reviews.

## Context

Similar strings and shared sources can conceal different meaning, tone, morphology, register or usage.

## Decision

Default to separate lexical identities for distinct varieties. Preserve exact source forms and reviewed form/sense restrictions; comparison links are explicit claims.

## Alternatives and consequences

Reject synthetic generalized Luhya vocabulary and global spelling uniqueness. No automatic Wanga/Luwanga merge; unresolved labels stay unresolved.

## Acceptance

Identical forms in different varieties and homographs within one variety coexist. Normalization never overwrites original text.

See the [architecture amendment](../../research/multilingual-architecture-amendment-001.md), [audit](../../research/multilingual-readiness-audit-001.md) and [validation matrix](../../research/multilingual-compatibility-validation-001.md). Next: [ADR-MULTI-004](adr-multilingual-004-cross-language-semantics.md).
