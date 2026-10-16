# 05 · Wire the quota library into your service

**What this is for.** Putting the quota decision in front of your API: a middleware that checks the caller's org and tier against `quota-config.json`, adds `X-Quota-*` headers, and denies with a `429` your frontend can show. Go first (`ab0t-quota-go`), then the Python equivalent (`ab0t-quota`).

**Before you start.** SOP 04's `quota-config.json`. A Redis your service can reach (single node, no eviction, Lua allowed), or `"memory://"` for a single dev process. Your auth middleware already validates the bearer token (Ally SOP 06); the quota library **never parses JWTs itself**.

## Steps (Go)

**1. Install, pinned.** The library is pre-1.0; the version lives in the git tag and breaking changes have shipped as patches, so pin and read the changelog on every bump (SOP 16).
```sh
go get github.com/ab0t-com/ab0t-quota-go@v0.1.9
go install github.com/ab0t-com/ab0t-quota-go/cmd/quotactl@v0.1.9      # the companion CLI
```
One warning before you read anything else in that repository: its `README.md` "minimal example" (`quota.Config{…}`, `qctx.Mount`, `CheckBundle`, `quota.WriteDenial`) and its env-var table describe an older API and do **not** match the v0.1.9 code. The real surface is below (compiled against v0.1.9) and in `examples/basic/main.go`.

**2. Start it and guard your routes.**
```go
import (
    "github.com/ab0t-com/ab0t-quota-go/engine"
    "github.com/ab0t-com/ab0t-quota-go/quota"
)

q, err := quota.Setup(ctx, quota.Options{ConfigPath: "quota-config.json"})
if err != nil { log.Fatal(err) }                      // refuses to start on a bad config or an undeclared Redis
defer q.Close(context.Background())

guard := q.Middleware(quota.MiddlewareDeps{
    Identity: func(r *http.Request) (userID, orgID string, err error) {
        a := actorFrom(r.Context())                   // what your auth middleware stored after ValidateToken
        return a.UserID, a.OrgID, nil
    },
    Router: func(r *http.Request) (resourceKey string, cost float64) {
        switch {
        case r.Method == "POST" && r.URL.Path == "/api/invoices": return "invoicer.invoices", 1
        default:                                                  return "invoicer.api.requests", 1
        }                                              // return "" to skip quota for a route
    },
    Exempt:   []string{"/healthz", "/api/quotas/"},
    FailOpen: false,                                   // 503 when the engine cannot decide; true = let it through
})
mux.Handle("/api/", guard(apiHandler))
mux.Handle("/api/quotas/", http.StripPrefix("/api/quotas", q.WebhookHandler()))   // receives /api/quotas/_webhooks/auth (SOP 10)
```
`Identity` and `Router` are required; the guard panics at construction without them (`middleware.Guard: Identity required`). The bearer token is placed in the request context for the `jwt` tier provider.

