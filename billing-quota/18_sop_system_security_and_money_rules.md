# 18 · Security and money rules

**What this is for.** The short list that keeps your customers' money, your keys, and your numbers safe. Each rule says what is enforced for you and what is on you.

## The rules

**1. The customer's `org_id` comes from their validated token.** Never from a parameter. Billing refuses a body/path mismatch; your proxy routes must not even read a client-supplied org. (SOP 12)

**2. Your keys stay server-side and per provider.** `X-API-Key` from your backend only; never in a browser, a log line, a ticket or chat. Billing's key is not valid at payment. Read key values from `~/.authmesh/invoicer/<provider>-consumer.<env>.json` into your secrets manager; never delete that folder. (SOP 03, Ally SOP 14)

**3. Never forward a user's bearer token to billing or payment.** Wrong audience, wrong permissions, and it would make the customer the payer of record for your call.

**4. Never touch card data.** Checkout and portal pages are Stripe's; set-up intents hand you a `client_secret` for Stripe.js only. Gateways cannot manage a customer's payment methods; the portal does. (SOP 07)

**5. Dollars, not cents.** Payment amounts are decimal dollars (`29.00`); billing money is decimal strings. A cents mistake is a 100× charge; payment refuses obvious ones (`> 10000`), not subtle ones.

**6. Every money write has an idempotency key.** `request_id` on usage and reserve, `reservation_id` on commit, `settlement_key` (= reservation id) on settle, `idempotency_key` on credits, Stripe `event.id` on webhooks, business keys on grant handlers. Retry with the **same** key; never mint a new one to "get past" a `409`. (SOPs 10, 11)

**7. Check before, spend after; fail closed on spend, open on release.** `Check` then work then `Spend`. `FailOpen: false` on anything that creates cost; `true` only on cleanup. (SOP 05, 12)

**8. Shadow before enforce; never a test charge on prod.** Limits go live only after a shadow day and the nine-item acceptance list. Money paths are proven on dev/staging with Stripe test cards, and you confirm with support that live payments are enabled for your account before launch. (SOP 06, 07)

**9. Never a `platform`-scope capability by default, and never hand it to a customer.** The cross-customer capability belongs to your service identity because it is a gateway; a customer's admin can never grant it to themselves, and you must never place it in a default grant, a default role, a default team or a self-serve tier of your own. Request only the writes you proxy; no `billing.admin` / `payment.admin` unless you administer plans. (SOP 03, Ally SOP 17)

**10. Verify webhooks over the raw body, with a shared secret you rotate.** Auth events: `X-Event-Signature` HMAC over the exact bytes; a missing secret means every event is rejected, which is the safe default. Give the secret to `quotactl replay` / `backfill` through `AB0T_AUTH_WEBHOOK_SECRET`, never `--secret` (a command line is visible in `ps`); on v0.1.9 their `--help` prints the exported secret, so do not run it in a shared terminal or CI log. Stripe events: forward body and `Stripe-Signature` unchanged to payment, or let Stripe call payment directly; never act on an unverified event. (SOP 08, 10)

**11. Counters are caches of a truth you own.** Wire truth providers; reconcile; never `redis-cli SET`. Redis must be single-node, non-evicting, Lua-enabled; the library refuses anything else. (SOP 13)

**12. Alerts go to a public `https` endpoint you control.** The dispatcher refuses private addresses; do not disable that in production.

**13. Read the changelog before every library bump.** Pre-1.0; breaking changes have shipped as patches. Pin tags. (SOP 16)

**14. Prefer the CLI and the documented endpoints; keep every manual money action in a ticket.** Hand tier changes (`PUT /tier` with `reason`), manual credits, refunds and backfills are audited server-side; mirror that with your own record.

## What is enforced for you today

Body/path org mismatch (400). Permission ceilings on every billing/payment route and on API-key scope. Cross-org refusals without the capability (403). Self-issued value refused (403). Required `request_id`/`idempotency_key` (400/422). Duplicate detection on usage, reserve, commit, settle, credits, webhooks. Payment amount sanity (`> 10000` refused). Redis safety gates and the undeclared-store refusal at boot. Paid-mode chain gates. Alert webhook SSRF guard. Credit-reset tier mismatch refusal. Stripe signature verification on payment's side.

## Coming

- **Scope model** (`scope: "platform"` tiers approved by the provider's admin into your sub-org; bounded to the orgs you serve). *Today:* the cross-customer capability, granted on request by support and not yet limited to the orgs you serve.
- **Server messages free of legacy names.** *Today:* `billing.cross_tenant` / `payment.cross_org` appear in `403` bodies.
- **Billing refusing usage when a prepaid balance would go negative** (a bounded credit line and suspension). *Today:* records and alerts; your `validate-access` gate is the refusal.

## Next

Back to `00_index.md`.
