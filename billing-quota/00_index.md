# Meter, limit and charge on the ab0t mesh, for the people using it

**Who this is for.** A team whose service already runs on the mesh (Ally's SOPs got you signed in and verifying tokens) and now wants to meter what customers use, stop them at a tier's limit, and charge them. Three pieces do that: **billing** (the ledger), **payment** (Stripe, plans, checkout, portal) and the **quota library** inside your service (`ab0t-quota-go` for Go, `ab0t-quota` for Python). The running example is **Acme**'s **`invoicer`**.

**How to use it.** Read 01 and 02 once. Then 03 → 06 in order for your first enforced tier, 07 → 08 to take money, and the rest as jobs come up. Each SOP has the same shape: what it is for, what to have ready, numbered steps with exact commands, what you will see, what to do when it goes wrong, what is **Coming** (approved or planned but not built, with today's workaround), and where to go next.

**Three things to know before any command.** `authsetup` defaults to **prod** (write `--env`). The self-serve billing and payment tiers are **read-only**; recording usage and starting checkouts need a tier upgrade the provider grants (SOP 03). Never run a "test charge" on prod; shadow mode and dev are the test path. Where a step needs a person at ab0t (a tier upgrade, a price map), that is the **platform team**, the support desk at `platform-team@ab0t.com`.

**Penny.** The agent in this folder (`agent.md`) follows these SOPs for you: plain words first, preview and your yes before anything changes, never prints a key, hands anything `authsetup` to Ally's SOPs.

## The journey

| # | SOP | one line |
|---|---|---|
| 01 | [The money model](01_sop_system_money_model_for_clients.md) | Billing is the ledger, payment is the money, quota is the decision; the customer's org is who pays. |
| 02 | [Day zero: Acme meters invoicer](02_sop_system_day_zero_acme_meters_invoicer.md) | The whole first day, in order, with the two waits named. |
| 03 | [Get your keys](03_sop_system_get_your_keys.md) | `authsetup connect billing|payment --as invoicer`; what the read-only tier allows; how to ask for writes; the `AB0T_QUOTA_*` env names. |
| 04 | [Describe tiers and resources](04_sop_system_describe_tiers_and_resources.md) | `quota-config.json`: resources (rate/accumulator/gauge), tiers, limits, billing models, credit grants, tier provider, storage, enforcement. |
| 05 | [Wire the library](05_sop_system_wire_the_library.md) | `quota.Setup`, `q.Middleware`, `q.Spend`; the Python one-liner; the headers and the 429 body; the README (stale on v0.1.9, current from v0.1.10). |
| 06 | [Shadow run, then enforce](06_sop_system_shadow_run_then_enforce.md) | A shadow day, the nine-item acceptance list, the rollback drill, the three emergency levers. |
| 07 | [Plans, prices, checkout, portal](07_sop_system_plans_prices_checkout_portal.md) | Create plans in dollars, the public plans list, subscription and top-up checkout, the portal, your proxy routes. |
| 08 | [Subscriptions, webhooks, tier sync](08_sop_system_subscriptions_webhooks_tier_sync.md) | Stripe → payment → billing tier; the price→tier map; reading subscription state; downgrades and credit resets. |
| 09 | [Tiers and upgrades](09_sop_system_tiers_and_upgrades.md) | Tier sources (jwt/static/mesh), the ladder, moving one customer by hand, per-user caps, trials. |
| 10 | [Credits, grants, auth events](10_sop_system_credits_grants_auth_events.md) | Sign-up gifts via signed auth events, the built-in `BillingCreditGranter` (v0.1.10) or your own, `quotactl subscribe-events|replay|backfill`, secret rotation, subscription refills, manual grants. |
| 11 | [Metering money with billing](11_sop_system_metering_money_with_billing.md) | Record usage, validate-access, reserve/commit/refund/settle, the ledger reads, the library's paid mode. |
| 12 | [Multi-tenant correctness](12_sop_system_multi_tenant_correctness.md) | `org_id` from the token, the cross-customer capability, what stays with the customer, counting at the right level. |
| 13 | [Observability, alerts, reconciliation](13_sop_system_observability_alerts_reconciliation.md) | Alerts, capabilities in `/healthz`, drift and `ReconcileOrg`, `doctor`, the kill switch. |
| 14 | [Changing things safely](14_sop_system_changing_things_safely.md) | Raise/lower limits, add/remove/rename resources, change prices, keyspace migration, paid mode. |
| 15 | [Keys and offboarding](15_sop_system_keys_and_offboarding.md) | Rotate billing/payment keys without downtime, a leaked key, leaving a provider, a customer leaving you, forget-me. |
| 16 | [Migrations and upgrades](16_sop_system_migrations_and_upgrades.md) | Library bumps (read the changelog), Python ↔ Go, billing/payment API changes, keyspace v2. |
| 17 | [Troubleshooting](17_sop_system_troubleshooting.md) | Every message from the library, `quotactl`, billing and payment, with meaning and fix; the chains to walk. |
| 18 | [Security and money rules](18_sop_system_security_and_money_rules.md) | Fourteen rules; what is enforced for you today. |

## Also in this folder

- `agent.md`, Penny; `skills/penny-billing-quota/SKILL.md`, the skill that points Penny at these SOPs; `README.md`, installing both.
- `GAPS.md`, every **Coming** item in one table: the spec list for the quota library, billing and payment client experience.
- For everything `authsetup` (install, environments, keys, rotation, its errors): Ally, next door in [`../authmesh/`](../authmesh/00_index.md).
