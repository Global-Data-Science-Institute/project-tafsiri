# Tafsiri Model Lab technical architecture 001

Status: future implementation design. Extends [Model Lab governance](../research/tafsiri-model-lab-architecture-001.md); no dataset approval, training or infrastructure provisioning occurs. The Lab runs actual optimization and evaluation of owned/authorized model artifacts; third-party LLM calls cannot substitute for the training system.

## Dataset boundary

The Research Core's private exporter is the only path from protected source/canonical storage into Lab datasets. Lab owns dataset/version metadata, not a second source registry. Immutable manifests reference original source/version/artifact/entry/evidence/canonical IDs and hashes, human decisions, transformation code/configuration, exact side scopes, orthographies, permitted purposes, policy/consent references, validity, approvals and exclusion reasons. The authoritative payload is [DatasetManifest v1](tafsiri-api-and-data-contracts-001.md).

Lifecycle: DRAFT → VALIDATED → APPROVED, with REVOKED possible from any admitted state. Approval binds exact bytes and intended project/use. A new record, split or transform means a new version and approval. Artifact URIs are private, short-lived capabilities issued separately from the manifest. A dataset's existence grants no download or training access.

Build train/dev/test splits before tuning. Group by intellectual work and alternate scan, duplicate/near-duplicate family, speaker where relevant, and lexical family where the hypothesis requires it. Preserve frozen HE001/test exclusions. Compare against benchmark hashes and normalized duplicate fingerprints, record a leakage report and manually review ambiguous overlaps. The transformation used for leakage detection must not overwrite original orthography. No universally valid ratio is prescribed: the protocol records coverage and split rationale. Blind test labels remain in an evaluator-only store.

Revocation traverses source → dataset → run → checkpoint → model → release. Block new jobs immediately, cancel/quarantine active jobs at policy checkpoints, restrict downstream artifacts and notify release governance. Retaining an audit identifier is not retaining unauthorized source content; record deletion/tombstone decisions and backup expiry separately.

## Experiments and collaboration

Projects contain members with researcher, project lead, dataset steward and evaluator roles, finite membership and explicit sharing scopes. PhD students and collaborators may submit bounded jobs and compare their project's results; they receive no research DB keys, unrestricted artifact bucket or another project's runs. Agreements record publication, background IP, attribution and retention before real access.

An experiment definition freezes hypothesis, baseline, model family, datasets/splits, transformations, hyperparameters, seeds, metrics, evaluation scope, resource budget and stopping criteria. A run adds commit, dependency lock, container/base-model/tokenizer digests, hardware/driver details, random states, attempts, logs, metrics and resource use. Comparison views require compatible benchmark versions and label unmatched comparisons; ablations vary one declared factor against matched data/compute. Log scalar metrics and approved examples only; source text and secrets never enter a public tracker.

## Training implementation choices

Recommendations below are design judgments based on primary documentation consulted 2026-11-20; package versions will be pinned and compatibility-tested at implementation, not selected by floating `latest`.

