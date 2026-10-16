---
name: ab0t-quota-go-auth-events
description: >-
  Receive signed auth events (sign-ups, org creation) in a Go service with ab0t-quota-go and act on
  them exactly once: mount q.WebhookHandler correctly, give sign-up credit with a CreditGranter
  (the built-in quota.BillingCreditGranter on v0.1.10),
  write your own handler with authevents.OnAuthEvent and authevents.Idempotent, subscribe with
  quotactl subscribe-events or AutoSubscribeAuthEvents, verify the HMAC, rotate the shared secret.
  Use when wiring sign-up credit, debugging "every event 401 / 404 / ignored", "credit granted
  twice", "credit not granted", or handling org.created / user.org_assigned. Verified against v0.1.9
  and v0.1.10 (differences marked); the step-by-step is billing-quota SOP 10.
---

# Auth events and sign-up credit

## What this is

When someone signs up on your login page, auth sends your service a signed event. The library
verifies it, finds the new customer's tier, and runs your handler once per event and once per
business key, with retries and a record of every attempt. The common use is a sign-up gift paid into
the customer's billing balance.

## The picture

```
auth ──POST <your public URL>/api/quotas/_webhooks/auth  (X-Event-Signature: sha256=<hmac of raw body>)──►
   your mux "/api/quotas/" ─► http.StripPrefix("/api/quotas", q.WebhookHandler())     (both versions)
     or "/api/quotas/_webhooks/auth" ─► q.WebhookHandler()                              (v0.1.10 only)
       ├─ HMAC check with AB0T_AUTH_WEBHOOK_SECRET (+ _PREVIOUS, v0.1.10) ─ fail ─► 401 {"detail":"invalid signature"}
       ├─ handlers for event_type? none ─► 200 {"status":"ignored"}
       └─ run each (delivery dedup on event_id, business dedup on your key, retry, ledger row)
             └─ default handler (if CreditGranter set): org.created, user.org_assigned
                   → tier → tier's credit_grant (v0.1.10: trigger "signup" only) → GrantCredit → billing
```

## Do this (the default path)

1. Put a `credit_grant` with `trigger: "signup"` on the tier (SOP 04/10). Only that trigger grants
   on auth events in v0.1.10; v0.1.9 grants any tier's `credit_grant` there (a paid tier's refill
   included), so on v0.1.9 your granter must skip other triggers.
2. Pass a `CreditGranter` to `quota.Setup`, with `EnablePaid: &paidOff` (`paidOff := false`) while
   the service does not meter into billing.
   - v0.1.10: `CreditGranter: quota.BillingCreditGranter(nil)` (uses `AB0T_QUOTA_BILLING_URL` /
     `_TOKEN`; a `credit_balance`/`persistent` grant goes to promotional credit, any other bucket to
     `apply-credit-grant`; the billing idempotency key is `user:{user}:initial_credit:{tier}` by
     default). `q.Billing.GrantCredit` also grants for real here (`OrgID` required).
   - v0.1.9: the ten-line granter that calls billing's `POST /billing/<org>/promotional-credit` and
     returns `nil` when `in.Trigger != "signup"` is in SOP 10 step 2 (compiled against v0.1.9). Do not
     use v0.1.9's typed `q.Billing.GrantCredit`: it posts to a path billing does not serve. Before
     swapping it for the built-in one, read SOP 10 step 2 (the idempotency key shape differs).
3. Mount the receiver. This form works on both versions:
   ```go
   mux.Handle("/api/quotas/", http.StripPrefix("/api/quotas", q.WebhookHandler()))
   ```
   On v0.1.10 `mux.Handle("/api/quotas"+authevents.WebhookPath, q.WebhookHandler())` works too; on
   v0.1.9 it answers every event `404 page not found`.
4. Same secret on both sides, then subscribe once by hand:
   ```sh
   export AB0T_AUTH_WEBHOOK_SECRET=$(openssl rand -hex 32)   # also in your service's environment
   export AB0T_AUTH_AUTH_URL=https://auth.service.ab0t.com AB0T_AUTH_WEBHOOK_PUBLIC_URL=https://<your service>
   export AB0T_AUTH_ADMIN_TOKEN=<token with events.subscribe and events.read>
   quotactl subscribe-events --events org.created,user.org_assigned --prefix /api --name <service>-credit-grant
   ```
   It prints `subscription_id: <id>`. On v0.1.10 any failure exits non-zero with the HTTP status
   and a remedy, and an existing subscription with other events or another secret is an error naming
   `--rotate-secret`. On v0.1.9 it exits `0` regardless: an empty id means nothing was registered
   (read the log line above it). `quota.Options{AutoSubscribeAuthEvents: true}` does the same at
   boot, in the background, logging failures only.
