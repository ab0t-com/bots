---
name: quota-troubleshooting
description: >-
  Diagnose quota, billing and payment problems from your own service, with your own tools: a
  customer blocked who should not be, usage numbers that look wrong, "paid but still on free",
  credit not granted, the service refusing to start, 503s from the guard, the emergency brake. Uses
  quotactl capabilities / doctor, X-Quota-* headers, your logs, ReconcileOrg and read-only billing
  and payment calls; never hand-edits a counter or another service's data. Use when debugging
  "false 429", "counter drift", "tier not updating", "credit missing", "Quota engine not
  initialized", "kill switch", and to know what to send support. Routes to billing-quota SOP 17.
---

# Troubleshooting from your side

## What this is

A short order of looks that finds most problems in minutes using only what you own: your config,
your logs, your Redis through the library, and read-only calls to billing and payment with your
keys. When the cause is inside billing or payment, you send support a small, exact bundle instead
of guessing.

## The picture

```
1 what the library thinks   quotactl capabilities · doctor          (WhyOff, BillingStatus, Resolved)
2 what one request got      X-Quota-Tier / -Reason / -Used / -Limit  (+ your OnDecision log line)
3 what billing/payment say  GET /billing/<org>/tier · /balance · GET /subscriptions/<org>
4 repair from the truth     q.Engine.ReconcileOrg(ctx, org, "")    (never redis-cli SET)
5 still stuck               the support bundle below
```

## Do this (the default path)

| symptom | look | usual cause → fix |
|---|---|---|
| customer gets `429` but should not | their `X-Quota-Tier`, `X-Quota-Used`, `X-Quota-Limit`, `X-Quota-Reason` | wrong tier (step 3), a drifted gauge (`ReconcileOrg`), or a limit too low (SOP 14) |
| usage number looks wrong | `ReconcileOrg` report (`before`/`after`/`status`) | a release path forgot `q.Release`; wire `ObservedUsageProvider` so it self-heals (SOP 13) |
| paid but still on free | `GET /billing/<org>/tier`, then `GET /subscriptions/<org>` | price not mapped to a tier, token not refreshed, or cache (SOP 08 chain) |
| credit not granted | receiver response and ledger outcome in your logs | `404` (mount without `StripPrefix`), `401` (secret), granter path or permissions (SOP 10) |
| service will not start | the first error line | the SOP 17 start-up table (Redis not declared or unsafe, paid-mode chain, config) |
| `503 {"detail":"quota engine error"}` | your logs: `quota guard: engine error, fail-closed` | unknown `resource_key` from `Router`, or Redis down (SOP 05) |
| need to stop all spend now | — | `enforcement.global_kill_switch: true` + deploy (denies everything); `shadow_mode: true` to stop denying instead (SOP 13 step 7) |

Repair a counter from your own truth, never by hand:
```go
rep, err := q.Engine.ReconcileOrg(ctx, orgID, "") // "" = every resource; returns before/after per resource
```

## What your customers notice

Wrong denials are the costly ones: while you investigate, `shadow_mode: true` (deploy) lets them
through and keeps counting. A `503` from your guard is safer than free usage, but tell them "try
again shortly" in your UI.

## Common mistakes

| mistake | why it hurts | instead |
|---|---|---|
| `redis-cli SET` on a `quota:*` key | the next reconcile overwrites it and the drift signal is lost | `ReconcileOrg` |
| guessing billing or payment state | you fix the wrong side | read `/tier`, `/balance`, `/subscriptions` with your key |
| running `doctor`/`capabilities` first on production | they connect and may create declared tables | dev/staging first |
| a new idempotency key to get past a `409` | possible double charge | retry with the same key (SOP 11) |

## Check it worked, and what to send support

After a fix: the customer's next response shows the expected `X-Quota-Tier` and `X-Quota-Reason`,
and `ReconcileOrg` reports `in_sync`. If the cause is in billing or payment, send
`platform-team@ab0t.com`: the org id, the time, the failing request and response with their status
(no keys or tokens), `quotactl capabilities` (or `doctor --json`) output, and your library version.

SOPs: [17 troubleshooting](../../17_sop_system_troubleshooting.md) ·
[13 observability and reconciliation](../../13_sop_system_observability_alerts_reconciliation.md) ·
[08 tier sync](../../08_sop_system_subscriptions_webhooks_tier_sync.md) ·
[10 credits](../../10_sop_system_credits_grants_auth_events.md).