Mount the auth-event receiver exactly as shown, with `http.StripPrefix`. The receiver answers on its own path (`/_webhooks/auth`), so `mux.Handle("/api/quotas"+authevents.WebhookPath, q.WebhookHandler())` (the form in the library's own examples) answers every event with `404 page not found` and no sign-up credit is ever granted.

**3. Spend after the work.** The guard only **checks**. Counters move only when you say so. `Spend` returns the new running total and an error; `Release` returns an error:
```go
// after the invoice was really created:
if _, err := q.Spend(r.Context(), engine.CheckInput{UserID: a.UserID, OrgID: a.OrgID, ResourceKey: "invoicer.invoices", Cost: 1}); err != nil {
    log.Printf("quota spend: %v", err) // the invoice exists: log it and reconcile later (SOP 13), do not fail the request
}
// gauges: Spend when a seat is taken, Release when it is freed
if err := q.Release(r.Context(), engine.CheckInput{UserID: a.UserID, OrgID: a.OrgID, ResourceKey: "invoicer.seats", Cost: 1}); err != nil {
    log.Printf("quota release: %v", err)
}
```
Check before, spend after: spending before the work over-counts; checking without spending means counters never advance. Every termination path (delete, crash cleanup, idle timeout) must release gauges.

**4. Point it at Redis and billing.**
```
QUOTA_CONFIG_PATH=/etc/invoicer/quota-config.json      # else ./quota-config.json, then /etc/ab0t/quota-config.json
QUOTA_REDIS_URL=redis://quota-redis:6379/0             # used when storage.redis_url is empty or interpolates it
AB0T_QUOTA_BILLING_URL=https://billing.service.ab0t.com
AB0T_QUOTA_BILLING_TOKEN=<billing key, SOP 03>
AB0T_QUOTA_PAYMENT_URL=https://payment.service.ab0t.com
AB0T_QUOTA_PAYMENT_TOKEN=<payment key, SOP 03>
```
Only names starting `QUOTA_`, `AB0T_QUOTA_`, `AB0T_AUTH_` (and the AWS SDK's) are read. A bare `REDIS_URL` or `AUTH_SERVICE_URL` is ignored. With no billing URL the library starts with billing **off** and says so (`WhyOff: "AB0T_QUOTA_BILLING_URL not set"`).

Setting `AB0T_QUOTA_BILLING_URL` also tells the library you mean to bill (paid mode). Until the durable outbox from SOP 11 step 6 is in place, `Setup` then refuses to start unless your config has `"outbox": {"allow_ephemeral": true}` (SOP 04's example does; dev only), and with it the service starts with billing disabled and `q.Healthy()` reporting not healthy. If you only enforce limits for now, leave the billing URL unset until SOP 11.

**5. Prove it loaded.**
```sh
quotactl capabilities --config ./quota-config.json | jq '.Enforcement, .ShadowMode, .Billing, .Payment, .CreditGrant, .WhyOff'
curl -sI -H "Authorization: Bearer $USER_TOKEN" https://invoicer.dev.acme.example/api/invoices | grep -i x-quota
curl -sI https://invoicer.dev.acme.example/healthz | grep -ci x-quota          # 0: exempt routes carry no headers
```
`capabilities` connects to the declared Redis (PING, script load) and would create DynamoDB tables if you declared them; it starts no background loops.

## Steps (Python, FastAPI)

```
pip install "ab0t-quota[all] @ git+https://github.com/ab0t-com/ab0t-quota.git@v0.6.7"
```
```python
from ab0t_quota import setup_quota
app = FastAPI()
setup_quota(app, enable_paid=False)                # reads quota-config.json (required); limits only, no billing yet

@app.post("/api/invoices")
async def create_invoice(request: Request, user: InvoiceWriter):
    quota = request.app.state.quota
    await quota.check_bundle(user.org_id, "invoice_create", user_id=user.user_id)     # raises HTTP 429 on deny
    inv = await create(...)
    await quota.increment_bundle(user.org_id, "invoice_create", user_id=user.user_id)
    return inv
```
`enable_paid` defaults to `True`, which wires the paid-tier routes and expects `AB0T_MESH_API_KEY` and `AB0T_CONSUMER_ORG_ID`; keep it `False` until SOP 11. Python refuses `"memory://"`, offers `engine_mode: "bridge"` (hosted enforcement, no Redis of your own), and ships `python -m ab0t_quota provision|preflight|doctor|events|replay|backfill`. The same `quota-config.json` works for both runtimes; the known differences are in SOP 16. For anything Python-specific beyond this page, the library's own `README.md` is the reference.

## What you'll see

Start-up logs one line per capability (`ab0t-quota capabilities`), `redis reachability verified (D-2/GT-T1): PING ok`, and `counter store resolved`. Allowed requests carry `X-Quota-Resource`, `X-Quota-Tier`, `X-Quota-Reason: under_limit`, `X-Quota-Limit`, `X-Quota-Remaining`, `X-Quota-Used`; near a threshold also `X-Quota-Warning`. A denial is:
```
HTTP/1.1 429  Content-Type: application/json  Retry-After: …
{"detail":"Quota exceeded for invoicer.invoices: 20/20 (tier: free).","reason":"exceeded",
 "resource":"invoicer.invoices","tier":"free","used":20,"limit":20,"upgrade_url":"https://invoicer.acme.example/upgrade"}
```
Other reasons you will meet: `near_warning`, `near_critical`, `burst_consumed` (allowed, warned), `unlimited`, `shadow_would_deny` (allowed; SOP 06), `tier_unresolved` (allowed, fail-open), `tier_not_in_config` (denied), `global_kill_switch` (denied), `enforcement_disabled` (allowed).

## If it goes wrong

- `ab0t-quota-go config error [QUOTA-CFG-001] — Redis counter store URL is not declared.` — set `storage.redis_url` or `QUOTA_REDIS_URL`; `"memory://"` for one dev process.
- `DECLARED REDIS UNREACHABLE/UNAUTHENTICATED (D-2) — refusing to start` after retrying for `connect_retry_seconds` — the library never degrades to memory silently any more. Fix the URL or the password (`storage.redis_password`; a conflicting URL-embedded password logs a warning).
- `quota: unsafe Redis counter store (eviction)` / `quota: Redis cannot run the counter's Lua scripts` / `quota: unsupported or unverifiable Redis topology` — your Redis violates a gate: no `maxmemory-policy` eviction, scripting allowed, single node (or confirm with `storage.redis_cluster_confirmed_disabled`). `quotactl provision --local` starts a conforming dev Redis on port 6399; `quotactl provision --emit compose|terraform|acl|iam` prints the artefacts for real infra.
- `503 {"detail":"quota engine error"}` on a route — the `Router` returned a `resource_key` that is not in `quota-config.json` (`engine: unknown resource_key`), or Redis failed at runtime, and `FailOpen` is false. Fix the key; keep fail-closed on spend paths.
- `401 {"detail":"identity required"}` — your `Identity` callback returned an error; the auth middleware did not run first.
- Every request allowed with `X-Quota-Reason: enforcement_disabled` — `enforcement.enabled` is missing or false.
- No headers at all — the path is exempt or `Router` returned `""`.
- Auth events to `/api/quotas/_webhooks/auth` answer `404 page not found` — the receiver was mounted without `http.StripPrefix` (step 2).
- `Setup` refuses with `quota.Setup: enable_paid but the billing chain is SEVERED — …` right after you set `AB0T_QUOTA_BILLING_URL` — paid mode is on without a durable outbox (step 4); add `"outbox": {"allow_ephemeral": true}` for dev, or finish SOP 11 step 6.
- Python: `Quota engine not initialized` — Redis URL, DynamoDB table permissions, or JSON syntax; the Python runtime refuses `memory://` (QUOTA-CFG-005).

## Coming

- **A README and example that match the code.** *Today:* use this SOP and `examples/basic/main.go`; ignore the README's `quota.Config`, `Mount`, `CheckBundle`, `WriteDenial`, and its `AB0T_MESH_*` env table.
- **`tier_provider.type: "mesh"` wired by `Setup`.** *Today:* the mesh provider needs a lookup you supply in code (`providers/mesh.go` `SetLookup`), else it returns `default_tier`; prefer `jwt`.
- **A webhook receiver that also answers when mounted at its full path** (as the library's examples do). *Today:* mount it with `http.StripPrefix` (step 2).
- **One env-name set across runtimes.** *Today:* Go `AB0T_QUOTA_*_URL/_TOKEN`, Python `AB0T_MESH_API_KEY`/`AB0T_CONSUMER_ORG_ID`; `connect` prints a third (`BILLING_SERVICE_*`).

## Next

SOP 06, shadow run, then enforce.
