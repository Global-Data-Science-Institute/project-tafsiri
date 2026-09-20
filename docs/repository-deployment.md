# Repository and staging deployment handoff

Updated 2026-09-19. The authoritative GitHub repository is `https://github.com/Global-Data-Science-Institute/project-tafsiri`. Local work is on `chore/repo-portal-consolidation`, based on `5ddd32d49f49c79dee8ba5eea7e8e5685f3b5174`. Safety tag: `pre-repo-consolidation-2026-09`.

The repository is a monorepo. The Vercel application root must be `apps/reviewer-portal`, with framework Next.js. The local `.vercel/project.json` names project `tafsiri-reviewer-portal`, project ID `prj_Mp6Yodv1AKR8Q4g1l33wrKMEfTrS`, and team ID `team_2CQfpCVGFxaAvjkGZjPvl9pJ`. Vercel CLI login is restored. Project ID and team were verified. Root Directory is now `apps/reviewer-portal`; framework remains Next.js. Preview variables were replaced with values from the locally verified staging Supabase configuration, with invitations `mock`. Git connection was attempted and rejected by Vercel; its GitHub app needs access to the organization repository.

Supabase CLI identifies `gfhdwmqefotkljrltfnx` as **Project Tafsiri Staging** and `ydkookidvipqrwuilqeu` as a separate **Project Tafsiri** production project. All six local migration versions match staging. The local portal `.env.local` points to the staging project ref; it is excluded from Git. This does not establish what Vercel currently uses.

The staging hostname `https://tafsiri-reviewer-portal-staging.vercel.app/` resolves to an existing Ready Preview deployment (`dpl_7Q2PB6y57am8mrwEedArE59S1rjC`), but anonymous requests receive a Vercel Authentication redirect. Its content and deployment commit cannot be verified anonymously. This protection also intercepts password-recovery links for reviewers who do not have Vercel access. Before a reviewer pilot, configure the chosen reviewer-facing domain so invited reviewers can reach it, while keeping other preview deployments protected as appropriate. Use a controlled automation bypass for hosted tests if protection remains on staging.

## Vercel checks after login

1. The existing project under team `team_2CQfpCVGFxaAvjkGZjPvl9pJ` is verified as `prj_Mp6Yodv1AKR8Q4g1l33wrKMEfTrS`.
2. In GitHub organization settings, grant the Vercel GitHub app access to `Global-Data-Science-Institute/project-tafsiri`, then connect this existing Vercel project in Settings > Git. Settings > General already has Root Directory `apps/reviewer-portal` and framework Next.js.
3. Keep `main` for future production. Use a `staging` Preview branch (or an explicitly named Staging environment, if configured). Assign a stable staging domain to that branch, and scope Preview variables to `staging` when possible. Do not copy staging credentials into the Production environment.
4. Preview variables were set from verified staging values. Confirm the final scoped configuration in Environment Variables for `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`, `TAFSIRI_INVITATION_MODE`, `TAFSIRI_STUDY_KEY`, and `NEXT_PUBLIC_APP_URL`. Their Preview values must target the staging ref, keep invitations `mock`, and use the verified stable staging origin. Never expose `SUPABASE_SECRET_KEY` through `NEXT_PUBLIC_*`.
5. Push the intended staging branch and verify the deployment metadata shows the pushed Git commit. Do not substitute an untracked CLI upload for this check.

## Staging Supabase Auth checks

In Supabase, select **Project Tafsiri Staging** (`gfhdwmqefotkljrltfnx`) before opening Authentication > URL Configuration. Set Site URL to the verified stable staging origin. Allow the application's exact invitation callback, `https://<staging-host>/auth/callback`, and its recovery callback, `https://<staging-host>/auth/callback?next=%2Fauth%2Fupdate-password`. Verify the recovery email template uses `{{ .ConfirmationURL }}` or an equivalent token-hash link that preserves the requested redirect. Avoid changing production Auth settings. The hosted recovery flow must be tested with a designated disposable reviewer after deployment.

## GDSI link

Display name: **Project Tafsiri Language Reviewer Portal**. CTA: **Review Language Data**. Description: **Contribute independent linguistic review to Project Tafsiri, a GDSI initiative building dialect-aware language resources.** Use the verified canonical staging URL for internal QA; choose a public pilot URL only after protection and access policy are settled.
