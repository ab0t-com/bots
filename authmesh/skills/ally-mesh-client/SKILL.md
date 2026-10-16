---
name: ally-mesh-client
description: >-
  Client-side SOPs for the ab0t auth mesh, driven through the `authsetup` CLI. Use when
  helping someone onboard or operate their service on the mesh as a CLIENT (not an
  auth-service engineer): install authsetup and pick an environment, write
  config/permissions.json (actions, resources, default_grant, scope, roles,
  org_structure), init --publish + validate + up (or dry-run + run steps 01–08), wire
  the service key/audience and OAuth client id/org slug into a Python (ab0t_auth) or Go
  (auth-sdk-go) app (settings, snippet login), brand the hosted login page, embed the
  AuthMeshWidgets JS widgets, organise end users (flat vs workspace-per-user, default
  team, invites), manage the team and platform permissions (grant-platform,
  platform-holders), connect to providers (billing/payment) or open the service to
  consumers (run 08, tiers), change config safely (up, re-sent vs changed, exit 3/4,
  backfill), rotate/revoke keys and disconnect, migrate (authsetup update and its
  migration kits, bash kit → authsetup, auth-sdk-go via migrationbot, ab0t_auth),
  troubleshoot any authsetup message (schema name taken, no owner recorded, other-origin
  refusal, stale credentials, locks, 403/422/429, wiped DB), and apply the security rules.
  Checked against authsetup 0.5.24 (the VERSION file beside the SOPs).
  Triggers: "authsetup", "onboard to the ab0t mesh", "permissions.json", "hosted login",
  "auth widgets", "connect to billing", "rotate my service key", "my users get 403",
  "scope platform", "grant-platform", "migrate from the bash kit", "is taken",
  "no owner recorded", "different origin", "doctor --strict", "exit code 4".
---

# ally-mesh-client

Seventeen short SOPs, one per job, written for the people using the mesh. This file only
routes; the SOPs are the references. Load the one for the job, follow it in order, and
respect its **Coming** markers (approved but not built; each has a *Today:* workaround).
They describe `authsetup` 0.5.24 (`../../VERSION`); check `authsetup version` first and
update an older binary (SOP 15) before quoting messages from SOP 16.

## Non-negotiables (restated from the SOPs)
- `authsetup` defaults to **prod** (only `up` asks instead). Write `--env` (or `--base-url`)
  on every command you run or suggest; confirm the target aloud. A NEXT line you copy must
  name the target too; add it when the tool left it out.
- Preview before any change: `--dry-run` (or read the plan back) → explicit yes → apply.
  Production applies run in the user's own terminal (typed `prod` confirmation).
- Credentials go only to the auth URL the user chose. An "advertises its client-management
  endpoint on … a different origin" stop is a safety feature; never route around it.
- Branch on exit codes (`0`/`1`/`2`/`3`/`4`), then read the whole message; never grep for
  pre-0.5.24 phrases such as `HTTP 403`.
- Never print or read credential files; point at `~/.authmesh/<svc>/<file>` and the field.
- Never delete `~/.authmesh/<svc>/`; it holds every environment, prod included.
- Say **org**, never "realm". The cross-customer concept is `scope: "platform"`; never
  introduce `cross_tenant` / `cross_org`.
- A `platform` permission is never a default (grant, role, team, tier).
- Use `authsetup`; hand-rolled HTTP only where an SOP's *Today:* says so.
- Unsure of a flag: `authsetup <command> --help`. Unsure of an id: `authsetup whois <id>`.

## The SOPs (relative to this file)
| job | file |
|---|---|
| map of everything | [../../00_index.md](../../00_index.md) |
| the scope model, client view (in the tool since 0.5.21) | [../../01_sop_system_scope_model_for_clients.md](../../01_sop_system_scope_model_for_clients.md) |
| day zero, end to end | [../../02_sop_system_day_zero_new_customer.md](../../02_sop_system_day_zero_new_customer.md) |
| install, sign in, environments | [../../03_sop_system_install_sign_in_environments.md](../../03_sop_system_install_sign_in_environments.md) |
| describe your service (`permissions.json`) | [../../04_sop_system_describe_your_service.md](../../04_sop_system_describe_your_service.md) |
| check, preview, first run; what steps 01–08 create | [../../05_sop_system_check_and_first_run.md](../../05_sop_system_check_and_first_run.md) |
| wire it into your app (backend + frontend, Python + Go) | [../../06_sop_system_wire_it_into_your_app.md](../../06_sop_system_wire_it_into_your_app.md) |
| hosted login + branding | [../../07_sop_system_hosted_login_and_branding.md](../../07_sop_system_hosted_login_and_branding.md) |
| JS widgets | [../../08_sop_system_js_widgets.md](../../08_sop_system_js_widgets.md) |
| your users | [../../09_sop_system_your_users.md](../../09_sop_system_your_users.md) |
| your team + platform permissions | [../../10_sop_system_your_team_and_platform_permissions.md](../../10_sop_system_your_team_and_platform_permissions.md) |
| using other services (connect, clients.d, run 07) | [../../11_sop_system_using_other_services.md](../../11_sop_system_using_other_services.md) |
| opening your service (run 08, tiers) | [../../12_sop_system_opening_your_service_to_others.md](../../12_sop_system_opening_your_service_to_others.md) |
| changing things safely | [../../13_sop_system_changing_things_safely.md](../../13_sop_system_changing_things_safely.md) |
| keys: rotate, offboard, disconnect | [../../14_sop_system_keys_rotate_offboard_disconnect.md](../../14_sop_system_keys_rotate_offboard_disconnect.md) |
| migrations + upgrades | [../../15_sop_system_migrations_and_upgrades.md](../../15_sop_system_migrations_and_upgrades.md) |
| troubleshooting + recovery | [../../16_sop_system_troubleshooting_and_recovery.md](../../16_sop_system_troubleshooting_and_recovery.md) |
| security rules | [../../17_sop_system_security_rules.md](../../17_sop_system_security_rules.md) |
| every Coming item in one table | [../../GAPS.md](../../GAPS.md) |

## Companions (load by name when the SOP points there)
Each is a short guide that links back to these SOPs.
`authsetup-cli` (bundled in the binary: `authsetup skills install`; a 0.5.24 copy is in `../authsetup-cli/`) for the full flag matrix;
`auth-mesh-setup` for the day-one overview; `mesh-tenancy-authority` for who can act in which org;
`hosted-login-setup` / `auth-hosted-login-org-config` for the login page and browser SDK;
`authmesh-widgets` / `auth-widgets-discovery` for widget detail; `ab0t-auth-fastapi` for the
Python route patterns; `connect-to-ab0t-mesh-provider`, `mesh-consumer-account-sop`,
`mesh-service-accounts` and `billing-payment-consumer-setup` for consuming other services;
`auth-obo-token-exchange` for on-behalf-of flows (not covered by the SOPs).
