---
name: ab0t-quota-go-testing
description: >-
  Prove an ab0t-quota-go integration works before customers depend on it: Go unit tests with
  quota.Setup + ConfigOverride (no network), httptest for the guard (allowed, 429, exempt), a signed
  auth-event test that grants credit exactly once, curl smoke tests against staging, the shadow day,
  and the nine-item acceptance list before enforcing. Use when writing tests for the quota library,
  generating signed webhook fixtures, building a pre-launch test plan, or debugging "test passes
  locally but not in staging", "webhook 401/404 in tests", "credit granted twice". The test file
  below runs green against v0.1.9.
---

# Testing a quota integration

## What this is

A short ladder of checks, from a unit test on your laptop to a day of shadow traffic, so the first
`429` a real customer sees is one you meant. Everything below runs without billing, payment or a
real Redis until the staging step.

## The picture

```
1 unit tests (go test, memory://)  →  2 curl smoke on staging  →  3 shadow day  →  4 acceptance list  →  enforce
   guard: 200 / 429 / exempt           headers, 401 bad sig, 200 good sig   would-denies per tier   SOP 06 step 4
   receiver: one grant per event
```

## Do this (the default path)

**1. Unit tests.** This file runs green against v0.1.9 (`go test ./...`). Note the two things tests
most often get wrong: `storage.redis_url` is required even in tests (declare `memory://`), and
`AB0T_AUTH_WEBHOOK_SECRET` is read by `Setup`, so set it before calling `Setup`.
```go
package yourpkg

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"

	"github.com/ab0t-com/ab0t-quota-go/authevents"
	"github.com/ab0t-com/ab0t-quota-go/config"
	"github.com/ab0t-com/ab0t-quota-go/engine"
	"github.com/ab0t-com/ab0t-quota-go/quota"
)

type ctxKey struct{}

func testConfig(withGrant bool) *config.Config {
	limit := 2.0
	free := config.Tier{TierID: "free", Limits: map[string]config.TierLimit{"api.calls": {Limit: &limit}},
		UpgradeURL: "https://example.test/upgrade"}
	if withGrant {
		free.CreditGrant = &config.CreditGrant{Trigger: config.CreditTriggerSignup,
			AmountPerPeriod: config.NewDecimal("5.00"), Dedup: config.DedupPerUserPerTier}
	}
	return &config.Config{
		Enforcement:  config.EnforcementConfig{Enabled: true},
		TierProvider: config.TierProviderConfig{Type: "static", DefaultTier: "free"},
		Storage:      config.StorageConfig{RedisURL: config.Declare("memory://")}, // required, even in tests
		Tiers:        []config.Tier{free},
		Resources:    []config.ResourceDef{{ResourceKey: "api.calls", CounterType: config.CounterAccumulator, ResetPeriod: "daily"}},
	}
}

func newServer(t *testing.T, q *quota.Quota) http.Handler {
	t.Helper()
	mux := http.NewServeMux()
	ok := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	guard := q.Middleware(quota.MiddlewareDeps{
		Identity: func(r *http.Request) (string, string, error) {
			u, _ := r.Context().Value(ctxKey{}).(string)
			return u, "org-a", nil
		},
		Router: func(r *http.Request) (string, float64) { return "api.calls", 1 },
		Exempt: []string{"/healthz"},
	})
	mux.Handle("/api/", guard(ok))
	mux.Handle("/healthz", ok)
	mux.Handle("/api/quotas/", http.StripPrefix("/api/quotas", q.WebhookHandler()))
	return mux
}

func get(srv http.Handler, path, user string) *httptest.ResponseRecorder {
	req := httptest.NewRequest("GET", path, nil)
	req = req.WithContext(context.WithValue(req.Context(), ctxKey{}, user))
	rec := httptest.NewRecorder()
	srv.ServeHTTP(rec, req)
	return rec
}

func TestGuard(t *testing.T) {
	q, err := quota.Setup(context.Background(), quota.Options{ConfigOverride: testConfig(false)})
	if err != nil {
		t.Fatal(err)
	}
	defer q.Close(context.Background())
	srv := newServer(t, q)

	// under the limit: allowed, with headers
	rec := get(srv, "/api/x", "alice")
	if rec.Code != 200 || rec.Header().Get("X-Quota-Tier") != "free" {
		t.Fatalf("want 200 + X-Quota-Tier, got %d %v", rec.Code, rec.Header())
	}
	// fill the counter to the limit, then expect a 429 with the upgrade link
	if _, err := q.Spend(context.Background(), engine.CheckInput{UserID: "alice", OrgID: "org-a", ResourceKey: "api.calls", Cost: 2}); err != nil {
		t.Fatal(err)
	}
	rec = get(srv, "/api/x", "alice")
	var body map[string]any
	_ = json.NewDecoder(rec.Body).Decode(&body)
	if rec.Code != 429 || body["reason"] != "exceeded" || body["upgrade_url"] == nil {
		t.Fatalf("want 429 exceeded + upgrade_url, got %d %v", rec.Code, body)
	}
	// exempt path: no quota headers
	if rec := get(srv, "/healthz", ""); rec.Code != 200 || rec.Header().Get("X-Quota-Tier") != "" {
		t.Fatalf("healthz should be exempt, got %d %v", rec.Code, rec.Header())
	}
}

type stubGranter struct{ calls atomic.Int32 }

func (g *stubGranter) GrantCredit(_ context.Context, in authevents.CreditGrantRequest) error {
	g.calls.Add(1)
	return nil
}

func TestSignupCreditOnceAndBadSignature(t *testing.T) {
	t.Setenv("AB0T_AUTH_WEBHOOK_SECRET", "test-secret") // read by Setup: set it first
	authevents.ClearHandlers()                          // the handler registry is package-wide
	gr := &stubGranter{}
	q, err := quota.Setup(context.Background(), quota.Options{ConfigOverride: testConfig(true), CreditGranter: gr})
	if err != nil {
		t.Fatal(err)
	}
	defer q.Close(context.Background())
	srv := newServer(t, q)

	body := []byte(`{"event_type":"org.created","event_id":"evt-1","data":{"user_id":"alice","org_id":"org-a"}}`)
	post := func(sig string) *httptest.ResponseRecorder {
		req := httptest.NewRequest("POST", "/api/quotas/_webhooks/auth", bytes.NewReader(body))
		req.Header.Set("X-Event-Signature", sig)
		rec := httptest.NewRecorder()
		srv.ServeHTTP(rec, req)
		return rec
	}
	for i := 0; i < 3; i++ { // the same event three times: one grant
		if rec := post("sha256=" + authevents.SignBody(body, "test-secret")); rec.Code != 200 {
			t.Fatalf("want 200, got %d %s", rec.Code, rec.Body.String())
		}
	}
	if n := gr.calls.Load(); n != 1 {
		t.Fatalf("want exactly 1 grant, got %d", n)
	}
	if rec := post("sha256=deadbeef"); rec.Code != 401 {
		t.Fatalf("bad signature: want 401, got %d", rec.Code)
	}
}
```

