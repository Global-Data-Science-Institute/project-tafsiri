# Luwanga lexical pilot readiness 001

Prepared 2026-11-19 local / 2026-11-20 UTC. Recommendation: **BLOCKED — SECURITY OR DEPENDENCIES**. Rights, provenance and qualifications are additional independent blockers. The protocol is prepared for review; the real-data pilot is not approved.

## Dependencies and inspection boundary

Read-only GitHub inspection found all dependencies OPEN, with no merge timestamp:

| PR | Head | Target |
|---|---|---|
| [22](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/22) | feature/tafsiri-multilingual-architecture | staging |
| [23](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/23) | feature/tafsiri-migration-011-lexical-core | staging |
| [24](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/24) | feature/tafsiri-canonical-lexical-promotion | feature/tafsiri-migration-011-lexical-core |

This branch starts at full 012 commit `fa986c88c80b027826c72478183c833fc28b7c09` and targets #24's branch as a stacked draft. No dependency was changed or merged. Historical design documents sometimes say 011 is not created; the implementation SQL/report supersede that design-era status, but do not establish deployment.

Read-only metadata queries against staging `gfhdwmqefotkljrltfnx` and production `ydkookidvipqrwuilqeu` both returned latest migration `20260928015644`, zero source entries, zero import batches, 12 registered artifacts and 110 linguistic-evidence records. `public.lexemes` and `lexical_governance` are absent in both. Thus neither 011 nor 012 is deployed. Detailed scope/rights/ACL inspection below was performed in production; equal aggregate counts do not establish full staging equivalence. No private source text, reviewer identities or permission narratives were selected for publication.

## Evidence availability and eligibility matrix

This is a resource-level screening matrix, not a list of invented lexical units. Source keys and version references resolve in the existing registry. Rights/policy references below mean current rows in `source_rights` and `source_use_policies` for that version; re-query validity at the time of intended use.

| Resource and version | Observed evidence / lineage | Primary screening outcome and additional blockers |
|---|---|---|
| WANGA_ENGLISH_DICTIONARY_2008; `c42ecf2e-9d8e-4e06-a0da-0686892cc20f` | Registered artifact `ART_SHA256_0483DE7C6CCDBDCC7206A38D`; no entries, batches or linguistic evidence | Pending rights confirmation: PUBLICLY_ACCESSIBLE_CITED is not accepted by 012; HUMAN_REVIEW and REVIEWER_DISPLAY REVIEW_REQUIRED. Also pending provenance and linguistic verification; Wanga mapping IN_REVIEW |
| MARLO_AKIDAH_1999_LUWANGA_MORPHOPHONEMICS; `592153b4-1fcd-4f8f-a9b7-8dd82e5003d5` | 10 VERIFIED DIALECT records, PRIMARY Luwanga; no registered artifact link or entries | Pending rights confirmation: UNKNOWN rights/HUMAN_REVIEW; INTERNAL_RESEARCH ALLOWED. Also pending artifact/import/entry provenance and lexical interpretation; source verification is not lexical approval |
| GREEN_MARLO_2019_WANGA_NOUN_TONE; `ff046e92-5323-4b0a-8959-fd2eb126a0b8` | No linguistic evidence, entries or artifact link | Pending rights confirmation: UNKNOWN rights/HUMAN_REVIEW; research ALLOWED. Also pending provenance and linguistic verification |
| LUWANGA_NOUNS_VERBS_MORPHOPHONOLOGY; `419e5560-2253-4e0a-b2ec-19b138d911ef` | No linguistic evidence, entries or artifact link | Pending rights confirmation: UNKNOWN rights/HUMAN_REVIEW; research ALLOWED. Also pending provenance and linguistic verification |
| MARLO_LUYIA_COMPARATIVE_DICTIONARY_WORKBOOK; `776bfd9f-c6ca-55b1-b7b2-3f1bd7717744` | Registered artifact `ART_SHA256_727C59A413D1521A910A0F46`; no entries/evidence | Pending rights confirmation: UNKNOWN rights, research and review policies. Also pending source-column interpretation, exact scope, provenance and verification |
| EBARB_GREEN_MARLO_LUYIA_TONE_MELODIES; `7d063f89-a107-45d4-a114-0ab3d54a4eac` | 10 VERIFIED MULTI_DIALECT_COMPARATIVE records with Luwanga COMPARISON links | Excluded as primary Luwanga support in policy 001; UNKNOWN rights/HUMAN_REVIEW and missing entries also block use |
| GLUCKMAN_ETAL_2017_LUYIA_MODALITY; `310433cf-9794-4e62-8aff-d71b3c10f3eb` | 10 VERIFIED MULTI_DIALECT_COMPARATIVE records with Luwanga COMPARISON links | Excluded as primary Luwanga support in policy 001; UNKNOWN rights/HUMAN_REVIEW and missing entries also block use |

