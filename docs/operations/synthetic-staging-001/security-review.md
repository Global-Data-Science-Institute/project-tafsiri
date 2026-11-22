# Security review preparation

Scope: PR #29 application, migrations 015/RC, Storage policies, provider adapters and current read-only hosted metadata. Reviewer: implementing coding agent; independent human acceptance **pending**. The intended independent reviewer should reproduce the harnesses, review the linked source locations and sign each disposition with commit, date and evidence. Automated checks are evidence, not approval.

## Control map

| Boundary | Code / evidence | Assessment |
|---|---|---|
| Tenant/project/contributor | `20261120032711_data_studio_private_intake.sql`: org_admin, project_role, can_read; two-institution browser journey | Exact project/owner checks; institution admins inherit PI access; GDSI oversight does not grant content access |
| Sessions and CSRF | RC migration session_active; `src/lib/studio/server.ts`; stale-JWT/Origin tests | Auth session existence, verified email, ban/expiry checked in public DB entrypoints; browser mutation Origin checked separately |
| Invitations/memberships | Baseline command, RC invitation_prepare/finish and last-admin guard | Email-bound, expiring, one-time acceptance; rotation invalidates prior token; explicit project grants must also be removed when offboarding |
| Direct API/RPC | Explicit grants, private wrapper placement and fixed search_path; 51 SQL denials | Public entrypoints are the security boundary; hiding UI or private schema alone is insufficient; service-only completions are denied to ordinary users |
| Storage | studio_upload_insert/read + studio_object_access; real-worker integration | Private bucket, no ordinary update/delete; pending/error/infected/withdrawn read denial; hash/size checked before admission |
| Workers | scan/deletion claim/finish leases; `scanner.mjs` | Stale results rejected, storage-first purge, 25-job bound; broad service key remains a privileged trust boundary |
| Secrets | `src/lib/supabase/admin.ts` server-only; environment guards; metadata-only hosted inspection | No service key in client imports/public names found. Separate key instances are operational isolation, not narrower service-role privileges |
| External AI | assist route, assistant adapter, DB begin/finish consent checks | Disabled default; exact project and contributor consent; no raw attachments sent; consent revocation cannot recall a request already transmitted, so external AI remains off |
| Logging/cache | no-store on Studio API/downloads; sanitized error codes; invitation URL flow | Application errors omit bodies; platform URL/access logs and browser history require separate review/redaction |
| Research boundary | Handoff PREPARED_BLOCKED, no source/lexeme ingestion checks | No automated linguistic verification, promotion or training |

Source paths above are under `supabase/migrations` or `apps/reviewer-portal`. See the existing `e2e-studio/partner-release.spec.ts` and `workspace.spec.ts` plus `tests/studio/clamav_database.mjs`. Recheck negative permissions through HTTP, RPC, views and Storage, not just SQL catalog inspection.

## Findings and release disposition

| ID / severity | Evidence and consequence | Synthetic staging disposition | Authentic partner disposition |
|---|---|---|---|
| S01 High | Actual ClamAV adapter returns CLEAN for `%PDF-1.7\n%%EOF` and `RIFFxxxxWAVE`. The MIME/magic policy is not a structural validator; literal PDF names do not cover encoded/indirect active content | Block promised malformed-document rejection. Add bounded structural/active-content validation in a separately reviewed implementation or explicitly approve a narrower policy before acceptance; do not weaken tests | Block file intake pending parser/sandbox policy and hostile corpus review |
| S02 High | Scanner trusts mtime and nonzero size of daily.cvd/cld; copying an old valid database can refresh mtime. This is a code-review finding, not a demonstrated malicious signature update | Block dependable freshness claim until signed database build/version age is checked and stale-copy regression exists, or security owner accepts a documented immutable updater attestation | Block operational malware-admission readiness |
| S03 High | Anonymous public.submissions insert/read reproduced by browser suite; 16 legacy public tables lack RLS; six definer views remain. Protected Vercel URLs do not protect the direct Supabase API | Block exposed hosted target until versioned least-privilege restrictions and direct-API denial tests are approved. No blanket destructive changes; inventory legacy consumer contracts first | Block shared-environment and real-data deployment |
| S04 High privilege impact | Application/worker service secrets can access Auth/Storage outside intended RPCs. Metadata lists SUPABASE_SECRET_KEY in both production and preview targets of existing Vercel project | New project only; no inherited/shared envs, no privileged preview keys. Dedicated per-purpose secrets, audited custody/rotation and named operators required before provisioning acceptance | Require reviewed scoped identities or explicit residual-risk acceptance and privileged-path audit |
| S05 Medium | Invitation tokens appear in query URLs. POST response no-referrer does not set the Studio document policy; browser history and platform request logs may retain tokens | Require URL-query redaction, no third-party analytics, exact document referrer-policy verification and short-lived synthetic accounts; add browser-history cleanup/token exchange design to remediation | Block until token handling and log retention independently accepted |
| S06 Medium | Global command lock, unpaginated state; seven-day synthetic retention and limited deletion holds | Bound to 2 institutions, 10 accounts, 100 contributions, 100 files/500 MB; no throughput claim. Holds must be placed before PURGING; operator escalation documented | Load testing, institution retention/backup/hold policy and metadata minimization required |
| S07 Medium | Existing project protection is all_except_custom_domains; exact future URL untested; hosted recovery/alerts/rotation unexecuted | Future deployment must remain operator-only until target-specific acceptance passes; absence of a future environment is not a falsely claimed local test failure | Block real data until independently witnessed operational evidence |

No remotely exploitable cross-tenant Studio disclosure was found in tested paths. This does not prove the absence of vulnerabilities. Legacy probes are bounded to 100 rows/relation in synthetic fixtures; privileged exports and all hosted policies were not exhaustively audited. S01/S02/S03 prevent an unconditional staging approval recommendation.

## Read-only hosted inspection, 2026-11-22

Supabase `gfhdwmqefotkljrltfnx`: ACTIVE_HEALTHY, us-east-2, PostgreSQL 17.6.1.155, migration history ends at 010 (`20260928015644`). Production `ydkookidvipqrwuilqeu` was not queried or modified.

Vercel `prj_Mp6Yodv1AKR8Q4g1l33wrKMEfTrS`, `tafsiri-reviewer-portal`: Next.js, Node 24.x, SSO protection enabled for all_except_custom_domains; password and trusted-IP protection disabled. Environment metadata, requested with decrypt=false, shows six names in each production/preview scope: NEXT_PUBLIC_APP_URL, TAFSIRI_STUDY_KEY, TAFSIRI_INVITATION_MODE, SUPABASE_SECRET_KEY, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, NEXT_PUBLIC_SUPABASE_URL. Secret values were not decrypted, displayed or copied. Whether the preview key equals a production key is **unknown**; no such equality is asserted. No Studio enabling/provider variables appeared in the returned metadata. Inherited/team secret configuration needs operator confirmation.

Required independent sign-off: tenant authorization reviewer; legacy API owner; scanner/security owner; operations owner; budget/deployment approver. Record names through the institution's private review process, not public test fixtures.
