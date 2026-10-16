# GAPS — every **Coming** item in the SOPs, in one table

Each row is something the SOPs describe as the ideal flow that `authsetup` (checked against **0.5.25**, see `VERSION`) does not do yet. This is the spec list. When a row ships, update the SOP and delete the row. Row numbers are stable (the CLI's own help cites some of them), so a shipped row's number is never reused.

**Shipped, rows deleted:**
- **0.5.21** (scope model): #1 `scope: "org" | "platform"` read by `validate` and sent at registration · #2 step 01 mints the service key without a platform admin (for a service that declares `scope`) · #3 `grant-platform` / `revoke-platform` · #4 reach-word lint · #5 `risk_level: high|critical` refused in any default · #23 who holds a platform permission (`platform-holders`).
- **0.5.22**: #9 `up` (plan → yes → apply) · #10 human names (your app / your users / your partners) · #11 `init --publish` writes `config/` · #13 `settings [--env-file]` · #14 `snippet login` · #15 `login-url [--check]`.
- **`ab0t_auth` 0.1.4**: #34 a Python migration kit and checker (`migrations/vFROM-to-vTO/` in the library's repository).
- **0.5.25**: shipped without a row: `authsetup bot install | status | uninstall` (Ally from the binary, offline and
  version-matched), `skills install` installs every bundled client skill, `destroy` names only the env's `*.<env>.json` files.
- **0.5.27**: shipped without a row: a REVOKED service key is re-minted by `run`/`up` (step 01; dead entry moved to `.archive/`; a failed check never re-mints) — the revoked-key half of #31; `run --json` / `up --json`.
- **0.5.24**: #41 step 06 removes its test user. Also shipped without a row: the schema name checked before anything is created, plain-language ownership messages, NEXT lines that keep the target, credentials sent only to the configured origin, `doctor --strict`.

| # | item | SOP | why users want it | today |
|---|---|---|---|---|
| 6 | **Partner tier moves approved by the provider's admin land in the partner's sub-org automatically** (scope model) | 01, 11, 12 | no platform staff when a partner needs a higher tier | in-house `run 07` against a declaring provider: done by the provider's admin during the run; external `connect` partners: the provider moves them by API (SOP 12 step 4) plus `grant-platform --org` |
| 7 | **Owner reassignment revokes everything the old owner handed out** (scope model) | 01, 10, 17 | clean handover | manual |
| 8 | **`authsetup login`**: sign in as a person; the tool acts as you | 03, 17 | identity today is "whichever credentials folder" | `accounts`, `info`, `--as <name>`; waits on a device sign-in flow in the auth service |
| 12 | **Roles that confer their permissions** (server-side role resolution) | 04 | the config already lists them | role sets a name only; permissions via `default_grant`, teams, `backfill --extra-perm` |
| 16 | **Logo upload** | 07 | not everyone hosts assets | `logo_url` must be a hosted `http(s)` URL |
| 17 | **SSO/social switches in `hosted-login.json`** | 07 | one file for the page | configured on the auth `/providers` API |
| 18 | **`authsetup widgets` / `authsetup snippet <widget>`**, and framework flavours of `snippet login` | 06, 08 | discover and embed from the CLI | catalogue page + skill; `snippet login --framework plain` |
| 19 | **Configurable install command in `apiKey` / `cliInstall` widgets; a `loginModal` widget; theming hooks** | 08 | widgets show ab0t's CLIs; Clerk-style modal expected | skip that block or mint via `POST /api-keys/`; `login` widget + SDK popup |
| 20 | **`authsetup invite <email> --org --role` and `authsetup users`** | 09 | invites and removals from the CLI | `POST /organizations/{id}/invite`; the `invite` widget |
| 21 | **Workspaces for users who signed up before switching to `workspace-per-user`** | 09 | late switchers | none; new signups only |
| 22 | **`authsetup invite-admin <email>`** (service org), and ordinary grants from the CLI | 10 | bring a colleague in | invite API with `role: admin`; `/permissions/grant` |
| 24 | **`connect` prints a ready `.env` fragment per language** | 11 | less transcription | two printed lines |
| 25 | **Consumer account self-delete on `disconnect`** | 11, 14 | clean offboarding | key revoked, account stays inert (server `DELETE /users/me` for consumer accounts not wired into `disconnect`) |
| 26 | **`authsetup approve <consumer> --tier` / `--revoke`** | 12 | provider moves a partner between tiers | team membership via API |
| 27 | **`authsetup consumers`**: who is connected, tier, key ids | 12 | provider visibility | org member/team lists via API |
| 28 | **Tier names free of legacy cross-customer wording** | 12 | vocabulary | some providers' tiers carry older names |
| 29 | **`run --prune`**: remove what config no longer lists, diff first | 13 | removals are manual today | default-team syncs are additive; only tiers reconcile exactly |
| 30 | **Rename the default team in place** | 13 | a rename makes a second team | avoid renaming |
| 31 | **`authsetup rotate-key`** (service key) | 14 | rotation is a hand edit of a credentials file today | clear `api_key` in `<svc>.<env>.json`, `run 01`, `DELETE /api-keys/{old}` |
| 32 | **`authsetup revoke-key <id>`** | 14 | leaked-key response from the CLI | `DELETE /api-keys/{id}` |
| 33 | **Admin password rotation from the CLI** | 14 | the admin is a normal account | reset server-side, update `admin.password` in the creds file, `doctor --strict` |
| 35 | **`migrate` imports consumer keys** | 15 | bash-kit leavers | copy `<provider>-consumer.json` into `~/.authmesh/<svc>/` as `.prod.json` first |
| 36 | **`authsetup migrate-config`**: add new schema fields with a diff | 15 | schema growth (e.g. `scope`) | hand edit; `validate` |
| 37 | **`run` warns when the binary is behind** | 15 | fewer stale installs | `doctor`, `update --check` |
| 38 | **`doctor` explains a 403 from a key or user id** | 16 | the most common support question | `whois <id>` + SOP 16 tables |
| 39 | **Guided repair for the orphaned users org and the `SELF:` audience** | 16 | both need the platform team today | platform team |
| 40 | **`authsetup unlock`** | 16 | stale locks | the lock message says stale or alive (0.5.24); move the one file aside when stale |
| 42 | **A machine-readable result for `up` / `run`** (`--json`) | 05, 13, 15 | scripts and agents should never read prose | exit codes `0`/`1`/`4`; `nothing to do` if you must |
| 43 | **`status` sees `redirect_uris` drift, and `status --json` exits `3` on drift** | 13 | CI that trusts `status` | `--dry-run run 02 04`; the human `status` exit code |
| 44 | **Self-serve fix for a permission schema with no owner recorded** | 05, 16 | today only the auth team can unblock it | ask the auth team (platform-team@ab0t.com) |
| 45 | **`destroy`'s NEXT names the environment's files, not the whole credentials directory** | 14, 17 | the default directory holds every environment, prod included | move aside only `*.<env>.json` |
