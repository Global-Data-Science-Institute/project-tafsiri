# Multilingual foundation validation 001

Implementation validation on 2026-11-19 local / 2026-11-20 UTC. All database writes use a disposable synthetic container; no hosted writes, corpus collection, source-rights changes or real promotions.

| Check | Current result |
|---|---|
| Python baseline plus new profiles | 189 passed: 156 inherited tests rerun and 33 new profile/adapter/client cases |
| Reviewer Portal | Typecheck, lint and production build passed; 28 tests across 8 files passed |
| Migration 011 foundation | 457 assertions rerun through existing isolated replay harness |
| Migration 012 | All 102 checks passed after 013 installation, including seven smoke-suite completions, atomic registration, promotion races and four inherited concurrency scenarios |
| Migration 013 | 55 checks passed: fresh replay, injected rollback, baseline preservation, scoped interfaces, evidence validation and all function/trigger lint with zero warnings/errors |
| Advisors | Fresh local run: 22 ERROR and 29 WARN; no finding names language_registry; legacy categories below |

The 013 harness reuses the 012 harness with an optional post-migration callback. That callback applies/rolls back/reapplies 013 before the inherited empty-state smoke suites and synthetic promotion fixtures. This ensures all inherited promotion tests run with 013 present. Public data/grant/policy/constraint snapshots must match except the explicitly widened evidence-scope CHECK and its new deferred constraint trigger. No earlier assertion is weakened; running an empty-state smoke after populated fixtures was corrected by placing the extension at the appropriate test lifecycle point.

New tests cover two unrelated synthetic languages, varieties, a language without varieties, disputed classification, multiple orthographies, explicit multilingual source components, missing IDs, normalization errors, immutable identity/history, private response minimization, independent capabilities, direct and cross-scope denial, revocation and exact-version resolution. The legacy lexical path is exercised after 013; sources with new undigested scopes are intentionally rejected by policy 001. No test claims translation quality or genuine linguistic correctness.

The Python tests exercise the existing generate/index/summary/export path, arbitrary explicit source scopes, preservation of original text, normalization selection, unsupported settings, allowlist and scope mismatch, no network access in synthetic mode, output protection and no real-mode fallback. The new evidence schema avoids pretending source-entry IDs are dictionary IDs or arbitrary glosses are English definitions. Existing historical fixtures/checksums remain unchanged.

No public API/browser multilingual flow, real registry provisioning, rights-aware private exporter, portal delegation, language-specific morphology, trained model, dataset release or commercial flow has been implemented or tested. Registry capabilities are explicit approval metadata, not proof of a deployed model. Full hosted drift/recovery review and security hardening remain deployment gates. See [implementation](multilingual-platform-foundation-001.md) and [hardening plan](../security/multilingual-foundation-hardening-plan-001.md).

## Advisor interpretation

Executed installed CLI `db advisors --type all --level warn --fail-on none --output json` against the disposable container on loopback port 55439, with TLS disabled only for that local test image. The generic CLI message says remote database; the supplied URL was 127.0.0.1, not a hosted project. Findings: 16 disabled-RLS table errors, 6 definer-view errors, 24 multiple-permissive-policy warnings, 3 Auth initplan warnings, 1 public vector extension warning and 1 unrestricted submissions warning. The six additional policy warnings versus the prior 23-WARN report reflect the extra reader group and two synthetic logins across languages/dialects; there are no new legacy policies or new registry-object findings. These results do not clear the deployment blockers in the separate hardening plan.
