---
name: penny-billing-quota
description: >-
  Client-side SOPs for metering, tier limits and charging on the ab0t mesh: the quota library
  (ab0t-quota-go / ab0t-quota, quota-config.json, quotactl), the billing service (usage, balance,
  reserve/commit/settle, tiers, credits) and the payment service (plans, prices, Stripe checkout,
  portal, subscriptions, webhooks). Use when helping a team whose service already runs on the
  mesh to: get billing/payment keys and understand the read-only self-serve tier, write
  quota-config.json (resources rate/accumulator/gauge, tiers, limits, billing_model, credit_grant,
  tier_provider, storage, enforcement), wire the Go middleware or Python setup_quota, run shadow
  mode then enforce, create plans in dollars and start checkout/portal sessions, trace how a
  payment becomes a tier, grant sign-up credit via signed auth events, record usage or reserve
  and commit with billing, keep tenants isolated, set alerts and reconcile counters, change limits
  safely, rotate keys, upgrade the library, or debug 403/402/409/429/503 messages. Triggers:
  "quota-config.json", "ab0t-quota", "quotactl", "meter my service", "free and pro tier",
  "connect to billing/payment", "checkout", "portal", "paid but still on free", "record usage",
  "reserve and commit", "credit grant", "shadow mode", "429 quota exceeded", "billing 403".
---

# penny-billing-quota

Nineteen short SOPs (00–18), one per job, for the people using the mesh to meter and charge. This file
only routes; the SOPs are the references. Load the one for the job, follow it in order, and
respect its **Coming** markers (approved or planned, not built; each has a *Today:* workaround).

## Non-negotiables (restated from the SOPs)
- `authsetup` defaults to **prod**; write `--env` on every authsetup command. Anything `authsetup`
  itself (install, env, connect/disconnect mechanics, its errors) is **Ally's** domain:
  [`../../../authmesh/`](../../../authmesh/00_index.md) SOPs `03_…`, `11_…`, `14_…`, `16_…`.
- Preview before any change (`authsetup --dry-run`, a shown diff, a read-back of the request) →
  explicit yes → apply. `quotactl capabilities|doctor` connect to Redis and may create declared
  DynamoDB tables: ask first.
- Never print or read credential files; point at `~/.authmesh/<svc>/<provider>-consumer.<env>.json`
  and `.api_key.key`. Never delete `~/.authmesh/<svc>/`.
- Never test money on prod: shadow mode + dev/staging + Stripe test cards. Shadow before enforce.
- Dollars, decimal strings, an idempotency key on every money write; retry with the same key.
- `org_id` from the validated token only; never forward a user's bearer upstream.
- Say **org**, never "realm". The cross-customer capability is "the provider's platform-scope
  tier"; never recommend the legacy `cross_*` names even though server `403`s still print them.
- The quota-go `README.md` describes an older API; the SOPs and `examples/basic/main.go` are the
  source. Mount the auth-event receiver with `http.StripPrefix` (SOP 05). Unsure of a flag:
  `quotactl <cmd> --help`.
- Never `redis-cli SET` a counter; reconcile. Billing and payment are reached only through their
  APIs; anything wrong there goes to support with the SOP 17 bundle.

## The SOPs (relative to this file)
| job | file |
|---|---|
| map of everything | [../../00_index.md](../../00_index.md) |
| the money model, client view | [../../01_sop_system_money_model_for_clients.md](../../01_sop_system_money_model_for_clients.md) |
| day zero, end to end | [../../02_sop_system_day_zero_acme_meters_invoicer.md](../../02_sop_system_day_zero_acme_meters_invoicer.md) |
| get your billing/payment keys | [../../03_sop_system_get_your_keys.md](../../03_sop_system_get_your_keys.md) |
| describe tiers and resources (`quota-config.json`) | [../../04_sop_system_describe_tiers_and_resources.md](../../04_sop_system_describe_tiers_and_resources.md) |
| wire the library (Go + Python) | [../../05_sop_system_wire_the_library.md](../../05_sop_system_wire_the_library.md) |
| shadow run, then enforce | [../../06_sop_system_shadow_run_then_enforce.md](../../06_sop_system_shadow_run_then_enforce.md) |
| plans, prices, checkout, portal | [../../07_sop_system_plans_prices_checkout_portal.md](../../07_sop_system_plans_prices_checkout_portal.md) |
| subscriptions, webhooks, tier sync | [../../08_sop_system_subscriptions_webhooks_tier_sync.md](../../08_sop_system_subscriptions_webhooks_tier_sync.md) |
| tiers and upgrades | [../../09_sop_system_tiers_and_upgrades.md](../../09_sop_system_tiers_and_upgrades.md) |
| credits, grants, auth events | [../../10_sop_system_credits_grants_auth_events.md](../../10_sop_system_credits_grants_auth_events.md) |
| metering money with billing | [../../11_sop_system_metering_money_with_billing.md](../../11_sop_system_metering_money_with_billing.md) |
| multi-tenant correctness | [../../12_sop_system_multi_tenant_correctness.md](../../12_sop_system_multi_tenant_correctness.md) |
| observability, alerts, reconciliation | [../../13_sop_system_observability_alerts_reconciliation.md](../../13_sop_system_observability_alerts_reconciliation.md) |
| changing things safely | [../../14_sop_system_changing_things_safely.md](../../14_sop_system_changing_things_safely.md) |
| keys and offboarding | [../../15_sop_system_keys_and_offboarding.md](../../15_sop_system_keys_and_offboarding.md) |
| migrations and upgrades | [../../16_sop_system_migrations_and_upgrades.md](../../16_sop_system_migrations_and_upgrades.md) |
| troubleshooting | [../../17_sop_system_troubleshooting.md](../../17_sop_system_troubleshooting.md) |
| security and money rules | [../../18_sop_system_security_and_money_rules.md](../../18_sop_system_security_and_money_rules.md) |
| every Coming item in one table | [../../GAPS.md](../../GAPS.md) |

## Companions (shipped in this folder; load by name when an SOP points there)
Each is a short guide verified against `ab0t-quota-go` v0.1.9 / `ab0t-quota` v0.6.7 that links back
to the SOPs; the SOPs win if they ever disagree.
- Library: `ab0t-quota` (start here), `ab0t-quota-billing-101` (the words), `ab0t-quota-go-design`
  (decision order), `ab0t-quota-go-setup`, `ab0t-quota-go-config`, `ab0t-quota-go-middleware`,
  `ab0t-quota-go-auth-events`, `ab0t-quota-go-cli`, `ab0t-quota-go-testing` (a test file that runs green).
- Services: `billing-service-api-reference`, `payment-service-api-reference`,
  `billing-payment-integration` (proxy routes + a Python client template).
- Keys and tenancy (also shipped with Ally): `billing-payment-consumer-setup`, `mesh-tenancy-authority`.
- Jobs: `quota-multi-tenant`, `quota-paid-tier-onboarding`, `quota-tier-management`, `quota-troubleshooting`.
- Everything `authsetup`: Ally's `ally-mesh-client` (install the authmesh bot).
