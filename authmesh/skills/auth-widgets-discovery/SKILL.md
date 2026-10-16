---
name: auth-widgets-discovery
description: >-
  Pick the right ab0t building block for adding sign-in and account UI to a website or app, then
  give a copy-paste snippet. Use when someone asks "how do I add login/sign-up to my app", "which ab0t
  SDK or widget do I use", "do you have a Clerk-style <SignIn/>, login popup or modal", "embed a login
  box / user menu / API-key / org switcher widget", "what options does a widget take", "why does the
  API-key widget show an install command I can't change", "window.AuthMesh is undefined", or how to
  check tokens on the backend. Routes intent to the login SDK, the authmesh-widgets library, the iframe
  drop-in, or a backend SDK, with the gotchas. Public URLs only.
allowed-tools: Read, Grep, Glob, Bash
---

# Adding ab0t sign-in to your app — pick the right piece

## What this is

ab0t ships a few small browser pieces and two backend libraries; each solves one job. Pick by what you
want the user to see, and you avoid the two classic mistakes: two scripts fighting over one global, and
your page holding tokens it should not.

## The picture

| piece | load | global | use it for |
|---|---|---|---|
| **login SDK** | `<auth>/login/_static/authmesh.global.js` | `window.AuthMesh` (`AuthMeshClient`) | redirect or popup sign-in, the session, a fresh token per request |
| **widget library** | `https://get.tool.ab0t.com/p/authmesh-widgets/@<version>/authmesh-widgets.js` | `window.AuthMeshWidgets` | ready-made account UI (user menu, API keys, invites, teams, …) |
| **iframe drop-in** | `<auth>/login/_static/auth-widget.js` | `window.AuthMesh` (`init` / `popup`) | a login box that renders itself in a `<div>` or a popup |
| **backend, Python** | `pip install "git+https://github.com/ab0t-com/auth_wrapper.git@v0.1.4"` | `ab0t_auth` | verify tokens and API keys, permission checks (FastAPI / Flask) |
| **backend, Go** | `go get github.com/ab0t-com/auth-sdk-go@latest` | `auth` | the same for Go services |

`<auth>` is `https://auth.service.ab0t.com` (prod) or `https://auth.dev.ab0t.com` (dev). Current
versions of all of these: `https://auth.service.ab0t.com/login/_static/sdk-catalog.json`.

| you want… | use |
|---|---|
| a "Sign in" button that goes to your branded page and back | login SDK `loginWithRedirect()` + `handleCallback()` (simplest; `authsetup --env dev snippet login` writes it) |
| sign-in without leaving the page | login SDK `loginWithPopup()` |
| a login box that draws itself inside your page | iframe drop-in `AuthMesh.init({ container, … })` |
| user menu, profile, org switcher, API keys, invites, usage, team admin | widget library, fed by the login SDK |
| social, enterprise SSO, passkeys, magic links | the hosted page offers whatever is enabled for your org; or `loginWithProvider()` / `loginWithSSO()` |
| to check tokens on your server | `ab0t_auth` (Python) or `auth-sdk-go` (Go), always with your audience (Ally SOP 06); any other language: `POST /auth/validate-token` |

## Do this (the default path)

```html
<script src="https://auth.service.ab0t.com/login/_static/authmesh.global.js"></script>
<script src="https://get.tool.ab0t.com/p/authmesh-widgets/@0.3.9/authmesh-widgets.js"></script>  <!-- pin the catalogue's version -->
<button id="signin">Sign in</button> <div id="menu"></div>
<script>
  const auth = new AuthMesh.AuthMeshClient({
    domain: 'https://auth.service.ab0t.com', org: 'invoicer-users',
    clientId: '<client id from authsetup settings>', redirectUri: 'https://invoicer.acme.example/auth/callback',
  });
  auth.on('session_expired', () => auth.loginWithRedirect());
  document.querySelector('#signin').onclick = () => auth.loginWithRedirect();

  AuthMeshWidgets.configure({
    authBase: 'https://auth.service.ab0t.com',
    orgSlug:  'invoicer-users',                 // widget option names: authBase / orgSlug (not domain / org)
    getToken: () => auth.getValidToken(),       // a fresh token on every call
  });
  AuthMeshWidgets.userMenu({ container: '#menu' });
</script>
```
On your callback page call `await auth.handleCallback()`. Call your own API with
`auth.authFetch('/api/…')`. Per-widget options and the iframe drop-in:
[references/integration-reference.md](references/integration-reference.md).

## What your customers notice

Your branded page (or an inline box), sessions that renew in the background across tabs, and account
screens that only ever show and change what that user may. When the session truly ends they are asked
to sign in again (`session_expired`). Your API answers `401` (sign in again), `403` (not allowed) or
`503` (try again) and never treats an auth error as a yes.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| the login SDK and `auth-widget.js` on one page | `AuthMesh.AuthMeshClient is undefined` or `AuthMesh.init is undefined` | load one; `AuthMeshWidgets` is separate and safe beside either |
| `AuthMeshWidgets.configure({ org: … })` | widgets behave unconfigured | `orgSlug` |
| a stored token, or the old synchronous `getAccessToken()` | widgets show "sign in", API calls `401` | `getValidToken()` / `authFetch` (`@authmesh/sdk` 0.4.1+ on that auth host) |
| the iframe drop-in on a site not allowed | the box stays blank / will not frame | add your exact origin to `security.widget_allowed_origins` in `hosted-login.json`, then `authsetup --env dev --config-dir ./config up` |
| the API-key / CLI widget's install command | shows ab0t's CLIs, cannot be changed | do not render that block, or mint keys with `POST /api-keys/` (a configurable command is planned) |
| `npm install` for any of these | nothing to install | load from the URLs above; the backend libraries install from GitHub |

## Check it worked

Signed out: account widgets show a sign-in state. Signed in: `userMenu` shows the user's name, your
API returns `200` through `authFetch`, and the console has no errors. `authsetup --env dev login-url
--check` confirms the page; `authsetup --env dev doctor` the rest. Still stuck: the console errors, the
page URL and `authsetup --env dev doctor --json` to `platform-team@ab0t.com`.

More: Ally [SOP 06](../../06_sop_system_wire_it_into_your_app.md),
[SOP 07](../../07_sop_system_hosted_login_and_branding.md),
[SOP 08](../../08_sop_system_js_widgets.md); the served guides
`https://auth.service.ab0t.com/login/_static/guides/WHICH_SDK.md` and
`…/AUTH_INTEGRATION_STANDARD.md`; the `authmesh-widgets` and `hosted-login-setup` skills.
