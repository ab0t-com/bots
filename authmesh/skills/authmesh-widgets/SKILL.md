---
name: authmesh-widgets
description: >-
  Embed the public Auth Mesh widget library (authmesh-widgets, global window.AuthMeshWidgets) in your
  own site: user menu, profile, org switcher, API-key minting, invites, usage, sessions, passkeys,
  team and user admin, and inline login / sign-up / password-reset / magic-link cards. Use when wiring
  AuthMeshWidgets.configure({ authBase, orgSlug, getToken }) and a widget factory into a container
  div, choosing which widget, pinning the version from the sdk-catalog, passing getToken from the
  AuthMesh login SDK, handling widget events (authenticated / logout / org-changed), or debugging a
  widget that shows "sign in", "needs …", CORS, or "AuthMeshWidgets is not defined".
---

# authmesh-widgets — drop-in account UI

## What this is

Ready-made account screens for your own site, served from a CDN: no framework, no build step, two
`<script>` tags and a `<div>`. Your customers get a user menu, API keys, invites, team management and
more without you building any of it, and every call goes to the auth service with the signed-in user's
own token, so a widget can never do more than that user may.

## The picture

```
your page
├── AuthMesh login SDK   (window.AuthMesh)         — signs the user in, holds the session (SOP 06)
└── authmesh-widgets     (window.AuthMeshWidgets)  — renders UI; asks the SDK for a token on every call
        configure({ authBase, orgSlug, getToken: () => auth.getValidToken() })
```

| family | widgets | needs |
|---|---|---|
| **account** | `userMenu`, `profile`, `orgSwitcher`, `apiKey`, `invite`, `usage`, `sessions`, `passkey`, `delegation` | `getToken` |
| **admin** | `teamSelector`, `teamCreate`, `teamMembers`, `teamHierarchy`, `userList`, `roleAssign`, `permCheck`, `accessControl`, `reports`, `activity` | `getToken` + the user's admin rights |
| **bootstrap** (create a session) | `login`, `signup`, `passwordReset`, `magicLink`, `emailVerify` | `orgSlug`, no token |
| **static** | `cliInstall` | nothing |

Required options by widget: `apiKey` → `scope:[…]` · `invite`, `teamSelector`, `teamCreate`,
`teamHierarchy`, `userList`, `sessions`, `permCheck` → `orgId` · `teamMembers` → `teamId` ·
`roleAssign` → `orgId` + `userId` · `delegation` → `userId` · `accessControl` → `storeId`. Without them a
widget renders a "needs …" state. Useful extras: `userMenu({ items:[{label,href}], loginHref, onLogout })`,
`apiKey({ keyName, compact:true, manageHref, docsHref })`, `orgSwitcher({ onChange, currentOrgId })`,
`usage({ upgradeHref })`, `userList({ role, limit })`.

## Do this (the default path)

1. Look up the current version: `https://auth.service.ab0t.com/login/_static/sdk-catalog.json` →
   `authmesh-widgets` → `latest` (0.3.9 when this page was written). Pin it; `@latest` is for demos.
2. Sign the user in with the login SDK first (`authsetup --env dev snippet login`, SOP 06).
3. Embed:
```html
<script src="https://get.tool.ab0t.com/p/authmesh-widgets/@0.3.9/authmesh-widgets.js"></script>
<div id="menu"></div>
<script>
  AuthMeshWidgets.configure({
    authBase: 'https://auth.service.ab0t.com',   // dev: https://auth.dev.ab0t.com — the env that signed the user in
    orgSlug:  'invoicer-users',                   // your USERS org slug; option names are exactly authBase / orgSlug
    getToken: () => auth.getValidToken()          // asks the login SDK every time; never a stored token string
  });
  AuthMeshWidgets.userMenu({ container: '#menu', items: [{ label: 'Invoices', href: '/invoices' }] });
  AuthMeshWidgets.on('logout', () => location.reload());
</script>
```
One bundle (`authmesh-widgets.js`) loads everything; or load `core.js` first and then single widget
files (`user-menu.js`, `api-key.js`, …) from the same versioned folder. Never copy the files into your
repo or `npm install` anything for this.

## What your customers notice

- The widgets render in a shadow DOM: your CSS neither leaks in nor out (theming hooks are not built
  yet). Signed out, an account widget shows a "sign in" state, not an error.
- A widget can only do what the signed-in user may: `apiKey` mints keys holding at most the permissions
  in `scope` that the user already holds, and shows the secret once.
- Revoked access shows up as the widget's signed-out or error state after the user's token is refused.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| `configure({ org: … })` or `domain:` | widgets act unconfigured (`orgSlug not configured`) | the names are `authBase` and `orgSlug` (`domain` / `org` belong to the login SDK) |
| `core.js` missing or after a widget file | `AuthMeshWidgets is not defined` | load `core.js` first, or the single bundle |
| `getToken` returns a stored or expired token | account widgets show "sign in" for a signed-in user | `getToken: () => auth.getValidToken()` (`@authmesh/sdk` 0.4.1+ on that host) |
| `authBase` is not the environment that signed the user in | CORS errors or `401` in the console | same environment for both |
| `apiKey` without `scope` | a key with no permissions | pass the permissions your users hold |
| `login` / `signup` widgets on a page that uses the login SDK | two sessions, tokens your page must store itself | use the SDK's hosted sign-in; the bootstrap widgets are for pages without it |
| the CLI install block in `apiKey` / `cliInstall` | shows ab0t's own CLIs, not yours | do not render that block (configurable install command is planned) |

## Check it worked

Signed out, each widget shows its sign-in state; after signing in with the login SDK, `userMenu` shows
the user's name; the browser console on your page has no errors; the script URL contains the exact
catalogue version. Events to hook: `AuthMeshWidgets.on('authenticated' | 'logout' | 'org-changed', fn)`
(also fired on `document` as `authmesh:authenticated` and so on).

More: Ally [SOP 08](../../08_sop_system_js_widgets.md) · the served setup guide
`https://auth.service.ab0t.com/login/_static/guides/prompts/authmesh-widgets-setup.md` · picking between
the login SDK, the widgets and the iframe drop-in: `auth-widgets-discovery`.
