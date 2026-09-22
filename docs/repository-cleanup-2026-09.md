# Repository cleanup record: 2026-09

This record describes the modernization performed from the `staging` branch. The safety tag `pre-main-modernization-2026-09` points to the pre-cleanup commit.

## Removed

- Placeholder or aspirational top-level directories: `api/`, `assets/`, `community/`, `core/`, `research/`, and `tools/`.
- Experimental legacy translation material: `examples/` and `languages/`.
- Obsolete dependency lists under `requirements/` and the unused `config/global_settings.yaml` model configuration.
- `CHANGELOG.md`, whose release and model claims were not supported by the current repository.
- Empty documentation placeholders under `docs/api/`, `docs/research/`, and `docs/tutorials/`.

These paths either contained only placeholders or described an unsupported 2025 model-serving structure. The removal did not alter the Reviewer Portal, database history, Pipeline 001, or evaluation evidence.

## Rewritten

Root and documentation indexes, technical architecture, project vision, language inclusion, contribution guidance, deployment status, and CI coverage were aligned with the implemented system.

## Preserved

- `apps/reviewer-portal/`
- `supabase/` and all applied migration history
- `scripts/candidate_generation/` and `config/candidate_generation/`
- `evaluation/`, `artifacts/`, database and research tests
- Architecture, lexical-core, provenance, and cultural-governance records in `docs/`

Frozen artifacts and their hashes were not modified.

## Root-level audit

| Path | Classification | Decision |
| --- | --- | --- |
| `api/` | Obsolete 2025 | Removed placeholder service structure; no active imports or tests. |
| `assets/` | Obsolete 2025 | Removed unused placeholder assets. |
| `community/` | Migrate content | Removed the unsupported program structure; retained current governance in `docs/cultural_guidelines.md` and the rewritten project docs. |
| `core/` | Obsolete 2025 | Removed unimplemented service placeholders. |
| `examples/` | Obsolete 2025 | Removed the experimental M2M100 example. |
| `languages/` | Obsolete 2025 | Removed stale model claims and the unused partial dialect configuration; the database is the current authority. |
| `requirements/` | Obsolete 2025 | Removed Python dependencies used only by deleted model and API examples. Current research scripts use the standard library; CI installs `pytest` for tests. |
| `research/` | Obsolete 2025 | Removed empty architectural placeholders. Frozen research evidence remains in `evaluation/` and `artifacts/`. |
| `tools/` | Obsolete 2025 | Removed unused placeholders. |
| `training/` | Unknown/untracked | No tracked content existed; no active training system is claimed. |
| `CHANGELOG.md` | Obsolete 2025 | Removed unsupported release and model claims. |
| `docs/` | Active current / migrate content | Rewrote current indexes and policy documents; removed empty placeholders. |
| `config/` | Active current / obsolete split | Preserved `candidate_generation/`; removed unused legacy model configuration. |

No legacy file was moved verbatim. Current principles were rewritten into the active documentation without retaining obsolete module claims.
