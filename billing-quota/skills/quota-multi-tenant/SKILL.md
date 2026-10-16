---
name: quota-multi-tenant
description: >-
  Keep every customer's limits, counters and money on their own org when one service serves many
  customers on the ab0t mesh: org_id from the validated token, the customer's org in the path,
  per-org counters with optional per-user caps, grant dedup per org vs per user, workspace-per-user
  products, fail-closed on spend, and a five-step isolation self-check. Use for "tenant isolation",
  "can one customer see or spend another's", "usage landing on the wrong org", "per-user limits
  inside an org", "B2B vs B2C dedup". Routes to billing-quota SOP 12.
---

# One service, many customers

## What this is

Your service uses one billing key and one payment key for all of its customers, so correctness
rests on one habit: the customer's org always comes from their validated token. Billing, payment and
the quota library then keep each customer's counters, balance and plan apart for you.

## The picture

```
customer A token ─► your API: org_id = token.org_id (A) ─► quota counters for org A
                                                     └─► /billing/A/…, /checkout/A/…   (X-API-Key: your key)
customer B can never reach A: not through your API (you ignore any org in the request),
not through billing/payment (another org needs the cross-customer tier, and A's admins cannot grant it)
```

| level | how it is kept apart |
|---|---|
| quota counters | partitioned by org; optional per-user caps (`per_user_limit`, `default_per_user_fraction`) |
| credit grants | `dedup`: `per_org_per_tier` (B2B: one per company) or `per_user_per_tier` (B2C: one per person) |
| billing and payment | the org in the path; a body `org_id` must match it; another org needs the provider's tier |

## Do this (the default path)

1. `Identity` returns the user and org from your auth middleware's validated token (SOP 05).
2. Every proxy route builds `/billing/<org>/…` and `/checkout/<org>/…` from that same org (SOP 07).
3. Pick the grant `dedup` for your market (SOP 04, 10).
4. Workspace-per-user products: the tier and the balance belong to the workspace org; make sure
   users' tokens are scoped to their workspace (Ally SOP 09; SOP 12 rule 6).
5. Run the five-step self-check on staging (SOP 12 "Steps").

## What your customers notice

Their own usage bar, plan and balance, and nobody else's. A request that tries another org gets your
API's normal answer for their own org (or a `403`), never another customer's data.

## Common mistakes (and what you will see)

| mistake | what you see | fix |
|---|---|---|
| `Identity` returns your service's own org or a shared parent | everyone's usage on one counter and one balance | use the token's org |
| an org id read from a query parameter | a customer can act on another's account | ignore it; use the token |
| per-user counters expected for an accumulator | per-user caps apply to gauges only | per-org limits, or a gauge |
| `per_user_per_tier` on a B2B product | each employee collects the sign-up gift | `per_org_per_tier` |

## Check it worked

SOP 12's self-check: as A, read B through your proxy and get A's data or `403`; spend in A and see
B's `X-Quota-Used` unchanged; grant twice and see `already granted`. Questions:
`platform-team@ab0t.com`.

SOPs: [12 multi-tenant correctness](../../12_sop_system_multi_tenant_correctness.md) ·
[05 wire the library](../../05_sop_system_wire_the_library.md) · skill `mesh-tenancy-authority`.
