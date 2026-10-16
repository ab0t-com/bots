# 02 · Day zero: Acme meters `invoicer`

Acme's `invoicer` is live on the mesh (Ally's SOPs 03–06 done: customers sign in, the backend verifies tokens). Now Acme wants a free tier, a $29 Pro tier, and to charge for PDF rendering. Here is the whole day, in order.

**1. Decide on paper (an hour).** What costs Acme money: PDF rendering and storage, not "requests". So the resources are `invoicer.invoices` (how many invoices a month: an accumulator), `invoicer.api.requests` (a rate, against abuse) and `invoicer.seats` (a gauge). Tiers: `free` (20 invoices, 1 seat, $5 sign-up credit), `pro` ($29/month, 500 invoices, 10 seats, $10 monthly credit), `enterprise` (unlimited, by contract). Acme meters per **org** (B2B), so grants dedup per org per tier. Enforce only after a shadow day.

**2. Get the keys (ten minutes, then a wait).** `authsetup --env dev connect billing --as invoicer`, then `payment`. Both arrive on the read-only tier. Acme emails the platform team the consumer account addresses and asks for `billing.write.usage`, `payment.write` and the cross-customer capability for its customers' orgs. *(Today this is a human step; the scope model makes it the provider admin's one-click approval into Acme's sub-org.)*

**3. Describe tiers and resources (half an hour).** `quota-config.json` as in SOP 04: three resources, three tiers with limits, `tier_provider: jwt` (Acme's tokens carry a `tier` claim), Redis declared, `enforcement: {enabled: true, shadow_mode: true}`, alerts to Acme's ops webhook.

**4. Wire the library (an hour).** `quota.Setup`, `q.Middleware` with `Identity` reading the validated actor and `Router` mapping `POST /api/invoices` to `invoicer.invoices`, `q.Spend` after an invoice is created, `q.Release` when a seat is removed. `quotactl capabilities` shows `Enforcement: true, ShadowMode: true`.

**5. Shadow for a day.** Nothing is denied; `shadow_would_deny` counts show four free-tier customers would hit 20 invoices. Acme keeps the limit and drafts the upgrade email.

**6. Plans and prices (twenty minutes).** In payment: product "Invoicer", plan "Pro" with `trial_period_days: 14` and metadata `tier_id: pro`, price `29.00` monthly. Acme sends the `price_id` → `pro` mapping to the platform team so a payment becomes a tier. The pricing page reads `GET /checkout/<acme org>/plans`.

**7. Checkout and portal (an hour).** Three proxy routes: `/api/payments/checkout/{plan}` → `POST /checkout/<customer org>/plan/<plan_id>` with `success_url`/`cancel_url`/`customer_email`; `/api/payments/topup` → `POST /checkout/<customer org>/session` in dollars; `/api/payments/portal` → `POST /portal/<customer org>/session`. The success page polls the subscription until `active`/`trialing`. Stripe's webhook points at payment directly.

**8. Credits (half an hour).** A `CreditGranter` that calls billing's promotional-credit route for the customer org with an idempotency key, and the receiver mounted with `http.StripPrefix`; `openssl rand -hex 32` as the shared secret; `quotactl subscribe-events --events org.created,user.org_assigned --prefix /api --name invoicer-credit-grant --org-slug invoicer-users`. One test sign-up: balance `credit_balance: 5.00`. Replayed: unchanged. Pro's $10 monthly refill arrives on its own when Stripe pays the invoice.

**9. Metering money (an hour).** PDF rendering records usage: `POST /billing/usage/<customer org>/` with `request_id: invoicer:pdf_render:<id>` and `cost: "0.0200"`. Bulk export reserves first: `reserve` → work → `commit` with `started_at`/`stopped_at`/`hourly_rate`, `refund` on cancel. `GET /balance` shows `available_balance` moving.

**10. Flip (five minutes, after the list).** Nine acceptance items ticked, rollback rehearsed, `shadow_mode: false`, deploy, watch the first hour: a handful of `429`s with `upgrade_url`, two upgrades the same afternoon.

**11. Prod.** Same files, `--env prod` for the keys; Acme confirms with support that live payments are enabled for its account before announcing the Pro tier.

**In short, for Acme:** one JSON file, two keys, about 150 lines of glue, a shadow day; billing is the ledger, payment is the money, the library is the decision. The waits are the platform team's two approvals (the write tier and the price map), which the scope model turns into provider-side clicks.

**Next:** SOP 03, get your keys.
