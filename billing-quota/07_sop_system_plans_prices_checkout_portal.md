# 07 · Plans, prices, checkout and the customer portal

**What this is for.** Letting a customer pay you: a pricing page fed by payment, an "Upgrade" button that opens a Stripe Checkout page, a "Top up" button for prepaid credit, and a "Manage billing" button that opens Stripe's customer portal. You write no Stripe code and never see a card.

**Before you start.** SOP 03 done, with the provider's cross-customer tier on your payment key (every step that names a *customer's* org needs it), and `payment.write` for top-ups and server-side subscription changes (plan checkout and the portal work with the read permissions). The self-serve tier has neither; see SOP 03 step 5. `PAYMENT_SERVICE_URL`/key in your backend env. Decide your plan names and monthly prices in **dollars**.

## Steps

**1. Create your plans and prices once** (your own org id, as plan owner):
```
POST https://payment.service.ab0t.com/plans/<your org id>/products     X-API-Key: <payment key>
{ "name": "Invoicer", "description": "Invoicing for teams", "sync_to_stripe": true }
POST https://payment.service.ab0t.com/plans/<your org id>
{ "product_id": "<from above>", "name": "Pro", "visibility": "public", "trial_period_days": 14,
  "features": [
    { "feature_key": "invoices", "type": "limit", "value": 500, "display_name": "500 invoices / month", "unit": "invoices" },
    { "feature_key": "seats", "type": "limit", "value": 10, "display_name": "10 seats", "unit": "seats" } ],
  "metadata": {"tier_id": "pro"}, "sync_to_stripe": true }
POST https://payment.service.ab0t.com/plans/<your org id>/<plan_id>/prices
{ "plan_id": "<plan_id>", "currency": "usd", "amount": 29.00, "type": "recurring", "interval": "month", "sync_to_stripe": true }
```
These need `payment.create.products` / `payment.create.plans`; if you do not hold them, the platform team creates the plans for you. Enum values are **lowercase**: `visibility` is `public`, `private` or `hidden`; price `type` is `recurring` or `one_time`; `interval` is `day`, `week`, `month` or `year` (anything else is a `422`). `features` is a list of objects (`feature_key`, `type` = `boolean` | `numeric` | `limit`, `value`, `display_name`, optional `unit`), not plain strings; leave it out if you do not need it. **Amounts are dollars**: `29.00`, never `2900` (anything over `10000` is refused with `Amount seems too high`, hint `This API expects dollars (99.99), not cents (9999)`). Put your quota `tier_id` in the plan's metadata; SOP 09 explains how a plan becomes a tier.

**2. Show the pricing page.** Public, no auth:
```
GET https://payment.service.ab0t.com/checkout/<your org id>/plans?include_prices=true
→ { "org_id", "count", "currency": "usd",
    "plans": [{ "plan_id", "name", "description", "features", "metadata", "trial_period_days",
                "prices": [{ "price_id", "amount": 29.0, "currency": "usd", "type": "recurring", "interval": "month", "display_text": "$29.00/month" }],
                "default_price": { … } }] }
```
Only `public` plans with at least one active price are listed, ordered by `metadata.display_order` if you set it. Your frontend renders cards; free gets "Start free", enterprise "Contact sales", the rest "Upgrade".

**3. Start a subscription checkout for a customer.** From **your backend**, with the customer's `org_id` taken from their validated token:
```
POST https://payment.service.ab0t.com/checkout/<customer org id>/plan/<plan_id>     X-API-Key: <payment key>
{ "success_url": "https://invoicer.acme.example/billing/success?session_id={CHECKOUT_SESSION_ID}",
  "cancel_url":  "https://invoicer.acme.example/pricing?cancelled=true",
  "customer_email": "<the customer's email>" }
→ { "id": "cs_…", "url": "https://checkout.stripe.com/…", "expires_at", "status", "verification_token" }
```
Redirect the browser to `url`. Always pass `customer_email`: without it the checkout is created under your service account's own email address. Payment keeps one Stripe customer per org, applies the plan's trial, and stamps `org_id` and `plan_id` into the subscription's metadata so the webhooks can find the org later. The same org/plan/email within one minute returns the same session (`409 Checkout for this plan was already completed for this email within the past minute.`).