5. Rotate the secret (SOP 10 step 7): on v0.1.10 deploy the new secret in `AB0T_AUTH_WEBHOOK_SECRET`
   and the old one in `AB0T_AUTH_WEBHOOK_SECRET_PREVIOUS`, run `quotactl subscribe-events --rotate-secret`,
   backfill the seconds in between, then drop `_PREVIOUS`; on v0.1.9 delete the subscription by hand,
   redeploy, re-subscribe, backfill.

Your own handler, run exactly once per business key (compiled against v0.1.9):
```go
h := authevents.Idempotent(handlerledger.IdempotentConfig{
    Handler: "welcome_email", // stable name; it is part of the ledger key
    Key:     func(e handlerledger.Event) string { return "welcome:" + e.GetUserID() },
    Retry:   handlerledger.DefaultRetry(),
}, func(ctx context.Context, ev handlerledger.Event, hctx *handlerledger.Context) error {
    if done, _ := hctx.AlreadyDone(ctx); done {
        return hctx.Skip("already sent")
    }
    if err := sendWelcome(ctx, ev.GetUserID()); err != nil {
        return err // retried with backoff, then recorded as failed_permanent
    }
    _ = hctx.MarkDone(ctx, "welcome-sent")
    return hctx.Success("welcome-sent")
})
authevents.OnAuthEvent("org.created", h)
```
Register handlers before `quota.Setup` if you use `AutoSubscribeAuthEvents` (it subscribes to the
event types registered at that moment).

## What your customers notice

A new customer's balance shows the gift (`credit_balance` up by the amount) moments after sign-up,
once. Replays, retries and duplicate deliveries never pay twice. If billing refuses, they simply do
not get the gift until you fix it and re-send with `quotactl backfill` (new event ids; `quotactl
replay` of an event that already ended `failed_permanent` is a no-op).

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| v0.1.9: receiver mounted at `"/api/quotas"+authevents.WebhookPath` | every event `404 page not found` | `http.StripPrefix` (step 3), or upgrade to v0.1.10 |
| v0.1.9: a paid tier's refill `credit_grant` and no trigger guard | the refill handed out each time someone joins an org on that tier | skip `in.Trigger != "signup"` in your granter, or upgrade to v0.1.10 |
| secret differs from the one the subscription was created with | every event `401 {"detail":"invalid signature"}` | put the original back, or rotate by replacing the subscription (SOP 10 step 7); re-running `subscribe-events` keeps the old one |
| body re-serialised before verifying | `401 invalid signature` | verify the raw bytes (the library does; do not wrap it in a JSON-rewriting proxy) |
| no `CreditGranter` | `200 {"status":"ignored"}`; `WhyOff credit_grant: no CreditGranter supplied; default handler not registered` | pass one |
| a plain `HandlerFunc` doing money work | the work happens twice on redelivery | wrap it in `authevents.Idempotent` |
| a `Key` that is not deterministic | granted twice | build it only from event fields |
| admin token expired (15 min) | v0.1.10: non-zero exit, `HTTP 401` · v0.1.9: `subscription_id:` empty, `create failed err="HTTP 401: …"` | fresh token, re-run |

## Check it worked

```sh
quotactl replay --file one-event.jsonl --target https://<your service>/api/quotas/_webhooks/auth   # secret from AB0T_AUTH_WEBHOOK_SECRET
# → 200 {"status":"ok","ran":1,…}; the customer's balance moves once, not twice
```
Prefer the environment to `--secret` (visible in `ps`). Ledger rows live in your Redis (or DynamoDB
if declared); the standalone `quotactl events` cannot see them (v0.1.10 refuses, v0.1.9 prints
nothing): read them with `q.LedgerStore.QueryByUser` / `QueryByStatus` in your service (SOP 10 Coming). Still stuck: send the receiver's response, the event id and your
`capabilities` output (no secrets) to `platform-team@ab0t.com`.

SOPs: [10 credits, grants, auth events](../../10_sop_system_credits_grants_auth_events.md) ·
[05 wire the library](../../05_sop_system_wire_the_library.md) ·
[17 troubleshooting](../../17_sop_system_troubleshooting.md).
