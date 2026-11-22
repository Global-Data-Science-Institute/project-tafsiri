# Partner RC 001: synthetic staging operations

Status: prepared for review, **deployment blocked pending the gates below**. No hosted resources, credentials, migrations, email delivery, or AI processing were activated. This runbook extends PR #28 rather than replacing the research pipeline.

## Environment inspection and proposed boundary

Read-only inspection on 2026-11-22 found Supabase staging `gfhdwmqefotkljrltfnx` active and migrated only through `20260928015644_create_source_artifact_foundation` (010). The subsequent architecture/lexical/registry/Studio stack has not been applied there. Vercel project `tafsiri-reviewer-portal` has deployment protection configured as `all_except_custom_domains`. That setting does not prove protection on a custom domain. Secret values and complete hosted environment-variable assignments were not inspected.

Use a **new, separately authorized synthetic Supabase project and protected application environment**, with its own Auth, Storage, secrets and operator access. Runtime guards reject the existing staging and production project refs, mismatched project URLs, and Vercel preview environments. Both RC and baseline Studio branches disable automatic Vercel deployment. Do not merge merely to deploy. The proposed variable names and disabled defaults are in [partner-rc-001.env.example](partner-rc-001.env.example); it contains no credentials. No project has been provisioned from this template.

Before deployment, an operator must inventory hosted environment-variable *names and target scopes*, prove that preview builds contain no production or Studio privileged secrets, and verify protection on the exact candidate URL. Use a dedicated Vercel project or approved custom environment; the application's preview guard deliberately rejects ordinary previews. Browser code receives only public URL/publishable key. Server and worker secrets stay in their separate secret stores. The Supabase service key is broad: database RPC grants narrow its intended use but do not narrow its Storage/Auth capability. Dedicated scoped worker identities and custody/rotation review remain real-data gates.

## Migration and deployment sequence

1. Review and resolve the open stack PRs #22–#28, including both lexical and registry changes. Confirm the exact candidate commit and migration list. Do not apply just the RC migration: it depends on `20261120032711_data_studio_private_intake.sql` and its predecessors.
2. Obtain explicit authorization for the new synthetic environment and planned migration sequence. Record project ref, operator, commit and rollback owner. Never run a linked reset or apply this stack to existing research data as a shortcut.
3. Create the separate environment, configure approved Auth redirects and confirmation/recovery, private Storage, deployment protection and environment-specific credentials. Keep email mock and external AI disabled.
4. Review the CLI migration dry run against that new ref, then apply the versioned sequence once. Confirm every private Studio table has RLS, no ordinary direct schema/table access, service-only worker RPCs, and a private quarantine bucket. Missing active Auth sessions must fail even with an otherwise unexpired JWT.
5. Deploy the reviewed app only after separate authorization. Install and exercise the scanner before accepting attachments; keep worker credentials off the frontend host. Run synthetic acceptance with independently created institution accounts. Local seed credentials must never be used in hosted staging.
6. Require a second reviewer to sign the security and operational evidence before enabling any partner access. Synthetic acceptance is not permission for real data, external AI, training, canonical promotion or ingestion.

## Scanner and retention operation

The worker is `apps/reviewer-portal/scripts/studio-worker.mjs scan|purge`. `--local` only accepts the isolated API on 55621 and uses an explicitly labeled synthetic mock. Hosted mode requires the approved project ref, exact URL, `synthetic-staging` environment and explicit worker authorization flag. There is no deployed scheduler.

Install ClamAV on a constrained worker host with a read-only signature directory, dedicated temporary directory, no public inbound endpoint, restricted outbound access and bounded CPU/memory. Supply absolute binary/database paths. Maintain signatures with an operator-owned freshclam service. The adapter rejects missing/stale daily signatures, invokes without a shell, imposes process/file/recursion limits, verifies the original upload hash and size, and removes temporary bytes. A real engine with current signatures, clean text/PDF/audio fixtures, EICAR, malformed/encrypted files, timeout and resource-limit cases must be tested before staging admission. The current tests exercise a stub engine contract and mock scanning, **not actual ClamAV detection**. Magic checks and the PDF active-content filter are conservative checks, not a full parser or sanitization guarantee. No extraction/transcription is enabled.

Schedule one bounded worker invocation per minute only after authorization; each invocation handles at most 25 objects. Scan leases last two minutes; ERROR retries wait five minutes. Monitor oldest PENDING/ERROR age and repeated failures; do not manually mark objects CLEAN to clear a queue. INFECTED stays inaccessible. CLEAN/MOCK_CLEAN files remain subject to exact membership, active session, ownership/reviewer permissions and withdrawal checks. No downstream evidence pipeline is activated.

