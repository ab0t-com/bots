# 11 · Metering money with billing

**What this is for.** Charging a customer's billing account for what they use: a known-cost call (record usage), an unknown-cost job (reserve, do the work, commit), and the paths the quota library takes for you when paid mode is on.

**Before you start.** SOP 03 with the write permissions granted (`billing.write.usage`; for reservations `billing.write.reservations`, `billing.write.transactions`, `billing.write.refunds`) and the cross-customer capability. The customer's `org_id`, always from their validated token.

## The shapes

| you know the cost? | do | idempotency |
|---|---|---|
| yes, at the time of the call | `POST /billing/usage/{org}/` | `request_id` in the body (required) |
| no, and the job is short | `POST /billing/{org}/validate-access` then do it, then `POST /billing/usage/{org}/` | `request_id` |
| no, and the job is long or expensive | `POST /billing/{org}/reserve` → work → `POST /billing/{org}/commit`; on cancel `POST /billing/{org}/refund` | `request_id` on reserve; `reservation_id` on commit |
| the job finished after the reservation expired | `POST /billing/{org}/settle` with `settlement_key` = the reservation id | durable, replay-safe |

All paths carry the customer's org in the URL; a body `org_id`, where present, must equal it (`400 Request body org_id does not match URL path`).

## Steps

**1. Record a known-cost usage.**
```
POST https://billing.service.ab0t.com/billing/usage/<customer org id>/        X-API-Key: <billing key>
{ "org_id": "<customer org id>", "user_id": "<user>", "tool_id": "invoicer.pdf_render", "session_id": "<session>",
  "request_id": "invoicer:pdf_render:<correlation id>", "cost": "0.0200", "metadata": {"invoice_id": "inv_…"} }
→ 200 { "status": "accepted", "message": "Usage will be processed asynchronously", "org_id", "timestamp", "usage_id" }
```
`request_id` is required (`400 request_id is required for usage idempotency`); a replay within 24 h returns the original body. Omit `cost` and billing prices it from its own model (`input_tokens`, `output_tokens`, `compute_time`, `resource_type`). `cost` is a decimal string, non-negative, at most `1,000,000`. The `/sync` variant answers `"status": "processed"` and is for tests. By default a prepaid balance may go **negative** on usage (billing alerts rather than refusing); set your own `validate-access` gate if you want to refuse.

**2. Check before an expensive call.**
```
POST /billing/<org>/validate-access     { "org_id": "<org>", "user_id": "<user>", "estimated_cost": "2.50", "tool_id": "invoicer.bulk_export" }
→ 200 { "allowed": true, "current_balance", "estimated_impact", "daily_usage", "monthly_usage", … }
→ 402 detail {"reason": "insufficient_balance", "current_balance": "1.10", "estimated_cost": "2.50", "required_topup": "1.40"}
```
Show `required_topup` and the top-up button (SOP 07). A `200` here is advisory; a race can still make `reserve` fail.

**3. Reserve, work, commit.**
```
POST /billing/<org>/reserve   { "org_id", "user_id", "tool_id": "invoicer.bulk_export", "session_id", "estimated_cost": "2.50",
                                "request_id": "invoicer:bulk_export:<job id>" }
→ 200 { "reservation_id": "res_…", "reserved_amount", "expires_at", "available_balance", "session_id" }
→ 402 { "error": "insufficient_balance", "message": "Insufficient balance for reservation", "available_balance", "requested_amount", "required_topup" }

POST /billing/<org>/commit    { "reservation_id": "res_…", "started_at": "…", "stopped_at": "…", "hourly_rate": "1.20", "allocation_fee": "0.10" }
→ 200 { "status", "reservation_id", "reserved_amount", "actual_cost", "refunded_amount", "message" }

POST /billing/<org>/refund    { "reservation_id": "res_…", "reason": "operation_cancelled", "partial_usage": { … } }
```
**Send the inputs, not a cost** on commit: when `started_at`/`stopped_at`/`hourly_rate` are present, billing prices them and ignores any `actual_usage.cost`; a commit that sends only `actual_usage.cost` still works but is deprecated (billing logs `commit_caller_supplied_cost_DEPRECATED`). Unused reservation is refunded automatically on commit. Reservations expire after 24 hours in production (`expires_at` tells you); a commit on an expired one is `404 Reservation not found or expired`. Reserve is rate-limited per org (`429 Reserve rate limit exceeded (60/min/org).`).

