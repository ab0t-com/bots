# 13 · Observability, alerts, the kill switch and reconciliation

**What this is for.** Knowing what quota and billing are doing in production: who is near a limit, which counters drifted, whether usage is reaching billing, and how to stop the bleeding in an emergency without losing the numbers.

**Before you start.** SOP 06 enforced on at least one environment. A webhook endpoint (public `https`, not a private address) for alerts. Log aggregation that can search JSON.

## Steps

**1. Turn on alerts in config.**
```json
"alerts": { "enabled": true, "webhook_url": "https://ops.acme.example/hooks/quota",
            "warning_threshold": 0.80, "critical_threshold": 0.95, "cooldown_seconds": 3600, "drift_sustained_threshold": 3 }
```
The webhook body is `{level, resource, tier, used, limit, threshold, timestamp}`; v0.1.10 adds `org_id` and `reason` (nothing was removed, so a v0.1.9 consumer keeps working). The cooldown is per org on v0.1.10; on v0.1.9 it is per resource and tier, so one org's alert mutes the same alert for every other org on that tier for `cooldown_seconds`. The dispatcher refuses non-`http(s)` schemes and, by default, private/loopback/link-local targets (`webhook: scheme "file" rejected`, `webhook: URL required`, `webhook: bad URL: …`).

**2. Surface capabilities in your health endpoint.** Call `q.Capabilities()` from `/healthz` and expose `Enforcement`, `ShadowMode`, `Billing`, `Payment`, `CreditGrant`, `LedgerBackend`, `FloatStore`, `WhyOff`. Intentional degradation (billing off in dev) and accidental degradation (token missing in prod) then look different on a dashboard.

**3. Log every decision you care about.** `MiddlewareDeps.OnDecision` and `OnWarn` receive each outcome; emit `{org_id, user_id, resource, tier, reason, used, limit}`. The reasons worth counting: `exceeded`, `per_user_exceeded`, `shadow_would_deny`, `near_critical`, `tier_not_in_config`, `tier_unresolved`, `recount_repaired_allow`, `recount_fail_open`, `recount_source_unavailable_kept_deny`.

**4. Watch drift and let it heal.** Wire the truth providers at `Setup` (`ObservedUsageProvider` for gauges: count live things per org; `AccumulatorUsageProvider` for period totals from your ledger). Then a would-be deny is re-checked against the truth before the `429`, and each repair emits `quota.drift_detected{org, resource, type, delta}`; sustained drift raises the CRITICAL alert `quota_drift_sustained`. Repair on demand:
```go
rep, _ := q.Engine.ReconcileOrg(ctx, orgID, "")     // "" = every resource; expose as POST /api/quotas/recalculate (admin only)
```
Statuses: `repaired | in_sync | skipped_rate | no_truth_source | no_observation | truth_unavailable`. **Never `redis-cli SET` a counter**: the next reconcile overwrites it and you lose the drift signal.

**5. Watch the money chain.** In your logs: `billing chain complete — drain loop started` at boot; outbox voids past the retry horizon (`outbox.past_horizon: void_and_alert`). Billing-side keys the platform team can search for you: `subscription_invoice_paid_applied|skip|failed_permanent`, `credit_grant_applied`, `reset_subscription_credit_applied`, `reset_subscription_credit_tier_mismatch` (WARNING), `lifecycle_commit_lost_to_expiry` (ERROR: revenue loss; page). Payment files reconciliation items (`tier_sync_failed`, `tier_resolution_unresolved`) when a tier change did not land.

**6. Posture, periodically.**
```sh
quotactl doctor --config ./quota-config.json --json --fail-on-risk
```
Grades persistence, eviction facts, PITR by assertion, encryption in transit, and names what it cannot check. Exit `0` ok, `1` gate refusal, `2` config, `3` unreachable, `4` internal. It runs the full boot (connects, may create declared tables).

**7. The emergency brake.** Three different levers; choose on purpose:

| lever | effect (Go) | counters | when |
|---|---|---|---|
| `enforcement.shadow_mode: true` | allow everything, tag `shadow_would_deny` | keep counting | limits are wrong, customers are being blocked unfairly |
| `enforcement.enabled: false` | allow everything (`enforcement_disabled`) | stop | quota itself is misbehaving |
| `enforcement.global_kill_switch: true` | **deny everything** (`429`, `Quota enforcement halted by global kill switch.`) | n/a | runaway cost, abuse, you must stop spend now |

All three need a config change and a redeploy. Go v0.1.9, Go v0.1.10 and Python v0.6.7 treat all three the same way; rehearse the one you would use before an incident.

## What you'll see

One INFO line at boot per capability (`ab0t-quota capabilities`), `WhyOff` entries such as `billing: AB0T_QUOTA_BILLING_URL not set`, `credit_grant: no CreditGranter supplied; default handler not registered`, `auth_events_signed: AB0T_AUTH_WEBHOOK_SECRET not set — receiver will reject all events with 401`. On v0.1.10, a `quota config: …` WARN line per config value that fails open (SOP 04 step 6), also in `Capabilities.ConfigWarnings`. Alert webhooks arrive once per org, resource and tier per cooldown on v0.1.10 (once per resource and tier, across all orgs, on v0.1.9). A recalculate response: `{"org_id": …, "resources": {"invoicer.seats": {"counter_type": "gauge", "before": 5, "after": 3, "changed": true, "source": "provider", "status": "repaired"}}}`.

## If it goes wrong

- No alerts ever: `alerts.enabled` false, webhook URL private (SSRF guard), or thresholds never crossed. Force one in staging.
- `reconciler OFF — non-durable activation ledger (D-39)` at boot: you passed `Options.ReconcileOrgs`, but the activation store is in memory; declare `storage.dynamodb_table` so the library can keep it in DynamoDB.
- `PREFLIGHT RE-VERIFICATION IS OFF (D-79) …` at boot, and `q.Healthy()` reporting not healthy: your counters are on Redis and no background reconciler is running, so the Redis safety checks run only at boot. To turn it on, pass `Options.ReconcileOrgs` (a function returning the org ids to reconcile) and declare DynamoDB as above. `quotactl capabilities` and `doctor` print it too, because they never start background loops.
- Drift repaired constantly for a gauge: a termination path misses `Release`. Find it; reconcile is the safety net, not the fix.
- `tier_lookup_failing_sustained` ERROR: billing/JWT lookups failing for a while; the cache is serving last-known-good. Check the provider URL/token.
- Kill switch on and customers see `429`s with reason `global_kill_switch`: that is what you asked for; flip it back with a deploy when safe.

## Coming

- **Flip shadow/enabled/kill switch without a redeploy.** *Today:* config + deploy.
- **Alert dispatchers beyond one webhook** (Slack/PagerDuty/log). *Today:* one `webhook_url`; fan out on your side.
- **A hosted usage/denials dashboard per org.** *Today:* your `OnDecision` logs.
- **`quotactl events` reading the production ledger.** *Today:* the CLI cannot reach it (v0.1.10 refuses with a non-zero exit; v0.1.9 reads an empty in-memory stub); use `q.LedgerStore.QueryByUser` / `QueryByStatus` from your service's admin route.- **Payment's reconciliation items visible to you.** *Today:* ask the platform team.

## Next

SOP 14, changing things safely.
