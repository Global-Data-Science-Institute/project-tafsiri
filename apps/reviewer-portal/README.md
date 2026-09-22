# Tafsiri Language Reviewer Portal

Local Next.js portal for invited reviewers and research administrators.

## Setup

Copy `.env.example` to `.env.local`, provide development values, run `npm install`, then `npm run dev`. Allow `http://localhost:3000/auth/callback` in development Auth redirects.

Never put `SUPABASE_SECRET_KEY` in a `NEXT_PUBLIC_` variable. Browser and user-server requests use the publishable key and RLS. The privileged client imports `server-only` and is reached only after `requireAdmin()` verifies `app_metadata.tafsiri_role === "research_admin"`.

Reviewer flow: invite → callback → onboarding → researcher approval → assignments → blinded Stage A → locked Stage B. Admin flow: dashboard → invitation preview → reviewer review → assignment preview. Invitation mode defaults to `mock`; no email is sent.

Real invitations require explicitly enabling live mode, configured custom SMTP, verified sender/SPF/DKIM/DMARC, approved redirect URLs, reviewed templates, expiration/rate limits, bounce handling, and a test recipient. Never store SMTP credentials here.

The assignment generator uses a documented seed, balances workload/strata/pairs, and validates coverage and duplicates. Default protocol: 6 reviewers, 3 reviews per item, 450 assignments, 75 each. Implementation 001 previews but does not execute assignments.

Implementation 002 persists Luwanga expertise and the versioned `HE001-PARTICIPATION-V1` acknowledgment through trusted server actions. Database triggers replace timestamp signals with server time. Onboarding never activates participation. Resume order is deterministic: Stage B incomplete, Stage A draft, then unstarted; ties use assignment time and ID. Activation and study-specific withdrawal require revalidated research-admin authorization. Assignment creation remains preview-only.

Commands: `npm run typecheck`, `npm run lint`, `npm test`, `npm run build`.

Authenticated routes are dynamic and must not use shared caches or ISR. Production deployment, Auth configuration, reviewer creation, and assignment execution require separate authorization.
