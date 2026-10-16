---
name: quota-tier-management
description: >-
  Manage the plans (tiers) a service on the ab0t mesh offers and the plan each customer is on: the
  tier ladder and limits in quota-config.json, where the library reads a customer's tier (jwt /
  static / mesh), how payment sets it in billing, moving one customer by hand (PUT /billing/{org}/tier
  with a reason), downgrades and credit resets, trials, per-user caps, and changing or renaming a
  tier safely. Use for "change a limit", "add a tier", "move this customer to pro", "downgrade",
  "trial", "tier not updating". Routes to billing-quota SOPs 09, 08 and 14.
---

# Tiers: the ladder and who is on which rung

## What this is

A tier is the plan a customer org is on; it picks their limits. You define the ladder in
`quota-config.json`; payment sets a customer's tier in billing when they subscribe or cancel; you can
also move one customer by hand for a sales deal or a support fix.

## The picture

```
quota-config.json tiers[]  ── free (1) · pro (2) · enterprise (3)   sort_order decides "downgrade"
customer's tier:  payment ─► billing PUT /billing/<org>/tier ─► your library reads it
                  (jwt claim on the next token · or billing within cache_ttl_seconds · or a static map in tests)
by hand:          your service ─► PUT /billing/<org>/tier {"tier_id","reason"}   (billing.write.tier)
```

## Do this (the default path)

1. Ladder and limits (SOP 04 step 3; SOP 09 step 1): `sort_order` rising with rank; `0` = not on
   this plan; `null` = unlimited.
2. Tier source: `jwt` with `jwt_claim_key` and `default_tier` (SOP 09 step 2). `mesh` needs a lookup
   you write in code.
3. Move one customer by hand (SOP 09 step 4):
   ```
   PUT https://billing.service.ab0t.com/billing/<customer org id>/tier   X-API-Key: <billing key>
   {"tier_id": "pro", "reason": "enterprise pilot"}
   ```
4. Change a limit: raise any time; lower behind a shadow day (SOP 14 steps 1–2). Rename a tier only at
   a period boundary, with the price map updated first (SOP 14 step 5).
5. Trials: `trial_period_days` on the payment plan (SOP 07, 09 step 6).

## What your customers notice

New limits within a few minutes of a change (token refresh or cache), a clear `429` with
`upgrade_url` on their current plan, and their allowance reset on a downgrade when the old tier says
`reset_on_downgrade: true`.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| a tier in billing or the token that your file lacks | `429 reason: tier_not_in_config` | add it |
| `PUT /tier` without the right permission or for your own org | `403` | `billing.write.tier` + cross-customer tier, as your service |
| expecting `GET …/tier/history` with a gateway key | `403` | it needs `billing.admin`; keep your own record |
| renaming a tier | counters restart, grants become eligible again | treat as remove + add (SOP 14) |
| downgrade did not reset credit | `409 Reset rejected: source tier mismatch`, or `reset_on_downgrade` false | intended protection, or set it (SOP 09) |

## Check it worked

`GET /billing/<org>/tier` and `X-Quota-Tier` on that customer's next response agree. Questions:
`platform-team@ab0t.com`.

SOPs: [09 tiers and upgrades](../../09_sop_system_tiers_and_upgrades.md) ·
[08 tier sync](../../08_sop_system_subscriptions_webhooks_tier_sync.md) ·
[14 changing things safely](../../14_sop_system_changing_things_safely.md).
