---
name: hosted-login-setup
description: >-
  Add sign-in to a product with the ab0t hosted login page and the AuthMesh browser SDK. Use when a
  team wants a branded login / sign-up page for its customers, a "Sign in" button that redirects (or a
  popup), the callback page, calling its own API with a fresh token (authFetch / getValidToken), the
  backend check with the right audience (ab0t_auth / auth-sdk-go WithExpectedJWTAudience), the
  login-config fields in hosted-login.json (branding, sign-up vs invitation-only, invite landing
  pages, embedding the page in an iframe), or debugging redirect_uri / audience / login-loop problems.
  Routes to Ally SOPs 06 and 07 for the procedure.
---

# Hosted login for your product

## What this is

Your customers sign in on a page the auth service hosts for you at
`https://auth.service.ab0t.com/login/<your users org>`, in your colours and words, with sign-up,
password reset, social and enterprise sign-in already built. Your frontend only redirects there and
back; your backend only checks each request's token, with your audience, so you never store
passwords or build login forms.

## The picture

```
browser  "Sign in" ──► auth: /login/invoicer-users  (your hosted-login.json branding)
   ▲                         │ OAuth 2.1 + PKCE, code
   └──── /auth/callback ◄────┘  auth.handleCallback()
   │
   └─ auth.authFetch('/api/…') ──► your API ── ab0t_auth / auth-sdk-go: valid? audience "invoicer"? permission?
```

| value | where it comes from | where it goes | secret? |
|---|---|---|---|
| auth URL | `https://auth.dev.ab0t.com` (dev) / `https://auth.service.ab0t.com` (prod) | frontend + backend | no |
| users org slug (`invoicer-users`) | `authsetup --env dev settings` | frontend `org` | no |
| client id | `end-users-oauth-client.<env>.json` via `settings` | frontend `clientId` | no |
| audience (`invoicer`) | your `service.audience` | backend | no |
| service key | `invoicer.<env>.json` via `settings --env-file` | backend only | **yes** |

## Do this (the default path)

```sh
authsetup --env dev --config-dir ./config up               # creates the users org, the sign-in client, applies hosted-login.json
authsetup --env dev settings --env-file .env               # backend + frontend values; the key goes into the file only
authsetup --env dev snippet login > login.html             # a working sign-in block with your real values
authsetup --env dev login-url --check                      # the page answers
```
The snippet follows the mesh's token standard; its shape:
```html
<script src="https://auth.dev.ab0t.com/login/_static/authmesh.global.js"></script>
<script>
  const auth = new AuthMesh.AuthMeshClient({
    domain: 'https://auth.dev.ab0t.com',              // prod: https://auth.service.ab0t.com
    org: 'invoicer-users',                            // your USERS org slug
    clientId: '<client_id from authsetup settings>',
    redirectUri: 'http://localhost:3000/auth/callback', // byte-identical to one in oauth-client.json
  });
  auth.on('session_expired', () => auth.loginWithRedirect());
  // Sign in:  await auth.loginWithRedirect()   (sign-up: loginWithRedirect({ screen_hint: 'signup' }))
  // Callback: await auth.handleCallback()
  // Your API: await auth.authFetch('/api/invoices')   — or getValidToken() right before each request
</script>
```
Backend, Python: `AuthGuard(auth_url=…, audience="invoicer", permission_check_mode="server")` from
`ab0t_auth`, installed with `pip install "git+https://github.com/ab0t-com/auth_wrapper.git@v0.1.4"`.
Go: `auth.New(url, auth.WithAPIKey(key), auth.WithExpectedJWTAudience("invoicer"))` from
`github.com/ab0t-com/auth-sdk-go` v0.12.1+. Your audience is your `service.audience`; never `LOCAL:…`
and never skip the check. Full code: SOP 06.

Branding, sign-up rules and invite landing pages: edit `config/hosted-login.json`, then
`authsetup --env dev --config-dir ./config up` (SOP 07; field list in
[references/login-config-schema.md](references/login-config-schema.md)). Every SDK method and event:
[references/sdk-integration.md](references/sdk-integration.md).

## What your customers notice

- Your logo, colours and wording on the page; sign-up only if you allow it (`signup_enabled`,
  `invitation_only`); an invitation email lands them on your `accept_invite_url`.
- Sessions refresh in the background; when the refresh is refused they are sent to sign in again
  (`session_expired`). Tokens last 15 minutes; your app never stores them.
- Your API answers `401` for no or bad token (they sign in again), `403` for a permission they lack, and
  `503` when the auth service could not be asked (retry; never treated as allowed). Revoking someone
  takes effect within the SDK cache window (15 s permissions, 60 s keys) when the backend checks with
  the server; otherwise when their token expires.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| backend audience wrong | `401 Audience doesn't match`, users loop back to login | `AB0T_AUTH_AUDIENCE=invoicer` / `WithExpectedJWTAudience("invoicer")`; `authsetup --env dev run 06` shows the token audience |
| org created without an audience by an older tool | step 06 warns `token audience is "SELF:<org id>", not "invoicer" — …` | immutable; contact the platform team (SOP 16) |
| callback URL not registered | `invalid redirect_uri` on sign-in | add it byte-for-byte to `oauth-client.json`, `up` (`run 04` for the customers' client) |
| using the service org slug in the frontend | users land in your staff org, no permissions | `org: 'invoicer-users'` |
| login SDK and `auth-widget.js` on one page | `window.AuthMesh` / `AuthMesh.AuthMeshClient is undefined` | load only one |
| keeping a token yourself, or the old `getAccessToken()` | expired-token `401`s | `authFetch` or `getValidToken()` per request (`@authmesh/sdk` 0.4.1+) |
| an invite URL on an origin not allowed | `HTTP 400: … Login config validation failed` | add the origin to `accept_invite_allowed_origins`, or leave it empty to use your redirect URIs' origins |

## Check it worked

```sh
authsetup --env dev login-url --check                     # exit 0 when the page answers
authsetup --env dev --config-dir ./config run 06          # throwaway sign-up: defaults held, audience matches, user removed
curl -s https://auth.dev.ab0t.com/organizations/invoicer-users/login-config/public | jq .branding
```
Then sign up a test user through your page and call your API: `200` on a default permission, `403` on
one you did not grant. Still stuck: `authsetup --env dev doctor --json`, `status --json` and the failing
output to `platform-team@ab0t.com`.

## SOPs (in `authmesh/`) and public guides

[06 wire it into your app](../../06_sop_system_wire_it_into_your_app.md) ·
[07 login page and branding](../../07_sop_system_hosted_login_and_branding.md) ·
[08 widgets](../../08_sop_system_js_widgets.md) ·
[16 troubleshooting](../../16_sop_system_troubleshooting_and_recovery.md). The auth service also serves
client guides: `https://auth.service.ab0t.com/login/_static/guides/AUTH_INTEGRATION_STANDARD.md` (the
token rules), `…/CLIENT_HOSTED_LOGIN_INTEGRATION.md`, and current SDK versions in
`https://auth.service.ab0t.com/login/_static/sdk-catalog.json`.
