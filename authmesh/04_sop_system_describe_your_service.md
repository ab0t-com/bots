# 04 · Describe your service (`config/permissions.json`)

**What this is for.** Writing the one file that tells the mesh what your service is, what people can do in it, who gets what by default, and how your users are organised. Everything `authsetup run` builds comes from this file.

**Before you start.** SOP 03 done. A folder for your service with an empty `config/` directory. Decide your service's short name now (next section); you cannot change it later.

## Choosing your service name

- **The rule: lowercase letters and digits only, starting with a letter, at least 3 characters.** `northwindrentals` and `invoicer2` are fine. Do not use hyphens, because the permission registry refuses them. Do not use underscores either. The registry accepts them, but the auth service drops them from org names (`nw_rentals` becomes the org `nwrentals`), and the first run then fails at step 05 because your users' login page is not where authsetup expects it. Keep the name short: `<name>-api-consumers` must fit the 63-character limit on org names, so use 49 characters at most.
- **It must be free.** On each environment the name is one entry in a shared permission registry, and org names are unique too. If another organization already holds the name, your first preview stops with `is taken` before anything is created (SOP 05). Generic words (`rentals`, `billing`, `app`) are the most likely to be taken, so put your company in the name (`northwindrentals`). dev and prod check the name separately, so a name that is free on dev can still be taken on prod. `authsetup --env prod --config-dir ./config up --dry-run` checks prod without changing anything.
- **It is the same word everywhere.** It goes in `service.id`, `service.audience` and `registration.service`, and it starts every permission id (`northwindrentals.read.equipment`). Your org names come from it (`northwindrentals`, `northwindrentals-users`, `northwindrentals-api-consumers`), and so do your customers' login page `/login/northwindrentals-users`, your service key's name (`northwindrentals-internal`), the default admin email (`northwindrentals-admin@…`) and your credentials folder (`~/.authmesh/northwindrentals/`). `init --publish --as <name>` fills all of these in for you.
- **Why you can't change it later.** Your org's audience is stamped on it when it is created and can never be changed; every customer token carries it and every backend checks it. Your permission ids are stored in your users' default team, in every grant and in every API key (a key keeps the permissions it was minted with). authsetup also files your credentials under the name. So a new name means a new, separate setup, with new orgs, a new login page and new keys. Your existing users stay in the old users org. authsetup has no rename command.

## Steps

