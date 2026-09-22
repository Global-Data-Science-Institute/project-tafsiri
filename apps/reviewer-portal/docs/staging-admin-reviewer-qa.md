# Staging admin and reviewer QA identity

Project Tafsiri Staging (`gfhdwmqefotkljrltfnx`) has one `research_admin` Auth user, `stg-admin-001@example.invalid`. The same Auth user also has active reviewer profile `STG-ADMIN-R001` for portal QA. No Auth user or role claim was replaced.

The profile has one `familiar` Luwanga expertise row with `self_reported=false`, `native_speaker=false`, and a staging QA note. This is administrative test metadata, not a claim of linguistic expertise. Its participation in `STAGING_PORTAL_SMOKE_001` is active using the staging QA information version `STAGING-SMOKE-V1`. One synthetic item with source hash `staging-source-2` is assigned. Existing research items, Pipeline 001, RLS policies, migrations, and production data were not changed.

The staging-only audit and setup scripts are `scripts/staging-admin-reviewer-audit.mjs` and `scripts/staging-admin-reviewer-setup.mjs`. Both refuse any Supabase URL outside the staging project. The setup script requires `--apply`, checks that exactly one `research_admin` exists, and reuses existing profile, expertise, participation, and assignment rows. It reads keys from the local environment and never prints them.

The hosted QA check used an ephemeral authenticated session for that same Auth user. `/admin/dashboard` and `/reviewer/dashboard` returned HTTP 200, the reviewer dashboard displayed Continue review, and the assigned review form loaded. Authenticated reviewer queries returned only its own profile and assignment; another reviewer's assignment and the pipeline snapshot before Stage A submission were hidden by RLS. A normal reviewer received HTTP 307 to `/pending-access` at `/admin/dashboard`.
