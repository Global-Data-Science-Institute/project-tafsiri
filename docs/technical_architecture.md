# Technical architecture

Project Tafsiri is a monorepo for dialect-aware lexical research and human review. It contains one deployed application, a versioned Supabase schema, candidate-generation research tools, and frozen evaluation evidence.

## Components

### Reviewer Portal

`apps/reviewer-portal/` is a Next.js application. It uses Supabase Auth and the database schema under `supabase/migrations/`. Reviewers and administrators have separate guarded workflows. Invitation delivery remains in mock mode until hosted Auth testing is complete.

### Canonical lexical data

Supabase is the schema authority. Applied migrations define canonical tables, constraints, access policies, and role grants. Schema work must be additive and versioned. Migration 006 introduces the source and provenance foundation; it contains no data backfill.

The approved migration sequence now reserves Migration 007 for the **Linguistic Literature & Evidence Foundation**, moves the **Canonical Lexical Core** to Migration 008, and reserves Migration 009 for **Evidence Promotion & Linguistic Rule Governance**. The detailed design is recorded in [Linguistic Evidence Architecture 001](research/linguistic-evidence-architecture-001.md).

Scholarly publications remain source records under the Migration 006 provenance foundation. A citable source version may support one or more located linguistic-evidence assertions. Human verification confirms that an assertion accurately represents its source; it does not promote the assertion into a canonical Tafsiri rule. Canonical promotion requires a later, explicit governance workflow.

Human verification outranks generated suggestions. Generated candidates cannot become verified data without an explicit review action. Dialect identity is stored explicitly and must not be inferred by blending varieties.

### Candidate generation

`scripts/candidate_generation/` and `config/candidate_generation/` implement research Pipeline 001. Its outputs are proposals with provenance, not translations approved for training or publication.

### Evaluation evidence

`evaluation/` contains frozen packages, manifests, and hashes. These records support reproducibility and must not be rewritten during product or repository maintenance.

## Environments

Local, staging, and production environments use separate configuration. The staging Vercel project serves the Reviewer Portal from `apps/reviewer-portal` and tracks the `staging` branch. Staging and production Supabase projects are distinct. Credentials belong in ignored environment files or the hosting provider, never in Git.

## Verification

Continuous integration checks portal types, lint, unit tests, and production build; Python research regressions; and the database migration sequence with SQL smoke tests and `supabase db lint`.
