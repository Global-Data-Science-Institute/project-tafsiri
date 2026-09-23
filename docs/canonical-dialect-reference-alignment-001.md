# Canonical Dialect Reference Alignment 001

The versioned manifest at `config/dialects/canonical_dialect_registry_001.json`
aligns canonical dialect names and lookup aliases across production and staging.
It contains no environment UUIDs. Production resolves the `Luhya` parent;
staging resolves `Staging Luhya` and preserves its existing `Luwanga` row.

Aliases support lookup and UI/source-name resolution. They do not verify
source-specific linguistic equivalence and do not change
`source_dialect_mapping_assertions` or `source_variety_mentions`.

```powershell
python -m scripts.dialect_registry.register_dialects --validate
python -m scripts.dialect_registry.register_dialects --dry-run --project-ref PROJECT_REF
python -m scripts.dialect_registry.register_dialects --execute --project-ref PROJECT_REF --confirm-project-ref PROJECT_REF
```

The utility writes only `dialects` and `dialect_aliases`, never updates or
deletes rows, preserves existing IDs, and stops on parent or alias conflicts.
The historical coexistence of canonical `Wanga` and `Luwanga` remains a future
dialect-governance review item.
