# Tafsiri architecture consistency review 001

Status: architecture review, 2026-11-20 UTC. Scope is repository documentation/contracts and PR dependency metadata. No live database audit, runtime validation of planned components or linguistic research was performed. [Reference architecture](tafsiri-platform-reference-architecture-001.md) is the integration entry point.

## Reconciliation and invariants

| Invariant | Cross-document result and consequence |
|---|---|
| One research pipeline | Registry profiles feed existing candidate generation; exporter extends its governed boundary. Model training is a downstream consumer, not a replacement ingestion pipeline |
| One Reviewer Portal | Future multilingual review and Lab human evaluation use the existing app; Lab/Cloud UIs have different purposes |
| One language registry | Existing languages/dialects IDs plus 013 metadata; Cloud catalog is a release projection without independent identity authority |
| One provenance system | Source/version/artifact/import/entry/evidence remain Research Core records; Lab manifests retain references and derived artifact checksums |
| One Canonical Lexical Core | 011 is authoritative; legacy dictionaries and model registries are not competing lexical truth |
| One promotion framework | 012 governs lexical decisions, 013 fails closed for unsupported scope inputs; future policy revision extends it rather than bypassing it |
| No classification authority inference | Every assignment, dataset, route and qualification checks exact identities; disputed parents and aliases grant nothing |
| Human verification differs from canonical approval | Portal annotations and evidence decisions cannot execute canonical promotion; independent qualified authority remains required |
| No automatic training permission | Dataset export/run approval checks purpose-specific current rights and consent separately from canonical status |
| No automatic commercial clearance | Research release, commercial clearance, production approval and active deployment are separate attributed decisions |
| No Cloud privileged research access | One-way minimal artifact transfer, separate stores/credentials, signed eligibility feed; no request-time research lookup |
| No unsupported operational claims | Baseline table labels deployed historical foundation, unmerged 011–013, and planned Lab/Cloud separately; schemas are documentation only |

Earlier conceptual registry lifecycle is superseded for implemented behavior by 013's owner-reviewed REGISTERED state. Earlier Model Lab/Cloud documents remain foundational governance decisions; this series supplies technical contracts, intermediate RESEARCH_RELEASE_APPROVED state and deployment mechanics. Old audits saying 011 did not exist are dated observations. The documentation index now directs readers to this integration status rather than silently rewriting historic evidence.

## Decisions and tradeoffs

Choose a modular backend per trust domain with separate execution workers; defer microservices/distributed training until measured need. Prefer existing stack and explicit versioned adapters. Start with private immutable experiment manifests; MLflow is a collaboration option, not governance authority. Keep Cloud physically/credential isolated from research even at small scale. Use expiring eligibility leases rather than assuming a transferred signature permits serving forever; this trades availability during control-channel outages for bounded unauthorized use.

Preserve original text and exact orthography; analytical normalization does not establish linguistic equivalence. Avoid invented native vocabulary or pan-Luhya blending. Explicit uncertainty may reduce apparent translation coverage but represents actual supported scope. Machine provenance remains visible after human review. Billing's initial successful-input-character policy is a proposal requiring business ratification, not a price or existing service promise.

## Open decisions and blockers

| Decision/blocker | Accountable future owner | Resolution/gate |
|---|---|---|
| Independent review and integration of PRs #22–#26 | Maintainers/database reviewer | Ordered merge plan; fresh hosted schema/grant/backup checks before deployment |
| Auth-to-registry gateway and typed study targets | Portal/security owners | Reviewed delegated identity contract and additive migrations; M2 activation blocked until tested |
| New-scope canonical promotion policy | Research/database governance | Digest and authority extension for 013 source scopes, regression/race tests; no bypass of existing guard |
| Legacy exposure and privileged export paths | Security owner | M3 remediation or independently tested isolation; P0 blocks protected data |
| Rights-aware export and real-data eligibility | Dataset steward/research authority | M4 plus M12 lineage, purpose, consent and qualifications; no real-data authorization here |
| Base model, dependency versions and compute provider | Lab lead/platform owner | Bounded approved experiment, license/hardware benchmark and budget before M6 real compute |
| Per-scope evaluation thresholds and hidden benchmarks | Linguistic/evaluation leads | Predeclare coverage/error/uncertainty criteria before M7 release evaluation |
| Signing algorithm/provider, lease duration and incident SLO | Security/release owners | Threat review, custody/revocation and outage tests before M8 production approval |
| Pricing, meter policy, provider and enterprise terms | Commercial owner | Ratify versioned commercial policy and reconciliation tests before billing activation |
| Region, retention, RPO/RTO and service SLO values | Platform/privacy/service owners | Cost/rights/operational review and measured restore/load evidence before launch |

These open operational choices have bounded owners and gates; they do not require architecture-only work to execute recruitment, rights remediation, security migrations or deployment. No applicable legal clearance or compliance certification is implied.

## Validation record

Executed checks: local Markdown link/fragment existence and balanced fences; JSON parsing and all 110 local JSON reference resolutions; Draft 2020-12 schema validation with `jsonschema`; OpenAPI 3.1 validation with `openapi-spec-validator`; equality of five shared schema definitions; two synthetic valid translation contract examples and five invalid-shape rejection checks; and `git diff --check`. Validators were installed into a temporary directory without changing project dependencies. Mermaid fences were checked but diagrams were not rendered. External primary documentation was consulted for technology choices; this was not an exhaustive external-link crawler.

These checks validate documentation and contract structure only. Requirements elsewhere are future acceptance tests, not claimed passing runtime coverage. No application, migration, training or serving behavior is implemented by this series, and no application/database tests were rerun for this documentation-only change.

All ten requested architecture deliverables are linked from the reference document. Two machine-readable contract files supplement the catalog. The branch is stacked on PR #26; prior PRs and hosted data remain unchanged.

## Data Studio amendment review

Data Studio corrects the assumption that a language must already have a corpus: a private proposed-language collection project can start with zero data. It is a collection/intake module, not a replacement research pipeline, registry or Reviewer Portal. Unapproved labels remain proposals. The AI assistant is replaceable and outputs only MACHINE_GENERATED/UNVERIFIED suggestions with evidence provenance. Source registration and qualified review remain independent gated handoffs. Collection volume never implies dataset/model readiness. The synthetic implementation report must distinguish tested contributor/admin capability from deferred external AI, scanner, source-registration and reviewer integrations. Real collection, hosted migrations and deployment remain unauthorized.