**4. Late settlement.** When the job outlived its reservation: `POST /billing/<org>/settle { "settlement_key": "<the reservation id>", "started_at", "stopped_at", "hourly_rate", "allocation_fee" }`. The key **must** be the reservation id when there was one, or you can double-charge. Replies: `200` with `status: settled` or `already_accounted` (replay has `replayed: true`): retire the event. A `409` means not eligible or not yours: **never infer anything from a 409**; look at the books. Omitting `hourly_rate` prices the settlement at zero and alerts.

**5. Read the ledger.**
```
GET /billing/<org>/balance                          → balance, credit_balance, subscription_credit, reserved_balance, available_balance, currency, source
GET /billing/<org>/transactions?start_date&end_date&limit&offset
GET /billing/<org>/reservations?reservation_status=active
GET /billing/usage/<org>/summary?period=day&group_by=tool_id
GET /billing/usage/<org>/records?user_id&tool_id&limit
```
`available_balance = balance + credit_balance + subscription_credit − reserved_balance` is the only number that means "can spend". `source: cache|database` tells you how fresh it is. The account is **created on first contact** (`GET /balance` never 404s); do not call `POST /billing/{org}/accounts` unless you need non-default limits, and never with a non-zero `initial_balance` for your own org (`403 an organization cannot issue value to itself`).

**6. Or let the library do it (Go, paid mode).** With `"billing": {"enable_paid": true}` and a durable outbox, `q.Spend` on priced resources is pushed to billing (`POST /billing/usage/{org}/`, `POST /billing/{org}/settle`) by a drain loop. The chain it refuses to start without: a durable outbox store (`"outbox": {"store": "ddb"}` with AWS credentials, which creates the `ab0t_quota_outbox` table, or a Redis you have confirmed durable with `outbox.redis_durability_confirmed`), a settlement publisher (`outbox.sns_topic_arn`, or `Options.SettlementPublisher` in code), and `AB0T_QUOTA_BILLING_URL`. The refusal reads `quota.Setup: enable_paid but the billing chain is SEVERED — …` and ends `or set outbox.allow_ephemeral=true to start with billing DISABLED (dev only)`.

## What you'll see

Async usage: `accepted` at once; the ledger row follows (`usage_id`). Reservation lifecycle: `active` → `committed | refunded | expired`. Replays of commit/refund on a finished reservation return the cached `200`, not `409`. The library logs `billing chain complete — drain loop started` or `BILLING DISABLED: billing chain severed (allow_ephemeral=true, DEV)`. While billing is wired, the Go library also sends a heartbeat every 60 s; billing has no heartbeat route yet, so a recurring `billing heartbeat failed` warning is expected and harmless.

## If it goes wrong

- `403 "Access denied - different organization"` (`details.required: "billing.cross_tenant"`) — your key cannot act for that customer org. SOP 03 step 5. Note the server still names the legacy permission; the concept you are asking for is the provider's `platform`-scope tier.
- `403 "One of permissions required: billing.write.usage, billing.write, billing.admin"` — read-only tier. SOP 03 step 5.
- `409 Duplicate usage request in progress for request_id` / `Duplicate request in progress for idempotency key` — a concurrent twin; wait and retry the same key.
- `409 Prior request did not complete; retry with same request_id` / `Prior commit request did not complete; retry with same reservation_id` — a stranded marker; retry with the **same** key, never a new one.
- `409 Concurrent reservation update conflict; retry request` — optimistic lock; retry.
- `400 Insufficient balance for debit operation` — only when the platform runs billing with negative usage disallowed; show the top-up.
- `422` with `estimated_cost must be positive`, `must be a decimal number`, `exceeds maximum allowed (1,000,000)` — your body.
- `404 Billing account not found` on `/transactions` only — nothing has touched this org yet; a `GET /balance` creates it.
- `429 {"error":"daily_limit_exceeded"}` / `monthly_limit_exceeded` — the account's caps; show `reset_time`.
- Reserve → `402` right after `validate-access` said allowed — a race; treat `reserve` as the gate.

## Coming

- **A self-serve metering tier** carrying `billing.write.usage` for your customers' orgs (scope model). *Today:* SOP 03 step 5.
- **Bounded cross-customer grant on billing** (payment already has `payment.cross_org.{org_id}`). *Today:* the capability is not yet limited to the orgs you serve, so keep your own `org_id`-from-token rule (SOP 12).
- **Durable async usage without SQS** on the billing side (today, without a queue, "accepted" usage is processed in-process). *Today:* prefer reserve/commit for anything that must not be lost, or confirm your billing deployment has the queue.
- **A client SDK for billing** (balance widgets, typed calls). *Today:* REST, or the quota library's typed client in paid mode.
- **Spend from `subscription_credit` draining in order on every deployment.** *Today:* confirm with the platform team that billing's commit spend-order change is live before you rely on refills.

## Next

SOP 12, multi-tenant correctness.
