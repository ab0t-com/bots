# 06 · Shadow run, then enforce

**What this is for.** Finding out what your limits would do to real traffic before a single customer sees a `429`, then turning enforcement on with a rollback you have already rehearsed.

**Before you start.** SOP 05 deployed to `dev`/staging with `"enforcement": {"enabled": true, "shadow_mode": true}`. Logs you can grep. A day of representative traffic.

## Steps

**1. Confirm you are in shadow.**
```sh
quotactl capabilities --config ./quota-config.json | jq '{Enforcement, ShadowMode, Billing, CreditGrant, WhyOff}'
```
Expect `Enforcement: true`, `ShadowMode: true`. In shadow, a would-be denial is **allowed** and tagged `X-Quota-Reason: shadow_would_deny` (or `shadow_would_deny_per_user`) with the message `Shadow mode: would-deny invoicer.invoices (21/20) but allowing.` One exception is deliberate: `tier_not_in_config` still denies, because a tier your config does not know is a bug, not a limit.

**2. Watch for a calendar day.** Count would-denies per resource and tier:
```sh
grep '"reason":"shadow_would_deny"' /var/log/invoicer/*.log | jq -r '"\(.resource) \(.tier)"' | sort | uniq -c | sort -rn
grep '"reason":"shadow_would_deny"' /var/log/invoicer/*.log | jq -r .user_id | sort | uniq | head
```
If the rate is far above what your pricing expects, the limits are too tight; if zero, check that `Router` returns the keys you think (`X-Quota-Resource` on a few requests).

**3. Prove the money path in staging** (if you grant credit or bill; SOPs 10–11): one real sign-up fires the credit grant once; the same event replayed does not fire again; a forced denial carries `upgrade_url`.

**4. Run the acceptance list.** All nine, written down:
1. `quotactl capabilities` shows every capability you rely on as `true`, `WhyOff` empty for them.
2. The curl smoke tests from SOP 05 step 5 pass against staging.
3. One day of shadow with no unexpected `shadow_would_deny`.
4. A real auth event fired the credit grant and billing's balance rose once.
5. The same event replayed changed nothing.
6. A forced deny returns `429` with `upgrade_url`.
7. Dashboards show real numbers; one alert fired correctly (SOP 13).
8. `quotactl doctor --config ./quota-config.json` exits `0` (production posture: persistence, eviction, PITR, TLS).
9. **Rollback drill:** set `shadow_mode: true`, redeploy, confirm `429`s stop within 60 s.

**5. Flip.** `"shadow_mode": false`, deploy, watch the `429` rate and the alert webhook for the first hour.

**6. Keep the emergency brake in mind.** `"enforcement": {"global_kill_switch": true}` makes the library **deny everything** (`429`, reason `global_kill_switch`, message `Quota enforcement halted by global kill switch.`), on purpose, for a runaway-cost emergency. Go v0.1.9 and Python v0.6.7 behave the same here. To stop denying instead, use `shadow_mode: true` (allow, keep counting) or `enabled: false` (allow, stop counting). Redeploy either way. (Some older Python documentation describes the kill switch as *disabling* checks; the code denies.)

## What you'll see

Shadow: `200` with `X-Quota-Reason: shadow_would_deny` and a log line per would-deny. Enforced: `429` bodies as in SOP 05, `Retry-After` on rate counters, warnings in `X-Quota-Warning` as users approach `warning_threshold` (0.80) and `critical_threshold` (0.95). `doctor` prints `DOCTOR POSTURE — grades are remediation advice; the exit code is the boot verdict` and ends `DOCTOR VERDICT: exit N` (`0` ok, `1` gate refusal, `2` config, `3` unreachable, `4` internal; `--fail-on-risk` turns risk findings into exit 1; `--json` for CI).

## If it goes wrong

- Still no `429` after the flip: the config that shipped still says `shadow_mode: true`, or `enabled` is absent (allows everything, `enforcement_disabled`). `capabilities` tells you which.
- Denials with `reason: tier_not_in_config`: your tier provider returned an id (`"starter"`) your `tiers[]` does not list. Add the tier or fix the mapping; this never softens in shadow.
- Everything allowed with `reason: tier_unresolved`: `Identity` returned no user/org or the tier lookup failed; the library fails open here. Check the auth middleware runs first and the JWT carries `jwt_claim_key`.
- A gauge over-counts (seats never go down): a termination path forgot `Release`. `q.Engine.ReconcileOrg(ctx, orgID, "")` repairs from your truth provider (SOP 13); never `redis-cli SET` a counter.
- `doctor` exits `2` (`CONFIG ERROR — nothing was contacted:`) or `3` (`REACHABILITY (exit 3, never a gate verdict):`): config or network, not posture. Fix and re-run.
- `doctor`/`capabilities` created DynamoDB tables you did not want: they run the real boot; declare DynamoDB only where you mean it.

## Coming

- **A read-only `capabilities`/`doctor`** that never connects or creates tables. *Today:* both perform the boot's one-shot verification.
- **A hosted shadow report** (would-denies per resource/tier/org) instead of grepping logs. *Today:* the `jq` lines above or your `OnDecision` hook.
- **A kill switch flipped without a redeploy.** *Today:* edit, redeploy.

## Next

SOP 07, plans, prices, checkout and the portal. Or SOP 11 if you bill usage directly.
