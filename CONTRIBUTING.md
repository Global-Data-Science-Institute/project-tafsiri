# Contributing to Project Tafsiri

Project Tafsiri accepts software, research, documentation, and expert language-review contributions.

## Before making a change

- Read `AGENTS.md` and the relevant design document in `docs/`.
- Inspect the current database migrations before proposing schema changes.
- Do not invent translations or merge dialect vocabularies.
- Keep generated candidates separate from human-verified data.
- Do not commit credentials, local environment files, or participant data.

## Development workflow

1. Create a focused branch from the intended base branch.
2. Make a small, reviewable change and update its documentation.
3. Add meaningful tests for behavior or schema changes.
4. Run the relevant portal, Python, and database checks.
5. Submit a pull request describing the evidence, risks, and migration impact.

Portal commands are documented in `apps/reviewer-portal/README.md`. Database changes must be new files in `supabase/migrations/`; never rewrite an applied migration. Research outputs must retain their inputs, configuration, provenance, and review status.

## Language contributions

State the dialect, source, collection method, and reviewer qualifications. Flag uncertainty explicitly. A contribution becomes verified only through the project's human review process.

## Conduct

Follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [docs/cultural_guidelines.md](docs/cultural_guidelines.md).
