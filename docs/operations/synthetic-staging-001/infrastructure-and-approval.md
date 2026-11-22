# Isolated synthetic infrastructure specification and approval request

**Proposed only. No hosted resource was created or changed. Approval recommendation is blocked by S01–S03.** The new environment must never point to `gfhdwmqefotkljrltfnx` or `ydkookidvipqrwuilqeu`, reuse their keys, restore their data or share their Storage buckets.

## Exact proposed resource envelope

| Resource | Specification |
|---|---|
| Supabase | New project named `tafsiri-synthetic-validation-001`, new isolated organization preferred, Pro/Micro, us-east-2. PostgreSQL 17 supported release, exact version captured at provisioning. Dedicated Auth, database, Storage and keys; no branch/clone of an existing project |
| Vercel | New project `tafsiri-synthetic-validation-001`, root `apps/reviewer-portal`, Next.js lockfile, Node 22.x matching CI. Dedicated synthetic project's production environment (not the research project's production environment). No Git auto-deploy; deploy only exact approved commit manually after authorization |
| Candidate URL | Provider-generated deployment URL plus `tafsiri-synthetic-validation-001.vercel.app` only if available. No existing/custom research domain. Capture exact issued hostname and deployment ID in approval execution record; block DNS/promote until protection is verified on both unique URL and alias |
| Protection | Per-project paid Password Protection covering all relevant production/deployment domains, plus Vercel account access controls for operators. Test anonymous document and API requests receive protection challenge; test authorized browser access. Store password outside source/PR. Standard protection alone must not be assumed to protect the alias |
| Worker host | One new DigitalOcean Basic regular 8 GiB / 4 vCPU / 160 GiB VM, NYC1, Ubuntu LTS; reserve 4 GiB/2 CPUs/64 PIDs/256 MiB tmpfs for one non-root scanner container. Remaining headroom for OS/updater/monitoring. No public application ports; SSH restricted to approved operator IPs or private access, MFA/control-plane audit |
| Storage | New private `studio-quarantine`, 5 MiB/object and approved MIME list, no ordinary update/delete. Distinct encrypted backup destination on separate custody; no public URLs or public buckets. Initial maximum 100 files/500 MB |
| Accounts/data | Two synthetic institutions, at most ten synthetic users, 100 contributions, seven-day acceptance window. Reserved `.example` identities, randomly generated unique passwords, no real user names, speech or vocabulary |
| Operator access | Named deploy operator + independent reviewer + recovery operator; MFA; no shared personal logins. Short-lived GDSI metadata bootstrap authority; no permanent broad content access grant |

The VM selection is a proposal, not provisioning authorization. Cross-region latency between NYC1, us-east-2 and the Vercel region must be measured; no latency SLO is claimed. Capture actual provider region/version/IDs in a private operator ledger. New hosted IDs cannot be truthfully supplied before provisioning; the specification binds creation to names, scopes, limits and the denylisted existing refs.

## Auth, secrets and network boundaries

Disable public signup, anonymous Auth, social providers, SMS and SMTP delivery. Pre-create confirmed synthetic accounts through an approved operator-only Auth procedure after future authorization; this simulates confirmation, not mailbox ownership verification. Set site URL and redirect allowlist to the exact protected candidate `/auth/callback` and approved recovery routes; no wildcard/localhost redirects. Proposed access-token lifetime 900 seconds; active-session DB checks remain mandatory. Record per-IP Auth rate limits and test them without bulk traffic. For no-email recovery tests, operator generates a one-use recovery link and transfers it privately to the test browser; never send a message or log its token.

Use the RC environment template with the **new** project ref, `DATA_STUDIO_ENABLED=synthetic`, `STUDIO_ENVIRONMENT=synthetic-staging`, mock email, live-email false and external-AI false. Do not set OpenAI/Resend credentials. `NEXT_PUBLIC_*` contains only app URL and new public Supabase URL/publishable key. Create separate named server and worker secret keys where supported; both still carry service-role power, so document blast radius. Server key only in the dedicated Vercel project's sensitive production scope; worker key only in the VM secret store. No shared/inherited variables, no secret-bearing preview builds, no worker key on Vercel. Backup custody is separate from the scanner key. Export metadata names/scopes to the review record without secret values.

Database connections require TLS and operator IP restrictions where supported. Data API/Auth/Storage endpoints remain Internet-addressable for browsers: database network restrictions and Vercel protection do **not** automatically close those endpoints. S03 therefore requires a versioned review of legacy grants/views/RPCs before exposing the project; the exact additional migration and checksum are an outstanding preflight dependency. Do not claim that the current sixteen migrations alone implement a hardened public API.

