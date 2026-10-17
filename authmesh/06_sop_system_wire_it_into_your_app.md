# 06 · Wire it into your app

**What this is for.** Taking the four values `authsetup run` produced and putting them where your code needs them: the **service key** and **audience** in your backend, the **client id** and **org slug** in your frontend. After this, a user can sign in on your login page and your API can tell who they are and what they may do.

**Before you start.** SOP 05 done on the environment you are wiring (`dev` first). You have `jq` or any JSON reader. You have a secrets manager, or at least an `.env` file that is gitignored.

## Steps

**1. Get the values.** One command prints them for the environment, with the service key masked (family prefix, length, fingerprint) and the file that holds it:
```sh
authsetup --env dev settings                       # BACKEND and FRONTEND values; the key is never printed
authsetup --env dev settings --env-file .env       # write them into .env: a managed block, mode 0600, your other lines kept
authsetup --env dev settings --json                # the same for scripts (never the key value)
```
`--env-file` writes `AB0T_AUTH_URL`, `AB0T_AUTH_AUDIENCE`, `AUTH_SERVICE_URL`, `AUTH_SERVICE_KEY` (the real key, in the file only), `AUTH_SERVICE_KEY_ID`, `AUTHMESH_DOMAIN`, `AUTHMESH_ORG`, `AUTHMESH_CLIENT_ID` and `AUTHMESH_LOGIN_URL`. Re-running updates the block in place and warns if the same name is also set elsewhere in the file. It refuses a `.env` inside a git repository that does not ignore it (`--write-gitignore` adds the ignore line). Rename the variables in your own code if you prefer; the values are what matter.

The values live in `~/.authmesh/invoicer/`, one file per environment, if you ever need them by hand:
```sh
authsetup --env dev info                                             # the map: which file holds what
jq -r .client_id        ~/.authmesh/invoicer/end-users-oauth-client.dev.json   # frontend client id (public)
jq -r .org_slug         ~/.authmesh/invoicer/end-users-org.dev.json           # invoicer-users
jq -r .hosted_login_url ~/.authmesh/invoicer/end-users-org.dev.json           # https://auth.dev.ab0t.com/login/invoicer-users
jq -r .api_key.key      ~/.authmesh/invoicer/invoicer.dev.json                # SERVICE KEY — secret; pipe it into your secrets store
```
Your **audience** is the `service.audience` you wrote in `permissions.json` (`invoicer`). It is also the slug of your service org.

Two sign-in clients exist on purpose: `oauth-client.dev.json` is for your **own admin surface** (service org); `end-users-oauth-client.dev.json` is for **your customers** (users org). Your product frontend uses the second one. `authsetup --env dev whois <client_id>` tells you which is which if you lose track.

**2. Backend: verify every request.** Your API receives either `Authorization: Bearer <jwt>` from a signed-in user or `X-API-Key: <key>` from another service. Never decode or trust either yourself; ask the auth service, and always pass your audience so a token minted for someone else is refused.

*Python (FastAPI), with `ab0t_auth`:*
```
# requirements.txt  (or: pip install "git+https://github.com/ab0t-com/auth_wrapper.git@v0.1.4")
ab0t-auth @ git+https://github.com/ab0t-com/auth_wrapper.git@v0.1.4
```
```python
# app/auth.py
from ab0t_auth import AuthGuard, AuthenticatedUser, require_permission
from ab0t_auth.middleware import register_auth_exception_handlers

auth = AuthGuard(
    auth_url=settings.AB0T_AUTH_URL,        # https://auth.dev.ab0t.com  (prod: https://auth.service.ab0t.com)
    audience=settings.AB0T_AUTH_AUDIENCE,   # "invoicer"  — your service.audience
    permission_check_mode="server",         # revocations take effect at once, not when the token expires
)

InvoiceReader = Annotated[AuthenticatedUser, Depends(require_permission(auth, "invoicer.read.invoices"))]

# app/main.py
async with auth.lifespan(): ...             # in your FastAPI lifespan
register_auth_exception_handlers(app)       # proper 401/403 bodies
```
Environment: `AB0T_AUTH_URL`, `AB0T_AUTH_AUDIENCE=invoicer`. Always pass your audience; never leave it out to make a `401` go away. Never set `AB0T_AUTH_BYPASS=true` (it also needs `AB0T_AUTH_DEBUG=true`, and signs every request in as a fake user) outside a local sandbox. Then, in every route that takes a resource id, load the resource and check that it belongs to the caller; permission says *what kind* of thing they may do, not *whose*. With a workspace per user, compare the resource's `org_id` with the caller's. In a shared space (`flat`), every customer has the same `org_id`, so store the owner's `user_id` on each record and compare that instead (SOP 09 step 2).

