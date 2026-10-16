# 10 · Credits, grants and auth events

**What this is for.** Giving customers money or allowance automatically and exactly once: a sign-up gift, a monthly refill that comes with a subscription, a manual grant for a support case. Sign-up grants ride on **auth events** (a signed webhook from auth to your service); subscription refills ride on Stripe invoices through payment.

**Before you start.** SOP 05 wired (the webhook handler mounted with `http.StripPrefix`). Your billing key can grant credit for a customer org: `billing.write.transactions` (the promotional-credit route needs it) plus the cross-customer capability (SOP 03 step 5). A public URL for your service.

## Steps

**1. Decide the grant in config** (SOP 04). Sign-up gift on `free`:
```json
"credit_grant": { "trigger": "signup", "amount_per_period": "5.00", "currency": "USD", "destination": "credit_balance",
                  "lifecycle": "persistent", "dedup": "per_user_per_tier", "reset_on_downgrade": false, "reset_on_upgrade": false }
```
Monthly refill on `pro`: `trigger: "subscription_invoice_paid"`, `destination: "subscription_credit"`, `lifecycle: "use_it_or_lose_it"`, `dedup: "per_org_per_tier"` (B2B; `per_user_per_tier` is the anti-farming default for B2C). Lifecycles: `use_it_or_lose_it` sets the bucket each period; `rollover_capped` adds up to `rollover_max_periods × amount`; `persistent` adds once and never expires.

**2. Supply the granter (Go).** Without it the sign-up handler is not registered (`WhyOff["credit_grant"]: "no CreditGranter supplied; default handler not registered"`). The granter is one method that calls billing's promotional-credit route for the customer's org (compiled against v0.1.9):
```go
// billingGranter gives sign-up credit through billing's promotional-credit route.
type billingGranter struct {
    baseURL string // AB0T_QUOTA_BILLING_URL
    key     string // AB0T_QUOTA_BILLING_TOKEN (your billing key)
    http    *http.Client
}

func (g billingGranter) GrantCredit(ctx context.Context, in authevents.CreditGrantRequest) error {
    body, _ := json.Marshal(map[string]string{
        "amount":          in.Amount.String(),
        "reason":          "signup_credit",
        "idempotency_key": in.OrgID + ":" + in.UserID + ":signup_credit:" + in.TierID, // the same key on every retry
    })
    req, err := http.NewRequestWithContext(ctx, http.MethodPost,
        g.baseURL+"/billing/"+in.OrgID+"/promotional-credit", bytes.NewReader(body))
    if err != nil {
        return err
    }
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("X-API-Key", g.key)
    resp, err := g.http.Do(req)
    if err != nil {
        return err // the library retries with backoff
    }
    defer resp.Body.Close()
    if resp.StatusCode >= 300 {
        return fmt.Errorf("billing promotional-credit: HTTP %d", resp.StatusCode)
    }
    return nil
}

q, err := quota.Setup(ctx, quota.Options{
    ConfigPath: "quota-config.json",
    CreditGranter: billingGranter{
        baseURL: os.Getenv("AB0T_QUOTA_BILLING_URL"),
        key:     os.Getenv("AB0T_QUOTA_BILLING_TOKEN"),
        http:    &http.Client{Timeout: 10 * time.Second},
    },
})
```
Write the HTTP call yourself as above: the library's typed billing client (`q.Billing.GrantCredit`) posts to a path billing does not serve. The library resolves the tier with your tier provider, composes the dedup key from the tier's `dedup` policy, and runs the handler on `org.created` and `user.org_assigned`. Idempotency is built in: delivery dedup on `(handler, event_id)`, business dedup on the key, retries with backoff, and a ledger row (`success | skipped | failed_permanent`). Billing adds its own guard rails on promotional credit: by default at most $500 per grant, $1,000 of promotional credit per org in total, and 10 grants per org per hour.

**3. Share a secret and subscribe to auth events.**
```sh
export AB0T_AUTH_WEBHOOK_SECRET=$(openssl rand -hex 32)   # the SAME value in your service's env
export AB0T_AUTH_AUTH_URL=https://auth.dev.ab0t.com
export AB0T_AUTH_WEBHOOK_PUBLIC_URL=https://invoicer.dev.acme.example
export AB0T_AUTH_ADMIN_TOKEN=<a token with events.subscribe/events.read>   # see Coming
quotactl subscribe-events --events org.created,user.org_assigned --prefix /api --name invoicer-credit-grant --org-slug invoicer-users
```
It registers `https://invoicer.dev.acme.example/api/quotas/_webhooks/auth` with auth (idempotent: it lists the subscriptions first and creates one only if none has that endpoint) and prints `subscription_id: …`. An **empty** `subscription_id:` means nothing was registered: the reason is on the log line above it (for example `auth-event auto-subscribe: create failed err="HTTP 401: …"`); the command still exits `0`, so read the id. Your service verifies each event's HMAC (`X-Event-Signature: sha256=<hex>`, over the raw body) with the same secret. Missing secret on your side means every event is rejected with `401 {"detail":"invalid signature"}`.

Prefer to subscribe at boot instead? `quota.Options{AutoSubscribeAuthEvents: true}` runs the same registration in the background when the service starts, from the same four variables, for the event types your handlers listen to, under the name `ab0t-quota-credit-grant`. It never blocks start-up and only logs a failure, and it needs a valid admin token in the service's environment at every boot, so run the CLI once by hand first and keep it as the way you check.

