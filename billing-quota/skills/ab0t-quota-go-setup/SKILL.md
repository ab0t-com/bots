---
name: ab0t-quota-go-setup
description: >-
  Add ab0t-quota-go to a Go service and start it: go get, quota.Setup and its Options, where the
  config file is found, the env vars it reads, the Capabilities snapshot and WhyOff, Healthy(),
  graceful shutdown. Use when adding github.com/ab0t-com/ab0t-quota-go, calling quota.Setup, choosing
  ConfigPath, setting AB0T_QUOTA_BILLING_URL / AB0T_QUOTA_PAYMENT_URL / QUOTA_REDIS_URL /
  AB0T_AUTH_WEBHOOK_SECRET, reading "billing off" or "credit_grant off" at start-up, or wiring Close()
  into shutdown. Verified against v0.1.9 and v0.1.10 (differences marked); the full walk-through
  is billing-quota SOP 05.
---

# Start the quota library in a Go service

## What this is

One call, `quota.Setup`, reads `quota-config.json`, connects to your Redis, and returns a handle
(`q`) with the HTTP guard, the auth-event receiver and the counters. It refuses to start on a bad
config or an undeclared store, and tells you in one log line which parts are on and why the others
are off.

## The picture

```
quota.Setup(ctx, quota.Options{…})
   ├─ config: Options.ConfigPath › $QUOTA_CONFIG_PATH › ./quota-config.json › /etc/ab0t/quota-config.json
   ├─ counters: storage.redis_url (or $QUOTA_REDIS_URL) — required; "memory://" for one dev process
   ├─ billing / payment clients: $AB0T_QUOTA_BILLING_URL(+_TOKEN), $AB0T_QUOTA_PAYMENT_URL(+_TOKEN)
   ├─ auth-event receiver: $AB0T_AUTH_WEBHOOK_SECRET
   └─ q.Capabilities(): what is on, and WhyOff for everything that is not
```

| `quota.Options` field | set it when |
|---|---|
| `ConfigPath` | your file is not in one of the search paths |
| `ConfigOverride` | tests: pass a parsed `*config.Config` and skip the disk |
| `CreditGranter` | you grant sign-up credit (SOP 10); on v0.1.10 `quota.BillingCreditGranter(nil)` is built in |
| `AutoSubscribeAuthEvents` | you want the auth-event subscription made at boot (SOP 10 step 3) |
| `ObservedUsageProvider`, `AccumulatorUsageProvider` | you want counters re-checked against your own truth before a deny (SOP 13) |
| `ReconcileOrgs` | you run the background reconciler (needs DynamoDB declared; SOP 13) |
| `SettlementPublisher`, `EnablePaid` | paid mode in code instead of config (SOP 11 step 6); `EnablePaid: &paidOff` (`paidOff := false`) when the billing URL is set but the service does not meter yet (limits and/or sign-up credit only): billing reads `OFF (paid disabled)` and `Healthy()` stays true (SOP 05 step 4) |
| `Logger` | you want your own `*slog.Logger` |

