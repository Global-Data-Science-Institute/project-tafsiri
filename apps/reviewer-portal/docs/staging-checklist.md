# Staging deployment checklist

Do not use production reviewer accounts or the production Human Evaluation 001 study for mutable validation.

- Configure `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` for staging.
- Configure `SUPABASE_SECRET_KEY` only in the server runtime. Never use a `NEXT_PUBLIC_` prefix.
- Set `NEXT_PUBLIC_APP_URL` to the exact HTTPS staging origin and allow its `/auth/callback` URL in Supabase Auth.
- Keep `TAFSIRI_INVITATION_MODE=mock` until invitation delivery is separately approved.
- Keep public email signup disabled; reviewer access remains invitation-only.
- Configure SMTP only in a separate approved task, including sender verification, SPF, DKIM, DMARC, bounce handling, rate limits, and template review.
- Use disposable staging reviewers and a disposable study; never mutate the frozen production study.
- Run typecheck, lint, tests, database regression, Playwright E2E, accessibility scans, responsive checks, and a production build.
- Audit browser bundles for privileged keys, database credentials, JWTs, and Auth Admin tokens.
- Keep assignment execution and real invitations disabled until separately approved.
