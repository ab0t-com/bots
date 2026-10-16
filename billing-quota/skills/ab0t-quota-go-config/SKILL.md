---
name: ab0t-quota-go-config
description: >-
  Write the quota-config.json that ab0t-quota-go (and the Python ab0t-quota) reads at start-up:
  resources (counter_type rate / accumulator / gauge), tiers and limits, billing_model, price,
  credit_grant (trigger, lifecycle, destination, dedup), tier_provider (jwt / static / mesh),
  storage (redis_url, required), enforcement (enabled, shadow_mode, global_kill_switch), alerts,
  ${QUOTA_*} interpolation. Use when defining free / pro / enterprise tiers, debugging "tier not in
  config", "credit_grant required", "QUOTA-CFG-001", or a config the library refuses. Verified
  against v0.1.9; the step-by-step is billing-quota SOP 04.
---

# quota-config.json

## What this is

The one file that says what you count, the limit per plan, where a customer's plan comes from,
where counters live and whether you are enforcing yet. The library validates it at start-up and
refuses to run with a named error, so a typo in a cross-field rule never reaches a customer.

## The picture

```
resources[]  what you count      rate (window_seconds) · accumulator (reset_period) · gauge (up/down)
tiers[]      each plan           limits per resource · billing_model · price · credit_grant · upgrade_url
tier_provider where the plan is  jwt claim · static user→tier map · mesh (billing; needs code)
storage      where counters live redis_url (required) — "memory://" for one dev process
enforcement  are we blocking?    enabled · shadow_mode · global_kill_switch
```

## Do this (the smallest config that starts)

```json
{
  "service_name": "invoicer",
  "resources": [
    { "service": "invoicer", "resource_key": "invoicer.invoices", "counter_type": "accumulator", "reset_period": "monthly" }
  ],
  "tiers": [
    { "tier_id": "free", "display_name": "Free", "sort_order": 1, "limits": { "invoicer.invoices": 20 } }
  ],
  "tier_provider": { "type": "jwt", "jwt_claim_key": "tier", "default_tier": "free" },
  "storage": { "redis_url": "${QUOTA_REDIS_URL:-memory://}" },
  "enforcement": { "enabled": true, "shadow_mode": true }
}
```
This boots on v0.1.9 as written (with `memory://` for one dev process; set `QUOTA_REDIS_URL` for
anything else). The full Acme config, with three tiers, a priced Pro tier and its monthly credit, is
SOP 04.

Rules the library enforces (and what it does not):
- `tiers[]` is required; `tier_id` and `resource_key` must be unique; a `resource_bundles` entry must
  name known resources.
- `rate` needs `window_seconds`; `accumulator` needs `reset_period` (`hourly`, `daily`, `weekly`,
  `monthly`); `counter_type` must be one of the three.
- A limit is a number, `null` (unlimited) or `{limit, warning_threshold, critical_threshold,
  burst_allowance, per_user_limit}`; a tier-level `default_per_user_fraction` derives per-user caps.
- `billing_model`: `subscription_with_credits` needs a `price` and a `credit_grant` with
  `trigger: "subscription_invoice_paid"`; `subscription_unlock_only` forbids a `credit_grant`;
  `consumption_only` forbids a `price`; `metered_billing` and `one_time_purchase` need
  `AB0T_QUOTA_ALLOW_EXPERIMENTAL_BILLING_MODELS=true`. Other values are not checked: spell them
  exactly (`free_tier`, `enterprise`).
- `credit_grant`: `trigger` (`signup`, `subscription_invoice_paid`, `scheduled_period_start`,
  `manual`, `webhook_admin`), `amount_per_period` > 0, `currency` (default `USD`), `lifecycle`
  (`use_it_or_lose_it` default, `rollover_capped` + `rollover_max_periods`, `persistent`),
  `destination` (`subscription_credit` default, `credit_balance`), `dedup` (`per_user_per_tier`
  default, `per_org_per_tier`, `per_user_global`, `per_org_global`), `reset_on_downgrade` /
  `reset_on_upgrade` (default `false`; write them).
- Legacy `initial_credit: "10.00"` on a tier becomes a `signup` grant with `lifecycle: persistent`
  and `destination: credit_balance`. Write `credit_grant` instead; never both.
- `storage.redis_key_prefix` must be `"quota"` or absent.
- Only `${QUOTA_*}` names are expanded (`${QUOTA_REDIS_URL:-default}`); other `${…}` get the default.
- Unknown top-level keys are kept and ignored; keys starting with `$` are dropped. A misplaced key
  (`shadow_mode` outside `enforcement`) silently does nothing: keep the nesting.
- Naming DynamoDB anywhere (`storage.dynamodb_table`, `outbox.store: "ddb"`, `outbox.ddb_table`)
  makes start-up create the library's tables in your AWS account; leave it out until paid mode.

## What your customers notice

`upgrade_url` and `display_name` are what they see in a `429`. `warning_threshold` /
`critical_threshold` decide when your app gets `X-Quota-Warning` to show "you are close". A limit of
`0` means "not on this plan"; `null` means unlimited.

## Common mistakes (and what you will see)

| mistake | what you see |
|---|---|
| `enforcement.enabled` left out | nothing is ever denied: `X-Quota-Reason: enforcement_disabled` |
| a paid tier without its grant | `tier "pro": billing_model "subscription_with_credits" requires credit_grant with trigger "subscription_invoice_paid"` |
| rate without a window | `resource "…": window_seconds required for rate counters` |
| accumulator without a period | `resource "…": reset_period required for accumulator counters` |
| `rollover_capped` alone | `tier "…": credit_grant.rollover_max_periods required when lifecycle is "rollover_capped"` |
| a tier the JWT names but the file lacks | requests denied with `reason: tier_not_in_config` (even in shadow) |
| `tier_provider.type: "mesh"` with no lookup | `mesh provider: no Lookup wired (call SetLookup at startup)` |

## Check it worked

```sh
quotactl capabilities --config ./quota-config.json   # loads it exactly as Setup does; connects to Redis
```
There is no offline validator yet; this (or starting the service) is the check. Still stuck: send the
error line and the file (no secrets) to `platform-team@ab0t.com`.

SOPs: [04 describe tiers and resources](../../04_sop_system_describe_tiers_and_resources.md) ·
[09 tiers and upgrades](../../09_sop_system_tiers_and_upgrades.md) ·
[10 credits](../../10_sop_system_credits_grants_auth_events.md) ·
[14 changing things safely](../../14_sop_system_changing_things_safely.md).
