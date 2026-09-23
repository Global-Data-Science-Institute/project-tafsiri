# Linguistic Literature Registration 001

This registration loads the 46 publication metadata records in
`config/linguistic_sources/literature_registry_001.json`. It writes only the
source, version, scholarly metadata, identifier, access location, variety
mention, rights, and use policy tables introduced by Migrations 006 and 007.
It never writes linguistic evidence or source text.

## Commands

```powershell
python -m scripts.linguistic_sources.register_literature --validate
python -m scripts.linguistic_sources.register_literature --dry-run --project-ref PROJECT_REF
python -m scripts.linguistic_sources.register_literature --execute --project-ref PROJECT_REF --confirm-project-ref PROJECT_REF
```

Set `SUPABASE_URL` and either `SUPABASE_SERVICE_ROLE_KEY` or
`SUPABASE_SECRET_KEY` in the process environment. The URL must contain the
declared project ref. Execution requires the same ref in
`--confirm-project-ref`.

The utility treats the inventory as desired state. A matching row produces
`NO_CHANGE`; a missing row produces `CREATE`; a managed-field difference
stops registration as `CONFLICT`. Repeated execution is idempotent.

Source-reported variety labels are retained literally. Candidate Tafsiri
dialect links remain `CANDIDATE`; unmatched family or reconstructed labels
remain `UNMAPPED`. Unknown licenses remain `UNKNOWN`, independently of public
availability.
