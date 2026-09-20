# Repository and staging deployment handoff

Updated 2026-09-19. The authoritative GitHub repository is `https://github.com/Global-Data-Science-Institute/project-tafsiri`. The `staging` branch contains the consolidation at `ec5629e82d710f0c5094894d50cb9e3ff6991ebf`. `main` remains at `5ddd32d49f49c79dee8ba5eea7e8e5685f3b5174`. Safety tag: `pre-repo-consolidation-2026-09`.

The repository is a monorepo. The existing Vercel project `tafsiri-reviewer-portal` (`prj_Mp6Yodv1AKR8Q4g1l33wrKMEfTrS`, team `team_2CQfpCVGFxaAvjkGZjPvl9pJ`) is connected to `Global-Data-Science-Institute/project-tafsiri`. Root Directory is `apps/reviewer-portal`; framework is Next.js. This project is dedicated to the **staging** portal. The Vercel API confirms its Production Branch is `staging`.

Supabase CLI identifies `gfhdwmqefotkljrltfnx` as **Project Tafsiri Staging** and `ydkookidvipqrwuilqeu` as a separate **Project Tafsiri** production project. All six local migration versions match staging. The local portal `.env.local` points to the staging project ref; it is excluded from Git. Six Vercel Production environment variables were set from that verified staging configuration before the Git-triggered deployment. Both the public Supabase URL and privileged key were previously checked against staging Auth. `SUPABASE_SECRET_KEY` is server-only, `TAFSIRI_INVITATION_MODE` is `mock`, and `NEXT_PUBLIC_APP_URL` is `https://tafsiri-reviewer-portal-staging.vercel.app`.

The canonical staging hostname is `https://tafsiri-reviewer-portal-staging.vercel.app/`. It is registered and verified as a Production domain on the existing project, and an anonymous request to `/auth/sign-in` returns HTTP 200. The first Git-triggered staging Production deployment was `dpl_AeAHZtEbKUFUWzKXJpD4FJxGp8pQ`, sourced from GitHub `staging` commit `6fda6a0829890daeecb55c18d9ec848a8262fa8c`. Vercel protection is `all_except_custom_domains`; generated preview URLs remain protected. The project default domain `https://tafsiri-reviewer-portal.vercel.app/` also serves the portal; use the canonical staging hostname for Auth redirects.

## Vercel deployment steps

1. The existing project under team `team_2CQfpCVGFxaAvjkGZjPvl9pJ` is verified as `prj_Mp6Yodv1AKR8Q4g1l33wrKMEfTrS`.
2. In this **dedicated staging** Vercel project, Settings > Environments > Production > Branch Tracking is `staging`; the API confirms `link.productionBranch=staging`.
3. The canonical staging domain is assigned to the Production deployment. An anonymous request reaches the portal Sign In page without Vercel SSO. Keep preview deployment protection enabled.
4. The six Production variables are `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`, `TAFSIRI_INVITATION_MODE`, `TAFSIRI_STUDY_KEY`, and `NEXT_PUBLIC_APP_URL`. They target staging, keep invitations `mock`, and use the chosen staging origin. Never expose `SUPABASE_SECRET_KEY` through `NEXT_PUBLIC_*`.
5. Push `staging` and verify the Vercel deployment metadata shows that Git commit. Do not substitute an untracked CLI upload.

## Staging Supabase Auth checks

In Supabase, select **Project Tafsiri Staging** (`gfhdwmqefotkljrltfnx`) before opening Authentication > URL Configuration. Set Site URL to `https://tafsiri-reviewer-portal-staging.vercel.app`. Allow exactly the application's invitation callback, `https://tafsiri-reviewer-portal-staging.vercel.app/auth/callback`, and recovery callback, `https://tafsiri-reviewer-portal-staging.vercel.app/auth/callback?next=%2Fauth%2Fupdate-password`. The callback exchanges a PKCE code or supported OTP token hash, then sends recovery sessions to `/auth/update-password` and invitations to `/reviewer/onboarding`; these destination paths are internal and need no additional Supabase redirect allowlist entries. Verify the recovery email template uses `{{ .ConfirmationURL }}` or an equivalent token-hash link that preserves the requested redirect. Avoid changing production Auth settings. The hosted recovery flow must be tested with a designated disposable reviewer after deployment.

## GDSI link

Display name: **Project Tafsiri Language Reviewer Portal**. CTA: **Review Language Data**. Description: **Contribute independent linguistic review to Project Tafsiri, a GDSI initiative building dialect-aware language resources.** Use the verified canonical staging URL for internal QA; choose a public pilot URL only after protection and access policy are settled.
