# 17 · Troubleshooting

**What this is for.** The messages you will actually see from the quota library, `quotactl`, billing and payment, in their own words, with what each means and what to do. Start with the three read-only looks, then find your message.

**Before you start.**
```sh
quotactl capabilities --config ./quota-config.json | jq '{Enforcement, ShadowMode, Billing, Payment, CreditGrant, WhyOff}'
quotactl doctor --config ./quota-config.json --json
authsetup --env <env> status --verify                      # are the billing/payment keys live? (Ally SOP 16 for authsetup itself)
```
Both `quotactl` commands connect to your declared stores (and would create declared DynamoDB tables); they start no loops.

## Quota library: start-up

| you see | it means | do |
|---|---|---|
| `config: no config file found (set QUOTA_CONFIG_PATH or place quota-config.json in CWD)` | wrong path | `QUOTA_CONFIG_PATH` (not `AB0T_QUOTA_CONFIG_PATH`) |
| `quota.Setup: validate config: config: tiers[] is required` and the other `validate` strings in SOP 04 | config | fix the named field |
| `ab0t-quota-go config error [QUOTA-CFG-001] — Redis counter store URL is not declared.` | no `storage.redis_url` / `QUOTA_REDIS_URL` | declare it; `"memory://"` for one dev process |
| `DECLARED REDIS UNREACHABLE/UNAUTHENTICATED (D-2) — refusing to start` (after `declared Redis unreachable — retrying within the D-2 budget`) | URL/password/network | fix; `storage.connect_retry_seconds` is the budget |
| `quota: unsafe Redis counter store (eviction)` · `quota: Redis cannot run the counter's Lua scripts` · `quota: Redis below the supported version floor` · `quota: unsupported or unverifiable Redis topology` | Redis violates a gate | no eviction policy, allow scripting, Redis 7, single node; `quotactl provision --emit compose` for a conforming definition |
| `REDIS TOPOLOGY UNSUPPORTED/UNVERIFIED (D-71) — refusing to start` | cluster or unverifiable | single node, or `storage.redis_cluster_confirmed_disabled: true` after you have checked |
| `quota.Setup: storage.redis_key_prefix="x" is not permitted — …` | custom prefix | remove it |
| `quota.Setup: enable_paid but the billing chain is SEVERED — <link>` (v0.1.10 adds `Paid mode is on because …; … pass Options.EnablePaid=&false`) | paid mode gate; setting `AB0T_QUOTA_BILLING_URL` turns paid mode on | fix the link (outbox store, `sns_topic_arn`, …); not metering yet (limits and/or sign-up credit only): `Options.EnablePaid=&false` on both versions (SOP 05 step 4); `outbox.allow_ephemeral: true` is dev only and leaves `q.Healthy()` false |
| `quota.Setup: CreditGranter is quota.BillingCreditGranter(nil) but billing is not wired — …` (v0.1.10) | built-in granter without `AB0T_QUOTA_BILLING_URL` | set `AB0T_QUOTA_BILLING_URL` and `AB0T_QUOTA_BILLING_TOKEN` (SOP 10 step 2) |
| `quota config: …` WARN lines (v0.1.10; also `Capabilities.ConfigWarnings`) | a config value that fails open: enforcement off, a `reset_period` that never resets, a limit naming no resource, an unknown `billing_model` / `trigger` / `dedup` / `lifecycle` / `destination` | fix the named field (SOP 04); on v0.1.9 the same mistakes are silent |
| `AB0T_QUOTA_CONFIG_PATH is set but IGNORED …` (v0.1.10) | wrong variable name, on both versions | rename it to `QUOTA_CONFIG_PATH` |
| `handler-ledger table has no GSI1/GSI2 …` (v0.1.10) | a DynamoDB handler-ledger table created by v0.1.9; `QueryByUser` / `QueryByStatus` / `DeleteUser` fail with `ValidationException` | add the two indexes (SOP 15 step 5) |
| `PREFLIGHT RE-VERIFICATION IS OFF (D-79)` and `q.Healthy()` false | counters on Redis, no reconciler loop | SOP 13 "If it goes wrong" |
| `billing heartbeat failed` every minute (v0.1.9) · one INFO `billing heartbeat: billing serves no heartbeat route — heartbeat stopped (harmless; nothing depends on it)` (v0.1.10) | billing has no heartbeat route | harmless; ignore |
| `KEYSPACE BOOT GUARD refused to start (K-8, spec §3.3)` · `QUOTA-CFG-011` · `QUOTA-CFG-012` | keyspace step out of order | SOP 16 D |
| `quota.Setup: tier provider: tier_provider.type unknown: "billing"` | typo | `jwt`, `static`, `mesh` |
| `mesh provider: no Lookup wired (call SetLookup at startup)` | `mesh` without a lookup or `default_tier` | wire it or use `jwt` |
| `HANDLER-LEDGER TABLE UNSAFE (D-76/D-82)` · `DDB STORE UNSAFE (D-76)` | DynamoDB table lacks PITR/encryption facts | fix the table or confirm with `storage.ddb_pitr_confirmed` |
| `panic: middleware.Guard: Identity required` / `Router required` | wiring | pass both callbacks |

