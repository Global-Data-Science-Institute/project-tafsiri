# Project Tafsiri documentation

This directory documents the repository's current architecture, research controls, and deployment procedures.

## Complete platform blueprint (architecture for review)

Start with the [authoritative reference architecture](architecture/tafsiri-platform-reference-architecture-001.md), which distinguishes deployed foundations, implemented-but-unmerged changes and planned services. This series integrates the earlier ADRs and implementation reports; it does not activate Model Lab or Tafsiri Cloud.

- [Multilingual Reviewer Portal](architecture/tafsiri-multilingual-reviewer-architecture-001.md)
- [Model Lab technical architecture](architecture/tafsiri-model-lab-technical-architecture-001.md)
- [Cloud technical architecture](architecture/tafsiri-cloud-technical-architecture-001.md)
- [Model release and commercial handoff](architecture/tafsiri-model-release-and-commercial-handoff-001.md)
- [Infrastructure](architecture/tafsiri-infrastructure-architecture-001.md)
- [Platform security](architecture/tafsiri-platform-security-architecture-001.md)
- [API and data contracts](architecture/tafsiri-api-and-data-contracts-001.md)
- [Implementation roadmap](architecture/tafsiri-platform-implementation-roadmap-001.md)
- [Architecture consistency review](architecture/tafsiri-architecture-consistency-review-001.md)

## Architecture and governance

- [Technical architecture](technical_architecture.md)
- [Project vision](project_vision.md)
- [Language inclusion framework](language_inclusion_framework.md)
- [Cultural guidelines](cultural_guidelines.md)
- [Source Registration 001](source-registration-001.md)
- [Import Reconciliation 001](import-reconciliation-001.md)
- [Canonical Lexical Core Architecture 001](research/canonical-lexical-core-architecture-001.md)
- [Migration 011 Canonical Lexical Core SQL Design 001](research/migration-011-canonical-lexical-core-sql-design-001.md)
- [Migration 011 implementation and validation](research/migration-011-implementation-report-001.md)
- [Migration 011 deployment-readiness checklist](research/migration-011-deployment-readiness-001.md)
- [Canonical lexical promotion and governance](research/canonical-lexical-promotion-architecture-001.md)
- [Canonical lexical promotion validation](research/canonical-lexical-promotion-validation-001.md)

## Multilingual architecture expansion (design only)

- [Readiness audit](research/multilingual-readiness-audit-001.md)
- [Architecture amendment](research/multilingual-architecture-amendment-001.md)
- [Migration 011 multilingual SQL review](research/migration-011-multilingual-sql-design-001.md)
- [Reviewer Portal extension](research/multilingual-reviewer-portal-design-001.md)
- [Model Lab](research/tafsiri-model-lab-architecture-001.md)
- [Tafsiri Cloud commercial boundary](architecture/tafsiri-cloud-commercial-architecture-001.md)
- [Compatibility and validation report](research/multilingual-compatibility-validation-001.md)

Decision records:

- [ADR-MULTI-001: Single pipeline](architecture/decisions/adr-multilingual-001-single-pipeline.md)
- [ADR-MULTI-002: Language and variety identity](architecture/decisions/adr-multilingual-002-language-variety-identity.md)
- [ADR-MULTI-003: Dialect-specific knowledge](architecture/decisions/adr-multilingual-003-dialect-knowledge.md)
- [ADR-MULTI-004: Cross-language semantics](architecture/decisions/adr-multilingual-004-cross-language-semantics.md)
- [ADR-MULTI-005: Reviewer authority](architecture/decisions/adr-multilingual-005-reviewer-authority.md)
- [ADR-MULTI-006: Model and dataset governance](architecture/decisions/adr-multilingual-006-model-dataset-governance.md)
- [ADR-MULTI-007: Research/commercial separation](architecture/decisions/adr-multilingual-007-research-commercial-boundary.md)

The original lexical architecture and SQL proposal remain historical records. Read the multilingual amendment and SQL review before implementing Migration 011. No new language support, migration deployment, training run or commercial service is implied by these documents.

## Luwanga lexical pilot 001 (preparation only)

- [Protocol](research/pilots/luwanga-lexical-pilot-protocol-001.md)
- [Readiness and resource eligibility](research/pilots/luwanga-lexical-pilot-readiness-001.md)
- [Private evidence packet and manifest specification](research/pilots/luwanga-lexical-evidence-manifest-spec-001.md)
- [Reviewer qualification template](research/pilots/luwanga-reviewer-qualification-packet-001.md)
- [Legacy security triage and hardening plan](security/legacy-advisor-triage-001.md)
- [Executed checks and limitations](research/pilots/luwanga-lexical-pilot-validation-001.md)

The pilot is blocked by dependencies/security and by rights, provenance and qualification gaps. No real-data promotion is authorized.

## Multilingual platform foundation (implementation, not deployed)

- [Registry, evidence and internal interfaces](research/multilingual-platform-foundation-001.md)
- [Versioned pipeline configuration](research/multilingual-pipeline-configuration-001.md)
- [Reviewer Portal next integration contract](research/multilingual-reviewer-integration-contract-001.md)
- [Security-hardening priorities](security/multilingual-foundation-hardening-plan-001.md)
- [Executed validation](research/multilingual-platform-validation-001.md)

## Operations

- [Institutional Data Studio local setup and acceptance walkthrough](research/institutional-data-studio-setup-001.md)
- [Institutional Data Studio validation and launch gates](research/institutional-data-studio-validation-001.md)
- [Data Studio technical architecture](architecture/tafsiri-data-studio-technical-architecture-001.md)
- [Collection API and governance contracts](architecture/tafsiri-data-studio-contracts-001.md)
- [AI Research Assistant](architecture/tafsiri-ai-research-assistant-001.md)

- [Repository and staging deployment](repository-deployment.md)
- [Repository cleanup record](repository-cleanup-2026-09.md)

Application documentation is in `apps/reviewer-portal/docs/`. Frozen evaluation records are in `evaluation/`; they are evidence artifacts rather than general documentation.
