# GAPS — every **Coming** item in the SOPs, in one table

Each row is something the SOPs describe as the ideal flow that the quota library (`ab0t-quota-go` v0.1.9 / v0.1.10, `ab0t-quota` 0.6.7), billing, payment or `authsetup` does not do yet. This is the spec list. When a row ships, update the SOP and delete the row, but keep a row that is fixed in v0.1.10 while v0.1.9 users still need its workaround: its "today" column then reads "fixed in v0.1.10; on v0.1.9: …". **(scope model)** = part of the approved permission-scope work; **(docs)** = documentation drift the SOP had to warn about.

| # | item | SOP | why users want it | today |
|---|---|---|---|---|
| 1 | **Self-serve metering/checkout tier** carrying `billing.write.usage` / `payment.write` for the consumer's customers' orgs, approved by the provider's admin into the consumer's sub-org (scope model) | 03, 07, 11, 18 | onboarding cannot finish without a human at the provider | both providers publish read-only tiers; ask support (`platform-team@ab0t.com`) for the upgrade |
| 2 | **Bounded cross-customer grant on billing** (serve only the orgs you serve), as payment's `payment.cross_org.{org_id}` (scope model) | 11, 12, 18 | least privilege for gateways | the capability is not yet limited to the orgs you serve |
| 3 | **Server `403` bodies without legacy permission names** | 11, 12, 17, 18 | vocabulary; the approved term is `scope: "platform"` | `details.required: billing.cross_tenant` etc. |
| 4 | **"Standard Consumers" tier carrying writes, or renamed**; **"Cross-Tenant (invite)" renamed** | 03 | descriptions say "read + write"; legacy wording | reads only; legacy name |
| 5 | **`connect` printing the quota library's env names** (`AB0T_QUOTA_*`) and one env-name set across runtimes | 03, 05 | three naming schemes today (`BILLING_SERVICE_*`, `AB0T_QUOTA_*`, `AB0T_MESH_*`) | translate by hand |
| 6 | **Offline `quotactl validate`** (no Redis/DynamoDB) | 04, 14 | check a config without connecting | `capabilities` connects; or start the service |
| 7 | **Enumerated `billing_model`, `reset_period`, `dedup`, `trigger` values** refused on typo | 04 | typos pass silently | warned at boot in v0.1.10 (`quota config: …`, not refused); on v0.1.9 silent (cross-field rules only) |
| 8 | **`tier_provider.type: "mesh"` wired by `Setup`** | 04, 05, 09 | config-only billing tier source | supply a lookup in code or use `jwt` |
| 9 | **`enforcement.enabled` defaulting to true or refusing when absent** | 04 | absent = allow everything, silently | warned at boot in v0.1.10 (not refused); on v0.1.9 silent; always write it |
| 10 | **Published JSON schema at the `$schema` URL** | 04 | editor validation | the Python repo's `quota-config-schema.json`; the Go repo's `examples/basic/quota-config.json` |
| 11 | **quota-go README and examples matching the code** (docs) | 05 | README shows `quota.Config`, `Mount`, `CheckBundle`, `WriteDenial`, `AB0T_MESH_*` (none exist); the examples mount the auth-event receiver at a path where it answers `404` | fixed in v0.1.10 (the README's minimal example is `examples/basic/main.go` verbatim); on v0.1.9: SOP 05 and `examples/basic/main.go` |
| 12 | **An auth-event receiver that also answers when mounted at its full path** | 05, 10 | the obvious mount silently drops every sign-up credit | fixed in v0.1.10 (answers any path ending in `/_webhooks/auth`); on v0.1.9: `http.StripPrefix("/api/quotas", q.WebhookHandler())` (works on both) |
| 13 | **Go supporting `engine_mode: bridge`** | 05, 16 | runtime parity (hosted enforcement without your own Redis) | Python only |
| 14 | **Read-only `capabilities` / `doctor`** (never create tables) | 06, 13 | safe smoke test | both run the real boot |
| 15 | **Hosted shadow report** (would-denies per resource/tier/org) | 06 | decide limits without grepping | `jq` over logs / `OnDecision` |
| 16 | **Kill switch / shadow flip without redeploy** | 06, 13 | incident speed | config + deploy |
| 17 | **Gateway-managed payment methods bound to the customer's Stripe customer** | 07, 12 | server-side card changes for a customer | portal only |
| 18 | **Consistent response keys in docs** (`url` vs `checkout_url`/`portal_url`) (docs) | 07 | copy-paste correctness | API returns `url` |
| 19 | **URL allow-listing for `success_url` / `cancel_url` / `return_url`** | 07 | open-redirect safety | validate on your side |
| 20 | **Price → tier mapping owned by the consumer** (plan metadata / `billing_integration.stripe_price_to_tier`) | 08, 09, 14 | a paid customer's tier stays unchanged until payment's price map knows the price | coordinate every price with support |
| 21 | **Cancellation landing tier in the consumer's config** | 08 | policy belongs to the service | hard-coded `free` |
| 22 | **Outbound webhooks from payment to consumers** (subscription changed, payment failed), with retries | 08 | event-driven consumers | poll `/subscriptions`, read `/billing/{org}/tier`; registration routes exist but deliver nothing |
| 23 | **Tier inheritance from a parent org to workspaces** | 09, 12 | workspace-per-user products | per-org tiers |
| 24 | **`quotactl tier set <org> <tier> --reason`** | 09 | audited manual move from the CLI | `PUT /billing/{org}/tier` |
| 25 | **Richer trials** (card-less, auto-convert) | 09 | onboarding | `trial_period_days` on the plan |
| 26 | **`quotactl events` / `delete-user` against the real ledger** | 10, 13, 15 | the standalone CLI cannot reach the service's ledger | v0.1.10: the CLI refuses honestly (non-zero) instead of reading a stub; on v0.1.9 it prints nothing / "deleted 0 rows" (exit 0, nothing deleted). Both: `q.LedgerStore.QueryByUser` / `QueryByStatus` / `DeleteUser` inside your service |
| 27 | **Scoped `events.subscribe` token for a service** | 10 | no auth admin token in a consumer's hands | `AB0T_AUTH_ADMIN_TOKEN` from support |
| 28 | **Webhook secret rotation in one step** (`subscribe-events` updating an existing subscription's secret, or auth allowing the edit) | 10, 15 | rotate without a delivery gap | partly fixed in v0.1.10: one command (`quotactl subscribe-events --rotate-secret`) plus `AB0T_AUTH_WEBHOOK_SECRET_PREVIOUS` so no event is rejected, then a backfill of the seconds between delete and create (auth editing a secret is still to come); on v0.1.9: delete the subscription, redeploy, re-subscribe, backfill the gap (SOP 10 step 7) |
| 29 | **The typed billing client's `GrantCredit` posting to a route billing serves** | 10 | a one-line granter | fixed in v0.1.10 (`GrantCredit` grants for real; built-in `quota.BillingCreditGranter(nil)`); on v0.1.9: a ten-line granter calling `/billing/{org}/promotional-credit` (SOP 10 step 2) |
| 30 | **`credit_grant.trigger: "manual"` admin tool** (referrals, goodwill) | 10 | support workflows | the promotional-credit route by hand |
| 31 | **One documented rewrite of legacy `initial_credit`** across runtimes (docs) | 10 | older docs disagree; the Go loader makes it a persistent `credit_balance` sign-up grant | write `credit_grant` explicitly |
| 32 | **Durable async usage on billing without SQS** | 11 | "accepted" usage can be lost in-process | reserve/commit for must-not-lose; confirm the queue |
| 33 | **A billing client SDK** (typed calls, balance widgets) | 11 | less REST by hand | REST or the quota library's paid mode |
| 34 | **Guaranteed `subscription_credit` spend order on every deployment** | 11 | refills that never drain | confirm with support |
| 35 | **A billing heartbeat route** for the library's 60-second heartbeat | 11, 17 | a liveness signal instead of a recurring warning | fixed in v0.1.10 on the library side (it stops after the first `404` with one INFO line; billing still serves no route, and nothing depends on it); on v0.1.9: ignore `billing heartbeat failed` |
| 36 | **Alert dispatchers beyond one webhook** (Slack/PagerDuty) and a hosted per-org dashboard | 13 | ops | fan out yourself; `OnDecision` logs |
| 37 | **A healthy Redis-backed service without the DynamoDB reconciler** | 13 | `PREFLIGHT RE-VERIFICATION IS OFF` and `Healthy() == false` on every Redis deployment that skips it | pass `Options.ReconcileOrgs` and declare DynamoDB, or read `Healthy()` reasons |
| 38 | **Payment's reconciliation items visible to the consumer** (`tier_sync_failed`, `tier_resolution_unresolved`) | 08, 13, 17 | self-diagnose a stuck upgrade | ask support |
| 39 | **`quotactl diff` / config hot-reload / counter migration tooling** (rename, type change) | 14 | safe day-2 | reason by the rules; redeploy; add-new-retire-old |
| 40 | **Overlapping key rotation in one verb** (`authsetup rotate <provider>`) | 15 | `disconnect` revokes immediately | order by hand |
| 41 | **Consumer account self-delete on disconnect; customer-offboarding checklist** | 15 | clean exits | inert account remains; four manual steps |
| 42 | **Migration kits + checker per breaking library release** (as `auth-sdk-go` ships), semver that signals breakage | 16 | pre-1.0 breaking patches | v0.1.10 ships the first kit (`migrations/v0.1.9-to-v0.1.10/`, read-only checker); for other bumps read every CHANGELOG entry |
| 43 | **A published change feed for billing and payment** | 16 | API changes bit consumers (idempotency keys, inputs-not-cost, dollars, lower-case enums) | ask support for change notes |
| 44 | **`quotactl explain <reason|status>`** | 17 | fast triage | SOP 17's tables |
| 45 | **Billing refusing usage that would take a prepaid balance negative** (bounded credit line, suspension) | 18 | predictable prepaid | records + alerts; your `validate-access` gate |
