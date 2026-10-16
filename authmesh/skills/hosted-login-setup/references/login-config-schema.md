# `config/hosted-login.json` — every field

This file is your login page's configuration. `authsetup --env <env> --config-dir ./config up` sends it
to your service org (step 03) and to your users org (step 04, with your default role and team filled
in). Fields you set overwrite; fields you omit keep their current value. Edit the file, never the
server: the file wins on every run (Ally SOP 07).

## Shape, with the server's defaults

```json
{
  "branding": {
    "logo_url": null,
    "primary_color": "#2563EB",
    "background_color": "#FFFFFF",
    "page_title": null,
    "custom_css": null,
    "hide_powered_by": false,
    "login_template": "default"
  },
  "content": {
    "welcome_message": null,
    "signup_message": null,
    "footer_message": null,
    "terms_url": null,
    "privacy_url": null,
    "support_url": null,
    "trust_section_label": null,
    "trust_logos": [],
    "footer_link_prefix": null,
    "footer_link_text": null,
    "footer_link_url": null
  },
  "auth_methods": {
    "email_password": true,
    "signup_enabled": true,
    "invitation_only": false
  },
  "registration": {
    "require_email_verification": true,
    "collect_name": true,
    "default_landing": "parent"
  },
  "security": {
    "post_logout_redirect_uri": null,
    "remember_me_enabled": true,
    "accept_invite_url": null,
    "accept_invite_error_url": null,
    "accept_invite_allowed_origins": [],
    "widget_allowed_origins": []
  }
}
```

## Fields that need a word

**branding**
- `primary_color`, `background_color`: `#RRGGBB` only; a colour name is rejected.
- `logo_url`: an `http(s)` URL you host (no upload yet). A stale logo is your CDN's cache.
- `login_template`: `default`, `dark` or `v3`. `trust_section_label`, `trust_logos` (`[{url, alt}]`) and
  `footer_link_*` show on `v3`.
- `hide_powered_by`: hides the "Powered by" footer.

**auth_methods**
- `invitation_only: true` wins over `signup_enabled`.
- `signup_enabled: false` with `invitation_only: false` means nobody can join.
- Social and enterprise sign-in (Google, SAML, …) are configured on the auth service's providers, not
  here; the page shows whatever is enabled.

**registration**
- `default_role`, `default_team`, `org_structure`: **do not set them here**. Step 04 fills them from
  `permissions.json` on every run.
- `default_landing`: `"parent"` lands a user in your users org; `"workspace"` lands them in their own
  workspace and needs `org_structure.pattern: "workspace-per-user"` (otherwise login falls back to the
  parent, with a warning).

**security** (never shown publicly)
- `post_logout_redirect_uri`: where people go after logout.
- `accept_invite_url`: where an invitee is sent after clicking the email link, with `?code=…`.
  `accept_invite_error_url` gets `?reason=used|expired|not_found|invalid`. Leave both unset to use the
  built-in pages (the invitee then lands on your hosted page's sign-up form).
- `accept_invite_allowed_origins`: the origins those two URLs may use, as `scheme://host[:port]` with no
  path and no trailing slash (`https://app.example.com`, `http://localhost:3000`). Leave it empty and
  the origins of your `oauth-client.json` redirect URIs are used, which is almost always right.
  `https://` and `http://` are different origins; wildcards are not accepted.
- `widget_allowed_origins`: the exact origins allowed to embed your login page in an iframe (the
  `auth-widget.js` drop-in, SOP 08). Empty means no site may embed it.

## Reading it back

`GET https://auth.dev.ab0t.com/organizations/invoicer-users/login-config/public` returns only
`branding`, `content` and `auth_methods` (plus the org's id, name and slug), with no sign-in needed; a
custom frontend can render your branding from it. `registration` and `security` are never exposed.

## What you'll see when it is wrong

- `HTTP 400: … Login config validation failed`: almost always an `accept_invite_*` URL whose origin is
  not allowed. The message is deliberately generic; check the origins.
- `registration.default_landing="workspace" but org_structure.pattern="flat"`: a warning; set the
  pattern or use `"parent"`.
- `~ re-sent: PUT login-config …` on every run: not a change; the tool cannot read this setting back to
  compare, so it sends your file again.
