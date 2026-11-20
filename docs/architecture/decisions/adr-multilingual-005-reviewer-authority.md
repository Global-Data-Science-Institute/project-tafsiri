# ADR-MULTI-005: Language-specific reviewer authority

Date: 2026-11-19. Status: direction accepted in the project brief; implementation subject to the linked design and migration reviews.

## Context

Current study participation and dialect expertise already constrain assignments; self-report is not verified authority.

## Decision

Extend the same portal with approved, revocable, task-scoped qualifications and exact study/item scope enforcement in server and database. Preserve frozen HE001 behavior until its reviewed compatibility transition.

## Alternatives and consequences

Reject language-family inheritance, browser-only filtering and automatic grants from self-report. Contributor canonical approvers and reviewers remain distinct authorities.

## Acceptance

An assigned Luwanga reviewer cannot access another-language item by UUID. Revocation is enforced on reads/writes, and Stage A stays blinded.

See the [architecture amendment](../../research/multilingual-architecture-amendment-001.md), [audit](../../research/multilingual-readiness-audit-001.md) and [validation matrix](../../research/multilingual-compatibility-validation-001.md). Next: [ADR-MULTI-006](adr-multilingual-006-model-dataset-governance.md).
