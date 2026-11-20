# Tafsiri Model Lab architecture 001

Date: 2026-11-19. Status: future research design. No training pipeline, production model, experiment result or training authorization is created.

## Purpose and dependencies

The Model Lab is the eventual experiment and evaluation layer of the existing Tafsiri research pipeline. First research uses approved Luwanga resources within the Luhya program. PhD students, GDSI researchers and approved academic collaborators may investigate whether dialect-aware and morphology-guided training improves low-resource translation. This is a research hypothesis, not a performance claim.

ByT5, mT5 and appropriate small language models are possible experiment families, not selected production dependencies. Verify each proposed base model's version, license, data obligations and suitability at experiment approval. Do not provision orchestration infrastructure until a bounded experiment and approved dataset require it.

## Dataset admission and immutable manifest

Source registration, human review and canonical acceptance are necessary evidence but individually insufficient for training. A future dataset builder reuses registered source-entry/artifact lineage and canonical revisions. It must validate explicit `MODEL_TRAINING=ALLOWED`, effective/unexpired policy and consent restrictions for every contributing source version. Benchmark disclosure, redistribution and commercial use each require their own policy decision. `UNKNOWN`, `REVIEW_REQUIRED`, `DISALLOWED`, missing lineage or conflicting consent excludes the item and records an exclusion reason.

Proposed manifest contract (a specification, not an implemented export):

| Field group | Required contents |
|---|---|
| Identity | Schema version, dataset key/version, immutable manifest hash, build ID/time, code commit and configuration hash |
| Scope | Per-side language/variety IDs and portable keys, definition/gloss language where relevant, orthography/version, direction, domain/register |
| Records | Record ID/hash, canonical object and revision IDs, human decision/promotion references, original machine/import provenance |
| Source lineage | Attestation/evidence IDs, source-entry IDs, import/parser versions, source-version IDs and exact artifact hashes; any unresolved lineage excludes training use |
| Rights | Relevant policy IDs/versions, decisions, effective/expiry times, consent restrictions, intended use and approval actor/time |
| Splits | Immutable train/dev/test record lists and hashes; grouping by source/work, duplicate family, speaker where applicable; exclusion and leakage audit |
| Transformations | Normalization/tokenization/augmentation versions and seeds; transformations never erase source text or machine provenance |
| Approval | Dataset review decision, limitations, permitted experiment scopes, retention/access constraints and revocation handling |

Do not classify the existing reviewed evaluation files as approved training data. Frozen human-evaluation test records must be reserved from training and tuning, including near duplicates and alternate scans of the same intellectual work. Cross-dialect experiments split by lineage and lexical families where needed; otherwise shared sources can make transfer results misleading.

## Experiment contract

Each approved run records dataset manifest hashes, split IDs, base-model/checkpoint digest and license, tokenizer version, code commit, dependency lock/container digest, seed, hyperparameters, compute/runtime details, logs and output artifact hashes. Record nondeterminism and hardware limitations rather than claiming bitwise reproducibility. Start with ordinary versioned configuration and the existing research artifact practices; choose an experiment tracking backend only when actual collaboration/scale warrants it.

Proposed experiment progression:

1. Reproduce a bounded baseline on an approved Luwanga dataset.
2. Compare a dialect-aware condition against a matched baseline using identical splits, compute budgets and reporting.
3. Introduce reviewed morphology guidance as a separate ablation; do not use unvalidated runtime rules.
4. Consider cross-variety or cross-language transfer only with approved scope, compatible rights and independently held-out evaluation for every endpoint.

Predeclare metrics, evaluation protocol, minimum coverage and stop/release criteria. Report chrF/BLEU or other justified automatic measures with exact implementation/version, plus independent native/expert human judgments for adequacy, naturalness, variety fidelity, cultural harm and preserve-and-explain behavior. Report per direction, variety, domain and uncertainty, including confidence intervals/sample counts and failure examples cleared for publication. Aggregate scores cannot hide poor performance on a small variety. No fixed quality threshold is invented in this architecture phase.

## Model lifecycle and release

Use separate decisions: `EXPERIMENTAL → EVALUATED_CANDIDATE → RESEARCH_RELEASE_APPROVED`. Commercial clearance and production service approval are additional independent gates, not automatic successor states. A failed evaluation keeps the model experimental; missing commercial rights blocks commercial release without erasing research results.

A model card contains training manifest hashes, base-model provenance/license, evaluated scope, metrics and human protocol, known failures, intended/prohibited uses, safety/linguistic limitations and approval references. Every release artifact is content-addressed and reproducibly associated with the run; never overwrite a version. Rights revocation triggers impact analysis of all dependent datasets/models, blocks new releases and starts remediation or withdrawal. A historical snapshot of permission is evidence, not permanent authorization after revocation.

## Collaboration and intellectual-property boundary

Provide project-scoped access to approved datasets and experiments, with expiry, least privilege and audit. Students receive no blanket database/service-role keys, private reviewer records or source redistribution rights. Before access, GDSI and collaborators must explicitly record permitted research, background IP, generated outputs, publication review, attribution/authorship, community obligations, retention/deletion and any model redistribution terms. Participation alone does not transfer GDSI's preexisting IP. These are governance requirements for agreements, not a legal determination or implied license.

Keep private source binaries and participant information out of repositories and public experiment trackers. Sharing an approved result does not imply permission to share all input artifacts. Research feedback returns through existing source/evidence review, with provenance and consent.

## Future acceptance tests

- Reviewed source with training policy `UNKNOWN`: export rejected, with policy reference/reason.
- Source allowed for internal research only: training and commercial release rejected.
- Missing artifact lineage or changed manifest bytes: build/run rejected.
- Same source work in train and held-out evaluation, including alternate scans: leakage check rejects or requires a documented exclusion before approval.
- Model passes aggregate metrics but lacks required variety evaluation: release remains blocked for that scope.
- Rights expire/revoke between dataset approval and run/release: revalidation denies new use and flags dependent artifacts.
- Student credential requests unrelated dataset or privileged research table: access denied and audited.

These gates are designed, not implemented or validated. See [Tafsiri Cloud](../architecture/tafsiri-cloud-commercial-architecture-001.md) for the future one-way release interface.
