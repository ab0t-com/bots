# 10 · Credits, grants and auth events

**What this is for.** Giving customers money or allowance automatically and exactly once: a sign-up gift, a monthly refill that comes with a subscription, a manual grant for a support case. Sign-up grants ride on **auth events** (a signed webhook from auth to your service); subscription refills ride on Stripe invoices through payment.

**Before you start.** SOP 05 wired (the auth-event receiver mounted, SOP 05 step 2). Your billing key can grant credit for a customer org: `billing.write.transactions` (the promotional-credit route needs it) plus the cross-customer capability (SOP 03 step 5). A public URL for your service.

## Steps

**1. Decide the grant in config** (SOP 04). Sign-up gift on `free`:
```json
"credit_grant": { "trigger": "signup", "amount_per_period": "5.00", "currency": "USD", "destination": "credit_balance",
                  "lifecycle": "persistent", "dedup": "per_user_per_tier", "reset_on_downgrade": false, "reset_on_upgrade": false }
```
Monthly refill on `pro`: `trigger: "subscription_invoice_paid"`, `destination: "subscription_credit"`, `lifecycle: "use_it_or_lose_it"`, `dedup: "per_org_per_tier"` (B2B; `per_user_per_tier` is the anti-farming default for B2C). Lifecycles: `use_it_or_lose_it` sets the bucket each period; `rollover_capped` adds up to `rollover_max_periods × amount`; `persistent` adds once and never expires.

Only a grant with `"trigger": "signup"` is handed out on auth events (v0.1.10: any other trigger is skipped, ledger reason `credit_grant trigger is …, not signup: <tier>`). Always write the trigger: a `credit_grant` with no trigger still grants in Go (with a boot warning), but the Python runtime grants nothing without it. **On v0.1.9** the sign-up handler granted *any* tier's `credit_grant` on `org.created` / `user.org_assigned`, so `pro`'s monthly refill above was handed out as a gift every time a user joined an org on `pro`; guard against it in your granter (step 2, v0.1.9).

**2. Supply the granter (Go).** Without it the sign-up handler is not registered (`WhyOff["credit_grant"]: "no CreditGranter supplied; default handler not registered"`).

*On v0.1.10*, use the built-in granter:
```go
paidOff := false
q, err := quota.Setup(ctx, quota.Options{
    ConfigPath:    "quota-config.json",
    CreditGranter: quota.BillingCreditGranter(nil), // uses AB0T_QUOTA_BILLING_URL + AB0T_QUOTA_BILLING_TOKEN
    EnablePaid:    &paidOff,                         // sign-up credit only: you do not meter into billing yet (SOP 05 step 4)
})
```
`Setup` refuses to start if `AB0T_QUOTA_BILLING_URL` is unset (a granter that can never reach billing must not look wired). Where the grant goes depends on the tier's `credit_grant`: `destination: "credit_balance"` with `lifecycle: "persistent"` → `POST /billing/{org}/promotional-credit` (a gift; billing's caps below apply); any other destination or lifecycle → `POST /billing/{org}/apply-credit-grant` (the declared bucket and policy, no lifetime cap). The idempotency key sent to billing comes from the tier's `dedup` policy, never from the event: `user:{user}:initial_credit:{tier}` (`per_user_per_tier`), `org:{org}:initial_credit:{tier}` (`per_org_per_tier`), `user:{user}:initial_credit` (`per_user_global`), `org:{org}:initial_credit` (`per_org_global`), the same keys the Python runtime sends. `q.Billing.GrantCredit` (and `billing.Client.GrantCredit`) also grants for real on v0.1.10 (`OrgID` is required), next to the new `GrantPromotionalCredit` and `ApplyCreditGrant`.

*Already running the hand-written granter below and upgrading?* Its key (`{org}:{user}:signup_credit:{tier}`) differs from the built-in one, so billing will not recognise grants it made under the old key. Users you already granted stay protected only if the library's handler ledger is durable (Redis or DynamoDB; `quotactl capabilities` shows the ledger backend). On the in-memory ledger, keep your granter.

