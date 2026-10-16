---
name: ab0t-quota-go-cli
description: >-
  Use quotactl, the ab0t-quota-go command-line tool: install it (go install or a release binary with
  SHA256SUMS), check a config and the live wiring (capabilities), grade production posture (doctor),
  start a conforming dev Redis or print infra templates (provision), register the auth-event
  subscription (subscribe-events), re-send or backfill signed events (replay, backfill), and what
  events / delete-user can and cannot do today. Use for "install quotactl", "quotactl capabilities",
  "doctor exit code", "subscribe-events", "replay missed events", "backfill sign-up credit",
  "quotactl --version says dev". Verified against v0.1.9.
---

# quotactl

## What this is

The companion command-line tool for the Go quota library. It loads your `quota-config.json` the same
way your service does, so it is the quickest way to see what the library will do, and it handles the
one-off jobs around auth events (subscribe, replay, backfill).

## The picture

| command | touches | use it to |
|---|---|---|
| `capabilities --config F` | your Redis (and creates declared DynamoDB tables); no background loops | see what is on, `WhyOff`, and where each value came from (`Resolved`) |
| `doctor --config F [--json] [--fail-on-risk] [--timeout 15]` | same as above | grade production posture; exit `0` ok · `1` gate refusal · `2` config · `3` unreachable · `4` internal |
| `provision --local [--port 6399] [--dry-run]` · `provision --emit compose\|terraform\|acl\|iam` | Docker (local) · nothing (emit) | a conforming dev Redis · templates for real infra |
| `subscribe-events [--events …] [--prefix /api] [--name …] [--org-slug S \| --org-id ID]` | the auth service | register your receiver (idempotent by endpoint) |
| `replay --file F --target URL [--secret S] [--bare]` | your receiver | re-send saved events, signed |
| `backfill --input users.csv --target URL [--secret S] [--dry-run] [--bare]` | your receiver | synthesize sign-up events for users from before you shipped grants |
| `events --user U \| --status S [--limit 50]` · `delete-user --user-id U` | an in-memory stub only | nothing useful yet (see below) |

## Do this (the default path)

```sh
go install github.com/ab0t-com/ab0t-quota-go/cmd/quotactl@v0.1.9
```
Or download a prebuilt binary and check it:
```sh
V=v0.1.9; OS=linux; ARCH=amd64     # or darwin / arm64; windows: quotactl-windows-amd64.exe
curl -fsSLO "https://github.com/ab0t-com/ab0t-quota-go/releases/download/$V/quotactl-$OS-$ARCH"
curl -fsSLO "https://github.com/ab0t-com/ab0t-quota-go/releases/download/$V/SHA256SUMS"
grep " quotactl-$OS-$ARCH\$" SHA256SUMS | sha256sum -c - && chmod +x "quotactl-$OS-$ARCH"
```
Then, on dev: `quotactl capabilities --config ./quota-config.json`. `--secret` on `replay` and
`backfill` defaults to `$AB0T_AUTH_WEBHOOK_SECRET`; `subscribe-events` reads `AB0T_AUTH_AUTH_URL`,
`AB0T_AUTH_ADMIN_TOKEN`, `AB0T_AUTH_WEBHOOK_PUBLIC_URL` and `AB0T_AUTH_WEBHOOK_SECRET` (SOP 10).
`users.csv` for `backfill` is `user_id[,org_id]` per line; `#` lines are comments.

## What your customers notice

Nothing, except through `replay` and `backfill`, which can hand out sign-up credit: always
`--dry-run` a backfill first. The receiver's dedup makes repeats no-ops.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| `quotactl --version` after `go install` | `quotactl version dev (commit unknown, built unknown)` | normal for `go install`; `go version -m "$(command -v quotactl)"` shows the module version; release binaries print it |
| `capabilities` against production first | it connects and may create tables there | run on dev/staging |
| expecting `events` / `delete-user` to see your service's ledger | `ledger backend: memory (stub — events/replay/backfill operate on this process only)` and no rows / `deleted 0 rows` | inspect or delete through your own service (SOP 10, 15) |
| trusting `subscribe-events`' exit code | exit `0` with `subscription_id:` empty | read the id; the log line above says why |
| re-running `subscribe-events` to change the secret | the old subscription (and old secret) is kept | SOP 10 step 7 |
| `--bare` mismatched | `401 invalid signature` from your receiver | the Go receiver accepts both forms; leave `--bare` off unless your receiver needs bare hex |

Any command error exits `2` with the reason on stderr; `doctor` uses its own `0`–`4` codes.

## Check it worked

```sh
quotactl capabilities --config ./quota-config.json | jq '{Enforcement, ShadowMode, Billing, CreditGrant, WhyOff}'
quotactl doctor --config ./quota-config.json --json --fail-on-risk; echo "exit $?"
```
Still stuck: send `capabilities` and `doctor --json` output to `platform-team@ab0t.com`.

SOPs: [06 shadow then enforce](../../06_sop_system_shadow_run_then_enforce.md) ·
[10 credits and auth events](../../10_sop_system_credits_grants_auth_events.md) ·
[13 observability](../../13_sop_system_observability_alerts_reconciliation.md) ·
[17 troubleshooting](../../17_sop_system_troubleshooting.md).
