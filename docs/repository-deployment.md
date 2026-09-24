# Repository and staging deployment handoff

Updated 2026-09-24. The authoritative GitHub repository is `https://github.com/Global-Data-Science-Institute/project-tafsiri`. Repository modernization and database migrations through Migration 009 are merged into `main` and synchronized to `staging`. The safety tag `pre-main-modernization-2026-09` identifies the exact pre-modernization commit; the earlier consolidation tag remains part of repository history.

The repository is a monorepo. The existing Vercel project `tafsiri-reviewer-portal` (`prj_Mp6Yodv1AKR8Q4g1l33wrKMEfTrS`, team `team_2CQfpCVGFxaAvjkGZjPvl9pJ`) is connected to `Global-Data-Science-Institute/project-tafsiri`. Root Directory is `apps/reviewer-portal`; framework is Next.js. This project is dedicated to the **staging** portal. The Vercel API confirms its Production Branch is `staging`.

Supabase CLI identifies `gfhdwmqefotkljrltfnx` as **Project Tafsiri Staging** and `ydkookidvipqrwuilqeu` as a separate **Project Tafsiri** production project. Both databases are aligned through Migration 009, `20260924035424_create_canonical_linguistic_rule_governance.sql`. The local portal `.env.local` points to the staging project ref; it is excluded from Git. Six Vercel Production environment variables were set from that verified staging configuration before the Git-triggered deployment. Both the public Supabase URL and privileged key were previously checked against staging Auth. `SUPABASE_SECRET_KEY` is server-only, `TAFSIRI_INVITATION_MODE` is `mock`, and `NEXT_PUBLIC_APP_URL` is `https://tafsiri-reviewer-portal-staging.vercel.app`.

## Migration 009 deployment verification

Migration 009 was deployed to staging and production on 2026-09-24 from the migration merged in commit `68ee3da9257a1c09ddae8963bf485e621443de1d`. Each environment's final migration history contains `20260924035424` exactly once, and a subsequent dry run reports the remote database is up to date with no pending migrations, seeds, or roles. The Supabase CLI link was restored to staging after production verification.

The live schema contains all 11 canonical rule governance tables, 25 distinct rule type configuration rows, and 6 distinct contributor role type configuration rows. Row-level security is enabled on every new table. There are no `anon` or `authenticated` table grants or policies, while `service_role` has access to all 11 tables. The four validation functions are invoker security functions with an empty `search_path` and no client execute privilege. Database lint reports no schema errors.

No canonical rule, revision, dialect link, condition, evidence link, promotion, promotion output, supersession, or contributor role was created by deployment. Existing evidence and provenance totals remained unchanged in both environments: 110 linguistic evidence rows, all 110 verified, machine generated, and LLM assisted; 53 sources, source versions, and source rights rows; and 424 source use policies. Staging reviewer data remained at 4 profiles, 9 assignments, 2 annotations, and 4 study participations. Production reviewer tables and Auth remained empty, while its existing evaluation study retained 150 items. Migration 009 therefore establishes governance structure and controlled vocabularies only; the first canonical promotion remains a separate governed operation.

Canonical Promotion Pilot 001 was subsequently applied to staging only on 2026-09-24. Staging now contains four `PROVISIONAL` canonical rules, four applied promotions, four revision-1 records, four canonical dialect links, four verified evidence links, two conditions, eighteen promotion outputs, and one time-bounded canonical-approver assignment. Production remains at zero rules, promotions, and contributor-role assignments. Human review of `artifacts/linguistic_rules/canonical_promotion_pilot_001_review.csv` is required before any separate production decision.

The canonical staging hostname is `https://tafsiri-reviewer-portal-staging.vercel.app/`. It is registered and verified as a Production domain on the existing project, and an anonymous request to `/auth/sign-in` returns HTTP 200. The first Git-triggered staging Production deployment was `dpl_AeAHZtEbKUFUWzKXJpD4FJxGp8pQ`, sourced from GitHub `staging` commit `6fda6a0829890daeecb55c18d9ec848a8262fa8c`. Vercel protection is `all_except_custom_domains`; generated preview URLs remain protected. The project default domain `https://tafsiri-reviewer-portal.vercel.app/` also serves the portal; use the canonical staging hostname for Auth redirects.

## Vercel deployment steps

1. The existing project under team `team_2CQfpCVGFxaAvjkGZjPvl9pJ` is verified as `prj_Mp6Yodv1AKR8Q4g1l33wrKMEfTrS`.
2. In this **dedicated staging** Vercel project, Settings > Environments > Production > Branch Tracking is `staging`; the API confirms `link.productionBranch=staging`.
3. The canonical staging domain is assigned to the Production deployment. An anonymous request reaches the portal Sign In page without Vercel SSO. Keep preview deployment protection enabled.
4. The six Production variables are `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`, `TAFSIRI_INVITATION_MODE`, `TAFSIRI_STUDY_KEY`, and `NEXT_PUBLIC_APP_URL`. They target staging, keep invitations `mock`, and use the chosen staging origin. Never expose `SUPABASE_SECRET_KEY` through `NEXT_PUBLIC_*`.
5. Push `staging` and verify the Vercel deployment metadata shows that Git commit. Do not substitute an untracked CLI upload.

## Staging Supabase Auth checks

In Supabase, select **Project Tafsiri Staging** (`gfhdwmqefotkljrltfnx`) before opening Authentication > URL Configuration. Set Site URL to `https://tafsiri-reviewer-portal-staging.vercel.app`. Allow the application's invitation callback, `https://tafsiri-reviewer-portal-staging.vercel.app/auth/callback`, and recovery request redirect, `https://tafsiri-reviewer-portal-staging.vercel.app/auth/confirm`. Configure the Reset Password template with a direct token-hash link to `/auth/confirm`, as specified in [staging-auth-recovery.md](../apps/reviewer-portal/docs/staging-auth-recovery.md). Avoid changing production Auth settings. The hosted recovery flow must be tested with a designated disposable reviewer after deployment.

## GDSI link

Display name: **Project Tafsiri Language Reviewer Portal**. CTA: **Review Language Data**. Description: **Contribute independent linguistic review to Project Tafsiri, a GDSI initiative building dialect-aware language resources.** Use the verified canonical staging URL for internal QA; choose a public pilot URL only after protection and access policy are settled.