| Option | Recommendation and tradeoff |
|---|---|
| PyTorch | Common training foundation; permits custom morphology/dialect losses. Record seeds, deterministic settings and hardware because reproducibility is not guaranteed across platforms/releases. [Reproducibility documentation](https://docs.pytorch.org/docs/2.15/notes/randomness.html) |
| Hugging Face Transformers | Initial Trainer/Seq2SeqTrainer adapter for small language-model fine-tuning and encoder-decoder translation; custom loop only when the experiment needs it. This reduces orchestration code without constraining linguistic evaluation. [Trainer documentation](https://huggingface.co/docs/transformers/main_classes/trainer) |
| PEFT | Evaluate LoRA first against a matched full/partial fine-tuning baseline; QLoRA adds quantized-base and hardware compatibility concerns. Record adapter targets, rank, precision and exact base digest; an adapter is not a standalone model. [PEFT integration](https://huggingface.co/docs/transformers/peft), [quantization guide](https://huggingface.co/docs/peft/developer_guides/quantization) |
| MLflow | Start with immutable Tafsiri run/result manifests; introduce a private tracking server when shared comparisons justify it. Its metadata/artifact interfaces fit collaboration, but Tafsiri authorization and release approval remain authoritative, not mutable tags or aliases. [Tracking server](https://mlflow.org/docs/latest/self-hosting/architecture/tracking-server/), [registry](https://mlflow.org/docs/latest/registry/) |
| Containerized Python workers | One pinned training image family with adapters, bounded filesystem/egress and per-job credentials. More reproducible than unmanaged notebooks; image/driver compatibility and patching remain operational duties |
| Distributed training | Defer until a measured model/memory/throughput need exceeds one worker. Preserve the same job contract; validate world-size and checkpoint compatibility before resume. [PyTorch distributed checkpoint](https://docs.pytorch.org/docs/2.15/distributed.checkpoint.html) |

Base-model selection remains experiment-specific: compare suitable small causal LMs and encoder-decoder models, with verified license and tokenizer coverage, rather than committing to one vendor/model. Multilingual transfer explicitly identifies every training/evaluation endpoint. Dialect tags and morphology features are versioned experimental inputs derived from approved evidence, not generalized Luhya rules. Evaluate baseline, dialect conditioning and morphology guidance as distinct ablations. No promise of performance improvement is made.

## Job lifecycle and compute

QUEUED → LEASED → RUNNING → SUCCEEDED/FAILED/CANCELLED, with CHECKPOINTED and resumable new attempts. The scheduler checks project membership, dataset/base-model eligibility, image allowlist, CPU/GPU memory class, concurrency, maximum wall time and cost budget before leasing. Start with one durable job queue and bounded worker pools; CPU handles validation/small fixtures and suitable experiments, GPU is requested only by approved resource class. No GPUs are provisioned by this design.

Leases have expiry, heartbeat and monotonically increasing fencing tokens. A lost worker cannot publish after a replacement acquires the job. Retries are at-least-once; unique job/attempt IDs and compare-and-set terminal publication prevent duplicate results. Checkpoint upload completes to a temporary object, then checksum verification publishes an immutable manifest. Save weights, optimizer/scheduler, RNG, sampler position, preprocessing configuration and progress. Resume requires compatible code/data/base/container, a valid complete checkpoint and current permissions; changed experiment inputs create a new run. On cancellation, revoke credentials, stop compute and apply artifact retention policy.

## Evaluation and model registry

| Evaluation layer | Required evidence |
|---|---|
| Automatic translation | chrF and BLEU with exact tokenizer/version/signature, sample counts and paired uncertainty estimates; metrics are descriptive, not sole release gates. [SacreBLEU reference implementation](https://github.com/mjpost/sacrebleu) |
| Scope fidelity | Per-direction/variety/domain strata, cross-variety contamination, orthographic and dialect consistency; no aggregate score hiding unsupported scopes |
| Morphology | Protocol-approved morphological phenomena, gold annotation provenance and error taxonomy; no universal Bantu feature requirement |
| Human linguistic review | Blinded qualified reviewers for adequacy, naturalness, culture/context, abstention and disagreement; independent adjudication through existing portal |
| Invented vocabulary/hallucination | Unsupported lexical invention, semantic additions/omissions, unjustified borrowing and preserve-and-explain behavior; uncertainty when a verified explanation cannot be produced |
| Transfer/generalization | Held-out language/variety/source/domain tests under separate permissions; zero-shot claims distinguish absent target training from shared-source leakage |

Benchmarks are immutable versioned manifests with access/publication permissions and an evaluator-owned hidden test split. Predeclare acceptance thresholds, minimum coverage and uncertainty policy for each scope before release evaluation; language experts and release owners must approve values. This document invents no universal passing score. Store error analysis with protected examples and publication-safe summaries.

Model records bind stable ID/version, base model and adapter dependencies, run/configuration/container/dataset hashes, tokenizer, evaluation reports, license references, model card, artifact checksums and size/format. Never overwrite versions. MLflow aliases may aid discovery but cannot approve a release. An independently approved evaluation may move a model to EVALUATED_RESEARCH; all later states follow the [release architecture](tafsiri-model-release-and-commercial-handoff-001.md). Revocation is propagated to the same lineage graph; rollback selects only currently eligible artifacts.