The production registry has Luwanga ID `928f469a-360c-49f1-8af2-006165673090` and a separate Wanga ID `ecd4a3ab-9ca5-4cf5-86c0-584c176f519c`. The only current mapping to Luwanga returned by inspection is assertion `aa5b0407-d140-4b91-9f99-4c7021ef92a7`, literal Wanga, status IN_REVIEW, dictionary version above. It is not verified authority to conflate those IDs.

Wanga rights record `93b22db2-d2c5-4469-9ec6-a88027cd8e02` is PUBLICLY_ACCESSIBLE_CITED; INTERNAL_RESEARCH policy `e1965b56-852d-405f-ab1f-30496ebf2a47` is ALLOWED; HUMAN_REVIEW `34d585ba-ecca-47a9-b075-3ff434b9797b` and REVIEWER_DISPLAY `29453786-d7da-48b0-857c-8623198958cc` are REVIEW_REQUIRED. These rows have no expiry recorded; absence of expiry does not upgrade permission. PUBLIC_DISPLAY, REDISTRIBUTION, MODEL_TRAINING and COMMERCIAL_API are UNKNOWN. BENCHMARK_PUBLICATION is REVIEW_REQUIRED. Possession of the registered copy is a separate fact.

The dictionary artifact SHA-256 is `0483de7c6ccdbdcc7206a38dd39e2d74f01908010e1bf7a1b197959f76c1311d`; the workbook SHA-256 is `727c59a413d1521a910a0f46d0e9d91b1544cab500444c19f5aee3fef381ecb4`. These are registry observations, not fresh byte-verification results. Durable private artifact-location approval is unresolved in the existing registration report.

## Counts and interpretation

- Genuine lexical candidate units assessed: **0**. No source-entry identity exists to support a unit-level assessment; forms/glosses were not extracted past the rights gate.
- Eligible units: **0**. Rights-blocked candidate units and units requiring linguistic review: **not estimable**, not zero-cleared. There is no admitted unit denominator.
- Resource leads screened: **7**; all seven lack the required rights/review combination. Thirty existing Luwanga-linked evidence records were assessed at metadata level, all on those blocked sources; ten are primary-scope, twenty comparative. These are evidence records, not thirty lexical units.
- Real proposal manifests, human approvals and executions created: **0**.

Existing Pipeline 001 reports 3,837 generated records, and the older semantic-review instructions describe a 150-record sample. Neither count is a canonical pilot sample or proof of rights/qualification. Existing linguistic-rule pilot approval is not lexical authority. No historical candidate, evaluation, rule-review CSV or source artifact was modified.

## Required clearance

Obtain documented compatible rights and use-specific policies; authorize private storage/display; complete artifact/import/entry reconciliation through the existing pipeline; verify the literal source mapping and claim-level evidence; identify independently qualified reviewers and scoped canonical authority using the [qualification packet](luwanga-reviewer-qualification-packet-001.md). Then refresh contradictions and freeze eligible unit packets. All original form, gloss, entry ID, verification decision and conflict fields currently lack an eligible unit to populate; do not invent placeholders as actual records.

Before real-data deployment, resolve the blocking access paths in the [security plan](../../security/legacy-advisor-triage-001.md), review/integrate dependencies, check hosted drift and recovery, and obtain separate deployment and pilot-execution authorization. Technical readiness cannot substitute for any of these decisions.