**2. Smoke tests against staging** (never production):
```sh
SVC=https://<your staging host>; SECRET="$AB0T_AUTH_WEBHOOK_SECRET"
curl -sI "$SVC/healthz" | grep -ci x-quota                                    # 0: exempt
curl -sI -H "Authorization: Bearer $USER_TOKEN" "$SVC/api/<route>" | grep -i x-quota
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$SVC/api/quotas/_webhooks/auth" \
  -H 'X-Event-Signature: sha256=deadbeef' -d '{"event_type":"org.created","event_id":"e1"}'   # 401
BODY='{"event_type":"x.test","event_id":"e-'$RANDOM'"}'
SIG=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | sed 's/^.* //')
curl -s -X POST "$SVC/api/quotas/_webhooks/auth" -H "X-Event-Signature: sha256=$SIG" -d "$BODY"   # {"event_type":"x.test","status":"ignored"}
```
A `404` on the last two means the receiver is mounted without `http.StripPrefix`.

**3. A shadow day and 4. the acceptance list:** SOP 06 steps 1–4 (count `shadow_would_deny` per
resource and tier, prove one real sign-up grants once, force one deny, rehearse the rollback).

## What your customers notice

Nothing while you test, provided tests run on dev/staging: journeys and replays create real data and
real credit on whatever they point at.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| test config without `storage.redis_url` | `ab0t-quota-go config error [QUOTA-CFG-001] …` from `Setup` | `config.Declare("memory://")` |
| secret set after `Setup` | every test event `401` | `t.Setenv` before `Setup` |
| two tests registering handlers | a test sees another's grants | `authevents.ClearHandlers()` per test |
| posting to `/_webhooks/auth` through a mux mounted at the full path | `404 page not found` | `http.StripPrefix` as above |
| `t.Context()` | does not compile before Go 1.24 | `context.Background()` |
| reading the ledger with `quotactl events` | nothing (in-memory stub) | assert on your granter, or read through your service |

## Check it worked

`go test ./...` green; the staging smoke lines give `0`, headers, `401`, `ignored`; SOP 06's nine
items ticked. Still stuck: send the failing test output and your `quotactl capabilities` (no secrets)
to `platform-team@ab0t.com`.

SOPs: [05 wire the library](../../05_sop_system_wire_the_library.md) ·
[06 shadow then enforce](../../06_sop_system_shadow_run_then_enforce.md) ·
[10 credits and auth events](../../10_sop_system_credits_grants_auth_events.md) ·
[17 troubleshooting](../../17_sop_system_troubleshooting.md).