*On v0.1.9*, write the granter yourself: one method that calls billing's promotional-credit route for the customer's org (compiled against v0.1.9):
```go
// billingGranter gives sign-up credit through billing's promotional-credit route.
type billingGranter struct {
    baseURL string // AB0T_QUOTA_BILLING_URL
    key     string // AB0T_QUOTA_BILLING_TOKEN (your billing key)
    http    *http.Client
}

func (g billingGranter) GrantCredit(ctx context.Context, in authevents.CreditGrantRequest) error {
    if in.Trigger != "signup" {
        return nil // v0.1.9 calls this for every tier's credit_grant; only sign-up gifts belong here
    }
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

paidOff := false
q, err := quota.Setup(ctx, quota.Options{
    ConfigPath: "quota-config.json",
    CreditGranter: billingGranter{
        baseURL: os.Getenv("AB0T_QUOTA_BILLING_URL"),
        key:     os.Getenv("AB0T_QUOTA_BILLING_TOKEN"),
        http:    &http.Client{Timeout: 10 * time.Second},
    },
    EnablePaid: &paidOff, // sign-up credit only (SOP 05 step 4)
})
```
On v0.1.9, write the HTTP call yourself as above: that version's typed billing client (`q.Billing.GrantCredit`) posts to a path billing does not serve. Returning `nil` for a non-`signup` trigger records the event as handled without granting anything. On both versions the library resolves the tier with your tier provider, composes the dedup key from the tier's `dedup` policy, and runs the handler on `org.created` and `user.org_assigned`. Idempotency is built in: delivery dedup on `(handler, event_id)`, business dedup on the key, retries with backoff, and a ledger row (`success | skipped | failed_permanent`). Billing adds its own guard rails on promotional credit: by default at most $500 per grant, $1,000 of promotional credit per org in total, and 10 grants per org per hour.

**3. Share a secret and subscribe to auth events.**
```sh
export AB0T_AUTH_WEBHOOK_SECRET=$(openssl rand -hex 32)   # the SAME value in your service's env
export AB0T_AUTH_AUTH_URL=https://auth.dev.ab0t.com
export AB0T_AUTH_WEBHOOK_PUBLIC_URL=https://invoicer.dev.acme.example
export AB0T_AUTH_ADMIN_TOKEN=<a token with events.subscribe/events.read>   # see Coming
quotactl subscribe-events --events org.created,user.org_assigned --prefix /api --name invoicer-credit-grant --org-slug invoicer-users
```
It registers `https://invoicer.dev.acme.example/api/quotas/_webhooks/auth` with auth (idempotent: it lists the subscriptions first and creates one only if none has that endpoint) and prints `subscription_id: …`.

*On v0.1.10* it fails loudly: any failure exits non-zero with the HTTP status and a remedy (`401`: the admin token was rejected or expired; `403`: the token lacks `events.read`, `events.subscribe`, or `events.delete` for `--rotate-secret`). It reads every page of auth's subscription list. If a subscription for your endpoint already exists but listens to different events, is disabled, or (where auth discloses it) signs with a different secret, it stops with an error that names `--rotate-secret` (step 7). On success it prints:
```
subscription_id: <id>
action: created            # or existing; rotated with --rotate-secret
endpoint: https://invoicer.dev.acme.example/api/quotas/_webhooks/auth
events: org.created,user.org_assigned
secret: not verified …     # only when auth does not disclose the stored secret
```
*On v0.1.9* the command exits `0` even when nothing was registered. An **empty** `subscription_id:` means it failed: the reason is on the log line above it (for example `auth-event auto-subscribe: create failed err="HTTP 401: …"`), so read the id rather than the exit code.

Your service verifies each event's HMAC (`X-Event-Signature: sha256=<hex>`, over the raw body) with the same secret. Missing secret on your side means every event is rejected with `401 {"detail":"invalid signature"}`.

