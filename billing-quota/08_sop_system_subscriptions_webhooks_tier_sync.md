# 08 · Subscriptions, webhooks, and how a payment becomes a tier

**What this is for.** What happens after the customer pays: Stripe tells payment, payment credits billing and sets the customer's tier, your quota library picks up the new limits. Also how you read subscription state, and what you must (and must not) build for webhooks.

**Before you start.** SOP 07 working on a test checkout. Your plan ids. The platform team's contact (one coordination step below is theirs today).

## The chain (nothing here is yours to code)
```
Stripe ──Stripe-Signature──▶ payment POST /webhooks/stripe
   customer.subscription.created/updated/deleted ─▶ payment resolves price → tier ─▶ billing PUT /billing/{org}/tier
   invoice.paid / invoice.payment_succeeded       ─▶ payment applies the plan's credit grant into billing (subscription_credit)
   checkout.session.completed (mode=payment)      ─▶ payment credits billing balance (top-up)
   subscription deleted / unpaid / expired        ─▶ tier set to "free"
your quota library ─▶ reads the tier (JWT claim, or billing GET /billing/{org}/tier) ─▶ new limits
```

## Steps

**1. Register the webhook with Stripe, once.** Two accepted shapes; pick one:
- **Direct**: point Stripe at `https://payment.service.ab0t.com/webhooks/stripe` (the platform team holds the signing secret). Simplest; nothing runs in your service.
- **Through your service**: expose `POST /api/webhooks/stripe`, read the raw body and the `Stripe-Signature` header, forward both unchanged to payment's `/webhooks/stripe`, return payment's status. You then see every event pass by (useful for your own logging) but you must not parse or act on it.
Events to subscribe: `checkout.session.completed`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.paid`, `invoice.payment_failed` (plus `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`, `charge.dispute.*`). Stripe expects a `2xx` within 20 s; payment de-duplicates on `event.id` (`"Webhook already processed"`) and retries pending rows.

**2. Make sure your plan maps to a tier.** Payment maps a Stripe price to a tier id using a map on **payment's side** (`QUOTA_PLAN_TIER_MAP`, JSON price-id → tier-id; the built-in default only knows `price_starter_*`/`price_pro_*`/`price_enterprise_*`). Give the platform team your real `price_id`s and the `tier_id`s from your `quota-config.json`. An unmapped price leaves the tier **unchanged**, logs an error, and files a reconciliation item; the customer paid and sees no upgrade. See *Coming*.

**3. Read subscription state when you need it.**
```
GET https://payment.service.ab0t.com/subscriptions/<customer org id>?status=active&include_plan_details=true
→ { "subscriptions": [{ "subscription_id", "plan_id", "price_id", "status", "current_period_end",
                        "cancel_at_period_end", "trial_end", "next_billing_date" }], "total", "has_more" }
```
Statuses: `active`, `trialing`, `paused`, `past_due`, `canceled`, `incomplete`, `incomplete_expired`, `unpaid`. `active` with `cancel_at_period_end: true` is a normal customer who will leave at renewal. Payment sends **no** outbound webhooks to you; poll, or read the tier from billing.

**4. Read the tier your library will use.**
```
GET https://billing.service.ab0t.com/billing/<customer org id>/tier          X-API-Key: <billing key>
GET https://billing.service.ab0t.com/billing/<customer org id>/tier/limits
```
If your tier provider is `jwt`, the claim must be refreshed on the user's next token; with `cache_ttl_seconds: 300` the library may serve the old tier for up to five minutes.

**5. Let customers cancel or change plan in the portal** (SOP 07 step 5). If you must do it server-side: `DELETE /subscriptions/<org>/<subscription_id>` (default `at_period_end=true`; returns `Subscription will be canceled at the end of the current billing period`), `PUT /subscriptions/<org>/<subscription_id>` with a new `price_id`, pause/resume endpoints. All need `payment.write`.

**6. Downgrades and credit.** When a `subscription_with_credits` tier is left and the old tier has `reset_on_downgrade: true`, billing's subscription credit for that tier is reset (`POST /billing/{org}/reset-subscription-credit` with `expected_source_tier`); a mismatch is refused on purpose (`409 Reset rejected: source tier mismatch`) so an enterprise org with several subscriptions keeps its credit. `sort_order` decides what counts as a downgrade: the new tier must be strictly lower.

## What you'll see

Within seconds of a test checkout: `GET /subscriptions/<org>` shows `trialing` or `active`; `GET /billing/<org>/tier` shows the mapped tier; `GET /billing/<org>/balance` shows `subscription_credit` equal to the grant with `subscription_credit_source` = the invoice id and `subscription_credit_source_tier` = the tier. Cancellation sets the tier to `free`.

## If it goes wrong

Walk the chain in order:
1. Stripe shows the event delivered with a `2xx`? If not, the URL or the secret on payment's side.
2. Payment logs the tier sync? A `tier_resolution_unresolved` reconciliation item means step 2 above (unmapped price).
3. `GET /billing/<org>/tier` changed? If not, payment could not reach billing (`tier_sync_failed`); it is non-fatal and reconciled later; ask the platform team.
4. Your service still on the old tier? JWT claim not refreshed, or the provider cache (≤ `cache_ttl_seconds`). Have the user log in again.
5. `subscription_credit` still 0 after `invoice.paid`? The subscription was created outside the checkout endpoint without `metadata.org_id`, or the tier is not `subscription_with_credits` with trigger `subscription_invoice_paid`.
- `GET /subscriptions/<org>` → `403 "Access denied to organization data"`: your key lacks the cross-customer capability for that org.

## Coming

- **Tier mapping owned by you** (plan metadata or your `quota-config.json`'s `billing_integration.stripe_price_to_tier`) instead of a map on payment's side. *Today:* step 2 with the platform team.
- **Cancellation policy in your config** (which tier a cancelled customer lands on). *Today:* hard-coded `free`.
- **Outbound webhooks from payment to your service** (subscription changed, payment failed) with retries. Endpoint-registration routes exist but deliver nothing yet. *Today:* poll, or read the tier from billing.
- **`GET /billing/{org}/tier` on the self-serve tier.** *Today:* `billing.read` is in the default tier, but reading a *customer's* org still needs the cross-customer capability.

## Next

SOP 09, tiers and upgrades in your config; SOP 10, credits and sign-up grants.
