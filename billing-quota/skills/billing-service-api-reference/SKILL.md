---
name: billing-service-api-reference
description: >-
  Call the ab0t billing service's REST API directly from your backend (billing.service.ab0t.com):
  read a customer org's balance, check before an expensive call (validate-access, 402), record usage
  (request_id required), reserve / commit / refund / settle with idempotency keys, give promotional
  credit, read and set a tier, read transactions and usage, and which permission each call needs.
  Use when writing billing calls in any language, handling 402 / 403 / 404 / 409 / 422 / 429 from
  billing, or reading the three-bucket balance. Verified against billing source 2026-10-16; the live
  OpenAPI is the contract. For payment (Stripe, plans, checkout) use payment-service-api-reference.
---

# Billing API (for your backend)

## What this is

Billing is the ledger: every one of your customers (an org) has an account with a balance, credits
and reservations, created the first time anything touches it. Your backend calls it with your own
billing key, always naming the **customer's** org in the path; the browser never calls it.

## The picture

```
your backend ── X-API-Key: <your billing key> ──► https://billing.service.ab0t.com/billing/<customer org id>/…
     org id: from the customer's validated token, never from the request
     money:  decimal strings ("2.50"), dollars
     writes: always with an idempotency key; retry with the SAME key
live contract: curl -s https://billing.service.ab0t.com/openapi.json | jq -r '.paths | keys[]'
```

| call | route | permission (your key) | idempotency |
|---|---|---|---|
| balance (3 buckets) | `GET /billing/{org}/balance` | `billing.read.accounts` | — |
| can they afford it? | `POST /billing/{org}/validate-access` | `billing.read.accounts` | — |
| record known-cost usage | `POST /billing/usage/{org}/` | `billing.write.usage` | `request_id` (required) |
| reserve before a long job | `POST /billing/{org}/reserve` | `billing.write.reservations` | `request_id` |
| commit the reservation | `POST /billing/{org}/commit` | `billing.write.transactions` | `reservation_id` |
| cancel it | `POST /billing/{org}/refund` | `billing.write.refunds` | `reservation_id` |
| settle after it expired | `POST /billing/{org}/settle` | `billing.write.transactions` | `settlement_key` = the reservation id |
| promotional / sign-up credit | `POST /billing/{org}/promotional-credit` | `billing.write.transactions` | `idempotency_key` (required) |
| credit grant into a declared bucket and lifecycle (no lifetime cap) | `POST /billing/{org}/apply-credit-grant` | `billing.write.transactions` | `idempotency_key` (required) |
| tier | `GET /billing/{org}/tier` · `GET …/tier/limits` | `billing.read` | — |
| move a customer's tier | `PUT /billing/{org}/tier` `{tier_id, reason}` | `billing.write.tier` | same tier twice is a no-op |
| history, ledger | `GET /billing/{org}/transactions` · `…/reservations` · `GET /billing/usage/{org}/summary` · `…/records` | `billing.read.transactions` / `.reservations` / `.usage` | — |

Acting on a **customer's** org also needs the provider's cross-customer tier (SOP 03 step 5).
`billing.admin` covers everything but is not needed by a gateway; `GET …/tier/history` and the
override routes are admin-only. `/health` is public.

## Do this (the default path)

```sh
B=https://billing.service.ab0t.com; ORG=<customer org id>; KEY=<your billing key>
curl -sS -H "X-API-Key: $KEY" "$B/billing/$ORG/balance"
curl -sS -X POST -H "X-API-Key: $KEY" -H 'Content-Type: application/json' "$B/billing/usage/$ORG/" \
  -d '{"org_id":"'"$ORG"'","user_id":"<user>","tool_id":"invoicer.pdf_render","request_id":"invoicer:pdf_render:<id>","cost":"0.0200","platform_fee":"0"}'
```
- Balance: `{balance, credit_balance, subscription_credit, reserved_balance, available_balance,
  currency, source}`; `available_balance = balance + credit_balance + subscription_credit −
  reserved_balance` is the only "can spend" number.
- Usage answers `200 {"status":"accepted", "usage_id", …}` at once and is processed asynchronously;
  a replay within 24 h returns the original. Billing uses your `cost` only when `platform_fee` is
  sent too; leave either out and billing prices the row itself (fallback rates, minimum charge), so a
  free row says `"cost":"0","platform_fee":"0"`.
- Reserve → work → commit: send the **inputs** on commit (`started_at`, `stopped_at`,
  `hourly_rate`, `allocation_fee`); a cost-only commit (`actual_usage.cost`) still works but is
  deprecated. Unused reservation is refunded on commit; reservations expire after 24 h.
- A body `org_id`, where present, must equal the path (`400 Request body org_id does not match URL path`).

Full worked flows: SOP 11 (usage, reservations, settle), SOP 10 (credit), SOP 09 (tiers).

## What your customers notice

Their balance and usage in your app, on their org only. When they cannot afford something,
`validate-access` and `reserve` answer `402` with `required_topup`: show that amount and a top-up
button (SOP 07). When billing is unreachable, answer your own `503` and retry; never let the work
through for free, and never show billing's error body to the customer.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| read-only key on a write | `403 {"error":"PERMISSION_DENIED","message":"One of permissions required: billing.write.usage, …"}` | ask for the write (SOP 03 step 5) |
| customer org without the cross-customer tier | `403 … "Access denied - different organization"` | same |
| crediting your own org | `403 … "an organization cannot issue value to itself"` | call as your service for a customer org |
| no `request_id` on usage | `400 request_id is required for usage idempotency` | add one |
| a new key on retry | double charge, or `409 Prior request did not complete; retry with same request_id` | retry with the same key |
| expecting `200 {allowed:false}` from validate-access | `402` with `{"reason":"insufficient_balance","required_topup":…}` | treat `402` as "not enough" |
| commit after expiry | `404 Reservation not found or expired` | `settle` with the reservation id |
| amounts as floats | rounding drift | decimal strings |

## Check it worked

`GET /billing/<org>/balance` with your key → `200`; without the header → `401`. After a usage call,
`GET /billing/usage/<org>/records?limit=5` shows the row. Still stuck: send the request (no key),
status, response body and the time to `platform-team@ab0t.com`. Every billing message, with its fix:
[SOP 17](../../17_sop_system_troubleshooting.md).

SOPs: [03 keys](../../03_sop_system_get_your_keys.md) ·
[09 tiers](../../09_sop_system_tiers_and_upgrades.md) ·
[10 credits](../../10_sop_system_credits_grants_auth_events.md) ·
[11 metering money](../../11_sop_system_metering_money_with_billing.md) ·
[12 multi-tenant correctness](../../12_sop_system_multi_tenant_correctness.md).
