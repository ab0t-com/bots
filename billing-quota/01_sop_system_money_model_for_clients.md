# 01 · The money model, in plain words

You run a product on the ab0t mesh and want to meter what your customers use, stop them at a limit, and charge them. Four things do that, and you only write code against two of them.

**Billing is the ledger.** Every one of your customers (an org) has a billing account there: a cash balance, promotional credit, subscription credit, and whatever is currently reserved. You *record usage* against it, or *reserve* funds before an expensive job and *commit* afterwards. The account appears the first time anyone touches it; you never create one by hand. Billing never calls Stripe and never talks to your customer.

**Payment is the money.** Plans, prices, checkout pages, the customer portal, subscriptions, invoices, refunds. It owns the Stripe relationship: one Stripe customer per org, card details never touch you. When a customer pays, payment credits their billing account and tells billing which **tier** they are on.

**Quota is the decision at request time.** A small library (`ab0t-quota-go` for Go, `ab0t-quota` for Python) inside your service reads one file, `quota-config.json`, that says: these are my tiers (free, pro, enterprise), these are the things I count (requests per minute, invoices per month, seats in use), and these are the limits per tier. On each request it answers allow or deny, adds `X-Quota-*` headers, and, when you tell it, spends against the counter. It keeps counters in Redis and pushes paid usage to billing through a durable outbox.

**Auth is the glue.** Your service's keys for billing and payment come from `authsetup connect` (Ally's job). Sign-ups and org creation arrive at your service as signed auth events, which the quota library uses to grant sign-up credit.

## Who is charged

Always the **customer's org**, never yours. Your service acts as a *gateway*: one key, many customers. That is why a metering key needs the provider's cross-customer capability (in the approved scope model, a `scope: "platform"` tier that the provider approves for you). Without it every call for a customer org answers `403`. It is not an over-grant; it is the job description of a gateway.

## Three words you will meet

- **Tier** — the plan a customer is on. Billing stores it; payment sets it when a subscription changes; your quota library reads it (from a JWT claim, from the mesh, or from a static map) and picks the limits.
- **Resource** — a thing you count. Three kinds: a **rate** (requests per window), an **accumulator** (invoices this month, resets on a schedule), a **gauge** (seats in use, goes up and down).
- **Credit grant** — money or allowance given automatically: on sign-up, when a subscription invoice is paid, on a schedule, or by hand. It has a lifecycle (use-it-or-lose-it, rollover, persistent) and a dedup rule so nobody farms it.

## What happens on one request

```
customer → your API → quota.Check (allow? headers) → your handler does the work
        → quota.Spend (counter moves) → outbox → billing records usage → ledger
```
Deny is a `429` with a JSON body naming the resource, the tier, used/limit and an upgrade link. Shadow mode lets you watch what *would* be denied before you enforce anything. A kill switch denies everything, on purpose, in an emergency.

## What happens when a customer pays

```
customer → your pricing page → payment checkout (Stripe) → Stripe webhook → payment
        → credits the org's billing balance + sets the org's tier in billing
        → your quota library sees the new tier on its next lookup
```
You never see a card number. You do see the subscription status if you ask payment, and the balance if you ask billing.

## In one sentence

Describe your tiers and resources in one file, get two scoped keys from Ally, add the middleware, run in shadow mode until the numbers look right, then enforce; payment and billing do the money.

**Next:** SOP 02, day zero for Acme's `invoicer`.
