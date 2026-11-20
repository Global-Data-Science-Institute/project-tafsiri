# Tafsiri infrastructure architecture 001

Status: infrastructure design only. Preserve PostgreSQL/Supabase, Next.js/React/TypeScript, Python, Vercel and GitHub Actions. No service or GPU is provisioned. [Reference architecture](tafsiri-platform-reference-architecture-001.md) defines ownership; [security](tafsiri-platform-security-architecture-001.md) defines trust.

## Monorepo and deployment units

| Location | Current or proposed role |
|---|---|
| `apps/reviewer-portal` | Existing research UI/server; extend rather than duplicate |
| `scripts/candidate_generation`, `scripts/lexical_promotion` | Existing single research pipeline and governed CLI |
| `supabase/migrations` | Existing versioned research schema authority; no historical rewrite |
| `config`, `evaluation` | Existing versioned configuration and frozen research artifacts |
| `apps/model-lab` | Proposed project/run UI and control API; may initially be a thin internal UI, not a second review system |
| `services/model-worker` | Proposed Python training/evaluation adapters with shared job contracts |
| `apps/tafsiri-cloud` | Proposed commercial customer/developer UI and modular control API |
| `services/inference-worker` | Proposed commercial container serving adapter |
| `packages/contracts` | Proposed generated bindings from reviewed contract versions; documentation schemas live in this series until implementation |

These proposed paths are a layout plan, not directories created by this task. Start with one modular backend per trust domain, not one service per table or language. Training and inference are independent execution processes because their hardware, runtime and isolation differ from request handling.

## Data and compute placement

Research remains on its existing Supabase database with restricted schemas and source artifact storage. Lab has separate database credentials and private dataset/model/checkpoint storage, receiving only approved exports. A separate Lab database is the preferred first multi-user deployment; a disposable local synthetic prototype may use isolated schemas without claiming production isolation. Cloud requires a separate database/project, storage and credentials from research and Lab from the outset. Its schema migrations have a separately targeted history and explicit environment selection; never apply Cloud migrations to the research project.

Keep relational metadata in PostgreSQL; store binaries in private object storage addressed by SHA-256 and verified size. Reuse existing source artifact IDs; dataset/model stores contain derived artifacts and references, not a second provenance registry. Enable object versioning/retention controls appropriate to approved rights, encryption and narrowly scoped signed downloads. An expiring download URL is a capability and must not be logged. Separate untrusted upload/quarantine locations from accepted artifacts and worker output prefixes.

Use existing Vercel hosting for portal and bounded HTTP control-plane workloads. Next.js route handlers fit those request/response boundaries; long-running training and hardware-specific inference belong in dedicated workers whose execution survives web-request timeouts. Provider limits/regions must be verified when deploying. This is a workload choice, not a claim that Vercel cannot run backends. [Vercel Functions documentation](https://vercel.com/docs/functions).

## Minimum deployment versus scale-out

| Concern | Minimum viable implementation | Scale-out trigger and extension |
|---|---|---|
| Scheduling | Durable PostgreSQL job/outbox records; one dispatcher and bounded workers | Measured queue contention/latency: managed queue preserving leases, fencing and deduplication |
| Training | One approved container worker/resource class; CPU synthetic validation first | Model memory or throughput needs: GPU pool, then distributed scheduler |
| Experiment tracking | Immutable run manifests and project UI | Multi-researcher comparison volume: private MLflow service behind project authorization |
| Inference | One approved model family, one region, explicit capacity admission | Load/SLO evidence: warm pools, batching, autoscaling and approved regional failover |
| Control APIs | Modular Next.js/TypeScript applications within each trust boundary | Independent scaling/release need: extract a specific service with versioned contracts |
| Telemetry | Structured text-free logs, metrics and trace IDs | Retention/query volume: dedicated observability backend; no raw text default |

Do not add Kubernetes, a vector store, Kafka or a distributed training cluster without a measured requirement. A durable queue is not permission to retry irreversible work blindly. Domain DB transactions write outbox events; workers fence attempts and consumers deduplicate. Dead-letter items retain reason/metadata with restricted access and explicit retry authority.

## Environments, networking and secrets

Local synthetic, CI, staging and production have separate databases, buckets, identity audiences, signing keys and worker credentials. Preview deployments receive synthetic or sanitized data and no production secrets. Each process receives only its domain credentials; Cloud network policy denies research/Lab databases and storage. Training egress permits approved artifact/metric endpoints, not arbitrary source exfiltration. Private ingress protects workers and tracking; public traffic terminates at the appropriate app gateway.

Use managed secret storage/workload identity where supported, short-lived job credentials and separate migration/operator roles. GitHub Actions uses least-privilege environment-scoped deployment identity and protected approval gates; no untrusted PR code accesses deployment secrets. Pin actions/dependencies/images and verify provenance before promotion. Do not share research service-role keys with Vercel Cloud settings or notebooks.

## Operations, recovery and delivery

Trace IDs join export/job/run/evaluation/release/request/usage records without logging private text. Monitor queue age, lease loss, training utilization/budget, inference latency, authorization denial, rights/revocation freshness, failed signatures, storage integrity and billing reconciliation. Domain owners define alert thresholds and on-call ownership before production; customer text is excluded from routine traces and error reports.

Back up metadata, immutable object manifests, approval/audit histories and encryption/signing recovery material under separate custody. Database backup alone does not establish object recovery: inventory and verify both. Proposed planning targets are RPO ≤24 hours/RTO ≤1 business day for private research prototypes and RPO ≤15 minutes/RTO ≤4 hours for production Cloud metadata; these are unapproved targets, not achieved guarantees. Cost, rights and service commitments must ratify them before deployment. Billing outbox durability and no double-charge recovery remain mandatory regardless of target.

Restore into an isolated environment, verify object checksums and FK/lineage consistency, replay revocations/key denials, reconcile in-flight jobs and usage, then obtain operator release before routing. Rehearse restore and credential rotation; backups containing deleted data expire under the approved schedule and cannot reintroduce it into active use.

CI stages: documentation/schema compatibility; application tests; isolated migration replay and authorization tests; worker fixture jobs; signed artifact provenance; synthetic integration; independent security/release approval. Build once, promote immutable artifacts through environments. Database roll-forward/recovery plans accompany each additive migration; no destructive rollback or automatic production migration on app startup. Deployment remains a separately authorized milestone.

## Data Studio module

The MVP adds isolated /studio and /api/studio routes within apps/reviewer-portal, reusing Next.js/TypeScript/Supabase while preserving all reviewer routes. A private data_studio schema and private quarantine bucket separate contributions from research and reviewer records. App enablement is default-off and organization/project membership is granted through scoped invitations; no default authority is seeded. Authenticated RPCs enforce contributor scope. A server-only service-role completion RPC persists AI results and cannot be called by contributors; its credential custody remains a real-onboarding review gate. Offline deterministic assistance requires no external credentials. Future parsers/scanners run in constrained workers; external provider credentials, processing consent and region/retention policies are separately reviewed. No offline cache or collection deployment is introduced by the design.

