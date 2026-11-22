# Synthetic staging validation 001

Decision, 2026-11-22: **BLOCKED — SYNTHETIC STAGING PREFLIGHT**.

This packet prepares independent review of [PR #29](https://github.com/Global-Data-Science-Institute/project-tafsiri/pull/29), commit `1d796289ba9077aa3f194fcb285bb6bf64b0580d`. It does not authorize provisioning, migrations on hosted systems, deployment, email, onboarding, or authentic data. This work changes validation harnesses and documentation, plus CI targeting and the new branch's automatic-deployment guard. Application code and migrations are unchanged. No independent human security assessment has occurred.

- [Security-review preparation and findings](security-review.md)
- [Actual ClamAV results and reproduction](scanner-validation.md), [machine-readable observations](clamav-results.json)
- [Infrastructure specification, cost and approval request](infrastructure-and-approval.md)
- [Hosted acceptance and operational checklist](acceptance-and-operations.md)
- [Conflict-aware integration plan](integration.md), [migration hashes](migrations.sha256), [exact PR/CI snapshot](pr-stack.json)

## Decision evidence

The real ClamAV 1.4.7 engine and verified daily signatures 28191 detected EICAR, admitted clean text/PDF/WAV, and enforced timeout and size limits. The real worker produced CLEAN/INFECTED/ERROR states through local Auth, Storage and database RPCs; unscanned downloads were denied. However, structurally invalid PDF/WAV fixtures were admitted as CLEAN. This contradicts a broad promise that malformed documents are rejected: malware detection does not establish structural validity. Scanner freshness checks also use filesystem mtime rather than signed database build time. These require reviewed remediation or a narrower explicitly accepted file policy before hosted acceptance.

The legacy public API remains reachable independently of the application's deployment protection. A separate database prevents damage to existing research data, but replaying the full migration sequence reproduces legacy anonymous-write surfaces in the new database. A security owner must approve a versioned restriction plan and verify denial before exposing it. A protected Vercel page alone cannot satisfy that gate.

The proposed infrastructure and bounded approval request are concrete, but **not yet recommended for approval** until the synthetic blockers in the security report are closed. Hosted-only controls are planned acceptance gates, not falsely reported as local failures. Authentic partner data additionally requires institution-approved governance, rights, retention, independent security review and operational service commitments.

## Validation record

- Research: 189 tests passed; frontend: 50 unit tests, typecheck, lint and production build passed.
- Studio: two existing complete browser scenarios passed against actual local Auth/API/Storage. Reviewer Portal: all eight browser regressions passed separately with guarded local resets.
- Database: seven existing SQL smoke files, 51 direct private-table denials, no canonical/source ingestion, and public/data_studio SQL lint passed.
- Database and private Storage backup/restore rehearsals passed; this is local recovery, not hosted PITR certification.
- Real scanner: 16 recorded cases, including two adverse structural observations; those two are findings, not test successes. Three worker-state cases passed. No authentic files or live AI/email requests were used.
- Sixteen ordered migration checksums verified against canonical Git blobs and normalized local files.
- PR #29's research/portal/database/Studio jobs were green. This packet's draft PR reruns the full CI suite, including lexical replay/concurrency, governed promotion and multilingual registry tests. Consult its exact check results rather than treating baseline CI as current evidence.

Local artifacts containing synthetic Auth sessions, database dumps or file bodies remain ignored under `.studio-local`; only metadata results are committed. No hosted credentials were injected into the scanner; the initial workspace mount was broader than necessary, as disclosed in the scanner report. The signatures and downloaded package are local test artifacts, not a deployed service.