**4. Top-up (prepaid credit) checkout.**
```
POST https://payment.service.ab0t.com/checkout/<customer org id>/session
{ "amount": 50.00, "currency": "usd", "description": "Invoicer credit", "mode": "payment",
  "success_url": "https://invoicer.acme.example/billing?topup=success", "cancel_url": "https://invoicer.acme.example/billing?topup=cancelled",
  "metadata": { "purpose": "topup" } }
```
Dollars, `≤ 10000`, Stripe only. `mode: "payment"` is what makes it a top-up; on completion payment credits the customer's billing balance. Metadata is yours except these reserved keys, which payment sets itself and silently drops from your request: `org_id`, `user_id`, `payment_id`, `plan_id`, `price_id`, `type`, `verification_token_hash`, `idempotency_key`, `session_token_hash`, `fingerprint`.

**5. The portal (cards, invoices, cancel, change plan).**
```
POST https://payment.service.ab0t.com/portal/<customer org id>/session     { "return_url": "https://invoicer.acme.example/billing" }
→ { "url": "https://billing.stripe.com/…", "id" }
```
Redirect there. This is how customers manage cards: a gateway **cannot** add or change a customer's payment method on their behalf (`Cross-organization payment method operations are not supported`).

**6. The success page.** Do not trust the redirect. Verify: `GET /checkout/sessions/<session_id>/verify` (add `?process_if_complete=true` only with `payment.write`), or poll the subscription (SOP 08) until it is `active`/`trialing`. Never increment a balance optimistically.

**7. Your proxy routes.** The browser never holds your payment key. Typical shape:
```
GET  /api/payments/plans            → step 2 (public)
POST /api/payments/checkout/{plan}  → step 3 with org_id from the caller's token
POST /api/payments/topup            → step 4
POST /api/payments/portal           → step 5
```

## What you'll see

Checkout URLs are real Stripe pages. Test with Stripe's test card `4242 4242 4242 4242` on dev and staging, and confirm with support (`platform-team@ab0t.com`) that live payments are enabled for your account before you announce a launch date. A mock mode returns `https://checkout.stripe.com/mock/…` and `https://billing.stripe.com/p/mock_portal_…` on dev stacks without Stripe.

## If it goes wrong

- `403 {"error":"PERMISSION_DENIED","message":"One of permissions required: payment.write, payment.admin, …"}` — your key is on the read-only tier (SOP 03 step 5).
- `403 "Organization access denied"` (plan checkout) / `"Access denied to organization data"` — your key cannot act for that customer org; the cross-customer capability is missing.
- `400 "Customer email is required for checkout"` — the call reached payment without your key (anonymous) and without `customer_email`; send the `X-API-Key` header and `customer_email`.
- `422` naming `visibility`, `type` or `interval` — an enum in upper case (`PUBLIC`, `RECURRING`, `MONTH`); write them in lower case.
- `400 {"error":"Amount exceeds maximum allowed", "amount_interpreted": "$2,900.00", …}` — you sent cents.
- `404 "Plan <id> not found for organization <org>"` — the plan belongs to another org or is archived; `400 "No pricing available for plan …"` — add a price.
- `400 "Cannot create portal session: no Stripe customer found for this organization"` — the customer never checked out; portal needs a Stripe customer first.
- `404 "Organization not found"` — the path org id is not a UUID.
- `503 "Checkout temporarily unavailable; please retry."` — Stripe or payment is down; retry with backoff.
- Error bodies come in two shapes: the auth layer's `{"error","message","details"}` and payment's own `{"detail": …}`. Handle both.

## Coming

- **A self-serve tier with `payment.write`** so a new service can start checkouts without a manual upgrade (scope model). *Today:* SOP 03 step 5.
- **Gateway-managed payment methods** for a customer org (bound to that org's Stripe customer). *Today:* refused; use the portal.
- **A response key that agrees across docs** (`url` in the API; some guides say `checkout_url`/`portal_url`). *Today:* the API returns `url`.
- **URL allow-listing for `success_url`/`cancel_url`/`return_url`.** *Today:* passed to Stripe as given; validate them yourself.

## Next

SOP 08, subscriptions, webhooks and how a payment becomes a tier.
