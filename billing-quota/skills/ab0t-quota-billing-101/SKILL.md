---
name: ab0t-quota-billing-101
description: >-
  Explain billing and quota ideas from zero, in plain words, for a team metering and charging on the
  ab0t mesh. Use when someone asks "what is a tier?", "credit_balance vs subscription_credit?",
  "why three balances?", "how does Stripe fit in?", "what is a webhook for?", "what does idempotent
  mean here?", "subscription vs consumption vs hybrid?", "gauge vs accumulator vs rate?",
  "Check vs Spend vs Release?", "what is fail-open?", "what is shadow mode?". Answers the one concept
  asked, then points at the SOP that uses it.
---

# Billing and quota, from zero

## What this is

The handful of ideas behind metering and charging on the mesh, one at a time. Answer only the
concept the person asked about, then point at the SOP where they will use it.

## The picture

```
what the customer is allowed (quota)      what the customer has paid (billing)       how they pay (payment)
tier → limits → counters in your Redis    org balance: 3 buckets, reservations       plans, checkout, portal (Stripe)
          └──────────── the tier is set in billing when a subscription changes ◄──────────────┘
```

## The ideas

**What does the customer pay for?** *Subscription* (a monthly fee for access), *consumption* (pay
per use) or *hybrid* (a fee that includes a monthly allowance, usage beyond it charged). In
`quota-config.json` that is a tier's `billing_model`: `subscription_unlock_only`,
`consumption_only`, `subscription_with_credits` (the hybrid), plus `free_tier` and `enterprise`
(`metered_billing` and `one_time_purchase` exist but are experimental). SOP 04.

**Tier.** The plan a customer org is on (`free`, `pro`, …). It picks the limits. Billing stores it;
payment sets it when a subscription changes; your library reads it from a JWT claim, a static map or
billing. SOPs 08, 09.

**The three balances.** Billing keeps each org's money in three buckets plus what is reserved:

| bucket | comes from | spent |
|---|---|---|
| `subscription_credit` | the allowance a paid invoice brings each period | first |
| `credit_balance` | sign-up gifts, promotions, goodwill | second |
| `balance` | top-ups the customer paid for | last |

`available_balance = balance + credit_balance + subscription_credit − reserved_balance` is the only
"can spend" number. Example: $10 allowance and $20 of top-up, spend $5 → allowance $5, top-up $20.
SOP 11.

**Credit grant.** Money given automatically: at sign-up, when a subscription invoice is paid, or by
hand. Its `lifecycle` is `use_it_or_lose_it` (resets each period), `rollover_capped` (keeps up to N
periods) or `persistent` (never expires); its `dedup` stops anyone collecting it twice. SOP 10.

**Three kinds of counter.** A **gauge** goes up and down (seats in use: `Spend` when taken,
`Release` when freed). An **accumulator** adds up within a calendar period and resets (`monthly`
invoices). A **rate** counts within a sliding window (requests per minute, against abuse). Use an
accumulator for a monthly allowance, not a rate. SOP 04.

**Check, Spend, Release.** The guard *checks* (would this be allowed?) and moves nothing; you
*spend* after the work really happened; you *release* a gauge when the thing ends. SOP 05.

**Shadow mode.** The library decides as if enforcing but lets everything through and logs
`shadow_would_deny`, so you see who would be blocked before anyone is. SOP 06.

**Fail-open vs fail-closed.** What happens when the quota engine itself cannot decide (Redis down).
Fail-closed (`503`) on anything that costs money; fail-open on release and cleanup. SOP 12.

**Webhook and idempotency.** A webhook is one service telling another "this happened". Deliveries
repeat, so every handler that moves money must give the same result when run twice: the library's
`authevents.Idempotent` and billing's idempotency keys do that. SOPs 10, 11.

## Do this

Pick the SOP that uses the idea: tiers and resources SOP 04, wiring SOP 05, shadow SOP 06, plans
SOP 07, credits SOP 10, money SOP 11. The SOP list: [`../../00_index.md`](../../00_index.md).

## What your customers notice

Limits as `429` with an upgrade link; prepaid money running out as a `402` with the top-up amount;
their allowance refilling when the invoice is paid; their own balance only, never another
customer's.

## Common mistakes

| mistake | what you see | fix |
|---|---|---|
| a monthly allowance metered as a `rate` | customers blocked for "the next hour" after a burst | use an `accumulator` with `reset_period: "monthly"` |
| spending before the work | counters higher than reality | spend after the work, release on every exit path |
| expecting subscription credit to roll over | allowance resets each period | that is `use_it_or_lose_it`; choose `rollover_capped` if you want carry-over |

## Check it worked

`GET /billing/<org>/balance` shows the three buckets separately; `X-Quota-Tier` on a response shows
the tier the library used. Questions: `platform-team@ab0t.com`.
