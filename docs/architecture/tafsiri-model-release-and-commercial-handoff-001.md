# Tafsiri model release and commercial handoff 001

Status: proposed approval and artifact-transfer protocol. Neither this document nor a registry capability activates a model. See [Model Lab](tafsiri-model-lab-technical-architecture-001.md) and [Cloud](tafsiri-cloud-technical-architecture-001.md).

## Lifecycle and independent authority

| State | Required transition evidence and authority | Permitted use |
|---|---|---|
| EXPERIMENTAL | Project-authorized completed run; immutable artifact/lineage record | Approved project research only |
| EVALUATED_RESEARCH | Independent evaluator signs report against frozen benchmark/protocol and exact artifact digest | Evaluated research within report scope |
| RESEARCH_RELEASE_APPROVED | Research release authority approves model card, research sharing/redistribution rights and limitations | Only approved research distribution/use |
| COMMERCIALLY_CLEARED | Rights authority approves every dataset, source, base model, adapter/tokenizer and derivative obligation for purpose/territory/term | Eligible for production review, not serving |
| PRODUCTION_APPROVED | Independent release authority approves quality, security, capacity, operations, retention and rollback evidence | Eligible for controlled deployment |
| ACTIVE | Deployment operator verifies signed release and receiver acceptance, then records rollout | Serving only approved scopes/regions/tenants |
| RETIRED | Operator/owner closes routing; historical record retained | No new serving; reactivation requires fresh current approval |
| REVOKED | Authorized rights/security/research owner records blocking event and affected lineage | No new use; quarantine/withdraw/delete as required |

State transitions append decisions rather than rewriting history. Denied transitions remain at the prior state with reasons. REVOKED is terminal for that release identity; remediation creates a new release and fresh approvals. A model may have separate releases for different scope/region sets. No contributor, project administrator or deployment operator automatically holds all approval roles. The model author cannot be the sole evaluator/release approver; rights and production decisions are separately attributable with current finite authority.

## Manifest and transfer

The [contract catalog](tafsiri-api-and-data-contracts-001.md) defines CommercialRelease v1. Bind release/model version; artifact list with digest, size and format; runtime image/tokenizer/base/adapter digests; dataset manifest and evaluation report hashes; exact direction/orthography scope; permitted regions/use; license and clearance references; research and production approvals; validity; revocation stream/lease reference; model card; issuer/key ID and signature.

Keep two projections: the private Lab dossier contains full lineage and approval evidence; the Cloud manifest contains only approved minimal identifiers/digests, restrictions and verifiable decisions. Dataset hashes are traceability references, not downloadable dataset links. Cloud never gets source text, reviewer identities, privileged URLs or research DB credentials. A dedicated publisher reads only approved release objects and writes a separate transfer bucket. The receiver has read access only to transferred artifacts and writes its own Cloud registry; neither side opens a cross-database connection.

Hash exact UTF-8 manifest payload bytes (detached signature avoids self-reference); publish the canonicalization/serialization version and reject duplicate JSON keys. Sign a domain-separated envelope containing payload digest, release ID, issuer, key ID and validity with an approved asymmetric key held in managed key custody. Algorithm/key-management provider selection requires security review at implementation. Verify key trust, validity, digest/size of every object, approvals, scope and current revocation before accepting. Uploaded artifact bytes remain quarantined until validation completes; unexpected files or executable model code require explicit review, never automatic loading.

Publisher idempotency is release ID plus immutable payload digest. A conflicting replay is rejected; identical transfer returns the prior receipt. Cloud receipt records verified digests, time, signing key, approval references and receiver version. Production deployment is a separate action with actor, environment, image/release digest, rollout policy, canary results and previous release. Signing proves provenance of the approval package, not legal sufficiency or linguistic quality.

## Revocation, freshness and rollback

The approval authority publishes signed monotonic revocation events and short-lived eligibility leases to Cloud through the same separate handoff channel. Each lease names release, sequence, issue/expiry and approved scope. Cloud stores its last accepted sequence, rejects replay/rollback and stops dispatch when the lease expires or the feed cannot satisfy freshness policy. The maximum lease duration and incident propagation SLO must be approved before production; there is no indefinite offline serving. A private deployment follows the same bounded lease policy or receives no commercial release.

On revocation: block routing and new jobs, cancel/drain affected in-flight work, prevent output publication, evict caches, identify dependent releases and notify operational owners. Decide withdrawal/deletion/retraining through documented governance; deleting a source does not prove a trained model has forgotten it. Audit tombstones preserve necessary accountability without retaining prohibited content.

Rollback selects the last healthy artifact whose rights, approvals, signatures and lease remain current for the exact scope/region. If none exists, service becomes unavailable. Restoring a database backup must first replay newer revocations and key deny lists before serving. Re-evaluation after a material model/runtime/tokenizer change creates a new release, even when the friendly model name is unchanged.

## Future verification gates

Test altered bytes, mismatched tokenizer/base adapters, expired authority, missing source commercial clearance, stale leases, revoked signing keys, duplicate/conflicting transfers, out-of-order revocation, in-flight cancellation, regional failover denial and rollback to revoked artifacts. Demonstrate that Cloud credentials cannot connect to research stores and that transfer manifests omit private fields. A full synthetic trace must connect source fixture → dataset → run → model → evaluation → approvals → release → request/usage without creating real linguistic or commercial claims.
