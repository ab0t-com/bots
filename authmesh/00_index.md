# The ab0t auth mesh, for the people using it

**Who this is for.** A team putting its own product on the ab0t auth mesh with one tool, `authsetup`: sign-in for your customers, permissions, a branded login page, keys for your backend, and connections to other services such as billing and payment. No auth internals required. The running example throughout is **Acme** and their service **`invoicer`**.

**Checked against `authsetup` 0.5.25** (the `VERSION` file). Run `authsetup version`; if yours is older, SOP 15 step A updates it first.

**How to use it.** Read 01 and 02 once (ten minutes). Then follow 03 → 06 in order on day one. Everything after that is a job you come back for. Each SOP has the same shape: what it is for, what to have ready, numbered steps with exact commands, what you will see, what to do when it goes wrong, what is **Coming** (approved but not built yet, with today's workaround), and where to go next.

**Three things to know before any command.** Most `authsetup` commands default to **production**; every command in these SOPs says `--env` and so should you. The one exception is `authsetup up`: it never guesses; with no environment chosen it asks once (default `dev`) and shows the environment on every plan. Second, when you copy a NEXT line the tool printed, check it names your environment (`--env …` or `--base-url …`) before you run it. Third, `~/.authmesh/<service>/` holds every environment's credentials, including prod; never delete it.

**Ally.** The agent in this folder (`agent.md`) follows these SOPs for you: it explains in plain words, previews every change and waits for your yes, confirms the environment every time, and never prints a secret. `README.md` says how to install it.

## The journey

| # | SOP | one line |
|---|---|---|
| 01 | [Scope model, for clients](01_sop_system_scope_model_for_clients.md) | One extra word, `scope: "org" \| "platform"`; the service that defines a permission decides who gets it. In the tool since 0.5.21; what is still Coming is marked. |
| 02 | [Day zero: a new customer joins](02_sop_system_day_zero_new_customer.md) | Acme puts `invoicer` on the mesh, end to end, in nine moves. |
| 03 | [Install, sign in, environments](03_sop_system_install_sign_in_environments.md) | One `curl` to install; check the version; `prod` is the default; `use-env dev`; who the tool acts as. |
| 04 | [Describe your service](04_sop_system_describe_your_service.md) | `permissions.json`: actions, resources, permissions, `default_grant`, `scope`, roles, how users are organised. |
| 05 | [Check it, preview it, run it](05_sop_system_check_and_first_run.md) | `authsetup up`: the plan in plain words, your yes, then the apply (experts: `--dry-run run` → `run`); the name check before anything is created; what each of steps 01–08 creates and where credentials go. |
| 06 | [Wire it into your app](06_sop_system_wire_it_into_your_app.md) | `authsetup settings --env-file .env` and `authsetup snippet login`: service key + audience in the backend (Python `ab0t_auth`, Go `auth-sdk-go`); client id + org slug in the frontend. |
| 07 | [Login page and branding](07_sop_system_hosted_login_and_branding.md) | `hosted-login.json`: colours, wording, sign-up vs invitation-only, where invites land. |
| 08 | [Drop-in JavaScript widgets](08_sop_system_js_widgets.md) | Find, embed, pin a version: user menu, API keys, invites, teams, inline login. |
| 09 | [Your users](09_sop_system_your_users.md) | Shared space or workspace per user; the default team; invites; removing someone. |
| 10 | [Your team and platform permissions](10_sop_system_your_team_and_platform_permissions.md) | Bringing colleagues in; ordinary vs `platform` grants; `grant-platform`, `revoke-platform`, `platform-holders`. |
| 11 | [Using other services](11_sop_system_using_other_services.md) | `providers` → `connect billing --as invoicer` → wire two env vars; billing/payment; the in-house `clients.d` + `run 07`. |
| 12 | [Opening your service to others](12_sop_system_opening_your_service_to_others.md) | `run 08`: tiers, the consumers org, the directory listing; moving a partner up a tier. |
| 13 | [Changing things safely](13_sop_system_changing_things_safely.md) | Edit → validate → `up` → status; which file drives what; re-sent vs changed; exit 3 and 4; what a run will not undo; `backfill`. |
| 14 | [Keys: rotate, offboard, disconnect](14_sop_system_keys_rotate_offboard_disconnect.md) | Service key rotation, consumer key rotation, leaving a provider, a leaked key, a leaving colleague. |
| 15 | [Migrations and upgrades](15_sop_system_migrations_and_upgrades.md) | `authsetup update` and its migration kits (`migrate-check.sh`); off the bash kit with `migrate`; `auth-sdk-go` via migrationbot; `ab0t_auth`. |
| 16 | [Troubleshooting and recovery](16_sop_system_troubleshooting_and_recovery.md) | The real messages and their fixes: name taken, no owner recorded, other-origin refusal, stale credentials, exit 4, locks; wiped local DB. |
| 17 | [Security rules](17_sop_system_security_rules.md) | Never default a `platform` permission; secrets handling; credentials only to your auth URL; never test against prod; verify with your audience. |

## Also in this folder

- `agent.md`, Ally; `skills/ally-mesh-client/SKILL.md`, the skill that points Ally at these SOPs; `README.md`, installing both.
- `GAPS.md`, every **Coming** item in one table: the `authsetup` spec list.
- `VERSION`, the `authsetup` version these pages were checked against; `bot.json`, the manifest; `install.sh`, the installer.
- `tests/sop_command_lint.sh`, which checks that every `authsetup` command and flag these pages show exists in your binary (`tests/README.md`).