From `ab0t_auth` 0.1.4 answers are cached briefly by default: a revoked grant stops passing within 15 s, a revoked API key within 60 s. For sensitive routes (admin, money, ownership) pass `fresh=True` to the dependency (`require_permission(auth, "…", fresh=True)`) so that call always asks the auth service. Every TTL is configurable; `token_cache_ttl=0` turns caching off. SOP 15 step D has the upgrade kit.

*Go, with `auth-sdk-go`:*
```sh
go get github.com/ab0t-com/auth-sdk-go@latest      # v0.12.1 or later
```
```go
import auth "github.com/ab0t-com/auth-sdk-go"

client := auth.New(os.Getenv("AUTH_SERVICE_URL"),        // "" = prod; "https://auth.dev.ab0t.com" for dev
    auth.WithAPIKey(os.Getenv("AUTH_SERVICE_KEY")),       // your invoicer-internal key, for calls your service makes
    auth.WithExpectedJWTAudience("invoicer"),             // reject user tokens minted for another service
)

actor, err := client.ValidateToken(ctx, bearer)          // who is this?
switch {
case auth.IsUnauthorized(err) || (err == nil && !actor.Valid): /* 401 */
case err != nil:                                         /* 503 — could not decide */
}
ok, err := client.Authorize(ctx, bearer, "invoicer.write.invoices", auth.Resource{Type: "invoice", ID: id})
if err != nil { /* 503 — never treat an error as yes */ }
if !ok     { /* 403 */ }
```
Three rules the SDK README states and you should too: a nil error is not a yes (check `ok`); never turn an error into an allow; always set the expected audience.

Which audience option: `WithExpectedJWTAudience` (v0.12.1) checks user tokens only, so the same routes can also accept other services' mesh keys (`X-API-Key`), which carry no audience. `WithExpectedAudience` checks API keys too and therefore rejects those keys; use it only if your API takes user tokens and nothing else. From v0.12.0 answers are cached briefly by default (a revocation reaches your process within 15 s for users and permissions, 60 s for API keys); wrap a sensitive call's context in `auth.WithFreshValidation(ctx)` to always ask, or `auth.WithValidationCache(0)` to turn caching off. With the `authmw` middleware from v0.12.1, an invalid or expired token is a `401` (it used to be a `503`). SOP 15 step C has the upgrade kits.

*Any language:* for a user token, `POST /auth/validate-token {"token": …, "expected_audience": "invoicer", "include_permissions": true}`. **Send `include_permissions: true`.** Without it (and without `required_permissions`) the answer carries `"permissions": []` even for a user who has permissions, so a backend that checks that list turns every customer away. Then decide:
- `valid: false` → `401`
- `valid: true` but the permission you need is not in `permissions` → `403`
- a `5xx` or no answer → `503`, never allow

`"required_permissions": ["invoicer.write.invoices"]` also works, but a missing permission then comes back as `valid: false` with `error: "Missing required permission: …"`, so you can't tell 401 from 403 without reading `error`.

For another service's key, `POST /auth/validate-api-key {"api_key": …, "required_permissions": [...]}` (a key's `permissions` come back without asking). Both answer `{valid, user_id, org_id, permissions, …}`. The live contract is `/openapi.json` on your environment's auth URL (`authsetup env` shows it).

*Does the validate call need your service key?* No. `/auth/validate-token` and `/auth/validate-api-key` are open on purpose: the auth service checks the token or key in the body. Today it ignores an `X-API-Key` header on these two calls, and the answer is the same with or without one. Your service key is for calls your service makes as itself, such as `POST /permissions/check` (which needs a caller credential) or another mesh service that takes your key. The Go SDK sends the key you gave `WithAPIKey` on every call, these two included, and that does no harm. When an environment rate-limits these two calls, it counts per calling IP address, not per key. Whether a later version will use a caller's key here (for rate limits or audit) has not been decided; nothing requires it today.

**3. Frontend: sign people in.** Two choices (SOP 07 has the page itself; SOP 08 has drop-in widgets).

