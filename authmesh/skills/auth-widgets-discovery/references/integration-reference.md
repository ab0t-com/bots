# ab0t sign-in in the browser — integration reference

Public detail for the three browser pieces. `<auth>` = `https://auth.service.ab0t.com` (dev:
`https://auth.dev.ab0t.com`). `org` / `orgSlug` = your **users** org slug (`invoicer-users`);
`clientId` / `redirectUri` come from your customers' OAuth client (`authsetup --env <env> settings`).

## Contents
1. The login SDK (`window.AuthMesh`)
2. The widget library (`window.AuthMeshWidgets`)
3. The iframe drop-in (`auth-widget.js`)
4. What happens during sign-in
5. Sessions and tabs

## 1. Login SDK — `new AuthMesh.AuthMeshClient(config)`

`config`: `{ domain, org, clientId, redirectUri, postLogoutUri?, scope?, usePopup?, autoRefresh?, versionCheck? }`.
- `loginWithRedirect({ screen_hint? })` + `handleCallback()` on the callback page; `loginWithPopup()`.
- `authFetch(url, init)` and `getValidToken()` (0.4.1+): the only ways to get a token for a request.
- `loginWithProvider(type)`, `loginWithSSO({ provider_id? })`, `getProviders()`.
- `logout()`, `getUser()`, `fetchUser()`, `fetchOrganizations()`, `switchOrganization(orgId)`.
- Events via `on()`: `login`, `logout`, `token_refreshed`, `refresh_error`, `session_cleared`,
  `session_expired`, `sdk_outdated`, `error`.

Full list: [the `hosted-login-setup` skill's SDK reference](../../hosted-login-setup/references/sdk-integration.md).

## 2. Widget library — `AuthMeshWidgets`

Load the pinned version from the catalogue (`<auth>/login/_static/sdk-catalog.json` →
`authmesh-widgets` → `latest`):
```html
<script src="https://get.tool.ab0t.com/p/authmesh-widgets/@<version>/authmesh-widgets.js"></script>
```
Configure once, then mount widgets into containers:
```js
AuthMeshWidgets.configure({
  authBase: 'https://auth.service.ab0t.com',
  orgSlug:  'invoicer-users',
  getToken: () => auth.getValidToken(),   // required for account and admin widgets
});
AuthMeshWidgets.userMenu({ container: '#menu' });
AuthMeshWidgets.on('logout',        () => location.reload());
AuthMeshWidgets.on('org-changed',   (org) => myApp.reload(org));
```

| widget | options (required in bold) |
|---|---|
| `login`, `signup`, `passwordReset`, `magicLink`, `emailVerify` | `onSuccess`, `title`, `forgotHref` (login), `loginHref` (signup), `token` (emailVerify) |
| `userMenu` | `items:[{label,href}]`, `loginHref`, `onLogout` |
| `profile` | — |
| `orgSwitcher` | `onChange`, `currentOrgId` |
| `apiKey` | **`scope:[…]`**, `keyName`, `compact`, `manageHref`, `docsHref` |
| `invite` | **`orgId`**, `roles:[…]` |
| `usage` | `upgradeHref` |
| `sessions` | **`orgId`** |
| `passkey` | — |
| `delegation` | **`userId`**, `orgId`, `scopes` |
| `teamSelector` / `teamCreate` / `teamHierarchy` | **`orgId`**; `onSelect` / `onCreate` |
| `teamMembers` | **`teamId`**, `roles` |
| `userList` | **`orgId`**, `role`, `limit` |
| `roleAssign` | **`orgId`**, **`userId`** |
| `permCheck` | `orgId` |
| `accessControl` | **`storeId`**, `orgId` |
| `reports` / `activity` | `status`, `category`, `limit` / `limit` |
| `cliInstall` | `cli` |

The bootstrap widgets (`login`, `signup`, …) hand your page the tokens once and store nothing; use them
only on pages that do not run the login SDK. Everything renders in a shadow DOM.

## 3. Iframe drop-in — `auth-widget.js`

```html
<script src="https://auth.service.ab0t.com/login/_static/auth-widget.js"></script>
<div id="login-box"></div>
<script>
  AuthMesh.init({ container: '#login-box', domain: 'https://auth.service.ab0t.com',
    org: 'invoicer-users', clientId: '<client id>', redirectUri: 'https://invoicer.acme.example/auth/callback',
    onSuccess: (tokens) => { /* signed in */ } });
  // or: AuthMesh.popup({ … }).then(tokens => { … })
</script>
```
The iframe names your page's origin to the auth service, which frames the page only for origins listed
in your login settings' `security.widget_allowed_origins` (set it in `hosted-login.json` and run
`authsetup --env <env> --config-dir ./config up`). It defines `window.AuthMesh`, so do not load it next
to the login SDK. It returns tokens once; it does not keep a session for you.

## 4. What happens during sign-in

1. The SDK or drop-in sends the user to `<auth>/login/{org}` with OAuth 2.1 + PKCE parameters
   (`response_type=code`, `code_challenge`, `state`, optional `screen_hint`).
2. The hosted page handles password, social, SSO, MFA, passkeys and reset, in your branding.
3. It returns an authorization `code`; the SDK checks `state` and exchanges the code at
   `POST /organizations/{org}/auth/token` for tokens.

Calls with a bearer token work from your own domain; cookie-based calls across origins do not.

## 5. Sessions and tabs

Let the login SDK hold the session. From 0.4.1 it refreshes in the background, runs one refresh across
your open tabs, backs off on server hiccups, and clears the session only on a real auth failure
(`session_expired`). Never copy a token into your own storage; ask `getValidToken()` each time.
