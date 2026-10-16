---
name: payment-service-api-reference
description: >-
  Call the ab0t payment service's REST API from your backend (payment.service.ab0t.com): create
  products, plans and prices (dollars, lower-case enums), list the public plans for a pricing page,
  start a subscription checkout or a top-up checkout (Stripe), open the customer portal, verify a
  checkout session, read, change, pause or cancel subscriptions, forward Stripe webhooks, and which
  permission each call needs. Use when writing payment calls, building checkout / upgrade / "manage
  billing" buttons, handling payment 400 / 403 / 404 / 409 / 422 / 503, or "the response has url,
  not checkout_url". Verified against payment source 2026-10-16; the live OpenAPI is the contract.
  For balances and usage use billing-service-api-reference.
---

# Payment API (for your backend)

## What this is

Payment owns Stripe for you: plans and prices, the hosted checkout page, the customer portal and
subscriptions. Your backend calls it with your payment key on behalf of a customer org; customers
only ever see Stripe's pages, and card details never touch your servers.

## The picture

```
pricing page ─► your backend ─► GET  /checkout/<your org>/plans?include_prices=true        (public)
"Upgrade"    ─► your backend ─► POST /checkout/<customer org>/plan/<plan_id>  → {url} ─► Stripe Checkout
"Top up"     ─► your backend ─► POST /checkout/<customer org>/session (mode=payment, dollars) → {url}
"Billing"    ─► your backend ─► POST /portal/<customer org>/session → {url} ─► Stripe portal
Stripe ──► payment /webhooks/stripe ──► billing: tier + credit           (nothing for you to code)
live contract: curl -s https://payment.service.ab0t.com/openapi.json | jq -r '.paths | keys[]'
```

| call | route | permission (your key) |
|---|---|---|
| create product / plan / price (your org) | `POST /plans/{org}/products` · `POST /plans/{org}` · `POST /plans/{org}/{plan_id}/prices` | `payment.create.products` · `payment.create.plans` · `payment.create.plans` |
| public plans for a pricing page | `GET /checkout/{org}/plans?include_prices=true` | none |
| subscription checkout | `POST /checkout/{org}/plan/{plan_id}` | none beyond the cross-customer tier for a customer org |
| top-up checkout | `POST /checkout/{org}/session` | `payment.write` |
| customer portal | `POST /portal/{org}/session` | `payment.read` |
| verify a session | `GET /checkout/sessions/{session_id}/verify` | `process_if_complete=true` needs `payment.write` |
| subscriptions | `GET /subscriptions/{org}` · `PUT|DELETE /subscriptions/{org}/{id}` · `POST …/pause` · `…/resume` | read · `payment.write` |
| Stripe webhooks | `POST /webhooks/stripe` | Stripe's signature only |

Acting on a **customer's** org needs the provider's cross-customer tier (SOP 03 step 5).

## Do this (the default path)

Plans, once, in **dollars** and with **lower-case** enums (full bodies in SOP 07 step 1):
```
POST /plans/<your org>        {"product_id":"…","name":"Pro","visibility":"public","trial_period_days":14,"metadata":{"tier_id":"pro"}}
POST /plans/<your org>/<plan_id>/prices   {"plan_id":"<plan_id>","currency":"usd","amount":29.00,"type":"recurring","interval":"month"}
```
Checkout for a customer, from your backend, with the org from their validated token:
```
POST /checkout/<customer org>/plan/<plan_id>
{"success_url":"https://app.example/billing/success?session_id={CHECKOUT_SESSION_ID}",
 "cancel_url":"https://app.example/pricing","customer_email":"<the customer's email>"}
→ {"id":"cs_…","url":"https://checkout.stripe.com/…","expires_at":…,"status":…,"verification_token":…}
```
Redirect the browser to `url`. The portal answers `{"url","id"}`. Then follow the subscription
(SOP 08): `GET /subscriptions/<org>?status=active` until `active` or `trialing`.

## What your customers notice

Stripe's checkout and portal pages, your success page, and their plan changing within a few
minutes of paying (SOP 08). A checkout started twice within a minute returns the same session.
When payment is down they should see "try again" from you (`503 Checkout temporarily unavailable;
please retry.` upstream), never a half-finished upgrade.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| upper-case enums (`PUBLIC`, `RECURRING`, `MONTH`) | `422` naming the field | lower case |
| `features` as plain strings | `422` | objects (`feature_key`, `type`, `value`, `display_name`), or leave it out |
| cents instead of dollars | `400 {"error":"Amount seems too high", "hint":"This API expects dollars (99.99), not cents (9999)"}` · `400 {"error":"Amount exceeds maximum allowed","amount_interpreted":"$2,900.00"}` | dollars |
| reading `checkout_url` / `portal_url` | `undefined` | the key is `url` |
| no `customer_email` on a gateway checkout | the receipt goes to your service account | pass it |
| customer org without the cross-customer tier | `403 "Organization access denied"` / `"Access denied to organization data"` | SOP 03 step 5 |
| top-up on the read-only tier | `403 … One of permissions required: payment.write, …` | same |
| portal before any checkout | `400 Cannot create portal session: no Stripe customer found for this organization` | checkout first |
| setting `org_id` / `plan_id` / `type` in metadata | silently dropped | payment sets those itself |

## Check it worked

`GET /checkout/<your org>/plans` lists your plan with a `display_text` like `$29.00/month`; a
checkout returns a `url` that opens Stripe; after a test-card payment `GET /subscriptions/<org>`
shows `trialing` or `active`. Test with `4242 4242 4242 4242` on dev and staging, and confirm with
support that live payments are enabled for your account before launch. Still stuck: send the
request (no key), status and body to `platform-team@ab0t.com`. Every payment message:
[SOP 17](../../17_sop_system_troubleshooting.md).

SOPs: [07 plans, checkout, portal](../../07_sop_system_plans_prices_checkout_portal.md) ·
[08 subscriptions and tier sync](../../08_sop_system_subscriptions_webhooks_tier_sync.md) ·
[12 multi-tenant correctness](../../12_sop_system_multi_tenant_correctness.md).