*Redirect to your hosted page (simplest).* Let the tool write it with your real values filled in:
```sh
authsetup --env dev snippet login > login.html     # only the snippet goes to stdout
```
It follows the mesh's one token standard: load the SDK once, ask it for a token every time, never keep a token yourself, react to `session_expired`. The shape:
```html
<script src="https://auth.dev.ab0t.com/login/_static/authmesh.global.js"></script>
<script>
  const auth = new AuthMesh.AuthMeshClient({
    domain:      'https://auth.dev.ab0t.com',          // prod: https://auth.service.ab0t.com
    org:         'invoicer-users',                      // your users' org slug, not "invoicer"
    clientId:    '<client_id — authsetup settings prints it>',
    redirectUri: 'http://localhost:3000/auth/callback', // must be one of oauth-client.json redirect_uris
  });
  auth.on('session_expired', () => auth.loginWithRedirect());   // the session really ended
  // "Sign in" button:                     await auth.loginWithRedirect();
  // on /auth/callback:                    await auth.handleCallback();
  // calling YOUR API:                     const res = await auth.authFetch('/api/invoices');
  // another HTTP client:                  const token = await auth.getValidToken();   // right before EACH request; never store it
</script>
```
`authFetch` and `getValidToken` need `@authmesh/sdk` 0.4.1 or newer on that auth host (`<auth>/login/_static/authmesh.version.json`); the generated snippet says so in the browser console if the host serves an older one. Never copy a token into your own variable or storage, and never use the old synchronous `getAccessToken()` before a request.
*No OAuth client at all (you own the form):* the same two calls the hosted page makes, both on your USERS org's slug:
- sign up: `POST <auth>/organizations/invoicer-users/auth/register {"email", "password", "name"}`
- sign in: `POST <auth>/organizations/invoicer-users/auth/login {"email", "password"}`

Refresh at `/auth/refresh`. Use the org-scoped register, not the global `/auth/register`: a person who signs up globally is in no org of yours and gets 403 later. `<auth>` is your environment's URL (`authsetup env`). Testing from a terminal:
```sh
AUTH=https://auth.dev.ab0t.com
curl -s -X POST "$AUTH/organizations/invoicer-users/auth/register" -H 'Content-Type: application/json' \
  -d '{"email":"test+1@yourco.example","password":"<a strong password>","name":"Test One"}'
```
The answer carries `access_token` and `audience: ["invoicer"]`. The hosted page also accepts `?redirect=<url>` and sends people back there.

*The OAuth client path by hand (what the hosted page does after sign-in):* `GET <auth>/auth/authorize?response_type=code&client_id=<client_id>&redirect_uri=<one of your redirect_uris>&code_challenge=<S256>&code_challenge_method=S256` needs the **signed-in customer's bearer** (`Authorization: Bearer <their access_token>` from the sign-in above); without it the answer is `401 {"detail":"Authentication required"}`. It returns JSON `{"code", "redirect_url"}`. Exchange the code at the `token_endpoint` from `<auth>/.well-known/oauth-authorization-server` (`/auth/oauth/token`, form body `grant_type=authorization_code`, `code`, `client_id`, `redirect_uri`, `code_verifier`).

**4. Put the values in the right place.**

| value | goes to | secret? |
|---|---|---|
| `api_key.key` from `invoicer.<env>.json` | backend env (`AUTH_SERVICE_KEY` or whatever you name it) | **yes** — server only, never in a bundle, never in chat |
| `service.audience` (`invoicer`) | backend env | no |
| `client_id` from `end-users-oauth-client.<env>.json` | frontend config | no (ships to the browser) |
| `invoicer-users` | frontend config | no |
| `hosted_login_url` | your "Sign in" link | no |

**5. Try it end to end.** Open the hosted login URL, sign up a test user, land on your callback, call your API with the bearer token. Expect `200` on `invoicer.read.invoices` routes and `403` on `invoicer.write.invoices` routes (not a default). A newly registered permission can take up to about five minutes to appear, or shows at once on a fresh login.

## What you'll see

A valid call returns the caller's `user_id`, `org_id` and `permissions`. A user token's permissions are *computed* from their org and teams; an API key's permissions are *fixed* at creation. The same endpoint can therefore answer `200` to a user and `403` to a key. If a key lacks something, it must be re-minted (SOP 14); it cannot be edited.

## If it goes wrong

- `401 Audience doesn't match` from your service, with users stuck in a login loop: your backend's audience and the org's audience differ. Check `authsetup --env dev run 06`; if it warns the token audience is `SELF:<org id>`, see SOP 16.
- `403` for a user who should have access: are they in `invoicer-users`? Did they sign up through *your* hosted page (org-scoped), not the global sign-up? Is the permission `default_grant: true`? Fresh login after a change.
- `403` for your own service key: `authsetup --env dev doctor` reports `service key ◐ UNDER-PERMISSIONED` when the key holds fewer permissions than config declares. Re-mint (SOP 14).
- `invalid redirect_uri` on sign-in: the browser's `redirectUri` is not byte-identical to one in `oauth-client.json`. Add it and `run 04` (customers' client) or `run 02` (admin client).
- `window.AuthMesh is undefined`: two scripts both define that global (the login SDK and `auth-widget.js`). Load one of them.

## Coming

- **Snippets for frameworks** (`--framework react` and friends) and for the widgets (`authsetup snippet <widget>`, SOP 08). *Today:* `--framework plain` (HTML + the browser SDK), which works in any page.

## Next

SOP 07, the login page and your branding. SOP 08 if you want ready-made account UI.