Prefer to subscribe at boot instead? `quota.Options{AutoSubscribeAuthEvents: true}` runs the same registration in the background when the service starts, from the same four variables, for the event types your handlers listen to, under the name `ab0t-quota-credit-grant`. It never blocks start-up and only logs a failure (on v0.1.10 it also reads every page of the list and logs an ERROR when the existing subscription signs with a different secret), and it needs a valid admin token in the service's environment at every boot, so run the CLI once by hand first and keep it as the way you check.

**4. Prove it once, then replay it.**
```sh
# a real sign-up at your hosted login page → your logs: credit granted via auth-event … → billing balance up by 5.00
quotactl replay --file one-event.jsonl --target https://invoicer.dev.acme.example/api/quotas/_webhooks/auth   # secret read from AB0T_AUTH_WEBHOOK_SECRET
# → 200 {"status":"ok","ran":1,…} and the balance does NOT move again
```
Backfill users who signed up before you shipped grants:
```sh
quotactl backfill --input users.csv --target <same url> --dry-run   # user_id[,org_id] per line
quotactl backfill --input users.csv --target <same url>
```
Business dedup makes already-granted users no-ops. Both commands read the secret from `AB0T_AUTH_WEBHOOK_SECRET`; prefer that to `--secret`, because a command line is visible in `ps`. On v0.1.9 the `--help` of `replay` and `backfill` prints the live secret as the flag's default, so do not run `--help` with the secret exported in a shared terminal or a CI log. *On v0.1.10* both exit non-zero when any event was not accepted, and `backfill` requires `--target` and a secret unless `--dry-run`; *on v0.1.9* they exit `0` whatever the receiver answered, so read the per-event output.

`replay` re-posts the **same** event ids, so an event that already ended as `failed_permanent` (or `success`) is a no-op on both versions. To retry a grant that failed, fix the cause and use `backfill`: it sends new event ids, and users already granted are no-ops.

**5. Subscription refills.** Nothing to code: when Stripe pays the invoice, payment applies the plan's grant into billing's `subscription_credit` (idempotency key `invoice:<invoice_id>:credit_grant`), provided the subscription carries `metadata.org_id` (checkouts started through SOP 07 do). Spend order at commit is subscription credit → credit balance → cash.

**6. Manual grants** (support, goodwill): your service identity calls `POST /billing/<customer org>/promotional-credit` with `{"amount": "10.00", "reason": "goodwill", "idempotency_key": "<a key unique to this grant>"}`; the same key replayed returns the original result. Never from a frontend.

**7. Rotate the shared secret.** Auth does not let you edit a subscription's secret, so a new secret needs a new subscription.

*On v0.1.10*, one command, and no event is rejected while you deploy:
```sh
NEW=$(openssl rand -hex 32)
# 1. deploy your service with AB0T_AUTH_WEBHOOK_SECRET=$NEW and AB0T_AUTH_WEBHOOK_SECRET_PREVIOUS=<the old secret>
#    (comma-separated if more than one; the receiver accepts all of them)
# 2. replace the subscription (deletes it and creates it again with the current secret and --events; needs events.delete)
AB0T_AUTH_WEBHOOK_SECRET=$NEW quotactl subscribe-events --rotate-secret --events org.created,user.org_assigned --prefix /api --name invoicer-credit-grant --org-slug invoicer-users
# → action: rotated, replaced: <old id> (…)
# 3. backfill sign-ups from the seconds between the delete and the create (step 4)
# 4. redeploy without AB0T_AUTH_WEBHOOK_SECRET_PREVIOUS
```

*On v0.1.9*, `subscribe-events` finds your subscription by its endpoint and leaves it unchanged, so delete it by hand first:
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

Receiver responses: `200 {"status":"ok","ran":1,"event_type":"org.created"}`, `200 {"status":"ignored","event_type":"…"}` (no handler), `400 {"detail":"invalid json"}`, `401 {"detail":"invalid signature"}`; on v0.1.10 also `405` (not a POST) and `413 {"detail":"body too large"}` (over 1 MiB). Handler skips in the ledger: `no tier for user`, `tier not in config: <id>`, `no credit_grant for tier: <id>`, `already granted: <key>`, and on v0.1.10 `credit_grant trigger is <trigger>, not signup: <id>`. `GET /billing/{org}/balance` shows `credit_balance` (gifts) and `subscription_credit` (refills) separately.

