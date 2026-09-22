# Repository and staging deployment handoff

Updated 2026-09-22. The authoritative GitHub repository is `https://github.com/Global-Data-Science-Institute/project-tafsiri`. Repository modernization is prepared on `staging` for review and normal merge into `main`. The safety tag `pre-main-modernization-2026-09` identifies the exact pre-modernization commit; the earlier consolidation tag remains part of repository history.

The repository is a monorepo. The existing Vercel project `tafsiri-reviewer-portal` (`prj_Mp6Yodv1AKR8Q4g1l33wrKMEfTrS`, team `team_2CQfpCVGFxaAvjkGZjPvl9pJ`) is connected to `Global-Data-Science-Institute/project-tafsiri`. Root Directory is `apps/reviewer-portal`; framework is Next.js. This project is dedicated to the **staging** portal. The Vercel API confirms its Production Branch is `staging`.

Supabase CLI identifies `gfhdwmqefotkljrltfnx` as **Project Tafsiri Staging** and `ydkookidvipqrwuilqeu` as a separate **Project Tafsiri** production project. Six applied migration versions match the remote history. Migration 006, `20260922035105_create_source_provenance_foundation.sql`, is prepared and locally verified but has not been deployed to production. The local portal `.env.local` points to the staging project ref; it is excluded from Git. Six Vercel Production environment variables were set from that verified staging configuration before the Git-triggered deployment. Both the public Supabase URL and privileged key were previously checked against staging Auth. `SUPABASE_SECRET_KEY` is server-only, `TAFSIRI_INVITATION_MODE` is `mock`, and `NEXT_PUBLIC_APP_URL` is `https://tafsiri-reviewer-portal-staging.vercel.app`.

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
