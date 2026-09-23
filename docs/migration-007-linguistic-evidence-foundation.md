# Migration 007 — Linguistic Literature & Evidence Foundation

## Status

Migration 007 was deployed and verified on production project `ydkookidvipqrwuilqeu` on 2026-09-23.

The final production-linked dry run identified only this migration as pending. After deployment, local and production migration histories matched through Migration 007. The CLI link was then restored to staging project `gfhdwmqefotkljrltfnx`, whose migration history still stops at Migration 005. This known environment divergence was not changed during Migration 007 deployment.

## Migration

`supabase/migrations/20260923040039_create_linguistic_evidence_foundation.sql`

The migration extends the Migration 006 source registry with scholarly metadata, identifiers, access locations, literal variety mentions, a governed evidence taxonomy, located evidence, dialect links, notation, narrow G2P evidence, examples and interlinear tiers, and evidence relationships.

The taxonomy contains configuration rows only. The migration registers no publications and inserts no linguistic evidence, G2P evidence, or examples.

## Security

Every new table has RLS enabled. `anon` and `authenticated` have no table privileges or policies. `service_role` has administrative table privileges. Researcher access requires a future explicit policy design.

Availability metadata remains independent of `source_rights` and `source_use_policies`. Example display policy remains independent of publication availability.

## Canonical boundary

Evidence records are append-oriented interpretations of located scholarly claims. Reviewed content cannot be silently rewritten. Corrections supersede existing evidence or create another interpretation.

Migration 007 creates no executable pronunciation rules, canonical linguistic rules, lexemes, senses, model-training structures, RAG indexes, or public APIs. Canonical lexical work remains Migration 008; evidence promotion and linguistic-rule governance remain Migration 009.

## Validation

Run locally:

```powershell
npx.cmd supabase db reset --local
cmd.exe /d /c "docker exec -i supabase_db_project-tafsiri psql -U postgres -d postgres -v ON_ERROR_STOP=1 < tests\database\linguistic_evidence_foundation_smoke.sql"
npx.cmd supabase db lint --local --level warning
```

The smoke suite runs inside a transaction and rolls back all test data.

## Deferred work

- Production deployment of Migration 007
- Registration of the 46 inventoried scholarly sources
- Linguistic Evidence Extraction 001
- Researcher-facing RLS policies
- Full tone, morphology, and acoustic measurement structures
- Canonical linguistic rules and evidence promotion
