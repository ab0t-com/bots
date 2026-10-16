# 16 · Migrations and upgrades

**What this is for.** Moving the quota library forward without surprises, moving from the Python runtime to the Go one (or running both), keeping up with billing and payment API changes, and the counter keyspace migration.

**Before you start.** A clean build and a passing test suite. The library's `CHANGELOG.md` open. A staging environment.

## Steps

**A. Upgrade `ab0t-quota-go`.**
1. The version is the git tag only; there is no version file. `go list -m github.com/ab0t-com/ab0t-quota-go` shows yours; the repository's tags show the latest (v0.1.9 at writing).
2. **Read every CHANGELOG entry between you and the target before touching `go.mod`.** The project is pre-1.0 and has shipped action-required changes as patch versions (v0.1.5 says so itself). Known action-required notes:
   - v0.1.4: paid mode needs a durable outbox (DynamoDB, or Redis you confirm durable), `outbox.sns_topic_arn`, no custom Redis prefix, Redis confirmed non-clustered.
   - v0.1.5: an undeclared counter store refuses to start (`QUOTA-CFG-001`); a declared-but-unreachable Redis retries then refuses instead of degrading to memory; invented AWS regions removed (`QUOTA-CFG-009/010`); the generic `AUTH_SERVICE_URL` fallback removed; a `redis_password` vs URL-password conflict warns.
   - v0.1.7: recount-before-deny is type-aware (gauge fails open, meter keeps the deny); observed usage is org-total only.
   - v0.1.8–0.1.9: last-known-good tier moved to Redis (cross-runtime), sustained tier-lookup failure signal.
3. `go get github.com/ab0t-com/ab0t-quota-go@v0.1.9 && go mod tidy && go build ./... && go vet ./... && go test ./...`.
4. `quotactl capabilities` (same version) on staging; compare the capability line with the previous one; then the shadow-day if any enforcement semantics changed.
5. Upgrade `quotactl` to the same tag (`go install …/cmd/quotactl@v0.1.9`).

**B. Python ↔ Go.** The same `quota-config.json` drives both; Redis key shapes, grant dedup keys and the last-known-good tier record are shared, so a Python service and a Go service can run side by side on one Redis. The known differences, so you are not surprised:

| topic | Python `ab0t-quota` (0.6.7) | Go `ab0t-quota-go` (0.1.9) |
|---|---|---|
| mesh env vars | `AB0T_MESH_API_KEY`, `AB0T_CONSUMER_ORG_ID` | `AB0T_QUOTA_BILLING_URL/_TOKEN`, `AB0T_QUOTA_PAYMENT_URL/_TOKEN`, `AB0T_QUOTA_SERVICE_TOKEN` |
| `engine_mode: "bridge"` (hosted enforcement) | yes | refused: `out of scope for v0.1.0` |
| `storage.redis_url: "memory://"` | refused (`QUOTA-CFG-005`) | allowed for one dev process |
| `enforcement.shadow_mode`, `global_kill_switch` | honoured (kill switch denies, as in Go) | honoured |
| missing `tiers[]` | `QUOTA-CFG-004` | `config: tiers[] is required` |
| `redis_key_prefix` | default `quota` | must be `quota` or absent |
| CLI | `python -m ab0t_quota provision\|preflight\|doctor\|events\|replay\|backfill` | `quotactl subscribe-events\|events\|replay\|backfill\|delete-user\|capabilities\|doctor\|provision` |
| default JWT tier claim | documented as `org_tier` in some templates | `tier` (`jwt_claim_key` to change) |

The Go repository's `MIGRATION_FROM_PYTHON.md` tail ("Redis/ledger wire in v0.2") is stale; v0.1.9 has them.

**C. Billing and payment API changes.** The ones that already bit consumers: money-in routes require a non-blank `idempotency_key` (`422` without); `commit` and `settle` want the **inputs** (`started_at`, `stopped_at`, `hourly_rate`, `allocation_fee`), not a cost; `settle` answers `settled`/`already_accounted` and a `409` must not be interpreted. Payment: amounts are dollars; enum values are lower case; the plan-checkout response key is `url`. Ask support (`platform-team@ab0t.com`) to send you billing and payment change notes.

**D. Keyspace v1 → v2** (service-segmented counter keys; needed before two services share one Redis safely). Declare `service_name`; set `storage.keyspace_dual_write: true` and run through one full period; then `storage.keyspace_version: 2`; later drop dual-write. The boot guards refuse out-of-order steps (`KEYSPACE BOOT GUARD refused to start (K-8, spec §3.3)`; `QUOTA-CFG-011` version regression, `QUOTA-CFG-012` brownfield orphaning). Dual-write against a store without dual-op support is refused at runtime.

**E. Moving an existing metering integration onto the library.** Keep your direct billing calls (SOP 11) for reservations and settlements; let the library take the per-request check/spend path first in shadow; turn on paid mode only when the outbox gates are met. Do not run two writers of usage for the same resource at once (double billing).

## What you'll see

After an upgrade: the same capability line, or new `WhyOff` entries naming what the new version now requires (`outbox …`, `QUOTA-CFG-00x`). After keyspace dual-write: counters appear under both key shapes until you flip.

## If it goes wrong

- Service refuses to boot after a bump with a `QUOTA-CFG-00x` message: the changelog told you; the message names the config key, the env var, and the remedy.
- `quota.Setup: enable_paid but the billing chain is SEVERED — …`: a gate from v0.1.4; fix the named link or `outbox.allow_ephemeral: true` in dev only.
- Counters appear to reset after an upgrade: a keyspace change (D) or a renamed resource (SOP 14). Billing is unaffected.
- Python and Go disagree on a decision for the same org: check both deploy the same `quota-config.json` and the versions in the table, and that both see the same tier (same tier provider and claim) before suspecting Redis.

## Coming

- **Migration kits with a checker per breaking release**, as `auth-sdk-go` ships. *Today:* the CHANGELOG and this SOP.
- **Semver that signals breakage** (minor for breaking). *Today:* read every entry.
- **Go supporting bridge mode.** *Today:* the table above.
- **A published change feed for billing and payment.** *Today:* ask support for change notes.

## Next

SOP 17, troubleshooting.
