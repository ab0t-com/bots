# 07 · Your login page and branding

**What this is for.** The page your customers see at `https://auth.service.ab0t.com/login/invoicer-users`: colours, wording, logo, whether people can sign up or only arrive by invitation, where they go after logout or after accepting an invite. All of it is one file, `config/hosted-login.json`, applied by `run`.

**Before you start.** SOP 05 done. You know your brand colour as `#RRGGBB`, your app's URL, and whether sign-up is open.

## Steps

**1. Edit `config/hosted-login.json`.** Acme's version:
```json
{
  "branding": {
    "primary_color": "#1F4FD8",
    "background_color": "#FAFAFA",
    "page_title": "Invoicer — Sign in",
    "logo_url": "https://invoicer.acme.example/logo.svg",
    "hide_powered_by": false,
    "login_template": "default"
  },
  "content": {
    "welcome_message": "Sign in to Invoicer",
    "signup_message": "Create your Invoicer account",
    "footer_message": "Invoicer by Acme",
    "terms_url": "https://acme.example/terms",
    "privacy_url": "https://acme.example/privacy",
    "support_url": "https://acme.example/support"
  },
  "auth_methods": { "email_password": true, "signup_enabled": true, "invitation_only": false },
  "registration":  { "require_email_verification": false, "collect_name": true, "default_landing": "parent" },
  "security": {
    "post_logout_redirect_uri": "https://invoicer.acme.example",
    "remember_me_enabled": true,
    "accept_invite_url":       "https://invoicer.acme.example/welcome",
    "accept_invite_error_url": "https://invoicer.acme.example/invite-error",
    "accept_invite_allowed_origins": []
  }
}
```
What the knobs mean:
- `login_template`: `default`, `dark`, or `v3`.
- `signup_enabled: false` with `invitation_only: false` means nobody can join. `invitation_only: true` wins over `signup_enabled`.
- `registration.default_role` and `default_team`: **do not set these**; step 04 fills them from `permissions.json`. (`default_role` in this file is the literal role the server assigns at sign-up; the one in `permissions.json` is what feeds it.)
- `default_landing`: `"parent"` (default) lands a user in `invoicer-users`; `"workspace"` lands them straight in their own workspace org and **requires** `org_structure.pattern: "workspace-per-user"` (SOP 09).
- `accept_invite_url` / `accept_invite_error_url`: where the auth service sends an invitee after clicking an email link (`?code=` on success; `?reason=used|expired|not_found|invalid` on failure). Leave unset to use the built-in pages.
- `accept_invite_allowed_origins`: the origins those two URLs may point at, as `scheme://host[:port]`, no path. Leave empty and the origins of your `oauth-client.json` redirect URIs are used, which is almost always what you want.

**2. Validate, preview, apply.** Two steps own this file: 03 writes it on your service org, 04 on your users org (with the role and team filled in).
```sh
authsetup --config-dir ./config validate
authsetup --env dev --config-dir ./config up          # plan (the login settings show as ~ re-sent), yes, apply
# expert path, just these two steps:
authsetup --env dev --config-dir ./config --dry-run run 03 04
authsetup --env dev --config-dir ./config run 03 04
```
Fields you set overwrite; fields you omit are kept.

**3. Look at it.**
```sh
authsetup --env dev login-url --check     # prints your users' sign-in page and checks it answers (exit 1 if not)
```
Open `https://auth.dev.ab0t.com/login/invoicer-users`. The public part of the configuration is readable by anyone, which is also how a custom frontend can render your branding:
`GET https://auth.dev.ab0t.com/organizations/invoicer-users/login-config/public` returns `branding`, `content` and `auth_methods` only; `registration` and `security` are never exposed.

**4. Use it from your app.** Link "Sign in" to the hosted URL (optionally `?redirect=<where to return>`), or use the SDK redirect flow from SOP 06. For sign-up, `screen_hint: 'signup'` opens the page on the register form.

## What you'll see

`run 04` prints `~ re-sent: PUT login-config on end-users org (default_role=invoicer-user, default_team=<id>, org_structure=flat, default_landing=parent)  (authsetup cannot compare this setting, so it sends it again — same values)` and `✓ hosted login page OK: …/login/invoicer-users`. The `~ re-sent` line is not a change by itself: the tool cannot read this setting back to compare it, so it sends your file again every run; your edit is live on the next page load. `login-url --check` prints the address and exits `1` with `the page does not answer: …` when it does not; before the first `up` on an environment it prints the address it *will* create and says `(expected address — … is not set up on dev yet; …)`.

## If it goes wrong

- `HTTP 400: … Login config validation failed`: almost always an `accept_invite_*` URL whose origin is not in the allow-list. `https://` and `http://` are different origins; entries take no path and no trailing slash.
- `branding.primary_color` rejected: use `#RRGGBB`, not a colour name.
- The logo does not change: the file is cached by your CDN or browser, not by the auth service.
- `registration.default_landing="workspace" but org_structure.pattern="flat"`: a warning; login falls back to the parent org until you switch the pattern.
- Branding reverted after a run: this file is the source of truth; whatever it says wins on every run. Fix the file, not the server.

## Coming

- **Logo upload.** *Today* `logo_url` must be a URL you host (`http(s)` only).
- **Social and enterprise SSO switches in this file.** *Today* providers are configured on the auth service's `/providers` API, not here; the hosted page shows whatever is enabled.

## Next

SOP 08 for drop-in account UI, or SOP 09 for how your users are organised.
