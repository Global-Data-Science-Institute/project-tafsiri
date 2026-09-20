# Tafsiri Reviewer Portal consolidation audit

Audited 2026-09-19. This is a historical consolidation audit. Current deployment and recovery instructions are in `docs/repository-deployment.md` and `apps/reviewer-portal/docs/staging-auth-recovery.md`; the callback and email-template guidance below has been superseded.

## Current state

| Area | Feature | Status | Evidence / limit |
| --- | --- | --- | --- |
| Auth | Sign in | WORKING (local implementation) | Supabase password sign-in, reviewer redirect |
| Auth | Sign out | WORKING (local implementation) | Reviewer navigation signs out |
| Auth | Forgot password | WORKING (local implementation) | Generic response; `resetPasswordForEmail` uses current origin |
| Auth | Recovery callback | PARTIAL | PKCE code and recovery token hash supported; live template unverified |
| Auth | Update password | PARTIAL | Requires valid Auth user; live email test outstanding |
| Auth | Invitation acceptance | PARTIAL | Callback handles code and invite token hash; invitation mode currently `mock` locally |
| Auth | Redirects | PARTIAL | Callback destinations fixed to known internal paths; remote allow list unverified |
| Reviewer | Onboarding, Luwanga expertise, acknowledgment | WORKING (local implementation) | Versioned participation flow and persistence actions |
| Reviewer | Pending approval, dashboard, assignments | WORKING (local implementation) | Gated participation, assignment summary and resume link |
| Reviewer | Stage A, autosave, Stage B, resume, completed item | WORKING (local implementation) | Existing tests exercise flow; Stage B data fetched after Stage A lock |
| Admin | Reviewer list, detail, activation, withdrawal | WORKING (local implementation) | Protected admin pages and actions |
| Admin | Assignment preview, coverage | WORKING (local implementation) | Preview only; dashboard coverage metrics |
| Security | RLS, privileged client, admin authorization | PARTIAL | Migrations and `server-only` client inspected; live policy state unverified |
| Security | Browser secret exposure | WORKING (local source audit) | Secret key only read by server-side code/scripts |
| Deployment | Vercel project and URL | PARTIAL | Project name `tafsiri-reviewer-portal`; staging URL candidate below, unreachable from audit environment |
| Deployment | Supabase environment | PARTIAL | Local project host `gfhdwmqefotkljrltfnx.supabase.co`; remote project identity and Auth config unverified |
| Deployment | Environment variables | PARTIAL | Local names inspected without disclosing values; Preview variable names and staging public values verified; server secret was set through Vercel CLI and cannot be read back |
| Deployment | Auth Site URL and Redirect URLs | PARTIAL | Local `supabase/config.toml` uses loopback; remote settings unverified |

## Recovery analysis

The prior callback required a `code`, so recovery templates that send `token_hash` and `type=recovery` could not establish a session. The old password page attempted `updateUser` without checking for a valid Auth user and routed directly to the dashboard on success. The configured staging hostname currently redirects anonymous requests to Vercel Login, which would block a reviewer without Vercel access before the recovery callback runs. The reported hosted failure may also involve the callback mismatch, remote redirect allow list, or template behavior; a real recovery link and dashboard access are still needed to distinguish them.

The callback now exchanges PKCE codes or verifies supported OTP token hashes, fixes destinations to onboarding or update-password, and returns a friendly recovery failure. The reset form uses the browser's current origin for its callback URL. The update form checks the Auth user before showing the form and before changing the password, validates matching 12-character passwords, and confirms success. Authenticated reviewers can change passwords from Profile > Security after validating their current credentials. Supabase owns Auth credentials; app tables do not receive passwords.

## Required remote release checks

1. In Vercel, verify project ID `prj_Mp6Yodv1AKR8Q4g1l33wrKMEfTrS` and its actual production domain. The script names `https://tafsiri-reviewer-portal-staging.vercel.app`; its availability was not verified.
2. In the Supabase dashboard, verify project ref `gfhdwmqefotkljrltfnx` before changing Auth settings. Set Site URL to the canonical portal origin. Allow the exact `https://<canonical-host>/auth/callback?next=%2Fauth%2Fupdate-password` recovery redirect and `https://<canonical-host>/auth/callback` invitation redirect. Add preview and localhost origins separately only where intentionally used.
3. Inspect the recovery email template. Default `{{ .ConfirmationURL }}` should preserve the `redirectTo` from the reset call. A custom token-hash template should link to `/auth/callback?token_hash={{ .TokenHash }}&type=recovery`. Confirm the actual emitted URL. If one-time links are consumed by email scanners, use a deliberate confirmation interstitial or code-entry flow before pilot.
4. With a designated test reviewer, request a reset, inspect the delivered URL, follow it, reject mismatched passwords, update successfully, verify old-password failure and new-password success, retry a consumed link, and change password from Profile > Security. Inspect browser/network logs for credential leakage. Do not use a real reviewer's account for this test.
5. Deploy to the existing Vercel project only after these checks; no deployment was made by this audit.

## Design and quality

The live GDSI home page presents a research-first hierarchy, compact institute navigation, an editorial hero, featured projects including Tafsiri, and a restrained footer. The live GDSI stylesheet and owned SVG logo were retrieved. The portal now uses its navy `#071d34`, teal `#007e89`, paper `#f5f7f6`, Inter and Source Serif 4 fonts, and logo, with consolidated tokens in `globals.css`. Landing, sign-in, recovery, reviewer navigation, dashboard, review form, and admin navigation now share the institutional visual layer. Stage A and Stage B remain separate. The compact footer links to GDSI.

TypeScript, ESLint, 22 unit tests, and production build pass. Browser E2E, hosted mobile/accessibility inspection, remote security verification, recovery email, and hosted regression remain unrun. No migration, Pipeline 001, canonical language data, or reviewer/evaluation data was changed.

Recommended GDSI link label: **Review Language Data**. Portal name: **Project Tafsiri Language Reviewer Portal**. Short description: **Contribute independent linguistic review to Project Tafsiri, a GDSI initiative building dialect-aware language resources.** Link to the verified canonical portal URL after the Vercel domain check.

**Recommendation: ACTION REQUIRED** until remote Auth configuration, designated-account recovery, hosted regression, and deployment are verified.
