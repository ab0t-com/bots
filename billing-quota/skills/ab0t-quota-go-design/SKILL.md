---
name: ab0t-quota-go-design
description: >-
  The order of decisions for adding plans, limits and charging to a service on the ab0t mesh, from
  "I want to charge for my API" to an enforced tier with a Stripe checkout: what to meter, the tier
  ladder, reset periods, per-org vs per-user, billing model, shadow first, then keys, config, wiring,
  shadow day, enforce. Use when a team asks "where do I start", "what do I decide first", "how do
  quota, billing and payment fit together", or wants a worked example from intent to live. Routes to
  the billing-quota SOPs (02 is the worked day) and the ab0t-quota-go-* skills.
---

# Designing plans, limits and charging

## What this is

Most of the work is six decisions on paper; the code is about 150 lines once they are made. This
guide puts the decisions in order and hands each one to the SOP that does it.

## The picture

```
decide on paper                                  then build, in order
1 do you need quota at all?                      7 keys: authsetup connect billing|payment   SOP 03
2 what costs you money → resources + types       8 quota-config.json                         SOP 04
3 the tier ladder and limits                     9 Setup + guard + Spend (+ granter)         SOP 05, 10
4 reset periods; per org or per user             10 shadow day + acceptance list              SOP 06
5 billing model per tier; sign-up gift           11 enforce; plans, checkout, portal          SOP 06, 07
6 fail-closed on spend, shadow first             later: tier sync, credits, money, changes   SOP 08–16
```

| layer | answers | runs |
|---|---|---|
| quota | "is this request within the plan?" | in your service (the library) |
| billing | "how much does this customer org have and owe?" | the billing service |
| payment | "charge the card; which plan are they on?" | the payment service (owns Stripe) |

## Do this (the decisions)

1. **Need quota?** "May this person do this at all?" is permissions (Ally), not quota. Quota is
   "how much".
2. **Meter cost drivers, not "requests".** Biggest line on your bill first. For each: a **gauge**
   for "how many right now" (seats), an **accumulator** with `reset_period` for "how much this
   period" (invoices a month), a **rate** with `window_seconds` for abuse. Never meter one as
   another; they fail in opposite directions.
3. **Ladder.** Usually `free`, a low paid tier, a high paid tier, `enterprise`. Gate quantity, not
   features. `sort_order` must rise with rank (it decides what a downgrade is).
4. **Scope.** B2B: count per org and dedup grants `per_org_per_tier`. B2C: `per_user_per_tier`
   stops sign-up farming. Per-user caps inside an org with `per_user_limit`.
5. **Money shape.** `subscription_unlock_only` (fee buys limits), `subscription_with_credits` (fee
   plus a monthly allowance), `consumption_only` (pay as you go). A small `signup` grant on free.
6. **Safety.** Fail-closed (`FailOpen: false`) on anything that costs money; ship with
   `shadow_mode: true`; keep `global_kill_switch` for a runaway-cost emergency.

Then build steps 7–11 in order; SOP 02 walks all of it for Acme's `invoicer` in one day.

## What your customers notice

A free plan that is useful, a clear `429` with an upgrade link when they outgrow it, a Stripe
checkout that works first time, their allowance refilling each month, and nobody blocked on day one
because you watched a shadow day first.

## Common mistakes

| mistake | what happens | instead |
|---|---|---|
| writing JSON before deciding 1–6 | config churn and resets later | decide on paper |
| keys last | the first write `403`s; checkout cannot start | step 7 first; the write tier needs the provider's approval (SOP 03 step 5) |
| `tier_provider.type: "mesh"` | no tier from billing unless you write a lookup in code | `jwt` (or `static` in tests) |
| enforcing on day one | real customers blocked by a wrong limit | a shadow day and the acceptance list |
| renaming a tier or resource later | everyone's counters restart; grants become eligible again | pick names you will keep (SOP 14) |

## Check it worked

The SOP 06 acceptance list is the definition of done. Questions about pricing a specific product:
`platform-team@ab0t.com`.

SOPs: [01 the money model](../../01_sop_system_money_model_for_clients.md) ·
[02 day zero](../../02_sop_system_day_zero_acme_meters_invoicer.md) ·
[04 tiers and resources](../../04_sop_system_describe_tiers_and_resources.md) ·
[06 shadow then enforce](../../06_sop_system_shadow_run_then_enforce.md).
