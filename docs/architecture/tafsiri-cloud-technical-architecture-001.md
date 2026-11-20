# Tafsiri Cloud technical architecture 001

Status: planned SaaS specification; no customers, billing or inference are activated. This extends the [commercial boundary](tafsiri-cloud-commercial-architecture-001.md) using the [release contract](tafsiri-model-release-and-commercial-handoff-001.md).

## Identity, tenancy and ownership

Cloud has its own identity audience, database credentials and deployment roles. Organizations own memberships, keys, subscriptions, terminology versions, service jobs and usage. Roles are owner (membership/organization), administrator (configuration/keys), developer (scoped inference), billing administrator (invoices/usage), and auditor (approved metadata). Enterprise accounts add contract entitlements and federation later; no role receives research authority.

Derive tenant and key scopes from a verified credential, never request-body tenant IDs. Every database query, job, object path, cache key and usage event includes the authorized tenant. Foreign keys should include tenant identity where needed to prevent cross-tenant associations. RLS and route checks must agree; workers receive narrowly scoped job capabilities. API secrets are randomly generated, displayed once, securely hashed server-side, expiring and revocable. Store a nonsecret prefix for identification; rotation supports a bounded overlap. Organization membership removal invalidates sensitive access without relying solely on stale token claims.

## API and routing

The documentation-only [OpenAPI contract](contracts/tafsiri-cloud-v1.openapi.json) defines `/v1/languages`, `/v1/capabilities`, `/v1/translate`, `/v1/models/{model_version}`, `/v1/usage` and key management. The [catalog](tafsiri-api-and-data-contracts-001.md) defines semantic validation beyond JSON shapes. These paths do not exist as a result of this task.

Translation requires explicit source/target language OR variety IDs and orthography versions. Resolve those against an approved catalog projection, tenant entitlement, allowed region and an immutable active release. Classification, alias similarity or a shared language parent never select another variety. A model pin must be available and eligible; never silently replace it. Language identification, conversational and speech services are separate future capabilities requiring evaluated contracts, consent and their own quotas; they are not implied by translation.

Return selected model/release, exact scopes and outcome. `translated` includes output text; `uncertain` includes an approved reason code and optional preserved original text but no invented translation/confidence. A known established native or borrowed term may be used; otherwise preserve the original term and explain only if that explanation is validated in the requested variety. If uncertain, abstain. Unsupported scopes return 422; policy-denied scopes return 403 without private rights narratives; temporary service/revocation-feed unavailability returns 503. Never claim a probability is calibrated without evaluation evidence.

## Request and billing flow

1. Authenticate, validate schema/size, derive tenant, check direction/model/region and current release eligibility.
2. Bind an idempotency key to tenant, route and request digest. Same key/different body is 409. Raw text is never logged in the idempotency index; encrypted replay material has a bounded policy-controlled TTL. Retention-off still allows transient processing, with no durable text history.
3. Atomically reserve quota and concurrency before enqueueing. Bound queue depth and deadline; return 429 with Retry-After for quota/rate limits, 503 for capacity exhaustion. Cancellation/timeout releases unused reservations.
4. Execute under a job lease. Recheck release before dispatch and before publishing output. A revoked release yields no new successful response.
5. Commit one terminal request record and one outbox usage event. Retries replay status or the response only while permitted transient replay material exists; otherwise return `result_expired` and never execute/charge again under that key.
6. Deliver usage at least once. Consumers deduplicate on event ID and tenant/request/charge dimension. Reconcile reservations, completed requests, meter ledger and provider invoices; orphaned work must not cause duplicate charges.

Initial metering proposal: Unicode scalar count of original input, before normalization, recorded with `meter_policy_version`; successful translated requests are billable, denied/uncertain/failed/cancelled requests are not. Record resource consumption separately for operations. A future business approval may select another policy only as a new version with explicit effective date, never by retroactively reinterpreting old events. Avoid platform-dependent UTF-16 length as billing count.

Plan versions define entitlements, included units, quota period/timezone, overage policy, concurrency and rate limits, independent of pricing amounts. Subscriptions bind a plan version and effective interval; enterprise contract overrides are explicit bounded entitlements, not rights overrides. A provider-neutral billing adapter maps deduplicated ledger entries to provider usage/invoice references. Signed webhook verification, replay protection, ordering tolerance and reconciliation are required. Monetary totals use fixed decimal/minor units and currency; adjustments are new ledger events, not edits. Customer analytics aggregate text-free usage by period/model/direction. No provider, price or payment integration is selected here.

## Serving and enterprise

Begin with a Python container serving adapter for approved model families and one worker pool per required hardware class. CPU may suit small/quantized models; select GPU only after measured latency/memory/throughput evaluation. A generic Transformers-backed worker favors compatibility initially; specialized batching engines are an implementation benchmark decision, especially for encoder-decoder and adapter support. Model weights/tokenizers cache by verified digest; evict revoked artifacts. Private request/response caches are off by default and never shared across tenants.

Autoscaling follows queue age, concurrency and GPU memory, with bounded warm capacity and tenant fairness. Readiness means the exact approved release is loaded and its health probe passed. Drain before rollout; use canary cohorts and atomic routing updates. Retry another worker only for idempotent work; failover must preserve release, direction, rights and region restrictions. If no compliant capacity exists, fail closed. Rollback uses a still-cleared release; it cannot override revocation. Define measured SLOs/capacity budgets before production approval rather than promising arbitrary availability.

Enterprise extensions include private deployments with signed offline bundles and bounded revocation leases, tenant-specific reviewed terminology versions, declared retention/deletion schedules, compliance evidence and region-bound processing/storage/backups. Terminology is tenant-owned, may not silently broaden model language support, and requires evaluation and rights for fine-tuning. Support access is time-bound and audited. Translation history is opt-in, tenant-isolated and deletable according to an approved retention schedule. Compliance certification is not claimed. Monitor text-free latency, errors, saturation, cost, quality feedback, revocation lag and billing reconciliation.
