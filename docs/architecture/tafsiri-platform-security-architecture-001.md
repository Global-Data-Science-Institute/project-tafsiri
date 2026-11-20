# Tafsiri platform security architecture 001

Status: design and future remediation requirements only. No policies, grants, identities, rights or consent records change. Builds on [legacy triage](../security/legacy-advisor-triage-001.md) and [013 hardening plan](../security/multilingual-foundation-hardening-plan-001.md).

## Trust and authority model

| Principal/domain | Allowed authority | Explicit exclusion |
|---|---|---|
| Reviewer Auth subject | Own participation and qualified assigned tasks | Self-reported expertise, email or classification cannot grant authority |
| Qualification issuer | Evidence-backed finite exact-scope/task grants | No self-approval or automatic canonical approval |
| Research contributor | Individually bound database principal with operation/scope authority | Shared service/owner login cannot stand in for a human approver |
| Project researcher/PhD collaborator | Approved project datasets, runs and results | No protected research DB or unrestricted source storage |
| Dataset steward/exporter | Purpose-limited reads and approved snapshot publication | No automatic training rights from canonical verification |
| Evaluator/rights/release authorities | Separate attributed decisions bound to artifact digests | No single mutable model tag or admin flag grants commercial clearance |
| Cloud tenant user/key | Own organization resources and permitted service operations | No research identity inheritance or cross-tenant access |
| Operator/owner | Audited privileged maintenance under separate approval | Owner bypass remains a trust risk, not something RLS eliminates |

Apply authenticated identity plus current resource scope at every boundary. RLS supplements explicit grants, API schema exposure and worker/storage policy; it does not protect against an owner or careless privileged export. Views and definer functions require explicit security review. Never use editable user metadata as authority or expose secret/service-role keys in browser bundles. [Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security).

## Rights, consent and export policy

Source receipt, evidence verification, canonical approval, dataset admission, research release and commercial release are independent decisions. Export validates exact artifact/entry/revision lineage, current permitted purpose, applicable consent, retention/region restrictions and finite approver authority. UNKNOWN, REVIEW_REQUIRED, conflicting or expired permission denies use. Training and COMMERCIAL_API permission are independently required; public accessibility or a citation is insufficient. Review display, benchmark publication and redistribution need their own relevant decisions.

Export is a server-side private operation with an immutable manifest and current-policy revalidation immediately before publication. Short-lived access grants bind project, dataset/version, purpose and expiry. Recheck permissions at training admission, periodically during execution and before model/release publication. Source changes invalidate dependent eligibility through lineage events. Tenant feedback is unverified intake and excluded from training absent explicit approved consent and review.

## Threat model and future tests

| Threat | Required control and verification |
|---|---|
| IDOR/cross-tenant or cross-language reads | Exact object/scope ownership at SQL, API, queue and storage; direct UUID and forged tenant tests |
| Forged qualifications/stale claims | Trusted grant store, issuer separation, expiry/revocation checks per operation; revoked session/qualification tests |
| Dataset poisoning and fabricated lexical truth | Preserve machine/source origin, independent review, canonical governance and immutable lineage; no automatic feedback promotion |
| Model/image/checkpoint supply-chain attack | Allowed digests/formats, quarantine, dependency/license review, signed releases and constrained execution; reject arbitrary remote code |
| Training exfiltration | Project-limited mounts, network egress, short-lived tokens, bounded logs and resource budgets; hostile synthetic job tests |
| Rights time-of-check/time-of-use | Transactional export checks, run revalidation and signed bounded serving leases; revocation during work tests |
| Secret/text leakage | No raw prompts, source text or keys in telemetry; storage/log/cache inspection and redaction tests |
| Billing replay/abuse | Quota reservation, bounded requests, unique ledger dimensions and signed webhook deduplication; concurrent retry/reconciliation tests |
| Privileged insider or lost audit | Separate operators/approvers, protected audit sink and access review; failed outer DB transactions require infrastructure audit coverage |
| Backup or rollback resurrects revoked material | Restore quarantine and latest revocation/key state before activation; destructive recovery rehearsal with synthetic data |

## Legacy findings and deployment impact

Historical production inspection and fresh local synthetic advisors are different evidence sets. The 013 local validation records 22 ERROR/29 WARN, including additional policy warnings from synthetic roles; this task performs no hosted advisor scan. Counts alone are not exploitability assessments.

| Finding | Severity/impact | Required future disposition |
|---|---|---|
| 16 legacy public tables without RLS | High confidentiality/integrity risk where grants/API exposure permit private text or writes | P0: inventory consumers and exposure; new least-privilege/RLS migration or independently tested isolation before protected data |
| Six definer views | High potential bypass/projection risk | P0: inspect dependencies/owner/grants; invoker behavior or restrict exposure with compatibility tests |
| Public submissions INSERT and SELECT | High poisoning and potential disclosure | P0: scoped intake, ownership, read restriction and rate controls; test direct API bypass |
| Public alias assumptions | Scope confusion/unauthorized classification inference | P1: exact IDs for new paths; separately restrict unsafe legacy writes |
| Duplicate permissive policies/auth initplan warnings | Lower confidentiality risk for intended public metadata; performance/maintenance | P2: equivalent-policy consolidation and query-plan tests |
| vector extension in public | Medium attack-surface concern, not proof of leakage | P2: dependency inventory and supported privilege/location review |

New private tables do not repair unsafe legacy paths. Real protected data deployment requires remediation or security-owner-approved technical isolation demonstrated end-to-end. Do not put private text in public concepts, legacy dictionaries, submissions or analytics to bypass a denial. Existing hardening plans contain affected object lists and migration acceptance criteria; this document does not authorize their execution.

## Keys, audit, retention and incidents

Separate signing, API, deployment, database and encryption keys by environment and purpose. Use managed custody, scoped issuance, rotation, revocation and audited recovery. Release signatures require trusted key IDs and freshness; an unknown/revoked key fails closed. API key plaintext is shown once and never retained in logs. Privileged break-glass access is time-bound, attributed and independently reviewed.

Audit records carry actor/service identity, effective scope, action, target version/digest, decision/policy, request/correlation ID and time. Append-only domain events feed a restricted tamper-evident archive with independent custody; no claim that database triggers defeat owners. Audit access is itself logged. Retention schedules distinguish source binaries, reviewer personal data, research approvals, models, tenant text, billing records and operational logs; owners must approve durations and deletion exceptions before activation. Minimize retained personal data and retain tombstones rather than prohibited payloads where possible. No legal compliance conclusion is made here.

Incident response: detect and classify; security owner coordinates containment; revoke affected access/releases and stop jobs; preserve minimum protected evidence; determine tenants/data/lineage affected; notify designated governance and customer owners under approved obligations; remediate in a separately reviewed change; validate recovery and publish an internal post-incident record. Release operators cannot reactivate a revoked model as an availability workaround. Security, rights and operational acceptance must all pass before production approval.
