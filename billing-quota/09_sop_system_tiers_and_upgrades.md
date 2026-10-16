# 09 · Tiers and upgrades

**What this is for.** Where a customer's tier comes from at request time, how to shape the ladder, how an upgrade or downgrade reaches your limits, and how to move one customer by hand.

**Before you start.** SOP 04's `tiers[]`. Know whether your end users' tokens carry a tier claim (ask whoever runs your auth; Ally SOP 06 covers the token).

## Steps

**1. Shape the ladder.** Four rungs is the usual: `free` (gate quantity, not features; cap the monthly cost), a low paid tier, a high paid tier, `enterprise` (unlimited or custom; it should feel about five times the rung below). `sort_order` must increase with rank; it is what decides whether a change is a downgrade. A limit of `0` means "not available on this tier"; `null` means unlimited.

**2. Pick the tier source (`tier_provider`).**

| type | how the tier is found | when |
|---|---|---|
| `jwt` | reads claim `jwt_claim_key` (default `tier`) from the bearer token the request carried; no signature check (your auth already did that); missing claim → `default_tier` | your auth mints the claim; simplest and fastest |
| `static` | `mapping` of **user id** → tier; else `default_tier` | tests, internal tools |
| `mesh` | asks billing (`GET /billing/{org}/tier`) through a lookup **you wire in code** | you want billing to be the only truth; see *Coming* |

Add `cache_ttl_seconds` (30–300). The cache serves the last known good tier when a lookup fails and never caches the free fallback; sustained lookup failure raises an ERROR-level `tier_lookup_failing_sustained` signal.

**3. Know how an upgrade arrives** (SOP 08): payment maps the paid price to a tier id and sets it in billing with `PUT /billing/{org}/tier`. If your tier is in the JWT, the claim updates on the user's next token; if you read billing, within `cache_ttl_seconds`. Tell customers "within a few minutes", not "instantly", unless you force a re-login after checkout.

**4. Move one customer by hand** (support, a sales deal, a fix). Preferred path, with a key that holds `billing.write.tier` (or `billing.admin`) and the cross-customer capability:
```
PUT https://billing.service.ab0t.com/billing/<customer org id>/tier     X-API-Key: <billing key>
{ "tier_id": "pro", "reason": "enterprise pilot, ticket 1234" }
GET https://billing.service.ab0t.com/billing/<customer org id>/tier/history
```
`GET …/tier/history` needs `billing.admin`; without it, keep your own record of the moves you make (rule 14 in SOP 18). Billing accepts any `tier_id` and logs `quota_tier_set_outside_known_set` when it does not recognise it; your `quota-config.json` is the policy. Setting the same tier twice is a no-op. An org cannot set its own tier (`is_not_self_funding`): the call must come from your service identity, not the customer's.

**5. Per-user caps inside an org.** `per_user_limit` on a limit object, or tier-level `default_per_user_fraction` (`ceil(limit × fraction)`, floored at 1). Denials then say `per_user_exceeded`. Always pass both ids from `Identity`.

**6. Trials.** Set `trial_period_days` on the payment plan (SOP 07); the subscription starts `trialing` and the tier sync treats it like `active`. There is no separate trial tier mechanism in the quota config.

## What you'll see

`X-Quota-Tier: pro` on every allowed request; `429` bodies name the tier; `GET /billing/{org}/tier` returns `{tier_id, …}`; `/tier/limits` returns the limits billing knows (which may be a subset of yours).

## If it goes wrong

- `X-Quota-Tier: free` for a paying customer: the claim is stale (re-login), the cache is warm (≤ `cache_ttl_seconds`), or payment never mapped the price (SOP 08 step 2). Check `GET /billing/{org}/tier` first; it tells you which side is wrong.
- `429 reason: tier_not_in_config`: billing or the JWT says a tier (`"starter"`) that your `tiers[]` does not list. Add it or fix the map. Shadow mode does not soften this.
- `mesh provider: no Lookup wired (call SetLookup at startup)`: you chose `mesh` and set no `default_tier`; wire a lookup or switch to `jwt`.
- `PUT /tier` → `403`: your key lacks `billing.write.tier` or the cross-customer capability, or you called it as the customer's own org.
- Downgrade did not reset credit: the old tier's `reset_on_downgrade` is `false` (Go default), or the new tier's `sort_order` is not strictly lower, or billing's `subscription_credit_source_tier` differs from the old tier (`409 Reset rejected: source tier mismatch`, kept on purpose).

## Coming

- **`tier_provider.type: "mesh"` working from config alone.** *Today:* supply the billing lookup in code or use `jwt`.
- **Tier inheritance from a parent org to its workspaces.** *Today:* tiers are per org; workspace-per-user products set each workspace's tier.
- **Price → tier mapping in your hands** (plan metadata / `billing_integration.stripe_price_to_tier`). *Today:* payment's `QUOTA_PLAN_TIER_MAP` via the platform team.
- **`quotactl tier set <org> <tier> --reason`** instead of a raw `PUT`. *Today:* step 4.
- **Richer trials** (card-less trials with auto-convert). *Today:* `trial_period_days` on the plan.

## Next

SOP 10, credits, grants and auth events.
