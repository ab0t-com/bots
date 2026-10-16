# 04 · Describe your tiers and resources (`quota-config.json`)

**What this is for.** The one file the quota library reads at start-up: what you count, how, the limits per tier, where the tier comes from, where counters live, and whether you are enforcing yet. Both the Go and the Python library read the same file.

**Before you start.** SOP 01 read. A list of the two or three things you actually want to limit. Your tier names. Whether a customer's tier is in their JWT, in the mesh (billing), or fixed.

## Steps

**1. Start from the example** in the Go library repository, `examples/basic/quota-config.json`. Put yours at `./quota-config.json` (the library also looks at `/etc/ab0t/quota-config.json`, or wherever `QUOTA_CONFIG_PATH` points).

**2. Name your service and your resources.** Acme's `invoicer`:
```json
{
  "$schema": "https://ab0t.com/quota-config.schema.json",
  "service_name": "invoicer",
  "engine_mode": "local",
  "resources": [
    { "service": "invoicer", "resource_key": "invoicer.api.requests", "display_name": "API requests",
      "counter_type": "rate", "window_seconds": 60, "unit": "requests" },
    { "service": "invoicer", "resource_key": "invoicer.invoices", "display_name": "Invoices created",
      "counter_type": "accumulator", "reset_period": "monthly", "unit": "invoices" },
    { "service": "invoicer", "resource_key": "invoicer.seats", "display_name": "Active seats",
      "counter_type": "gauge", "unit": "seats" }
  ],
```
Three counter types: **rate** needs `window_seconds`; **accumulator** needs `reset_period` (`hourly`, `daily`, `weekly`, `monthly`); **gauge** goes up on acquire and down on release. `resource_bundles` lets one name cover several keys (`"invoice_create": ["invoicer.api.requests", "invoicer.invoices"]`).

**3. Name your tiers and limits.**
```json
  "tiers": [
    { "tier_id": "free", "display_name": "Free", "sort_order": 1, "billing_model": "free_tier",
      "limits": { "invoicer.api.requests": 60, "invoicer.invoices": 20, "invoicer.seats": 1 },
      "upgrade_url": "https://invoicer.acme.example/upgrade" },
    { "tier_id": "pro", "display_name": "Pro", "sort_order": 2, "billing_model": "subscription_with_credits",
      "price": { "amount_per_period": "29.00", "currency": "USD", "period": "month" },
      "credit_grant": { "trigger": "subscription_invoice_paid", "amount_per_period": "10.00", "currency": "USD",
                        "lifecycle": "use_it_or_lose_it", "destination": "subscription_credit",
                        "reset_on_downgrade": true, "reset_on_upgrade": false, "dedup": "per_org_per_tier" },
      "limits": { "invoicer.api.requests": { "limit": 600, "warning_threshold": 0.8, "critical_threshold": 0.95, "burst_allowance": 60 },
                  "invoicer.invoices": 500, "invoicer.seats": 10 } },
    { "tier_id": "enterprise", "display_name": "Enterprise", "sort_order": 3, "billing_model": "enterprise",
      "limits": { "invoicer.api.requests": null, "invoicer.invoices": null, "invoicer.seats": null } }
  ],
```
- A limit is a number, `null` (unlimited), or an object with `limit`, `warning_threshold` (0.80), `critical_threshold` (0.95), `burst_allowance`, `per_user_limit`.
- `billing_model` values: `consumption_only`, `subscription_unlock_only`, `subscription_with_credits`, `free_tier`, `enterprise`. (`metered_billing` and `one_time_purchase` are experimental and refused unless `AB0T_QUOTA_ALLOW_EXPERIMENTAL_BILLING_MODELS=true`.) `subscription_with_credits` requires a `price` and a `credit_grant` whose trigger is `subscription_invoice_paid`; `consumption_only` forbids a price; `subscription_unlock_only` forbids a credit grant.
- `credit_grant`: `trigger` (`signup`, `subscription_invoice_paid`, `scheduled_period_start`, `manual`, `webhook_admin`), `amount_per_period` (> 0), `lifecycle` (`use_it_or_lose_it` default, `rollover_capped` + `rollover_max_periods`, `persistent`), `destination` (`subscription_credit` default, `credit_balance`), `dedup` (`per_user_per_tier` default, `per_org_per_tier`, `per_user_global`, `per_org_global`). Write `reset_on_downgrade` and `reset_on_upgrade` explicitly; they default to `false`. For a sign-up gift on the free tier, `"credit_grant": {"trigger": "signup", "amount_per_period": "5.00", "destination": "credit_balance", "lifecycle": "persistent", "dedup": "per_user_per_tier", "reset_on_downgrade": false, "reset_on_upgrade": false}` (SOP 10).

