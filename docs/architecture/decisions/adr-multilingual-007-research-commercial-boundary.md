# ADR-MULTI-007: Separate research and commercial serving

Date: 2026-11-19. Status: direction accepted in the project brief; implementation subject to the linked design and migration reviews.

## Context

Private source and reviewer data must not become customer-facing dependencies.

## Decision

Commercial systems consume approved versioned release artifacts through a controlled handoff, using separate credentials, storage, operational roles and tenant isolation. Commercial clearance and production approval are separate.

## Alternatives and consequences

Reject direct privileged research queries, research-only asset serving, automatic feedback promotion and payment/customer infrastructure during architecture work.

## Acceptance

A research-only checkpoint cannot deploy; tenant access is isolated; a revoked commercial artifact cannot be restored by rollback.

See the [architecture amendment](../../research/multilingual-architecture-amendment-001.md), [audit](../../research/multilingual-readiness-audit-001.md) and [validation matrix](../../research/multilingual-compatibility-validation-001.md).