Scanner container has no inbound listener and no general Internet access. A separate trusted supervisor downloads/upload bytes to the new project's Storage and calls worker RPCs over TLS; scanner execution itself has no credentials. Permit updater egress to official ClamAV signature endpoints and DNS only, and supervisor egress to the exact new Supabase endpoint. Signature update must be signed, load-tested, timestamp-validated and atomically activated; scan containers get a read-only versioned signature snapshot. Do not run an untrusted file parser with the broad service key in its environment. The current in-process worker needs a reviewed supervisor/container packaging implementation to realize this boundary; local harness demonstrates the split, not a production installation.

## Scheduling, monitoring and recovery

Use a single non-overlapping systemd oneshot supervisor with `OnUnitInactiveSec=60s`, batch at most 25, per-engine 45s deadline, total job deadline 25 minutes. Never overlap purge and recovery/cutover. Leases remain authoritative; a stopped worker must not be restarted by falsely marking files CLEAN. Run purge separately once/hour after PI approval; minimum seven days, no active hold. Freshclam cadence hourly; alert if signed age exceeds 24h, fail closed at approved maximum 48h. No timers have been installed.

Collect counts/ages/exit codes only: oldest PENDING >10m, ERROR repeats >3, expired PURGING >5m, delivery PREPARED >5m, no successful worker heartbeat >5m, signature age, resource kills, auth rejection spikes and backup age >24h. Alert the named operator in the existing approved monitoring channel only after separate authorization; this task sent no notifications. Manual fault injection must prove alert delivery/acknowledgement before acceptance. Platform access logs must redact invitation query tokens; no content-bearing error trackers/session replay.

Proposed synthetic RPO <=24h and RTO <=4h are **targets to measure**, not established guarantees. Nightly database backup plus separate object bytes/manifests; quiesce writes for a consistent acceptance snapshot. Keep encrypted backups seven days, metadata evidence thirty days. Restore to a new disposable recovery project (not existing research staging), preserve schema/grants/RLS, verify every object hash, revoke restored sessions/invites and replay deletion tombstones before access. Budget includes a temporary recovery Micro instance. Hosted PITR is not included in the estimate and must not be advertised as tested.

## Cost envelope (USD, checked 2026-11-22)

| Item | Monthly planning allowance |
|---|---:|
| Dedicated Supabase Pro organization, first Micro | $25 |
| Temporary second Micro for recovery | Up to $10 |
| Dedicated Vercel Pro plan, one deploying seat | $20 |
| Per-project Password Protection | $20 |
| DigitalOcean 8 GiB Basic worker VM | $48 |
| Encrypted backup storage / small usage contingency | $10 estimate, not a provider quote |
| Total planning allowance | **$133/month before taxes/overages** |

Request a **$150 maximum first-month budget**, with alerts at $75/$120 and stop/review at $150; no paid upgrades or overage approval is implied. Some monthly fees may not prorate for a seven-day test. Extra deploy seats, static IP add-ons, paid log drains, PITR, egress and taxes are excluded and require revised approval. Existing subscriptions may lower incremental cost, but the envelope deliberately does not assume access to them. Confirm checkout prices before creating resources.

Sources: [Supabase pricing](https://supabase.com/pricing), [Vercel Pro pricing](https://vercel.com/docs/plans/pro-plan), [per-project protection pricing](https://vercel.com/changelog/password-protection-now-costs-20-per-project-per-month-on-pro), [DigitalOcean Basic pricing](https://www.digitalocean.com/pricing/droplets). Deployment protection scope must follow [Vercel's current documentation](https://vercel.com/docs/deployment-protection).

## Explicit approval request — prepared, not executed

After S01–S03 remediation and independent review, request authorization for **one seven-day synthetic validation environment** within the resource envelope and $150 cap above: create the new primary project, protected app and worker VM; apply the approved checksum manifest plus reviewed remediation migration; deploy the exact approved commit; create only listed synthetic accounts; execute the acceptance plan including a separate recovery target; then remove only these recorded resources. Email and external AI stay off. No merge into existing staging, existing-project writes, authentic data or commercial endpoint is included.

Approval record must identify approver, operator, independent reviewer, final commit/migration checksums, scanner image digest, budget cap, account allowlist, dates, and exact created resource IDs/URL before activation. The future operator must present the actual dry-run and URL protection evidence before opening test access. This packet is **not ready for unconditional approval** because the required parser/freshness/legacy remediation is not implemented under this planning-only assignment.

Teardown is limited to resources created under that future approval: disable candidate access and timers, revoke test sessions and keys, export metadata-only results, purge test objects/backups according to the agreed deadline, remove the new recovery/primary projects, app and VM, and verify billing/service removal. Compare each ID against the creation ledger and refuse the two existing Tafsiri refs. Deleting any existing resource is excluded. No teardown command was executed against a hosted service.
