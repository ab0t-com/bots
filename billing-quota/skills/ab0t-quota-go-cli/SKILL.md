---
name: ab0t-quota-go-cli
description: >-
  Use quotactl, the ab0t-quota-go command-line tool: install it (go install or a release binary with
  SHA256SUMS), check a config and the live wiring (capabilities), grade production posture (doctor),
  start a conforming dev Redis or print infra templates (provision), register the auth-event
  subscription (subscribe-events), re-send or backfill signed events (replay, backfill), and what
  events / delete-user can and cannot do today. Use for "install quotactl", "quotactl capabilities",
  "doctor exit code", "subscribe-events", "replay missed events", "backfill sign-up credit",
  "quotactl --version says dev". Verified against v0.1.9 and v0.1.10 (differences marked).
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
| `subscribe-events [--events …] [--prefix /api] [--name …] [--org-slug S \| --org-id ID] [--rotate-secret]` | the auth service | register your receiver (idempotent by endpoint); `--rotate-secret` (v0.1.10) deletes and re-creates it with the current secret and `--events` |
| `replay --file F --target URL [--secret S] [--bare]` | your receiver | re-send saved events, signed, with their **same** event ids |
| `backfill --input users.csv --target URL [--secret S] [--dry-run] [--bare]` | your receiver | synthesize sign-up events (new event ids) for users from before you shipped grants, or to retry failed grants |
| `events --user U \| --status S [--limit 50]` · `delete-user --user-id U` | nothing it can reach: v0.1.10 refuses (non-zero); v0.1.9 an empty in-memory stub | use `q.LedgerStore` inside your service (see below) |

## Do this (the default path)

```sh
go install github.com/ab0t-com/ab0t-quota-go/cmd/quotactl@v0.1.10   # or @v0.1.9; use the tag your service pins
```
Or download a prebuilt binary and check it:
```sh
V=v0.1.10; OS=linux; ARCH=amd64    # or darwin / arm64; windows: quotactl-windows-amd64.exe
curl -fsSLO "https://github.com/ab0t-com/ab0t-quota-go/releases/download/$V/quotactl-$OS-$ARCH"
curl -fsSLO "https://github.com/ab0t-com/ab0t-quota-go/releases/download/$V/SHA256SUMS"
grep " quotactl-$OS-$ARCH\$" SHA256SUMS | sha256sum -c - && chmod +x "quotactl-$OS-$ARCH"
```
Then, on dev: `quotactl capabilities --config ./quota-config.json`. `replay` and `backfill` read the
secret from `$AB0T_AUTH_WEBHOOK_SECRET` when `--secret` is not given; prefer that (a command line is
visible in `ps`). On v0.1.9 their `--help` prints the exported secret as the flag default: do not run
it in a shared terminal or CI log. `subscribe-events` reads `AB0T_AUTH_AUTH_URL`,
`AB0T_AUTH_ADMIN_TOKEN`, `AB0T_AUTH_WEBHOOK_PUBLIC_URL` and `AB0T_AUTH_WEBHOOK_SECRET` (SOP 10).
`users.csv` for `backfill` is `user_id[,org_id]` per line; `#` lines are comments.

## What your customers notice

Nothing, except through `replay` and `backfill`, which can hand out sign-up credit: always
`--dry-run` a backfill first. The receiver's dedup makes repeats no-ops.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| `quotactl --version` after `go install` (v0.1.9) | `quotactl version dev (commit unknown, built unknown)` | normal for a v0.1.9 `go install`; `go version -m "$(command -v quotactl)"` shows the module version; release binaries print it. A v0.1.10 `go install …@v0.1.10` prints `v0.1.10` |
| `capabilities` against production first | it connects and may create tables there | run on dev/staging |
| expecting `events` / `delete-user` to see your service's ledger | v0.1.9: `ledger backend: memory (stub — events/replay/backfill operate on this process only)` and no rows / `deleted 0 rows` with exit `0` (nothing was deleted) · v0.1.10: non-zero exit, `this CLI cannot reach your service's handler ledger …` | `q.LedgerStore.QueryByUser` / `QueryByStatus` / `DeleteUser` inside your own service (SOP 10, 15) |
| trusting `subscribe-events`' exit code on v0.1.9 | exit `0` with `subscription_id:` empty | read the id; the log line above says why. v0.1.10 exits non-zero with the HTTP status and a remedy |
| trusting `replay` / `backfill`' exit code on v0.1.9 | exit `0` even when the receiver refused events | read the per-event `HTTP <status>` lines. v0.1.10 exits non-zero when any event was not accepted |
| `replay` to retry a grant that ended `failed_permanent` | nothing happens (same event id, already final) | fix the cause, then `backfill` (new event ids; already-granted users are no-ops) |
| re-running `subscribe-events` to change the secret | v0.1.9: the old subscription (and old secret) is kept · v0.1.10: an error naming `--rotate-secret` | SOP 10 step 7 |
| `--bare` mismatched | `401 invalid signature` from your receiver | the Go receiver accepts both forms; leave `--bare` off unless your receiver needs bare hex |

Any command error exits `2` with the reason on stderr; `doctor` uses its own `0`–`4` codes. On
v0.1.10, `subscribe-events`, `replay`, `backfill`, `events` and `delete-user` count as errors
whenever what you asked for did not happen; on v0.1.9 they can exit `0` without doing it.

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
