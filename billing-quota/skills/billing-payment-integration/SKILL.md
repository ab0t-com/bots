---
name: billing-payment-integration
description: >-
  Add pricing, checkout, top-ups, the customer portal and a balance view to a service on the ab0t
  mesh without writing Stripe code: four proxy routes in your backend that call payment and billing
  with your keys, the buttons in your frontend, the success page, and optional Stripe webhook
  forwarding. Use when a team wants an "Upgrade" button, a pricing page, "manage billing", "top up",
  "show my balance", or a FastAPI/Express/Go backend calling payment and billing on behalf of its
  users. Ships a small Python client template; the full procedure is billing-quota SOPs 07 and 08.
---

# Pricing, checkout and the portal in your app

## What this is

Your frontend never talks to billing or payment. It calls four small routes in your own backend,
which take the customer's org from their validated token and call payment or billing with your
service's key. Payment hosts the checkout and portal pages on Stripe, so there is no card form and
no card data on your side.

## The picture

```
browser                       your backend (validates the user's token; org_id from it)          mesh
/pricing ─────────────► GET  /api/payments/plans          ─► GET  /checkout/<YOUR org>/plans      payment
"Upgrade" ────────────► POST /api/payments/checkout/{plan}─► POST /checkout/<customer org>/plan/… payment → Stripe
"Top up" ─────────────► POST /api/payments/topup          ─► POST /checkout/<customer org>/session payment → Stripe
"Manage billing" ─────► POST /api/payments/portal         ─► POST /portal/<customer org>/session  payment → Stripe
"Balance" ────────────► GET  /api/billing/balance         ─► GET  /billing/<customer org>/balance  billing
Stripe ─(webhook)─► payment directly (simplest), or your /api/webhooks/stripe forwarding it unchanged
```

## Do this (the default path)

1. Keys: `authsetup --env dev connect payment --as <service>` and `… billing …`, then ask the
   provider for the cross-customer tier (and `payment.write` if you sell top-ups) (SOP 03).
2. Plans and prices in your org, in dollars, lower-case enums (SOP 07 step 1).
3. The four routes. A FastAPI shape using the client template in
   [`references/payment-client-template.py`](references/payment-client-template.py):
   ```python
   payment = PaymentServiceClient()          # PAYMENT_SERVICE_URL, PAYMENT_SERVICE_API_KEY

   @app.get("/api/payments/plans")
   async def plans():
       return await payment.get_plans(MY_ORG_ID)                 # your org owns the plans

   @app.post("/api/payments/checkout/{plan_id}")
   async def checkout(plan_id: str, request: Request, user=Depends(current_user)):
       base = str(request.base_url).rstrip("/")
       s = await payment.create_checkout_session(user.org_id, plan_id, user.email,
               f"{base}/billing/success?session_id={{CHECKOUT_SESSION_ID}}", f"{base}/pricing")
       return {"url": s["url"]}

   @app.post("/api/payments/portal")
   async def portal(request: Request, user=Depends(current_user)):
       p = await payment.create_portal_session(user.org_id, str(request.base_url).rstrip("/") + "/billing")
       return {"url": p["url"]}
   ```
   `current_user` is your auth dependency (Ally SOP 06); `user.org_id` comes from the validated
   token, never from the request. Map `PaymentServiceError` to your own messages (below).
4. Frontend: `fetch` the route, then `window.location.href = data.url`. The success page polls
   `GET /subscriptions/<org>` (through your backend) until `active` or `trialing` (SOP 08).
5. Webhooks: point Stripe at payment's `/webhooks/stripe` (simplest), or forward the raw body and
   `Stripe-Signature` unchanged with `forward_stripe_webhook` (SOP 08 step 1).

## What your customers notice

Your pricing page, Stripe's hosted checkout and portal, then their new plan within a few minutes.
Your routes should answer them in your own words: "Please try again" for upstream `503`/timeouts,
"Something went wrong on our side" for `401`/`403` from payment (a key problem for you to fix, not
them), and a clear message for `400`s you can explain (for example "add a payment method first" when
the portal has no Stripe customer yet).

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| org id from a query parameter or body | one customer can pay for, or read, another's account | take it from the validated token only (SOP 12) |
| the payment key in the browser | a leaked key | keep both keys server-side |
| `checkout_url` / `portal_url` in the frontend | `undefined` | the key is `url` |
| prices sent in cents | `400 Amount seems too high` | dollars |
| crediting the balance on the redirect | balance up without a payment | trust the subscription/balance, not the redirect (SOP 07 step 6) |
| your own Stripe webhook handler acting on events | double tier changes or credits | forward unchanged or let Stripe call payment |
| upstream error bodies returned to the browser | customers see org ids and permission names | log them; return your own message |

## Check it worked

On dev with a Stripe test card (`4242 4242 4242 4242`): pricing lists your plan; "Upgrade" lands on
Stripe; after paying, `GET /billing/<org>/tier` shows the mapped tier and the portal opens. Confirm
with support that live payments are enabled for your account before launch. Still stuck: send the
failing route's upstream status and body from your logs (no keys) to `platform-team@ab0t.com`.

SOPs: [07 plans, checkout, portal](../../07_sop_system_plans_prices_checkout_portal.md) ·
[08 subscriptions, webhooks, tier sync](../../08_sop_system_subscriptions_webhooks_tier_sync.md) ·
[12 multi-tenant correctness](../../12_sop_system_multi_tenant_correctness.md). API detail:
`payment-service-api-reference`, `billing-service-api-reference`.
