# Staging password recovery configuration

The portal now verifies recovery token hashes at `/auth/confirm` and writes the Supabase session to cookies before redirecting to `/auth/update-password`. The email link can be opened in a different browser from the one that requested it. The old Supabase `/auth/v1/verify?token=pkce_...` email link does not use this route and may fail when the originating browser's PKCE verifier is unavailable. The reported expired link alone cannot distinguish a missing verifier from a consumed or expired token.

In **Project Tafsiri Staging** (`gfhdwmqefotkljrltfnx`) only:

1. Open **Authentication > URL Configuration**. Set **Site URL** to `https://tafsiri-reviewer-portal-staging.vercel.app`. Include these exact **Redirect URLs** for the current portal flows:
   - `https://tafsiri-reviewer-portal-staging.vercel.app/auth/confirm` (reset request's `redirectTo`)
   - `https://tafsiri-reviewer-portal-staging.vercel.app/auth/callback` (invitations)
2. Open **Authentication > Email Templates > Reset Password**. Set the subject to `Reset your Project Tafsiri password` and the HTML body to:

```html
<h2>Reset your password</h2>
<p>We received a request to reset your Project Tafsiri Reviewer Portal password.</p>
<p><a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&amp;type=recovery">Reset password</a></p>
<p>If you did not request this, you can safely ignore this email.</p>
```

The link must start with the portal Site URL and include `token_hash` and `type=recovery`. It must not use `{{ .ConfirmationURL }}` or the old `/auth/callback?next=...` URL. The token appears only in the link target, never as visible body text. The route redirects to a URL without the token and rejects any external `next` value. The recovery route does not require a Supabase redirect allowlist entry for `/auth/update-password`; that redirect is internal to the portal.

Verify the saved template by requesting a reset **from the portal** using a disposable staging account, then inspect the emitted link's host and path without recording the token. Open it in a separate browser/session. Verify the password form, old/new password behavior, consumed-link error, and a second successful reset. Do not use a dashboard-generated recovery email as the primary test.

The confirmation endpoint verifies on GET. Supabase documents that some email security systems prefetch one-time links and can consume them. There is no evidence yet that prefetching caused this staging failure. If the new flow is still consumed before a user click, add an explicit confirmation page that waits for a user action before calling `verifyOtp`; do not increase token lifetime as a substitute.
