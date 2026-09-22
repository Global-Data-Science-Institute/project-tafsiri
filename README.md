# Project Tafsiri

## Mission

Project Tafsiri develops dialect-aware AI and language infrastructure for Luhya languages and dialects, supporting research toward English-Luhya and Swahili-Luhya systems.

## Current architecture

The project follows an evidence-first path:

**source evidence -> human review -> canonical corpus -> derived datasets and retrieval -> models and runtime**

Each stage must retain provenance. Machine-generated candidates remain proposals until qualified human reviewers verify them.

## Current implemented systems

- **Canonical concept foundation:** versioned Supabase schema for concepts, terms, dialects, relationships, and review state.
- **Source and provenance foundation:** Migration 006 defines source, version, rights, policy, contact, import, entry, and dialect-mapping records. It is prepared for release and contains no backfill.
- **Pipeline 001:** deterministic candidate-generation scripts, configuration, and artifacts for research review.
- **Human Evaluation 001:** frozen evaluation packages and import tooling with manifests and hashes.
- **Reviewer Portal:** a Next.js research application for invited reviewers and administrators, backed by Supabase Auth and row-level security.

The public translation runtime has not been released. Model training is not the current production architecture. The Reviewer Portal is a research tool, not the public Tafsiri application.

## Repository layout

- `.github/` - continuous integration
- `apps/reviewer-portal/` - current review application
- `artifacts/candidate_generation/` - Pipeline 001 outputs
- `config/candidate_generation/` - Pipeline 001 configuration
- `docs/` - current architecture, governance, and operations
- `evaluation/` - frozen Human Evaluation 001 evidence and import tooling
- `scripts/candidate_generation/` and `scripts/evaluation/` - research tooling
- `supabase/migrations/` - authoritative, versioned database history
- `tests/` - candidate-generation, evaluation, and database regression tests

## Dialect principle

Lutsotso, Bukusu, Luwanga, Maragoli, Isukha, and other varieties remain first-class dialects. Do not create an artificial generalized vocabulary by blending dialects. Use a verified native equivalent when one exists, use an established borrowing when documented, and otherwise preserve the source term with a natural explanation. Do not guess.

## Data governance

Human-verified data outranks generated data. Every accepted lexical assertion should retain its source, rights, import, and review provenance. Generated material cannot automatically become verified training data. Database changes are additive, versioned migrations; applied migrations and reviewed production data are never rewritten during routine development.

## Development

The [documentation index](docs/README.md), [technical architecture](docs/technical_architecture.md), and [contribution guide](CONTRIBUTING.md) describe current work. Portal setup is in [apps/reviewer-portal/README.md](apps/reviewer-portal/README.md). Deployment and environment facts are recorded in [docs/repository-deployment.md](docs/repository-deployment.md).

The staging Vercel project tracks `staging` with Root Directory `apps/reviewer-portal`. Staging and production use separate Supabase projects. Keep credentials in ignored local files or provider-managed environment variables.
