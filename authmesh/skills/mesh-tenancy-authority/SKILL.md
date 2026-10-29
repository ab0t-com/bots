---
name: mesh-tenancy-authority
description: >-
  Who can act in which org on the ab0t auth mesh, explained for a team running its product there.
  Use when someone asks how orgs nest (service org, users org, partners org, a workspace per user,
  a customer's own child orgs), who the admins of each org are and what they may do, whether a
  parent org can act in its child orgs, how invitations bring people in, what an org admin of a
  customer can and cannot grant, what a "platform" (cross-customer) permission is and who may hold
  one, or why a partner service that records usage for many customers needs a special tier.
  Triggers: "who can do what in which org", "org hierarchy", "parent org / child org", "can my
  customer's admin grant X", "workspace owner", "invite an admin", "cross-customer access",
  "scope platform", "tenant isolation", "why does my gateway key 403 on a customer's org".
---

# Who can act in which org

## What this is

Everything on the mesh is an **org**: your service, the people who sign up to it, the services that
call it, and each customer's own space. Who may do what is decided by **membership** of an org and the
**teams** inside it, so getting the shape right once means your customers are isolated from each other
without you writing any access-control plumbing.

## The picture

```
invoicer                         ← your app: your staff, your admin account, your service key
├── invoicer-users               ← your users: everyone who signs up on your login page
│   ├── Default Users (team)     ← holds every default_grant permission; every sign-up joins it
│   ├── alice's workspace        ← only with "workspace-per-user": an org Alice owns
│   └── bob's workspace
└── invoicer-api-consumers       ← your partners: other services that call your API, one team per tier
```

| who | where | may | may never |
|---|---|---|---|
| your service admins | your service org and the orgs beneath it | invite colleagues; grant your `org` permissions; hand out a `platform` permission one person at a time, with a reason (`grant-platform`) | — (auth's platform admin can still override anything) |
| a user in `invoicer-users` | the shared users org | what the default team carries (`default_grant`) | grant anything to anyone |
| a workspace owner (`workspace-per-user`) | their own workspace only | invite teammates, create teams, hand out your `org` permissions (including `invoicer.admin`) inside it | reach another user's workspace; obtain or grant a `platform` permission, even to themselves |
| a customer's org admin | their own org (and child orgs they create under it) | hand out your `org` permissions there | grant a `platform` permission |
| a partner service | its own consumer account | exactly its tier's permissions, fixed in its key | anything outside its tier |

- **Membership is the grant.** Join an org (sign-up, invitation) → join a team → hold the team's
  permissions. No per-user grants, no webhooks.
- **Parent and child.** An admin of a parent org can see and manage the orgs beneath it through org-level
  calls (list members and teams, invite). Two exceptions: a TEAM is changed only by a sign-in to the team's
  own org, and only a member can sign in to a user's workspace. So your service admin cannot change a team
  in a workspace it is not a member of; `backfill` names those, and their owners apply it. A child cannot act in its
  parent or its siblings. Permissions do **not** flow down the org tree: what someone can do comes from
  their teams in the org they are working in.
- **One cross-customer word.** Most permissions act inside one customer's org (`scope: "org"`, the
  default). The few that reach across every customer (a support view of all invoices) are marked
  `"scope": "platform"`; they are never a default, only your own admins hand them out, and your
  customers' admins can never grant them. Never use the older names `cross_tenant` / `cross_org`.
- **Say "org"**, never "realm". A "consumer" is always another service, never a person.

## Do this (the default path)

1. Pick the shape before real users arrive, in `config/permissions.json` (SOP 04 step 5):
   `"org_structure": { "pattern": "flat" }` for a shared tool, or `"workspace-per-user"` when each
   customer has their own data, teammates and bill. For workspaces also set
   `registration.default_landing: "workspace"` in `hosted-login.json` (SOP 07).
2. Mark the few cross-customer permissions `"scope": "platform"`, then check and apply:
   ```sh
   authsetup --config-dir ./config validate
   authsetup --env dev --config-dir ./config up --dry-run
   authsetup --env dev --config-dir ./config up
   ```
3. Bring people in by invitation: `POST https://auth.dev.ab0t.com/organizations/<org_id>/invite` as an
   admin of that org (`"role": "member"` or `"admin"`), or drop in the `invite` widget (SOP 08, 09, 10).
4. Hand out a cross-customer permission only to a named colleague, with a reason:
   `authsetup --env dev grant-platform dana@acme.example invoicer.support.read_all --reason "Tier-2 support rota" --dry-run`,
   then the same without `--dry-run` (SOP 10).
5. In your own API, after the permission check, compare the loaded resource's `org_id` with the
   caller's. A permission says *what kind* of thing someone may do, not *whose* (SOP 06, SOP 17 rule 6).

## What your customers notice

- They only ever see your login page and your app, never ab0t. Two customers never see each other's
  orgs; in `workspace-per-user` one user never sees another's workspace.
- Removing someone takes effect for new tokens at once; a live token lasts until it expires (15
  minutes) unless your backend asks the auth service on each request (`permission_check_mode="server"`),
  and even then the SDKs cache answers for up to 15 s (permissions) or 60 s (API keys).
- A new default permission reaches existing users within about five minutes or on a fresh login; in
  `workspace-per-user`, existing workspaces need `backfill` (SOP 13) — only those your service admin is a
  member of; a user's own workspace is updated by its owner.
- Your API should answer `401` for a missing or invalid token, `403` for a valid caller without the
  permission (`404` for another org's resource, if you prefer not to reveal that it exists), and `503` when the auth service could not be asked (never an allow).

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| a cross-customer permission made a default | `validate`: `privileged permission "…" must not be default_grant:true (cross-tenant is invite/explicit-only)` | keep it non-default; `grant-platform` it to named people |
| a reach-word name not marked | `validate`: `permission "invoicer.support.read_all" reaches across customers by its name (…) — set "scope": "platform" on it, …` | add the scope, or rename it |
| granting a `platform` permission to someone outside the org | `dana@acme.example is not a member of org <id> — invite them first (POST /organizations/<id>/invite), then re-run` | invite first |
| users signed up through the global sign-up | they have no permissions (`403` on a default) | send sign-up through `/login/invoicer-users` |
| switching `flat` → `workspace-per-user` after launch | old users stay in the shared space | only new sign-ups get workspaces; plan the switch before launch |
| a gateway key acting on a customer's org | `403 … Access denied - different organization` from billing | that needs the provider's cross-customer tier (SOP 11 step 5, `billing-payment-consumer-setup`) |

## Check it worked

```sh
authsetup --env dev info                  # your three orgs and what drives each
authsetup --env dev --config-dir ./config run 06   # signs up a throwaway user, checks the defaults, removes it
authsetup --env dev platform-holders      # who holds which platform permission, when, why
authsetup --env dev whois <id>            # what an org / client / key id from a log line is
```
Still stuck: send `authsetup --env <env> doctor --json`, `status --json`, the failing output and the
latest `~/.authmesh/<service>/journal/*.jsonl` (secrets are already redacted) to
`platform-team@ab0t.com`. Never send a credentials file.

## SOPs (in `authmesh/`)

| job | SOP |
|---|---|
| the scope model, in five minutes | [01_sop_system_scope_model_for_clients.md](../../01_sop_system_scope_model_for_clients.md) |
| how your users are organised; invites; removing someone | [09_sop_system_your_users.md](../../09_sop_system_your_users.md) |
| your colleagues; ordinary vs `platform` grants | [10_sop_system_your_team_and_platform_permissions.md](../../10_sop_system_your_team_and_platform_permissions.md) |
| calling billing, payment and other services | [11_sop_system_using_other_services.md](../../11_sop_system_using_other_services.md) |
| letting other services call yours; tiers | [12_sop_system_opening_your_service_to_others.md](../../12_sop_system_opening_your_service_to_others.md) |
| the security rules | [17_sop_system_security_rules.md](../../17_sop_system_security_rules.md) |
