---
name: ab0t-quota-go-middleware
description: >-
  Put the ab0t-quota-go guard in front of a Go HTTP API and read what it returns: q.Middleware with
  the Identity and Router callbacks, Exempt paths, FailOpen, OnDecision/OnWarn hooks, the X-Quota-*
  headers, the 429 body, every decision reason (exceeded, shadow_would_deny, tier_unresolved,
  tier_not_in_config, enforcement_disabled, global_kill_switch, …), q.Check / q.Spend / q.Release
  outside a request, and chi / gorilla / echo / gin adapters. Use when wiring the guard, debugging
  why a request was denied or carries no headers, or choosing fail-open vs fail-closed. Verified
  against v0.1.9; the compiled walk-through is billing-quota SOP 05.
---

# The quota guard (HTTP middleware)

## What this is

A standard `func(http.Handler) http.Handler` that asks the quota engine, before your handler runs,
whether this customer may do this now. It only **checks**; counters move when you call `q.Spend`
after the work really happened, so a failed request never uses up a customer's allowance.

## The picture

```
request ─► Exempt path? ─yes─► your handler (no headers)
            │no
            ▼
          Router → "" ? ─yes─► your handler (no headers)
            │resource, cost
            ▼
          Identity → error? ─► FailOpen ? handler : 401 {"detail":"identity required"}
            │user, org
            ▼
          engine.Check → error? ─► FailOpen ? handler : 503 {"detail":"quota engine error"}
            │decision
            ▼
          denied? ─► 429 + JSON body + X-Quota-* + Retry-After
          allowed ─► X-Quota-* (+ X-Quota-Warning near a threshold) ─► your handler ─► you call q.Spend
```

## Do this (the default path)

```go
guard := q.Middleware(quota.MiddlewareDeps{
    Identity: func(r *http.Request) (userID, orgID string, err error) {
        a := actorFrom(r.Context()) // set by your auth middleware after it validated the token
        return a.UserID, a.OrgID, nil
    },
    Router: func(r *http.Request) (resourceKey string, cost float64) {
        if r.Method == "POST" && r.URL.Path == "/api/invoices" {
            return "invoicer.invoices", 1
        }
        return "invoicer.api.requests", 1 // return "" to skip quota for a route
    },
    Exempt:   []string{"/healthz", "/api/quotas/"},
    FailOpen: false,
})
mux.Handle("/api/", guard(apiHandler))
```
After the work: `if _, err := q.Spend(ctx, engine.CheckInput{UserID: u, OrgID: o, ResourceKey: "invoicer.invoices", Cost: 1}); err != nil { … }`.
For a gauge (seats, live sessions): `Spend` when it starts, `q.Release(ctx, engine.CheckInput{…})`
on **every** way it ends. Outside a request (a background job): `res, err := q.Check(ctx, in)`, then
`res.Allowed()`.

Frameworks: `chi` / `gorilla/mux` → `r.Use(guard)`; `echo` → `e.Use(echo.WrapMiddleware(guard))`;
`gin` → wrap per route, `gin.WrapH(guard(handler))`.

## What your customers notice

Allowed responses carry `X-Quota-Resource`, `X-Quota-Tier`, `X-Quota-Reason`, `X-Quota-Limit`,
`X-Quota-Remaining`, `X-Quota-Used`, and `X-Quota-Warning` near a threshold. A denial:
```
HTTP/1.1 429   Retry-After: …
{"detail":"Quota exceeded for invoicer.invoices: 20/20 (tier: free).","reason":"exceeded",
 "resource":"invoicer.invoices","tier":"free","used":20,"limit":20,"upgrade_url":"https://…/upgrade"}
```
Show `detail` and an upgrade button from `upgrade_url`.

| reason | allowed? | meaning |
|---|---|---|
| `under_limit`, `unlimited` | yes | normal |
| `near_warning`, `near_critical`, `burst_consumed` | yes | close to or just past the limit (warned) |
| `shadow_would_deny`, `shadow_would_deny_per_user` | yes | shadow mode: would have been denied |
| `enforcement_disabled` | yes | `enforcement.enabled` is false or missing |
| `tier_unresolved` | **yes** (fail-open) | no user/org from `Identity`, or the tier lookup failed |
| `exceeded`, `per_user_exceeded` | no (`429`) | over the limit |
| `tier_not_in_config` | no (`429`) | the tier exists in the token/billing but not in your file; not softened by shadow |
| `global_kill_switch` | no (`429`) | you turned the emergency brake on |

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| `Identity` or `Router` nil | `panic: middleware.Guard: Identity required` | pass both |
| auth middleware runs after the guard | `401 {"detail":"identity required"}` | auth first |
| `Router` returns a key the config lacks | `503 {"detail":"quota engine error"}` (`engine: unknown resource_key`) | add the resource first (SOP 14 step 3) |
| a token without the tier claim | `200` with `X-Quota-Reason: tier_unresolved` or the `default_tier` | check `jwt_claim_key`; set `default_tier` |
| a release path forgot `Release` | a gauge that only goes up | release on every exit; reconcile (SOP 13) |
| `FailOpen: true` on a route that costs money | free usage while Redis is down | fail-closed on spend, open on release |

## Check it worked

```sh
curl -sI -H "Authorization: Bearer $USER_TOKEN" https://<dev host>/api/invoices | grep -i x-quota
curl -sI https://<dev host>/healthz | grep -ci x-quota      # 0 — exempt
```
Log `OnDecision` (`{org_id, user_id, resource, tier, reason, used, limit}`) to see every decision.
Still stuck: send one request/response pair with its `X-Quota-*` headers (no tokens) to
`platform-team@ab0t.com`.

SOPs: [05 wire the library](../../05_sop_system_wire_the_library.md) ·
[06 shadow then enforce](../../06_sop_system_shadow_run_then_enforce.md) ·
[12 multi-tenant correctness](../../12_sop_system_multi_tenant_correctness.md) ·
[17 troubleshooting](../../17_sop_system_troubleshooting.md).
