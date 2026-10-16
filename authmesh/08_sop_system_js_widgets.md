# 08 · Drop-in JavaScript widgets

**What this is for.** Ready-made account UI for your own site: a user menu, profile, org switcher, API-key minting, invites, usage, team management, and an inline login or sign-up card. No framework, no build step; two `<script>` tags and a `<div>`.

**Before you start.** SOP 06 done: your frontend can get an access token. You know your users org slug (`invoicer-users`).

## Steps

**1. Find the widgets.**
The current version is in the public catalogue `https://auth.service.ab0t.com/login/_static/sdk-catalog.json` (entry `authmesh-widgets`, field `latest`; 0.3.9 when this page was checked), with a setup guide at `https://auth.service.ab0t.com/login/_static/guides/prompts/authmesh-widgets-setup.md`. The files are served, versioned, from `https://get.tool.ab0t.com/p/authmesh-widgets/@<version>/`. There are two families:
- **Bootstrap** widgets create a session and need no token: `login`, `signup`, `passwordReset`, `magicLink`, `emailVerify`.
- **Consumer** widgets need a token from you: `userMenu`, `profile`, `orgSwitcher`, `apiKey`, `invite`, `usage`, `sessions`, `passkey`, `delegation`, and the admin set `teamSelector`, `teamCreate`, `teamMembers`, `teamHierarchy`, `userList`, `roleAssign`, `permCheck`, `accessControl`, `reports`, `activity`. `cliInstall` is static.

**2. Embed, pinned to a version.**
```html
<script src="https://get.tool.ab0t.com/p/authmesh-widgets/@0.3.9/core.js"></script>
<script src="https://get.tool.ab0t.com/p/authmesh-widgets/@0.3.9/user-menu.js"></script>
<div id="menu"></div>
<script>
  AuthMeshWidgets.configure({
    authBase: 'https://auth.service.ab0t.com',   // dev: https://auth.dev.ab0t.com
    orgSlug:  'invoicer-users',                   // your USERS org slug
    getToken: () => auth.getValidToken()          // from the login SDK in SOP 06 (asks for a fresh token each time)
  });
  AuthMeshWidgets.userMenu({ container: '#menu', items: [{label:'Invoices', href:'/invoices'}] });
  AuthMeshWidgets.on('logout', () => location.reload());
</script>
```
- `core.js` must load first. One tag for everything: `…/@<version>/authmesh-widgets.js`.
- The global is **`window.AuthMeshWidgets`**. `window.AuthMesh` is the login SDK; they coexist.
- Pin a version in production (the catalogue's `latest`; `@latest` in the URL is fine for a demo).
- The option names are exactly `authBase`, `orgSlug` and `getToken`; `domain` / `org` belong to the login SDK and are ignored here.

**3. Common picks.**
```js
// Let a customer mint their own API key, limited to what they hold:
AuthMeshWidgets.apiKey({ container:'#ak', scope:['invoicer.read.invoices'], compact:true });
// Invite a teammate into the caller's org:
AuthMeshWidgets.invite({ container:'#inv', orgId: currentOrgId, roles:['member','admin'] });
// Inline email+password card that hands you tokens (you store them):
AuthMeshWidgets.login({ container:'#login', onSuccess: t => saveTokens(t) });
```
`apiKey` needs `scope`; a key minted without one has no permissions. `invite`, `teamMembers`, `roleAssign`, `sessions` and friends need the matching `orgId` / `teamId` / `userId` or they render a "needs …" state.

**4. Listen for events.**
`AuthMeshWidgets.on('authenticated' | 'logout' | 'org-changed', fn)`; the same fire on `document` as `authmesh:authenticated` and so on. Bootstrap widgets hand you tokens once and store nothing; keep the session with the login SDK, whose refresh de-duplicates across calls.

## What you'll see

Widgets render in a shadow DOM, so your CSS neither leaks in nor out. A consumer widget with no token shows a "sign in" state rather than an error. The API-key secret is shown once and then cleared from the page.

## If it goes wrong

- `AuthMeshWidgets is not defined`: `core.js` did not load, or loaded after the widget file.
- `AuthMesh.AuthMeshClient is undefined`: you loaded both the login SDK bundle and `auth-widget.js`; both claim `window.AuthMesh`. Load one.
- A consumer widget shows "sign in" although the user is logged in: `getToken` returned null (expired, or the wrong storage). Use the login SDK's `getValidToken()` (needs `@authmesh/sdk` 0.4.1+ on that auth host, SOP 06), not the old synchronous `getAccessToken()` or a token you stored yourself.
- CORS or `401` in the console: the widget calls `authBase` with a bearer; make sure `authBase` is the environment that minted the token.
- The API-key widget shows a CLI install command you cannot change: known limitation (it shows ab0t's own CLIs). Either do not render that block or mint keys with `POST /api-keys/` yourself.

## Coming

- **Discover and embed widgets from the CLI** (the sign-in block itself already exists: `authsetup snippet login`, SOP 06): `authsetup widgets` to list the catalogue with your `authBase` and `orgSlug` filled in, and `authsetup snippet <widget>` to print the embed. *Today:* the catalogue page and the snippet above.
- **Configurable install command in `apiKey` / `cliInstall`**, and a single Clerk-style `loginModal`. *Today:* use `login` + the SDK popup from SOP 06.
- **Theming hooks.** *Today* the shadow DOM styling is fixed.

## Next

SOP 09, your users.
