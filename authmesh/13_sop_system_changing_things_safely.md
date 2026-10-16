# 13 · Changing things safely

**What this is for.** Day two and every day after. There is no "update" command: you edit `config/`, preview, apply. This SOP tells you which file drives which thing, how to read what a run says it did, what a run will and will not undo, and how to roll a new default permission out to users who already exist.

**Before you start.** A working setup (SOP 05). `authsetup version` 0.5.24 or later (the wording below is 0.5.24's). Fifteen minutes. The environment named explicitly in every command, including any NEXT line you copy.

## Steps

**1. The loop. Always the same four commands.**
```sh
$EDITOR config/<file>.json
authsetup --config-dir ./config validate                       # offline
authsetup --env dev --config-dir ./config up --dry-run         # the plan in plain words, diffed against the live server
authsetup --env dev --config-dir ./config up                   # the same plan → your yes → apply
authsetup --env dev --config-dir ./config status               # exit 0 converged, 3 drift
```
`up` shows `+` for things it will create or change and `~` for settings it re-sends from your files; it re-sends those only when a config file changed since the last `up` on that environment, so an unchanged re-run ends `✓ invoicer on dev already matches your config — nothing to change.` To force a full re-send (for example after someone edited the login page by hand on the server), use the expert path: `authsetup --env dev --config-dir ./config --dry-run run`, then `authsetup --env dev --config-dir ./config run`.
Then the same against `--env prod`, in your own terminal.

**2. Know which file moves which object.**

| you want to | edit | run | existing users? |
|---|---|---|---|
| add a permission everyone gets | `permissions.json` → `default_grant: true` | `up` (or `run 01 04`) | `flat`: yes, at once. `workspace-per-user`: new signups yes; existing workspaces need step 5 |
| add a permission some users get | `permissions.json` (new entry, `default_grant: false`) | `up` (or `run 01`) | grant via a team, `backfill --extra-perm`, or `grant-platform` for a `platform` one (SOP 10) |
| mark a permission cross-customer | `permissions.json` → `"scope": "platform"` | `validate`, then `up` | nobody gains it; only `grant-platform` hands it out |
| change redirect URLs | `oauth-client.json` | `up` (or `run 02` admin client, `run 04` customers' client) | no |
| branding, sign-up rules, invite landing | `hosted-login.json` | `up` (or `run 03 04`) | next page load |
| default role or team name | `permissions.json` → `end_users.*` | `up` (or `run 04`) | new signups |
| consumer tiers, directory listing, consumer sign-up | `api-consumers.json` | `up` (or `run 08`) | existing keys unchanged |
| a provider you consume in-house | `clients.d/<provider>.json` | `up` (or `run 07`) | key re-minted only if its permissions changed |

`authsetup --env dev info` prints this map for your setup; `authsetup --env dev whois <id>` tells you which object an id from a log line is and which file drives it.

**3. Read what the run says it did.** From 0.5.24 the words are exact:
- `✓ …` — something matched or was changed.
- `~ re-sent: PUT login-config on … (authsetup cannot compare this setting, so it sends it again — same values)` — not a change. The tool cannot read that setting back to compare, so it sends your file again.
- The last line: `N changed · M re-sent`, or `no changes were needed — server state already matches config (M setting(s) re-sent: …)`.
- A preview: `→ would: …` lines and `N change(s) planned — nothing was mutated`, where N equals the `would:` lines.
- A failure: `✗ run failed at step NN (<name>)`, the steps after it marked `not reached`, and NEXT `fix the failure above, then resume with: authsetup --env dev --config-dir ./config run NN …`. Check the resume line names your environment, then run it.
- `needs you` against a step, and exit `4`: see step 4.

**4. When a run says `needs you` (exit `4`).** The tool found drift it cannot repair itself; everything else converged. Almost always: `redirect_uris` in `oauth-client.json` changed, and the client's management credentials are not in your credentials folder. It prints the difference (`+ <uri>   (in your config, not on the client)`, `- <uri>   (on the client, not in your config)`) and three options, in this order:
1. restore `~/.authmesh/invoicer/<oauth-client or end-users-oauth-client>.<env>.json` from a backup and re-run that step; the tool then updates the client in place;
2. give the client a new `client_name` in `oauth-client.json` and re-run the step; a **new** client is registered, and your app needs its new client id (`authsetup --env dev settings`);
3. ask the auth team to re-issue the management token for that client id.

**5. Roll a new default out to existing workspaces (`workspace-per-user` only).**
```sh
authsetup --env dev --config-dir ./config --dry-run backfill                  # candidates and what each would gain
authsetup --env dev --config-dir ./config backfill --only-org <one workspace org id>
#   → that user logs in again → the formerly-403 call works
authsetup --env dev --config-dir ./config backfill                            # all workspaces; idempotent
```
`--extra-perm invoicer.write.invoices` (repeatable) adds a non-default permission to every workspace owner's default team. Under `flat` there is nothing to backfill; step 04 already updated the shared team.

**6. Watch for drift.** A scheduled `authsetup --env prod --config-dir ./config status` exits `3` when the server no longer matches config (someone edited a team by hand, a half-failed run); its summary reads `── Check summary ──` and `checked — server state matches config` when all is well. In CI use the exit code of the human `status` (or `status --pipeline`); `status --json` always exits `0` and carries the state in the document. `--dry-run run` shows the repair; `run` applies it.

## Know what a run will not do

- **Remove a permission from the default team.** Syncs are additive unions; the tool never takes away something you granted by hand. To remove, edit the team's permission array on the server deliberately (`PUT /teams/{id}`), then run so config and server agree.
- **Remove actions or resources from your registered permission schema.** The schema check only asks "does the registry already cover my config?", so a removal reads `… nothing to do` and the registry keeps the extra.
- **Rename your service or change its audience.** `service.id`, `registration.service` and `service.audience` are fixed at creation. A different id is a different service (and the name check of SOP 05 applies to it).
- **Rename the default team.** A new `default_team_name` creates a new team; the old one stays with its members. Prefer not to.
- **Re-mint keys.** A key keeps the permissions it was minted with (SOP 14).
- **Exception:** consumer **tiers** (`run 08`) are reconciled *exactly*; removing a permission from a tier removes it from the live team.

## What you'll see

A clean apply ends `no changes were needed — server state already matches config`. `validate` prints `redirect_uris 18/20 — near the server limit (max 20); you have room for 2 more.` as you approach the cap. After a permission change, users see it within about five minutes (cache) or at once on a fresh login; a brand-new permission may `403` for those first minutes, which is not a misconfiguration.

## If it goes wrong

- Exit `4`, `needs you`: step 4.
- `✗ run failed at step NN (…)`: read the line above it (SOP 16 has every message), fix, then the printed resume command.
- `redirect_uris 20/20 — AT the limit; the auth service rejects the next one with 400 (max 20). Remove one before adding.`: exactly that.
- `backfill`: `403` on the team update for one workspace: your admin lacks authority over that child org in this environment; stop and contact the platform team.
- `backfill` changed nothing for a permission you added: it must be `default_grant: true` or passed with `--extra-perm`.
- Two people ran at once: `another authsetup run (pid …) is working on this setup right now (lock …) — wait for it to finish, then run again`. If it instead says `a stale lock from … was left at … — it is safe to remove that file`, move that one file aside.
- A step 04 that fails on the permission schema still updated your users' sign-in settings and client first (0.5.24 checks the schema last there); fix the schema message (SOP 16) and run again.

## Coming

- **`run --prune`**: let the tool remove what config no longer lists (default team and tiers alike), with the diff shown first. *Today:* additive only, except tiers.
- **Rename the default team in place.** *Today:* a new name is a new team.
- **`status` seeing `redirect_uris` drift**, and **`status --json` exiting `3` on drift**. *Today:* `--dry-run run 02 04` shows a redirect difference; use the human `status` exit code in CI.
- **`up --json` / `run --json`** (a machine-readable result). *Today:* exit codes.

## Next

SOP 14, keys. SOP 16 if a run fails and you cannot tell why.
