# Tafsiri Study Import 001

`scripts.evaluation.import_study` validates the frozen Human Evaluation 001
sample without regenerating or resampling it.

## Safe commands

```powershell
py -3 -m scripts.evaluation.import_study --validate
py -3 -m scripts.evaluation.import_study --dry-run
```

Dry-run writes only `human_evaluation_001_import_manifest.json` locally. It
does not open a database connection.

Database validation and the future execution path read the connection string
from `TAFSIRI_DATABASE_URL`; credentials are never stored in repository files.
Execution additionally requires both `--execute` and:

```text
--confirm-study-key HUMAN_EVALUATION_001_LUWANGA
```

The execution path requires Psycopg 3 and performs validation, draft study
creation, item and pipeline-snapshot insertion, count verification, and study
activation in one PostgreSQL transaction. Any exception rolls it back.

## Canonical snapshot hashing

Source and Pipeline snapshots are serialized as JSON with recursively sorted
object keys, compact `,` and `:` separators, no ASCII escaping, no NaN values,
and UTF-8 encoding. SHA-256 is calculated over those exact bytes. Array order
is preserved because it is evidence.

Reviewer fields are validation inputs only. They are excluded from both source
and Pipeline snapshots. Pipeline classifications are excluded from the Stage A
source snapshot and stored only in the separately blinded Pipeline snapshot.
