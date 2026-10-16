# AuthMesh browser SDK — reference

Load it from the auth service you sign in against (it is not an npm package):
`<script src="https://auth.service.ab0t.com/login/_static/authmesh.global.js"></script>` (dev:
`https://auth.dev.ab0t.com/…`). The global is `window.AuthMesh`. The version that host serves is in
`<auth>/login/_static/authmesh.version.json`; the current release is listed in
`https://auth.service.ab0t.com/login/_static/sdk-catalog.json` (`authmesh-sdk` → `latest`). Methods
marked 0.4.1+ need that version or newer on the host. `authsetup --env <env> snippet login` writes a
working page for you.

## Config — `new AuthMesh.AuthMeshClient(config)`

```typescript
interface AuthMeshConfig {
  domain: string          // auth service URL, e.g. "https://auth.service.ab0t.com"
  org: string             // your USERS org slug, e.g. "invoicer-users"
  clientId: string        // the customers' OAuth client id (authsetup settings)
  redirectUri: string     // byte-identical to one of oauth-client.json redirect_uris
  postLogoutUri?: string  // where logout sends people
  scope?: string          // default "openid profile email"
  usePopup?: boolean
  popupWidth?: number     // default 500
  popupHeight?: number    // default 650
  autoRefresh?: boolean   // default true: refresh in the background, one refresh across tabs
  versionCheck?: boolean  // default true: at most once a day, a console notice when the host's SDK is outdated
}
```

## Signing in and out

- `loginWithRedirect({ screen_hint?: 'signup' | 'login' })`: full-page redirect to `/login/{org}` with PKCE.
- `loginWithPopup({ screen_hint? })`: a popup; resolves with tokens.
- `handleCallback()`: call on your `redirectUri` page; checks `state`, exchanges the code, cleans the URL.
- `loginWithProvider(type)`, `loginWithSSO({ provider_id?, callback_url? })`, `getProviders()`: social and
  enterprise sign-in, as enabled on your org.
- `logout()`: clears the session, tells the server, redirects to `postLogoutUri`.

## Calling your API (the token standard)

- **`authFetch(url, init)`** (0.4.1+): `fetch` with a valid token attached; on a `401` it refreshes once
  and retries once. Use this.
- **`getValidToken({ forceRefresh? })`** (0.4.1+): a token valid for at least 30 s, or `null` with no
  session. Call it right before each request when you use another HTTP client; never store the result.
- `getAccessToken()`: a synchronous peek kept for compatibility; do not use it for requests.
- `refreshToken()`: the SDK calls it for you.
- `dispose()`: stops background work (single-page-app unmount).

Rules (`https://auth.service.ab0t.com/login/_static/guides/AUTH_INTEGRATION_STANDARD.md`): load the SDK
once, ask it for a token every time, never keep a token yourself, react to `session_expired`.

## User, orgs, permissions

- `isAuthenticated()`, `getUser()` (cached), `fetchUser()` (from the server), `getState()`.
- `fetchOrganizations()`, `fetchMyMembership()`, `switchOrganization(orgId)`, `findMyWorkspace()` (for
  `workspace-per-user`).
- `orgRegister({ email, password, name?, invitation_code? })`, `orgRequestPasswordReset(email)`.
- `checkPermission(userId, permission, orgId?)`, `getUserPermissions(userId, orgId?)`,
  `getValidPermissions()`, `getRoles()`.

UI permission checks are for showing and hiding buttons only; your backend must still check every
request (Ally SOP 06).

## Events — `on(event, handler)` returns an unsubscribe function

`login`, `logout`, `token_refreshed`, `refresh_error`, `session_cleared`, `session_expired` (the refresh
was refused: send the user to sign in), `sdk_outdated`, `error`.

## Under the hood

The code-for-token exchange and refresh use `POST /organizations/{org}/auth/token`
(`application/x-www-form-urlencoded`, `grant_type=authorization_code` with `code`, `client_id`,
`redirect_uri`, `code_verifier`; or `grant_type=refresh_token`). Session data is kept in the browser
under `authmesh_*` keys (PKCE values in `sessionStorage`); treat them as the SDK's, not yours.

## Without the SDK

- Send people to the hosted page and back: `https://auth.service.ab0t.com/login/invoicer-users?redirect=<url>`.
- Own the form yourself: `POST /organizations/invoicer-users/auth/login {email, password}`,
  `/auth/register`, `/auth/refresh`. You then own token storage and refresh, which is exactly what the
  SDK exists to get right; prefer the SDK.
