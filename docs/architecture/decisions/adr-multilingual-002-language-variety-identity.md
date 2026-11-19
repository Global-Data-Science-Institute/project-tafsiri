# ADR-MULTI-002: Language and variety identity

Date: 2026-11-19. Status: direction accepted in the project brief; implementation subject to the linked design and migration reviews.

## Context

The repository already has languages, dialects and aliases; dialects.language_id is nullable and classification can be contested.

## Decision

Retain UUIDs and existing associations. Add governed classification/name/code/orthography metadata around those identities. A variety-scoped lexical identity does not require a settled language parent.

## Alternatives and consequences

Reject a replacement registry and a mandatory universal parent tree. Classification assertions can compete; alias lookup and language-family membership confer neither identity equivalence nor authority.

## Acceptance

A parent-ambiguous variety can retain evidence and its own lexemes; conflicting classifications coexist without rewriting existing Luhya IDs.

See the [architecture amendment](../../research/multilingual-architecture-amendment-001.md), [audit](../../research/multilingual-readiness-audit-001.md) and [validation matrix](../../research/multilingual-compatibility-validation-001.md). Next: [ADR-MULTI-003](adr-multilingual-003-dialect-knowledge.md).