**4. Prove it once, then replay it.**
```sh
# a real sign-up at your hosted login page → your logs: credit granted via auth-event … → billing balance up by 5.00
quotactl replay --file one-event.jsonl --target https://invoicer.dev.acme.example/api/quotas/_webhooks/auth --secret "$AB0T_AUTH_WEBHOOK_SECRET"
# → 200 {"status":"ok","ran":1,…} and the balance does NOT move again
```
Backfill users who signed up before you shipped grants:
```sh
quotactl backfill --input users.csv --target <same url> --secret "$AB0T_AUTH_WEBHOOK_SECRET" --dry-run   # user_id[,org_id] per line
quotactl backfill --input users.csv --target <same url> --secret "$AB0T_AUTH_WEBHOOK_SECRET"
```
Business dedup makes already-granted users no-ops.

**5. Subscription refills.** Nothing to code: when Stripe pays the invoice, payment applies the plan's grant into billing's `subscription_credit` (idempotency key `invoice:<invoice_id>:credit_grant`), provided the subscription carries `metadata.org_id` (checkouts started through SOP 07 do). Spend order at commit is subscription credit → credit balance → cash.

**6. Manual grants** (support, goodwill): your service identity calls `POST /billing/<customer org>/promotional-credit` with `{"amount": "10.00", "reason": "goodwill", "idempotency_key": "<a key unique to this grant>"}`; the same key replayed returns the original result. Never from a frontend.

**7. Rotate the shared secret.** `subscribe-events` finds your subscription by its endpoint and leaves it unchanged, and auth does not let you edit a subscription's secret, so a new secret needs a new subscription:
```sh
NEW=$(openssl rand -hex 32)
# 1. delete the old subscription in auth (its id is what subscribe-events printed; needs events.delete)
curl -sS -X DELETE -H "Authorization: Bearer $AB0T_AUTH_ADMIN_TOKEN" "$AB0T_AUTH_AUTH_URL/events/subscriptions/<subscription_id>"
# 2. deploy your service with AB0T_AUTH_WEBHOOK_SECRET=$NEW
# 3. register again with the new secret
AB0T_AUTH_WEBHOOK_SECRET=$NEW quotactl subscribe-events --events org.created,user.org_assigned --prefix /api --name invoicer-credit-grant --org-slug invoicer-users
```
Sign-ups that happen between steps 1 and 3 are not delivered to you; send them afterwards with `quotactl backfill` (step 4). Business dedup makes anyone already granted a no-op.

## What you'll see

Receiver responses: `200 {"status":"ok","ran":1,"event_type":"org.created"}`, `200 {"status":"ignored","event_type":"…"}` (no handler), `400 {"detail":"invalid json"}`, `401 {"detail":"invalid signature"}`. Handler skips in the ledger: `no tier for user`, `tier not in config: <id>`, `no credit_grant for tier: <id>`, `already granted: <key>`. `GET /billing/{org}/balance` shows `credit_balance` (gifts) and `subscription_credit` (refills) separately.

## If it goes wrong

- `auth-event auto-subscribe skipped: missing one of AB0T_AUTH_AUTH_URL, AB0T_AUTH_ADMIN_TOKEN, AB0T_AUTH_WEBHOOK_PUBLIC_URL, AB0T_AUTH_WEBHOOK_SECRET` — set all four for the CLI run.
- `subscription_id:` printed empty with `auth-event auto-subscribe: create failed err="HTTP 401: …"` (or `403`) — the admin token expired (15 minutes) or lacks `events.subscribe` / `events.read`. Get a fresh token and re-run.
- Every event `404 page not found` — the receiver is mounted without `http.StripPrefix` (SOP 05 step 2).
- Every event `401 invalid signature` — the secret differs between the subscription and your service, or the body was re-serialised before verifying. Re-running `subscribe-events` does **not** change the secret of an existing subscription: put the secret the subscription was created with back in your service, or rotate with step 7.
- `200 "ignored"` — no handler: pass `CreditGranter` or register one with `authevents.OnAuthEvent`.
- Granted twice — your own handler used a plain `HandlerFunc`, or its `Key` is not deterministic. Use `authevents.Idempotent`.
- Granted, but balance still 0 — billing refused your call (`403` cross-customer, `422` missing `idempotency_key`, `404` from a granter that posts to the wrong path, or `400 Promotional credit exceeds single-credit maximum` / `lifetime cap reached`). The ledger row says `failed_permanent`; fix the cause and replay.
- `quotactl events --status failed_permanent` shows nothing — the standalone CLI reads an **in-memory** ledger (`ledger backend: memory (stub …)`); it cannot see your service's Redis/DynamoDB ledger. Read the ledger through your service's own admin route or logs. See *Coming*.

## Coming

- **`quotactl events` / `delete-user` reading the real ledger.** *Today:* the CLI uses an in-process stub; inspect from inside your service.
- **A scoped `events.subscribe` token for your service** instead of an auth admin token. *Today:* `AB0T_AUTH_ADMIN_TOKEN` from the platform team.
- **Secret rotation in one command** (`subscribe-events` updating the secret of an existing subscription, or auth letting you edit it). *Today:* step 7.
- **The library's typed billing client granting credit through a route billing serves.** *Today:* the granter in step 2.
- **A `credit_grant.trigger: "manual"` admin tool** (referral credits, goodwill). *Today:* the billing credit route by hand.
- **One sign-up grant across runtimes:** the Go loader rewrites legacy `initial_credit` into a `credit_grant` whose documented lifecycle/destination differ between the Go and Python docs. *Today:* write `credit_grant` explicitly and never set both.

## Next

SOP 11, metering money with billing.