## If it goes wrong

- `auth-event auto-subscribe skipped: missing one of AB0T_AUTH_AUTH_URL, AB0T_AUTH_ADMIN_TOKEN, AB0T_AUTH_WEBHOOK_PUBLIC_URL, AB0T_AUTH_WEBHOOK_SECRET` — set all four for the CLI run.
- `subscribe-events` exits non-zero with `HTTP 401` or `HTTP 403` (v0.1.10), or on v0.1.9 prints an empty `subscription_id:` with `auth-event auto-subscribe: create failed err="HTTP 401: …"` (or `403`) — the admin token expired (15 minutes) or lacks `events.subscribe` / `events.read`. Get a fresh token and re-run.
- `subscribe-events` stops with `subscription … exists but …` and names `--rotate-secret` (v0.1.10) — the existing subscription listens to other events, is disabled, or signs with a different secret. Rotate with step 7.
- Every event `404 page not found` — on v0.1.9, the receiver is mounted at its full path without `http.StripPrefix` (SOP 05 step 2). On v0.1.10 the receiver answers any path ending in `/_webhooks/auth`, so a `404` means the event reaches a path that is not that (check `--prefix` and your mux).
- Every event `401 invalid signature` — the secret differs between the subscription and your service, or the body was re-serialised before verifying. Re-running `subscribe-events` does **not** change the secret of an existing subscription: put the secret the subscription was created with back in your service, or rotate with step 7.
- A paid tier's monthly refill granted every time someone joins an org on it — v0.1.9 grants any tier's `credit_grant` on auth events. Upgrade to v0.1.10, or keep the `if in.Trigger != "signup"` guard in your granter (step 2).
- `200 "ignored"` — no handler: pass `CreditGranter` or register one with `authevents.OnAuthEvent`.
- Granted twice — your own handler used a plain `HandlerFunc`, or its `Key` is not deterministic. Use `authevents.Idempotent`.
- Granted, but balance still 0 — billing refused your call (`403` cross-customer, `422` missing `idempotency_key`, `404` from a granter that posts to the wrong path, or `400 Promotional credit exceeds single-credit maximum` / `lifetime cap reached`). The ledger row says `failed_permanent`; fix the cause and re-send with `quotactl backfill` (step 4; `replay` of the same event is a no-op).
- `quotactl events --status failed_permanent` shows nothing (v0.1.9), or refuses with `this CLI cannot reach your service's handler ledger` (v0.1.10) — the standalone CLI has no connection to your service's Redis/DynamoDB ledger; v0.1.9 read an empty in-memory stub instead. Read the ledger inside your service with `q.LedgerStore.QueryByUser` / `QueryByStatus` (for example from an admin route). See *Coming*.

## Coming

- **`quotactl events` / `delete-user` reading the real ledger.** v0.1.10 makes them refuse honestly (non-zero) instead of reading an empty stub. *Today:* inspect from inside your service with `q.LedgerStore`.
- **A scoped `events.subscribe` token for your service** instead of an auth admin token. *Today:* `AB0T_AUTH_ADMIN_TOKEN` from the platform team.
- **Secret rotation without deleting the subscription** (auth letting you edit a subscription's secret). *Today:* step 7; v0.1.10 makes it one command (`--rotate-secret`) plus a backfill of the few seconds in between.
- **A `credit_grant.trigger: "manual"` admin tool** (referral credits, goodwill). *Today:* the billing credit route by hand.
- **One sign-up grant across runtimes:** the Go loader rewrites legacy `initial_credit` into a `credit_grant` whose documented lifecycle/destination differ between the Go and Python docs. *Today:* write `credit_grant` explicitly and never set both.

## Next

SOP 11, metering money with billing.