**4. Say where the tier comes from.**
```json
  "tier_provider": { "type": "jwt", "jwt_claim_key": "tier", "default_tier": "free", "cache_ttl_seconds": 300 },
```
`jwt` reads a claim from the bearer token (no signature check; your auth middleware already validated it). `static` maps **user ids** to tiers (`"mapping": {"usr_…": "pro"}`), good for tests. `mesh` asks billing; see *Coming*. `cache_ttl_seconds` keeps the last known good tier if a lookup fails.

**5. Say where counters live, and whether you enforce.**
```json
  "storage": { "redis_url": "${QUOTA_REDIS_URL:-redis://localhost:6399/0}", "connect_retry_seconds": 30 },
  "enforcement": { "enabled": true, "shadow_mode": true, "global_kill_switch": false },
  "alerts": { "enabled": true, "webhook_url": "https://ops.acme.example/hooks/quota", "cooldown_seconds": 3600 },
  "billing": { "enable_paid": false },
  "outbox": { "allow_ephemeral": true }
}
```
- `storage.redis_url` is **required**; the library refuses to start without it. `"memory://"` is allowed in Go for a single process in development (Python refuses it). Only `${QUOTA_*}` names are expanded inside the file.
- `enforcement.enabled` has **no default**: leave it out and nothing is ever denied (`reason: enforcement_disabled`). Start with `shadow_mode: true` (SOP 06).
- `billing.enable_paid` and the `outbox` are for when usage must reach billing (SOP 11). Until then `allow_ephemeral: true` lets the service start with billing off even if `AB0T_QUOTA_BILLING_URL` is set. This day-one config declares no DynamoDB: anything that names it (`storage.dynamodb_table`, `outbox.store: "ddb"`, `outbox.ddb_table`) makes the library create its tables in your AWS account at start-up, so add it only when you turn on paid mode (SOP 11 step 6).

**6. Check it.** There is no offline validator command (see *Coming*). The library validates at start-up and refuses with a named error; the fastest check is the CLI's smoke run, which **does connect** to the declared Redis (and would create DynamoDB tables if you declared them):
```sh
quotactl capabilities --config ./quota-config.json
```
Read the capabilities report: `enforcement`, `billing`, `payment`, `credit_grant`, `auth_events_signed`, each with a `WhyOff` reason.

## What you'll see

Validation errors, in the library's words, as `quota.Setup: validate config: …` or `quota.Setup: load config: …`:
- `config: no config file found (set QUOTA_CONFIG_PATH or place quota-config.json in CWD)`
- `config: tiers[] is required` · `config: duplicate tier_id "pro"` · `config: duplicate resource_key "…"`
- `resource "invoicer.api.requests": window_seconds required for rate counters` · `resource "…": reset_period required for accumulator counters` · `resource "…": unknown counter_type "meter"`
- `tier "pro": billing_model "subscription_with_credits" requires price` · `tier "pro": billing_model "subscription_with_credits" requires credit_grant with trigger "subscription_invoice_paid"` · `tier "free": billing_model "consumption_only" forbids price`
- `tier "pro": credit_grant.amount_per_period must be > 0` · `credit_grant.rollover_max_periods required when lifecycle is "rollover_capped"`
- `quota.Setup: tier provider: tier_provider.type required (jwt | mesh | static)` · `quota.Setup: tier provider: tier_provider.type unknown: "billing"`
- `ab0t-quota-go config error [QUOTA-CFG-001] — Redis counter store URL is not declared.` (set `storage.redis_url` or `QUOTA_REDIS_URL`)
- `config: engine_mode "bridge" is out of scope for v0.1.0` (bridge is Python-only; the message still names v0.1.0 in v0.1.9)
- `config: keyspace v2 keys carry a service segment — declare service_name before storage.keyspace_version=2 or keyspace_dual_write`

## If it goes wrong

- A `billing_model` typo passes silently (values are not enumerated); only the cross-field rules fire. Spell them from the list above.
- `reset_period` and `dedup` values are also not enumerated; a typo is used verbatim. Copy them exactly.
- Unknown nested keys are ignored, so a misplaced `"shadow_mode"` outside `enforcement` does nothing. Keep the nesting shown.
- `storage.redis_key_prefix` must be `"quota"` or absent; anything else is refused at start-up (it would fork the keyspace from the Python runtime).

## Coming

- **An offline `quotactl validate`** (no Redis, no DynamoDB) that prints the errors above. *Today:* `capabilities`, which connects, or start the service.
- **Enumerated `billing_model`, `reset_period`, `dedup`, `trigger` values** refused on typo. *Today:* silent.
- **`tier_provider.type: "mesh"` working out of the box.** *Today* the library does not wire its lookup; you must supply one in code (SOP 09) or use `jwt`/`static`.
- **`enforcement.enabled` defaulting to true, or refusing to start when absent.** *Today:* absent means allow everything.
- **A published JSON schema at the `$schema` URL and a `quota-config.example.json` in the Go repo.** *Today:* the Python repo's `quota-config-schema.json` and `quota-config.example.json`.

## Next

SOP 05, wire the library.
