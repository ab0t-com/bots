# 14 · Changing things safely

**What this is for.** Day two for quota and money: raising or lowering a limit, adding a resource, renaming a tier, changing a price, moving a counter's meaning. Which changes are free, which need shadow first, and which you must not make in place.

**Before you start.** A working deployment (SOP 06). The rollback drill done once (set `shadow_mode: true`, deploy, `429`s stop within 60 s).

## The loop

```
edit quota-config.json → quotactl capabilities --config … (loads it; connects to Redis) → deploy to staging
→ shadow if limits moved down → watch a day → deploy to prod → watch the 429 rate and alerts
```
There is no offline validator yet (SOP 04 Coming); the library's start-up is the validator and it refuses loudly.

## Steps by kind of change

**1. Raise a limit.** Safe at any time; deploy. Customers under the new limit stop getting `429`s on the next request.

**2. Lower a limit.** Shadow first: set the new number with `shadow_mode: true`, count `shadow_would_deny` by org for a day (SOP 06), warn affected customers, then enforce.

**3. Add a resource.** Add it to `resources[]` **and** to every tier's `limits` (or omit for unlimited) **before** your `Router` returns its key: a key the config does not know is an engine error (`engine: unknown resource_key "…"`) and, fail-closed, a `503` for that route. Deploy config before code, or in the same release with the Router change behind a flag.

**4. Remove a resource.** Reverse order: stop routing to it first, then delete it from the config. Its counters expire with their TTL (rate) or sit idle (gauge/accumulator); nothing deletes them.

**5. Rename a tier or a resource key.** Treat as remove + add. Counter keys include the resource key; grant dedup keys include the tier id. A rename makes every customer look fresh (new counters, grants eligible again). If you must rename, do it at a period boundary and tell the platform team to re-map prices to the new tier id (SOP 08 step 2).

**6. Change a counter's type** (gauge ↔ accumulator ↔ rate). **Do not do this in place.** They measure different truths and fail in opposite directions; the old counters become meaningless. Add a new resource key with the new type, run both, retire the old.

**7. Change a price or add a plan.** In payment (SOP 07): add a new price, keep the old active until existing subscribers roll over; a changed `amount` on a live price is a new price in Stripe anyway. Then update the price → tier map with the platform team (SOP 08 step 2) **before** the first customer buys it, or their tier stays unchanged.

**8. Change a credit grant.** Amount changes take effect at the next trigger. Changing `dedup` or `destination` changes the dedup key or the bucket: customers already granted under the old key may be granted again. Do it deliberately at a period boundary.

**9. Change tier thresholds or `upgrade_url`.** Free; deploy.

**10. Move Redis or change the keyspace.** The library namespaces counters in keyspace v1 by default. Moving to v2 (service-segmented keys) is a declared migration: set `service_name`, then `storage.keyspace_dual_write: true` for a period, then `storage.keyspace_version: 2`. Skipping steps trips the boot guard (`KEYSPACE BOOT GUARD refused to start (K-8, spec §3.3)`; `QUOTA-CFG-011/012`). Never change `storage.redis_key_prefix` (only `"quota"` is permitted).

**11. Turn paid mode on.** `"billing": {"enable_paid": true}` plus the outbox gates in SOP 11 step 6. Do it on staging with billing's dev host first; the refusal text names exactly which link is missing.

**12. Anything in the money services.** Tier by hand: SOP 09 step 4 (`PUT /billing/{org}/tier` with a reason; it is audited). Credits: SOP 10 step 6 (idempotency key). Never a direct database edit, never a `redis-cli SET` on a counter (SOP 13).

## What you'll see

A clean deploy logs the capability line with the new values. After lowering a limit in shadow, `shadow_would_deny` counts tell you exactly who is affected before anyone is. `quotactl capabilities` prints `Resolved` (where each value came from: config key, env var, or unset; secrets presence-only) so you can confirm the deployed file is the one you edited.

## If it goes wrong

- `503 {"detail":"quota engine error"}` after a release: a route now returns a key the config lacks (step 3). Roll the code back or hot-add the resource.
- Customers blocked after a limit change: shadow was skipped; set `shadow_mode: true`, deploy (the rehearsed rollback), then do step 2 properly.
- Everyone's counters reset to zero: a resource key or `service_name`/keyspace change (steps 5, 10). Nothing is lost in billing; only the quota window restarted.
- `quota.Setup: storage.redis_key_prefix="…" is not permitted …`: remove the prefix.
- Grants fired twice after a config change: the dedup key changed (step 8). Stop, reconcile the affected orgs' credit with the platform team, then redeploy with a stable policy.

## Coming

- **`quotactl validate` (offline) and `quotactl diff`** (what this config change does to live counters/grants). *Today:* reasoning by the rules above; `capabilities` connects.
- **Config hot-reload** without a redeploy. *Today:* every change is a deploy.
- **Price/tier map you own** (SOP 08 Coming). *Today:* coordinate every new price with the platform team.
- **Counter migration tooling** for a type change or rename. *Today:* add new, run both, retire old.

## Next

SOP 15, keys and offboarding.
