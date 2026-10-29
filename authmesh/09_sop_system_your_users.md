# 09 · Your users

**What this is for.** How the people who sign up to your product are organised, what they can do on day one, how they bring teammates in, and how you take access away. Your users never talk to ab0t; they see your login page and your app.

**Before you start.** SOP 05 done. You have decided between a shared space and a workspace per user (SOP 04, step 5). You know your users org slug (`invoicer-users`) and id (`jq -r .org_id ~/.authmesh/invoicer/end-users-org.dev.json`).

## Steps

**1. Understand where a new user lands.**
```
invoicer                 ← your service org: Acme's staff and the service key
└── invoicer-users       ← every customer who signs up at /login/invoicer-users
    ├── Default Users    ← team; holds every default_grant permission; every signup joins it
    ├── alice            (member → team → permissions)
    └── bob
```
`authsetup up`, `status`, `info` and `settings` call `invoicer-users` **your users** (with the slug next to it). Membership *is* the grant. No webhooks, no cron, no per-user grants. Remove someone from the org and their access is gone.

**2. Choose the shape (once, before real users).**

*Shared space (`flat`)*: all users in `invoicer-users`, all holding the defaults. Right for tools, dashboards, APIs anyone calls.

*Workspace per user (`workspace-per-user`)*: each signup also gets a private org they own, nested under `invoicer-users`, with its own default team. Right when each customer has their own data, invites their own teammates, and pays their own bill.

**What each gives you, and what your backend checks.**

| | `flat` | `workspace-per-user` |
|---|---|---|
| the customer's token `org_id` | the same for everyone: your users org | their own workspace (on sign-in, with `default_landing: "workspace"`, below) |
| how your backend tells customers apart | `user_id`: store the owner's `user_id` on each record and compare it with the caller's | `org_id`: store the workspace's `org_id` on each record and compare it with the caller's (SOP 06) |
| teammates | none; customers cannot invite anyone or see each other | the owner invites people into their workspace and hands out your `org` permissions there |

A rental business that rents to individuals can use `flat`: store each booking with the renter's `user_id` and serve it only to that `user_id`. If it rents to companies whose staff book on one company account, it needs `workspace-per-user`. Choose `workspace-per-user` whenever a customer can be more than one person, or when a customer's own admin should decide who sees and does what. `flat` has no idea of a customer's team; you would have to build that in your app.

Under `workspace-per-user`, a token whose `org_id` is your users org itself (`invoicer-users`) does not belong to any customer's workspace. The token from sign-up is one of these: it stays on the users org, and the next sign-in lands in the workspace. Never store or match records under the users org's `org_id`.

**Changing it later.** Edit `org_structure` and run `up`. Only people who sign up after the change get the new pattern. Existing users stay in the shared space, and today you have no way to give them workspaces yourself (*Coming*). Records you stored by `user_id` would also need moving to workspace `org_id`s. Decide before launch.
```json
"end_users": {
  "default_role": "invoicer-user",
  "org_structure": {
    "pattern": "workspace-per-user",
    "config": {
      "slug_template": "{service_id}-{email_prefix}-{short_id}",
      "name_template": "{email_prefix}'s workspace",
      "default_team_name": "Default",
      "default_team_permissions": ["invoicer.read.invoices", "invoicer.write.invoices"]
    }
  }
}
```
Then in `hosted-login.json` set `registration.default_landing: "workspace"` so a login scopes the token to the user's own workspace instead of the shared parent. Apply with `authsetup --env dev --config-dir ./config run 04`. In their workspace a user is **owner**: they can invite teammates, create teams, and hand out `invoicer.write.invoices` or `invoicer.admin` **for that workspace only**. They can never obtain a `platform` permission.

**3. Change what everyone gets.**
Flip `default_grant` in `permissions.json`, then `authsetup --env dev --config-dir ./config run`. In `flat`, the shared team is updated at once. In `workspace-per-user`, existing workspaces carry a frozen copy; roll the change out with `backfill` (SOP 13). It reaches the workspaces your service admin is a member of; a user's own workspace is changed by its owner. Users see it within about five minutes, or at once on a fresh login.

**4. Invite someone.**
Your app (or you) calls the auth service as an admin of the target org:
```
POST https://auth.dev.ab0t.com/organizations/<org_id>/invite
Authorization: Bearer <admin token for that org>
{ "email": "carol@customer.example", "role": "member", "team_id": "<optional team id>", "message": "Join our invoicing workspace" }
```
Carol gets an email with a link on the auth service; after clicking she is sent to your `security.accept_invite_url` with `?code=…` (SOP 07), and your app completes `POST /organizations/invoicer-users/auth/register` with `invitation_code`. The ready-made `invite` widget does the first call for you (SOP 08). Invitation-only products set `auth_methods.invitation_only: true`.

**5. Remove someone.** Remove the membership in the org (and, for a workspace owner, the workspace org). Access ends immediately for new tokens; a live token lasts until it expires (15 minutes) unless your backend checks permissions server-side (SOP 06, `permission_check_mode="server"`), in which case it ends now.

## What you'll see

`run 04` prints `create team "Default Users" with 1 default_grant permissions` the first time, and later `team "Default Users" already carries all N default_grant permissions`. Step 06 proves a brand-new signup holds every default. Under `workspace-per-user`, step 06 adds `workspace materialization is event-driven`: the workspace appears moments after sign-up, so a login *immediately* after registering may still land on the parent once.

## If it goes wrong

- Users sign up but have no permissions: they used the global sign-up instead of your org's page, or the default team lost its permissions. Point sign-up at `/login/invoicer-users` and re-run `run 04`.
- `end-users org "invoicer-users" already exists but is not visible to this admin`: a half-finished earlier run. Do not create a second one; contact the platform team to repair membership, then re-run.
- A workspace owner gets `403` on something you just made a default: that workspace's team has the old copy. `authsetup --env dev backfill --only-org <workspace org id>` changes it if your service admin is a member there; otherwise it says `NOT changed … not a member`, and the owner adds the permission to the workspace's default team, signed in to that workspace (SOP 13).
- Switching `flat` → `workspace-per-user` later: only **new** signups get workspaces. Existing users keep the shared space. Plan the switch before launch if you can.

## Coming

- **`authsetup invite <email> --org <id> --role member`** and **`authsetup users`** (list, remove). *Today:* the API call above, or the `invite` widget.
- **Workspaces for users who signed up before you switched the pattern.** *Today:* none; only new signups.

## Next

SOP 10, your own team and platform permissions.
