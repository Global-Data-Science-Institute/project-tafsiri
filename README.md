# Project Tafsiri

Project Tafsiri develops dialect-aware language technology and research resources for Luhya languages. Human-verified linguistic evidence takes precedence over machine-generated suggestions. Keep dialects distinct and preserve provenance.

## Active applications

- **Reviewer Portal:** `apps/reviewer-portal/` is the Next.js application for invited language reviewers and research administrators. Its setup and workflow are described in `apps/reviewer-portal/README.md`.

## Data and research components

- `supabase/` contains the local Supabase configuration and versioned database migrations. Review the existing schema before proposing a new migration; never rewrite applied migration files.
- `scripts/candidate_generation/` and `config/candidate_generation/` contain Pipeline 001 and related candidate-generation tools and settings. Pipeline output is preliminary evidence, not verified linguistic data.
- `evaluation/` contains frozen human-evaluation packages, manifests, hashes, and research artifacts. Keep their content and provenance intact.
- `tests/` contains database and research regression checks.
- `docs/`, `training/`, and `artifacts/` contain project documentation and research material.

## Repository layout

This is a monorepo. The Reviewer Portal is an application within it; database schema, research code, evaluation data, and tests remain at the repository root.

## Local development

From `apps/reviewer-portal/`, copy `.env.example` to `.env.local` and set values for the intended development environment. Run `npm ci`, then `npm run dev`. Quality checks are `npm run typecheck`, `npm run lint`, `npm test`, and `npm run build`. Root tooling uses `package.json` and `package-lock.json`; Python regression tests are under `tests/`.

## Database migration workflow

Inspect the existing schema and migration sequence in `supabase/migrations/` first. Implement schema changes as new, versioned migrations and test against a non-production Supabase environment before applying them elsewhere. Never drop existing Tafsiri tables or rewrite applied migrations without explicit approval.

## Staging and production

Staging and production must use separate Supabase projects and environment variables. The Vercel Root Directory for the portal must be `apps/reviewer-portal`; only the verified staging branch/Preview environment should receive staging Supabase credentials. Keep invitations in mock mode until hosted Auth tests pass. Verify Vercel project, Git connection, branch mapping, and Supabase project identity before any deployment or Auth configuration change.

## Production safety

Do not commit `.env` files, service keys, database credentials, or Vercel tokens. Do not modify Pipeline 001 semantics, canonical linguistic data, or frozen evaluation artifacts as part of portal or repository housekeeping. Do not delete reviewer or evaluation data. Follow `AGENTS.md` for language and database rules.

## Verified staging database

Supabase CLI identifies project ref `gfhdwmqefotkljrltfnx` as **Project Tafsiri Staging**. Six local migration versions match its remote migration history as of 2026-09-19. Production is a different Supabase project. This does not confirm the Vercel environment variables or hosted Auth settings.