Env names it reads (only these prefixes: `QUOTA_`, `AB0T_QUOTA_`, `AB0T_AUTH_`, plus the AWS SDK's):
`QUOTA_CONFIG_PATH`, `QUOTA_REDIS_URL`, `AB0T_QUOTA_BILLING_URL`, `AB0T_QUOTA_BILLING_TOKEN`,
`AB0T_QUOTA_PAYMENT_URL`, `AB0T_QUOTA_PAYMENT_TOKEN`, `AB0T_QUOTA_SERVICE_TOKEN` (fallback for
either token), `AB0T_AUTH_WEBHOOK_SECRET` (and, v0.1.10, `AB0T_AUTH_WEBHOOK_SECRET_PREVIOUS` during a
secret rotation), `AB0T_QUOTA_ALLOW_EXPERIMENTAL_BILLING_MODELS`, and for
the auth-event subscription `AB0T_AUTH_AUTH_URL`, `AB0T_AUTH_ADMIN_TOKEN`,
`AB0T_AUTH_WEBHOOK_PUBLIC_URL`. A token starting `ab0t_sk_` is sent as `X-API-Key`.

## Do this (the default path)

```sh
go get github.com/ab0t-com/ab0t-quota-go@v0.1.10    # v0.1.9 still works with the SOPs' "on v0.1.9" notes
```
```go
q, err := quota.Setup(ctx, quota.Options{ConfigPath: "quota-config.json"})
if err != nil {
    log.Fatal(err) // a bad config or an undeclared Redis stops you here, with the reason
}
defer q.Close(context.Background())

caps := q.Capabilities()
log.Printf("quota: enforcement=%v shadow=%v billing=%v why_off=%v", caps.Enforcement, caps.ShadowMode, caps.Billing, caps.WhyOff)
```
Then the guard and the receiver (SOP 05 step 2, compiled code). On shutdown stop your HTTP server
first, then `q.Close(ctx)`. Expose `q.Capabilities()` and `q.Healthy()` on your health endpoint so
intentional "off" (billing not wired in dev) and accidental "off" (a token missing in prod) look
different.

## What your customers notice

Nothing until you enforce. If `Setup` fails the service does not start, which is the point: a
service that started without its counters would let every customer use everything.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| config in the wrong place or env named `AB0T_QUOTA_CONFIG_PATH` | `config: no config file found (set QUOTA_CONFIG_PATH or place quota-config.json in CWD)` (v0.1.10 also warns `AB0T_QUOTA_CONFIG_PATH is set but IGNORED …`) | `QUOTA_CONFIG_PATH` |
| no Redis declared | `ab0t-quota-go config error [QUOTA-CFG-001] — Redis counter store URL is not declared.` | `storage.redis_url` / `QUOTA_REDIS_URL` |
| Redis unreachable | `DECLARED REDIS UNREACHABLE/UNAUTHENTICATED (D-2) — refusing to start` | fix URL/password; `storage.connect_retry_seconds` is the wait |
| billing URL set, no durable outbox | `quota.Setup: enable_paid but the billing chain is SEVERED — …` (v0.1.10 adds why paid mode is on and `pass Options.EnablePaid=&false`) | not metering yet: `EnablePaid: &paidOff`; metering: SOP 11 step 6; `outbox.allow_ephemeral: true` is dev only and leaves `Healthy()` false |
| `BillingCreditGranter(nil)` without a billing URL (v0.1.10) | `quota.Setup: CreditGranter is quota.BillingCreditGranter(nil) but billing is not wired — …` | set `AB0T_QUOTA_BILLING_URL` / `_TOKEN` |
| `tier_provider.type` missing | `quota.Setup: tier provider: tier_provider.type required (jwt \| mesh \| static)` | set it |
| `engine_mode: "bridge"` | `config: engine_mode "bridge" is out of scope for v0.1.0` | Python only; use `local` |
| generic `REDIS_URL` / `AUTH_SERVICE_URL` | ignored | use the names above |

## Check it worked

```sh
quotactl capabilities --config ./quota-config.json | jq '{Enforcement, ShadowMode, Billing, Payment, CreditGrant, FloatStore, BillingStatus, WhyOff, Resolved}'
```
`Resolved` shows where each value came from (config key, env var or unset; secrets as "present"
only). It connects to Redis and creates declared DynamoDB tables, like a real boot, but starts no
background loops. On v0.1.10 also read `ConfigWarnings` (the boot's `quota config: …` lines). Still stuck: send that output and the start-up log (no keys) to
`platform-team@ab0t.com`.

SOPs: [04 config](../../04_sop_system_describe_tiers_and_resources.md) ·
[05 wire the library](../../05_sop_system_wire_the_library.md) ·
[17 troubleshooting](../../17_sop_system_troubleshooting.md).
