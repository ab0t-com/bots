---
name: quota-paid-tier-onboarding
description: >-
  Go from "customers see a pricing page" to "a customer pays and gets the new limits" on the ab0t
  mesh: plans and prices in payment, the checkout and portal routes, how a Stripe payment becomes a
  tier in billing and new limits in your quota library, the monthly credit that comes with a
  subscription, the price-to-tier map, and the end-to-end test. Use when adding paid tiers, an
  upgrade button, "paid but still on free", or wiring the payment → billing → quota chain. Routes to
  billing-quota SOPs 07, 08 and 09.
---

# Paid tiers, end to end

## What this is

The chain that turns a card payment into higher limits, with nothing for you to code in the middle:
payment handles Stripe, tells billing the customer's new tier and pays in the plan's monthly credit,
and your quota library reads the tier on its next lookup.

## The picture

```
pricing page ─► checkout (payment, Stripe) ─► customer pays
   Stripe ─► payment: price → tier ─► billing PUT /billing/<org>/tier
           └─ invoice paid ─► billing subscription_credit (if the tier is subscription_with_credits)
your quota library ─► tier from the JWT claim (next token) or billing (within cache_ttl_seconds) ─► new limits
```

## Do this (the default path)

1. Tiers in `quota-config.json`, with `billing_model` and, for a bundled allowance, a
   `credit_grant` with `trigger: "subscription_invoice_paid"` (SOP 04).
2. Product, plan (with `metadata.tier_id`) and price in payment, dollars, lower-case enums (SOP 07).
3. Give support your real `price_id`s and the `tier_id`s they map to: payment's price → tier map is
   what turns a payment into a tier (SOP 08 step 2). Do this before the first sale.
4. Proxy routes and buttons (SOP 07 step 7; skill `billing-payment-integration`).
5. Test on dev with `4242 4242 4242 4242`: checkout → subscription `active`/`trialing` →
   `GET /billing/<org>/tier` shows the tier → your responses carry `X-Quota-Tier: pro` (SOP 08).

## What your customers notice

An upgrade that takes effect "within a few minutes" (the next token, or the tier cache), their
monthly allowance in the balance after each paid invoice, and on cancellation a return to `free` at
the end of the period.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| price not in payment's price → tier map | customer paid, tier unchanged; a `tier_resolution_unresolved` reconciliation item | send the mapping to support (SOP 08 step 2) |
| tier id in billing that your config lacks | `429 reason: tier_not_in_config` | add the tier or fix the map |
| JWT tier claim not refreshed | `X-Quota-Tier: free` for a payer | re-login, or read the tier from billing |
| subscription created outside checkout | no monthly credit (no `metadata.org_id`) | start subscriptions through SOP 07 step 3 |

## Check it worked

The SOP 08 chain walk: Stripe delivered `2xx` → billing tier changed → your service shows the new
tier. Stuck at a step you cannot see: send the org id, subscription id and time to
`platform-team@ab0t.com`.

SOPs: [07 plans, checkout, portal](../../07_sop_system_plans_prices_checkout_portal.md) ·
[08 subscriptions, webhooks, tier sync](../../08_sop_system_subscriptions_webhooks_tier_sync.md) ·
[09 tiers and upgrades](../../09_sop_system_tiers_and_upgrades.md).
