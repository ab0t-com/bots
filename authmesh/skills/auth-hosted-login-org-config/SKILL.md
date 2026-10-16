---
name: auth-hosted-login-org-config
description: >-
  Change how your customers' hosted login page looks and behaves on the ab0t auth mesh: colours,
  logo, wording, template, sign-up open vs invitation-only, email verification, where people land
  after login or logout, where an invitation link sends people, which sites may embed the page.
  Use when someone wants to edit or audit config/hosted-login.json, re-brand the login page, turn
  sign-up off, set accept_invite_url / accept_invite_allowed_origins, or fix "Login config validation
  failed". Short router: the procedure is Ally SOP 07 and the field list is in the hosted-login-setup
  skill.
---

# Your login page's settings

## What this is

Everything about your customers' login page lives in one file you keep in your repo,
`config/hosted-login.json`, and `authsetup` applies it. Change the file, preview, apply; the file wins
on every run, so the page never drifts from what you reviewed.

## The picture

| you want to change | field(s) | applies |
|---|---|---|
| colours, logo, title, template | `branding.*` | next page load |
| wording, footer links, terms/privacy/support | `content.*` | next page load |
| open sign-up / invitation only / nobody | `auth_methods.signup_enabled`, `auth_methods.invitation_only` | next page load |
| email verification, asking for a name | `registration.require_email_verification`, `registration.collect_name` | new sign-ups |
| land in the user's own workspace | `registration.default_landing: "workspace"` (needs `workspace-per-user`) | next login |
| after logout / after accepting an invite | `security.post_logout_redirect_uri`, `security.accept_invite_url`, `security.accept_invite_error_url`, `security.accept_invite_allowed_origins` | next click |
| let your site embed the page in an iframe | `security.widget_allowed_origins` | next embed |

Every field and its default: [the `hosted-login-setup` skill's field list](../hosted-login-setup/references/login-config-schema.md).
Do not set `registration.default_role`, `default_team` or `org_structure` here: step 04 fills them
from `permissions.json`.

## Do this (the default path)

```sh
$EDITOR config/hosted-login.json
authsetup --config-dir ./config validate
authsetup --env dev --config-dir ./config up --dry-run     # login settings show as "~ re-sent"
authsetup --env dev --config-dir ./config up
authsetup --env dev login-url --check
```
Then the same with `--env prod`, in your own terminal. Do not edit the page's settings on the server by
hand: the next run puts the file back.

## What your customers notice

Branding and wording change on the next page load (their browser or your CDN may cache the logo).
Turning sign-up off stops new accounts at once and does not affect people already signed in. An
invitation email always links to the auth service first, which then sends the invitee to your
`accept_invite_url` (or the built-in pages when unset).

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| an invite URL on an origin not in the allow-list | `HTTP 400: … Login config validation failed` | add `scheme://host[:port]` (no path, no slash) or leave the list empty to use your redirect URIs' origins |
| a colour name | `branding.primary_color` rejected | `#RRGGBB` |
| `"workspace"` landing on a `flat` service | warning `registration.default_landing="workspace" but org_structure.pattern="flat"` | switch the pattern (SOP 09) or use `"parent"` |
| both sign-up switches off | nobody can join | `invitation_only: true` if you want invites |
| expecting `~ re-sent` to be a change | it appears on every run | it is not a change; the tool cannot compare this setting |

## Check it worked

```sh
authsetup --env dev login-url --check
curl -s https://auth.dev.ab0t.com/organizations/invoicer-users/login-config/public | jq '{branding, auth_methods}'
```
Still stuck: `authsetup --env dev doctor --json` and the failing output to `platform-team@ab0t.com`.

SOPs (in `authmesh/`): [07 login page and branding](../../07_sop_system_hosted_login_and_branding.md) ·
[09 your users](../../09_sop_system_your_users.md) ·
[13 changing things safely](../../13_sop_system_changing_things_safely.md).