## Quota library: at request time

| you see | it means | do |
|---|---|---|
| `503 {"detail":"quota engine error"}` | `Router` returned a key not in config (`engine: unknown resource_key`), or Redis failed, fail-closed | add the resource (SOP 14 step 3); check Redis |
| `401 {"detail":"identity required"}` | `Identity` errored | auth middleware must run first |
| every request `X-Quota-Reason: enforcement_disabled` | `enforcement.enabled` absent/false | set it |
| `X-Quota-Reason: shadow_would_deny` with `200` | shadow on | expected; SOP 06 |
| `429 reason tier_not_in_config` | provider returned a tier not in `tiers[]` | add tier / fix map; not softened by shadow |
| `200 reason tier_unresolved` | no user/org or lookup failed; fail-open | check claims / provider |
| `429 reason global_kill_switch` | you flipped it | flip back when safe |
| `X-Quota-Reason: per_user_exceeded` | per-user sub-limit (gauges) | expected |
| `recount_fail_open` / `recount_source_unavailable_kept_deny` | truth provider unavailable during a deny | check the provider; gauges fail open, meters keep the deny |
| no `X-Quota-*` headers | exempt path or `Router` returned `""` | expected |
| `quota: idempotency key looks like a bare recyclable resource id …` | strict idempotency mode | use a unique key per operation |
| `lifecycle_settle_RETRY` (paid mode, v0.1.10) | billing answered a settlement with `401`, `403` or a route `404` (rotated key, permission change, wrong base URL); the money event stays pending and is retried | fix the key or URL; the events then settle (on v0.1.9 these were voided) |
| `lifecycle_event_VOIDED` / a void alert with `no_settlement_key` (paid mode, v0.1.10) | a money event carried no `reservation_id`, so it cannot be settled safely (v0.1.9 settled it under a blank key, and billing treated every later one as already seen) | emit lifecycle money events with their reservation id |

## Auth events / credit grants