**1. Let `init` write it, or start from the examples.**
```sh
authsetup init --publish          # a few questions: name, app URL, what your app manages, shared space or a workspace each
# or without questions:
authsetup init --publish --as invoicer --name Invoicer --app-url https://invoicer.acme.example \
  --resources invoices --users shared --default-access read
```
It writes `config/permissions.json`, `config/oauth-client.json` and `config/hosted-login.json`, checks them with `validate`, and never overwrites an existing file (`--force` moves the old one to `config/.archive/` first). The starter is deliberately safe: `read`, `write` and `delete` on each thing you name; `read` for everyone, `write` for everyone only in a workspace-each setup, `delete` never by default. Edit it from there. Or copy the examples:
```sh
cp config/permissions.json.example  config/permissions.json
cp config/oauth-client.json.example config/oauth-client.json
cp config/hosted-login.json.example config/hosted-login.json
```
(The example files ship in the public `clientsetup` repository's `config/` folder; copy them from there.) `permissions.json` is required. The other two are optional but you will want them: without `oauth-client.json` nobody can sign in from your frontend; without `hosted-login.json` your login page is unbranded.

**2. Say who you are.** Acme's invoicing product:
```json
"service": {
  "id": "invoicer",
  "name": "Invoicer",
  "description": "Invoices for Acme customers",
  "version": "1.0.0",
  "audience": "invoicer",
  "maintainer": "platform@acme.example",
  "domain": "invoicer.acme.example"
},
"registration": {
  "service": "invoicer",
  "actions":   ["read", "write", "admin", "support"],
  "resources": ["invoices", "read_all"]
}
```
- `service.id`, `service.audience`, `registration.service` and every permission prefix must be the **same word** (*Choosing your service name*, above). `validate` checks that each permission id starts with `registration.service`. It does not compare `service.id` or `service.audience` with that word, so check those two yourself.
- `audience` is stamped on your org when it is created and **cannot be changed afterwards**. Your backend will check tokens against it forever (SOP 06). Keep it equal to `id` unless you have a reason.
- `registration.actions` × `registration.resources` is what the registry actually registers. A permission whose action or resource is not in those lists is **dead**: it registers nothing and nobody can be granted it. `validate` warns about this.

**3. List what people can do.** Each entry is `invoicer.<action>` or `invoicer.<action>.<resource>`.
```json
"permissions": [
  { "id": "invoicer.read.invoices",  "name": "Read invoices",  "description": "See invoices in your org",
    "risk_level": "low",    "default_grant": true },
  { "id": "invoicer.write.invoices", "name": "Write invoices", "description": "Create and edit invoices in your org",
    "risk_level": "medium", "default_grant": false },
  { "id": "invoicer.admin",          "name": "Invoicer admin", "description": "Administer invoicer inside your own org",
    "risk_level": "high",   "default_grant": false,
    "implies": ["invoicer.read.invoices", "invoicer.write.invoices"] },
  { "id": "invoicer.support.read_all", "name": "Support: read every customer",
    "description": "Acme support staff can see every customer's invoices",
    "risk_level": "critical", "default_grant": false, "scope": "platform" }
]
```
- **`default_grant: true`** means every person who signs up gets it, automatically, through the default team. Use it for the few things everyone needs. Never for admin, delete, or anything that reaches across customers.
- **`scope`** is the one new word (SOP 01). `"org"` is the default and means "acts inside one customer's org". `"platform"` means "reaches across customers". Mark the few that do. Using `scope` on any permission puts the whole file in *declared* mode: every unmarked permission is then `org` (so `invoicer.admin` is ordinary), `validate` refuses a reach-word name (`cross`, `global`, `platform`, `tenant_gateway`, `_wide`, `read_all`, `superadmin`) that is not marked `platform`, and a `platform` or `high`/`critical` permission may not be a default anywhere. A file with no `scope` at all keeps the older rule, which judges by name and treats `invoicer.admin` and `invoicer.*` as privileged too.
- `implies` is documentation for humans and admin tooling; it does not grant anything by itself.

**4. Name the roles.**
```json
"roles": [
  { "id": "invoicer-user",  "name": "User",  "description": "Everyday user",
    "permissions": ["invoicer.read.invoices"], "default": true },
  { "id": "invoicer-admin", "name": "Admin", "description": "Org admin of invoicer",
    "permissions": ["invoicer.admin", "invoicer.write.invoices"], "default": false }
]
```
Exactly one role may be `default: true`; it becomes the role new signups get. **Today a role sets a name only** (see *Coming*): what a new user can actually *do* comes from the `default_grant` permissions, not from the role's list.

**5. Say how your users are organised.**
```json
"end_users": {
  "default_role": "invoicer-user",
  "default_team_name": "Default Users",
  "org_structure": { "pattern": "flat", "config": {} }
}
```
Two patterns:

| pattern | pick it when | what each signup gets |
|---|---|---|
| `flat` | your users share one space (a tool, a dashboard, an API anyone calls) | membership of `invoicer-users` + the default team |
| `workspace-per-user` | each user is a tenant: their own data, their own teammates, their own bill | the above **plus** a private org they own, with its own default team |

Not sure which? Ask one question: will a customer ever be more than one person, sharing records or inviting colleagues? If yes, pick `workspace-per-user`. If each customer is one person who sees only their own things (a renter and their bookings), `flat` works. But under `flat` every customer's token carries the same `org_id`, so your backend must tell customers apart by `user_id` (SOP 06 step 2). SOP 09 step 2 compares the two patterns in full. If you switch later, only new sign-ups get the new pattern.

For `workspace-per-user` you may add to `config`: `slug_template` (default `{service_id}-{email_prefix}-{short_id}`), `name_template`, `default_team_name`, and `default_team_permissions` (defaults to your `default_grant` set). SOP 09 goes deeper.

**6. Your frontend and your login page.**
`oauth-client.json`: set `client_name` and `redirect_uris` (exact URLs; keep `http://localhost:3000/auth/callback` for development; the server allows at most 20). Leave `token_endpoint_auth_method: "none"`; browsers use PKCE, not a secret.
`hosted-login.json`: set `branding.page_title`, `content.welcome_message`, `security.post_logout_redirect_uri`. SOP 07 covers the rest.

**7. Check it, offline.**
```sh
authsetup --config-dir ./config validate
```
No server is touched (the first line says `— not contacted: validate is local-only`). Fix every line it prints, then run it again until you see `✓ config valid: service "invoicer", 4 permissions (1 default_grant), 2 roles, pattern "flat"`. Its NEXT points at a preview on **dev** (`authsetup --env dev --config-dir ./config --dry-run run`), never at production.

`validate` cannot know whether the name `invoicer` is free in the shared permission registry; the first preview checks that (SOP 05).

**The three orgs, in plain words.** `authsetup up`, `status`, `info` and `settings` show them as **your app** (`invoicer`), **your users** (`invoicer-users`) and **your partners** (`invoicer-api-consumers`), with the real slug next to the words (`--json` output carries the slugs only).

## What you'll see

`validate` prints one `✗` line per problem (exit `1`), and `!` warnings that never change the exit code, in the tool's words:
- `registration.service "my-invoicer" will be REJECTED by the auth service registry (lowercase letters, digits and _ only — must match ^[a-z][a-z0-9_]*$). Try "myinvoicer".` (with `, and start your N permission id(s) with "myinvoicer." to match` when your ids use that name; the suggestion is the same id `init --publish` would generate)
- `permission "invoicer.read.invoice" must be prefixed "invoicer." (registration.service)`
- `no permission has default_grant:true — new users would have no access`
- `privileged permission "invoicer.support.read_all" must not be default_grant:true (cross-tenant is invite/explicit-only)` and, in declared mode, `permission "invoicer.support.read_all" (platform) must not be default_grant:true — a platform permission is never handed to every new user`
- declared mode: `permission "invoicer.support.read_all" reaches across customers by its name (cross / global / platform / tenant_gateway / _wide / read_all / superadmin) — set "scope": "platform" on it, or rename it if it really acts inside one org`
- declared mode: `default role "invoicer-user" carries "…" — platform and high/critical permissions are never in a default role; …`
- `role "invoicer-admin" references undefined permission "invoicer.delete.invoices"`
- `more than one role marked default:true`
- `end_users.org_structure.pattern "teams" not in {flat, workspace-per-user}`
- a warning: `permission "invoicer.export.invoices" is DEAD — action "export" is not in registration.actions […], so the registry never generates it (registering NOTHING). …`
- a warning: `oauth-client.json redirect_uris[0] "notaurl" is not a full URL (it needs scheme://host/path, e.g. https://app.example.com/auth/callback) — the auth service will refuse it at step 02` (or `… has a #fragment …`)
- an advisory: `redirect_uris 3/20 (server cap)`

`validate --json` prints one JSON document with `valid`, `problems[]` and `warnings[]`, even when a file cannot be read.

## If it goes wrong

- You already registered this service under a hyphenated or different name with older scripts. Pick the clean short name once and move on; do not try to keep two namespaces alive. If the old org must be kept, ask the platform team before running anything.
- `permissions.json is required: open config/permissions.json: no such file or directory` — wrong folder. The NEXT block offers `authsetup init --publish` (write one here) or `--config-dir <dir>` (point at the one you have); `AUTHSETUP_CONFIG_DIR` works too.
- `config/permissions.json: invalid JSON at line 2, column 24 — …` — a trailing comma, a comment, a missing quote; go to that line. (`hosted-login.json: invalid JSON` has no line number; same causes.)
- `! config/oauth-client.json: invalid JSON at line … — ignored, so the OAuth sign-in client steps (02 and 04) are skipped until it is fixed` — a warning, but nobody can sign in from your frontend until you fix it.
- `auth would refuse this registration (invalid_platform_permission) — check the "scope" declarations above` (or `scope_required`) — the same check the auth service runs at registration; most often a `platform` permission that `registration.actions × registration.resources` does not generate (a typo, or a prefix that does not match `registration.service`). Fix the lines above it and it goes away.

## Coming

- **Roles that actually confer their permissions.** *Today* `roles[]` sets the default role's name; permissions flow from `default_grant` and teams. To give a tier of users more than the defaults, use a team or `authsetup backfill --extra-perm` (SOP 13).

## Next

SOP 05, check it and run it.
