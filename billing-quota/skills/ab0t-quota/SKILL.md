---
name: ab0t-quota
description: >-
  Start here for the ab0t quota library (ab0t-quota-go for Go, ab0t-quota for Python): what it does
  for a service on the ab0t mesh, the default way to add it, and which guide or SOP answers the
  question. Use when someone mentions ab0t-quota, ab0t-quota-go, quota-config.json, quotactl,
  quota.Setup, q.Middleware, q.WebhookHandler, CreditGranter, tier_provider, shadow_mode,
  credit_grant, subscription_credit, credit_balance, or asks "how do I limit / meter / charge for my
  API", "where do I start with quota", "how do I test it works". Routes to the billing-quota SOPs and
  the ab0t-quota-go-* companion skills.
---

# The quota library — start here

## What this is

A small library inside your service that decides, on every request, whether a customer is within
the limits of their plan, and tells your frontend why when they are not. You describe your plans
and what you count in one file (`quota-config.json`); billing and payment (two mesh services) hold
the money, so you never write a ledger or touch Stripe.

## The picture

```
customer → your API → quota guard: allow? (X-Quota-* headers)  → your handler → q.Spend
                          │ deny → 429 + upgrade_url                               │
                          └─ tier from the JWT claim / a static map / billing       └─ counters in your Redis
customer pays → payment (Stripe) → billing: balance + tier → the guard sees the new tier
```

| piece | holds | you touch it with |
|---|---|---|
| quota library | limits and counters, the allow/deny decision | `quota-config.json` + ~150 lines of glue |
| billing | each customer org's balance, usage, reservations, tier | your billing key (`X-API-Key`) |
| payment | plans, prices, checkout, portal, subscriptions (Stripe) | your payment key |

## Do this (the default path)

1. Keys first (Ally): `authsetup --env dev connect billing --as <service>` and `… payment …` (SOP 03).
2. Write `quota-config.json` with `enforcement: {enabled: true, shadow_mode: true}` (SOP 04).
3. Add the library (versions are git tags; pin them):
   ```sh
   go get github.com/ab0t-com/ab0t-quota-go@v0.1.10
   go install github.com/ab0t-com/ab0t-quota-go/cmd/quotactl@v0.1.10
   pip install "ab0t-quota[all] @ git+https://github.com/ab0t-com/ab0t-quota.git@v0.6.7"   # Python instead
   ```
   v0.1.9 still works; the SOPs mark its workarounds "on v0.1.9".
4. Wire `quota.Setup`, `q.Middleware`, `q.Spend` (SOP 05, compiled code there).
5. Run a shadow day, then enforce (SOP 06). Plans and checkout: SOP 07. Sign-up credit: SOP 10.

## What your customers notice

- Under the limit: nothing, plus `X-Quota-*` headers your UI can turn into a usage bar.
- Over the limit: `429` with `{"detail","reason":"exceeded","resource","tier","used","limit","upgrade_url"}`.
- Out of prepaid money (when you meter money with billing): billing answers `402` with
  `required_topup`; show a top-up button (SOP 11).
- Your Redis down: `503 {"detail":"quota engine error"}` on guarded routes (fail-closed default);
  billing or payment down: answer your own `503` and retry, never a free pass.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| `enforcement.enabled` left out | every request `X-Quota-Reason: enforcement_disabled` | write it (SOP 04) |
| no Redis declared | `ab0t-quota-go config error [QUOTA-CFG-001] — Redis counter store URL is not declared.` | `storage.redis_url` or `QUOTA_REDIS_URL`; `"memory://"` for one dev process |
| v0.1.9: receiver mounted at its full path | auth events answer `404 page not found`; no sign-up credit | `http.StripPrefix("/api/quotas", q.WebhookHandler())` (SOP 05; works on both versions; v0.1.10 also answers at the full path) |
| billing URL set before paid mode is ready | `quota.Setup: enable_paid but the billing chain is SEVERED — …` | not metering yet: `Options.EnablePaid=&false` (SOP 05 step 4); `outbox.allow_ephemeral: true` is dev only |
| v0.1.9: following the quota-go README's example | `quota.Config`, `Mount`, `CheckBundle` do not compile | use SOP 05 and `examples/basic/main.go` (from v0.1.10 the README matches the code) |

## Check it worked

```sh
quotactl capabilities --config ./quota-config.json | jq '{Enforcement, ShadowMode, Billing, Payment, CreditGrant, WhyOff}'
curl -sI -H "Authorization: Bearer $USER_TOKEN" https://<your dev host>/api/<a guarded route> | grep -i x-quota
```
`capabilities` connects to your Redis (and creates declared DynamoDB tables), so run it on dev
first. Still stuck: send the `capabilities` output, the failing request and response (no keys) and
your library version to `platform-team@ab0t.com`.

## Where to go next

| question | go to |
|---|---|
| words: tier, credit, subscription credit, gauge vs accumulator | `ab0t-quota-billing-101` |
| what to decide first, in what order | `ab0t-quota-go-design`, SOP 02 |
| `quota.Setup`, env vars, `Capabilities` | `ab0t-quota-go-setup`, SOP 05 |
| `quota-config.json` fields | `ab0t-quota-go-config`, SOP 04 |
| the HTTP guard, headers, `Spend`/`Release` | `ab0t-quota-go-middleware`, SOP 05 |
| sign-up credit, auth events | `ab0t-quota-go-auth-events`, SOP 10 |
| `quotactl` | `ab0t-quota-go-cli` |
| tests and a pre-launch checklist | `ab0t-quota-go-testing`, SOP 06 |
| a message you do not understand | SOP 17, `quota-troubleshooting` |

The SOPs live in the billing-quota bot folder: [`../../00_index.md`](../../00_index.md).