| you see | it means | do |
|---|---|---|
| `401 {"detail":"invalid signature"}` on every event | `AB0T_AUTH_WEBHOOK_SECRET` differs from the secret the subscription was created with, or the body was re-serialised | put the original secret back, or rotate by replacing the subscription (SOP 10 step 7); re-running `subscribe-events` does not change the secret |
| `404 page not found` on every event | v0.1.9: receiver mounted at its full path without `http.StripPrefix`; v0.1.10: the request reaches a path that does not end in `/_webhooks/auth` | SOP 05 step 2 (v0.1.9: use `http.StripPrefix`; v0.1.10: check the mux and `--prefix`) |
| `405` / `413 {"detail":"body too large"}` (v0.1.10) | not a POST / body over 1 MiB | send POST; something other than auth is calling the receiver |
| `200 {"status":"ignored"}` | no handler for that type | pass `CreditGranter` / register a handler |
| ledger `skipped`, reason `credit_grant trigger is …, not signup: <tier>` (v0.1.10) | the tier's grant is not a sign-up grant (e.g. a monthly refill) | expected; on v0.1.9 such grants were handed out on join (SOP 10 step 1) |
| `WhyOff credit_grant: no CreditGranter supplied; default handler not registered` | as it says | SOP 10 step 2 |
| `auth-event auto-subscribe skipped: missing one of AB0T_AUTH_AUTH_URL, AB0T_AUTH_ADMIN_TOKEN, AB0T_AUTH_WEBHOOK_PUBLIC_URL, AB0T_AUTH_WEBHOOK_SECRET` | CLI or `AutoSubscribeAuthEvents` env | set all four |
| v0.1.9: `subscription_id:` printed empty, with `auth-event auto-subscribe: create failed err="HTTP 401: …"` (exit code still `0`) · v0.1.10: non-zero exit naming `HTTP 401` (token rejected or expired) or `HTTP 403` (token lacks `events.read` / `events.subscribe` / `events.delete`) | admin token expired or lacks a permission; nothing registered | fresh token, re-run |
| `subscribe-events`: `subscription … exists but …` naming `--rotate-secret` (v0.1.10) | the existing subscription listens to other events, is disabled, or signs with a different secret | `quotactl subscribe-events --rotate-secret` (SOP 10 step 7) |
| ledger `failed_permanent` with `billing promotional-credit: HTTP 403` (or your granter's own message) | billing refused your grant | key permissions (SOP 03 step 5); `404` means the granter posts to the wrong path (SOP 10 step 2); after the fix re-send with `quotactl backfill` (`replay` of the same event is a no-op) |
| `quotactl events` shows nothing (v0.1.9) · refuses with `this CLI cannot reach your service's handler ledger` (v0.1.10) | the standalone CLI has no access to your ledger (v0.1.9 read an empty in-memory stub) | `q.LedgerStore.QueryByUser` / `QueryByStatus` inside your service |
| `replay` / `backfill` exit non-zero (v0.1.10) | at least one event was not accepted (or `backfill` ran without `--target` / secret) | read the per-event `HTTP <status>` lines; on v0.1.9 these exit `0`, so read them anyway |

## Billing (your key → billing)

| status | detail (verbatim) | do |
|---|---|---|
| 401 | `Authentication token not provided` / `Invalid token` | header `X-API-Key`; right provider's key |
| 403 | `{"error":"PERMISSION_DENIED","message":"One of permissions required: billing.write.usage, …"}` | tier upgrade (SOP 03 step 5) |
| 403 | `Access denied - different organization` (`details.required: billing.cross_tenant`) | cross-customer capability missing (SOP 03 step 5); the server names the legacy permission |
| 403 | `Access denied - missing resource organization` | org missing from path |
| 403 | `Access denied - an organization cannot issue value to itself` | call as your service identity for a *customer* org |
| 400 | `request_id is required for usage idempotency` | add `request_id` |
| 400 | `Request body org_id does not match URL path` | body = path |
| 400 | `Insufficient balance for debit operation` | only when negative usage is disallowed on that deployment; show top-up |
| 400 | `Billing account already exists for organization: <org>` | you did not need `POST /accounts` |
| 402 | validate-access: `{"reason":"insufficient_balance","required_topup":…}` · reserve: `{"error":"insufficient_balance","message":"Insufficient balance for reservation",…}` · commit: `Insufficient balance for additional charge` | show `required_topup`; SOP 07 step 4 |
| 404 | `Reservation not found` · `Reservation not found or expired` · `Billing account not found` (transactions only) | re-reserve with a new `request_id`; `GET /balance` creates the account |
| 409 | `Duplicate usage request in progress for request_id` · `Duplicate request in progress for idempotency key` | concurrent twin; retry same key |
| 409 | `Prior request did not complete; retry with same request_id` · `Prior commit request did not complete; retry with same reservation_id` | retry with the **same** key |
| 409 | `Concurrent reservation update conflict; retry request` (and commit/refund/balance variants) | retry |
| 409 | `Reservation is not eligible for settlement` · `Reservation has already been settled` | look at the books; never infer |
| 409 | `Reset rejected: source tier mismatch` | correct refusal; credit preserved on purpose |
| 422 | `estimated_cost must be positive` · `estimated_cost exceeds maximum allowed (100,000)` · `must be a decimal number` · `must not be negative` · `exceeds maximum allowed (1,000,000)` · blank `idempotency_key` | your body |
| 429 | `Reserve rate limit exceeded (60/min/org).` · `{"error":"daily_limit_exceeded",…}` · `monthly_limit_exceeded` | back off; show `reset_time` |
| 503 | `Quota service temporarily unavailable` · `Quota module not initialized` | billing's quota module; platform team |

## Payment (your key → payment)

| status | detail (verbatim) | do |
|---|---|---|
| 403 | `One of permissions required: payment.write, …` | tier upgrade (SOP 03 step 5) |
| 403 | `Access denied to organization data` · `Organization access denied` | cross-customer capability |
| 403 | `Cross-organization payment method operations are not supported` | use the portal (SOP 07 step 5) |
| 403 | `Insufficient permissions for checkout processing` · `This plan requires authentication` | `process_if_complete` needs `payment.write`; plan not anonymous |
| 400 | `Customer email is required for checkout` | pass `customer_email` as a gateway |
| 400 | `{"error":"Amount exceeds maximum allowed","amount_interpreted":"$…"}` · `Amount seems too high` | you sent cents |
| 400 | `No pricing available for plan <id>` · `Price <id> is not valid for plan <id>` · `Plan <id> is not available for subscription` | fix the plan/price |
| 400 | `Cannot create portal session: no Stripe customer found for this organization` | customer never checked out |
| 404 | `Plan <id> not found for organization <org>` · `Subscription not found` · `Organization not found` (non-UUID org) | ids |
| 409 | `Checkout for this plan was already completed for this email within the past minute.` | reuse the session |
| 422 | `plan_id is required for subscription creation` · `price_id is required when plan has zero or multiple active prices` | body |
| 503 | `Checkout temporarily unavailable; please retry.` | retry with backoff |

Two error shapes exist: the auth layer's `{"error","message","details"}` and the services' own `{"detail": …}`.

## Chains to walk

**Paid but still on free** (SOP 08): Stripe delivered with 2xx? → payment logged the tier sync (or `tier_resolution_unresolved` → unmapped price)? → `GET /billing/{org}/tier` changed? → your tier source refreshed (JWT re-login, cache TTL)?

**Credit granted but balance 0** (SOP 10): ledger row `success` with a side-effect id? → billing call `403/422`? → right bucket (`credit_balance` vs `subscription_credit`)? → stale balance cache (`source: cache`)?

**Counter wrong**: `quota.drift_detected` in logs? → `ReconcileOrg` report (`repaired` / `no_truth_source`)? → a termination path missing `Release`? Never `redis-cli SET`.

## If it goes wrong beyond this page

Collect the `quotactl capabilities` output (it is JSON) or your start-up capability line, `quotactl doctor --json`, the failing request/response with ids (never keys), and the relevant `authsetup --env <env> status --json`. Send to `platform-team@ab0t.com`.

## Coming

- **`quotactl explain <reason|status>`** printing this table's row. *Today:* this page.
- **Server error bodies without legacy permission names.** *Today:* `details.required: billing.cross_tenant` and similar.
- **A client-visible reconciliation feed from payment** (`tier_sync_failed`). *Today:* ask.

## Next

SOP 18, security and money rules.