`SYNTHETIC-RETENTION-1` is a test policy, not an institution-approved retention agreement. A contributor withdraws first, then requests deletion; a project PI approves after reviewing holds. The worker waits at least seven days from request and refuses a hold. Once PURGING starts, a new hold cannot be applied; stop the worker and involve the operator if an urgent legal hold arises. Storage removal precedes database scrubbing. Failures retain a retryable lease and cannot acknowledge completion while object metadata remains. Purge erases contribution content, event snapshots, idempotency copies, AI results and handoff content; IDs, original hashes and consent/rights receipts remain. This is not full account erasure. Approve retention periods, retained metadata, appeal/hold handling and backup expiry before real use.

## Invitation and account operations

Mock delivery is deterministic and sends nothing. The optional Resend adapter uses server-only credentials, a configured sender, a fixed provider endpoint, bounded timeout and delivery idempotency key. It sends only the invitation link and recipient address. Provisioning a sender/service and sending even test emails require separate authorization. Authorize a recipient allowlist and verify sender DNS, bounce handling, provider retention and support ownership before enabling it.

Resend creates a new token and seven-day expiry and invalidates older links. Same-request retries return a receipt without re-exposing the token or sending again. A network/process failure can leave PREPARED or FAILED; inspect the receipt and explicitly resend with a new request to recover. SENT means provider accepted, not inbox delivery. There are limits of five preparations per invitation/hour and fifty per actor/day. Expired invitations cannot be accepted; an authorized administrator may resend. Revocation, verified-email binding and exact invitation roles still apply. The last organization administrator cannot remove themselves until another administrator accepts.

Recovery uses existing Supabase Auth password recovery. It restores identity, never revoked membership. Configure approved recovery URLs and rate limits, test email delivery independently, and avoid revealing whether an account exists. Administrator replacement requires verified institutional authority and an audited operator procedure, not editable user metadata.

## Monitoring, incidents and key rotation

Application rejection logs contain event, bounded error code and random request ID only. Worker logs contain processed counts and environment label; database receipts contain scan/delivery/deletion state. Never log contribution bodies, Auth JWTs, invitation URLs, provider responses or secret values. Operators should alert on worker failures, scan backlog over ten minutes, stale signatures, expired PURGING leases, PREPARED deliveries over five minutes, elevated rejection rates, and unexpected service-key use. These thresholds are proposed; no hosted alerts or on-call system have been configured.

On suspected exposure: disable Studio and external providers, stop workers, revoke affected Auth sessions and memberships, preserve metadata-only incident evidence, rotate server/worker/provider credentials in their separate stores, redeploy the reviewed configuration, and rerun isolation checks. Report to the institution under its approved agreement. Do not export private content into issue trackers. Credential revocation must be tested with old credentials before reopening.

## Backup, restore and rollback

Local rehearsal commands, after Studio acceptance has created fixtures:

```powershell
python tests/studio/backup_restore.py
# From apps/reviewer-portal:
node scripts/studio-storage-restore.mjs
```

The database rehearsal writes an ignored synthetic archive, restores into a uniquely named disposable database, compares content checksum/counts/RLS/grants/private bucket, and removes only that new database. It preserves ownership using the local `supabase_admin` role. It is not a portable hosted restore recipe. The Storage rehearsal exports actual object bytes with SHA-256 manifests, restores to a new private local bucket, checks every checksum and anonymous denial, then removes only its test bucket. Database backups do **not** contain Storage bytes.

For hosted recovery, approve encrypted database backups/PITR plus independently versioned private object backups, restricted backup operators, key custody and retention. Set and measure institution-approved RPO/RTO (not established here). Capture application commit, migration versions, roles/grants, Auth/Storage configuration and deletion tombstones. Restore to a new isolated target with all external providers/workers disabled; verify database/Storage checksum correspondence, RLS, session handling and private bucket policies. Replay all deletion tombstones since the backup before opening access, expire restored invitation tokens and revoke restored sessions. Never resurrect deleted material into the live environment. Backups must expire according to the approved retention policy.

Prefer rolling forward additive fixes. To roll back the app, disable Studio and providers first, restore the last reviewed compatible deployment, and verify the expected migration contract. Do not reverse this migration with DROP statements or restore over existing research data. Database rollback requires a separately approved new-target restore and explicit cutover. Preserve incident/deletion audit receipts. Hosted recovery, alert delivery, failover and credential rotation still require an operator rehearsal.

## Deployment decision checklist

- [ ] Independent reviewer accepts tenant/session/API/Storage evidence and legacy isolation design.
- [ ] New synthetic project and protected host explicitly authorized; preview-secret audit complete.
- [ ] Dependency stack/migrations reviewed against exact target; no existing research data affected.
- [ ] Actual ClamAV engine/signature/resource tests and worker schedule/alerts exercised.
- [ ] Hosted database plus Storage recovery, tombstone replay, key rotation and RPO/RTO exercised.
- [ ] Auth recovery and optional invitation provider operations approved/tested.
- [ ] Synthetic demo accounts and full acceptance pass on the candidate URL.
- [ ] Separate institutional governance/retention/privacy approval before any authentic data.
