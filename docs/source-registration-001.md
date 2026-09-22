# Source Registration 001

Source Registration 001 records bibliographic, version, rights, use-policy, and source-scoped dialect-mapping metadata. It creates no import batches, source entries, lexical rows, concepts, evaluation rows, or training data.

The versioned manifest is `config/sources/source_registry_001.json`. Public evidence was checked against the source publications, institutional catalogs, Harvard Dataverse, African Proverbs sources, Mulembe Nation, and Project Tafsiri's public provenance article. Public accessibility is never treated as an open license.

## Utility

Run offline validation:

```text
python -m scripts.source_registry.register_sources --validate
```

Dry run against an explicitly configured Supabase project:

```text
python -m scripts.source_registry.register_sources --dry-run --project-ref PROJECT_REF
```

Execution additionally requires an exact confirmation:

```text
python -m scripts.source_registry.register_sources --execute --project-ref PROJECT_REF --confirm-project-ref PROJECT_REF
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` must be supplied through the process environment. The utility only permits writes to the six Source Registration 001 metadata tables. Existing records with conflicting managed fields stop execution; matching records produce no changes.

## Deliberate gaps

- No contact events are registered because no dated outreach evidence is present in the repository.
- No import batch is registered because no authoritative original artifact and checksum have been reconciled.
- No source entry is registered.
- Mulembe Nation receives no source-wide dialect mapping because the site spans several dialects.
- Wanga to Luwanga and Lubukusu to Bukusu remain `IN_REVIEW` source-version assertions.
