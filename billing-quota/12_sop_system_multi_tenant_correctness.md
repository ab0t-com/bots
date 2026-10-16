# 12 · Multi-tenant correctness

**What this is for.** One key, many customers. Every number you count and every dollar you charge must land on the right org, and no customer may ever reach another's. These are the rules; most are enforced by the servers, the rest by you.

**Before you start.** SOPs 05 and 11. Your auth middleware returns a validated `user_id` and `org_id` per request (Ally SOP 06).

## The rules

**1. `org_id` comes from the validated token, never from the request.** Not a query param, not a header, not a body field a client can set. Your `Identity` callback and your proxy routes read it from what `ValidateToken` returned. Billing double-checks: a body `org_id` that differs from the path is `400 Request body org_id does not match URL path`.

**2. The customer's org goes in the path; your key goes in the header.** `/billing/<customer org>/…`, `/checkout/<customer org>/…`, `X-API-Key: <your key>`. Never forward the customer's bearer token to billing or payment: wrong audience, wrong permissions.

**3. Reaching another org is a capability, not a permission list.** Billing and payment let a key touch a different org only if the key holds the cross-customer capability (the approved term is the provider's `scope: "platform"` tier; the servers still name the legacy permissions in their `403` bodies), or, on billing, if your org is an **ancestor** of the target in the org tree (parent → child, never child → parent). An org admin's own permissions (`billing.admin`, `payment.admin`) never cross orgs. Customers' admins can never grant themselves the capability.

**4. Some things stay with the customer even for a gateway.** Payment refuses cross-org writes to payment methods (`Cross-organization payment method operations are not supported`): cards are managed by the customer in the portal. Billing refuses value an org issues to itself (`An organization cannot issue value to itself`): credits and tier changes come from your service identity, not from the customer's own session.

**5. Count at the right level.** The quota engine partitions counters by org, with optional per-user sub-limits. Pass both ids every time. Choose the dedup policy for grants deliberately: `per_user_per_tier` for B2C (one gift per human per tier), `per_org_per_tier` for B2B (one per company). The library's partition is by org; the Python runtime shares the same key shapes, so the two can share Redis.

**6. Workspace-per-user products.** If each user has a private org (Ally SOP 09), the tier and the balance belong to the **workspace**, not the shared parent. Make sure the token your users carry is scoped to the workspace (`default_landing: "workspace"`), or your `Identity` callback picks the wrong org and one user's usage lands on the shared pool.

**7. Fail closed on spend, open on release.** `FailOpen: false` (the default) on anything that creates cost: a `503` is better than free compute. `FailOpen: true` only on release/cleanup hooks so a Redis blip cannot leak a seat forever. Recount-before-deny follows the same logic: a gauge outage fails open, an accumulator outage keeps the deny.

**8. Never leak the upstream.** Log billing/payment errors server-side; return your own generic message to the browser. The two services' error bodies contain org ids and permission names your customers do not need.

## Steps (a self-check you can run on staging)

1. Two test orgs A and B, a user in each. As A, call your API: `X-Quota-*` headers name A's tier; `GET /billing/<A>/balance` through your proxy returns A's balance.
2. As A, try to read B through your proxy (`/api/billing/balance?org_id=<B>` or whatever shape your routes have): your proxy must ignore the param and answer with A's data, or `403`.
3. Spend in A; confirm B's counter did not move (`X-Quota-Used` on B's next request).
4. Grant a sign-up credit twice for the same user: the second is `already granted`.
5. With a key that lacks the capability, call `GET /billing/<B>/tier` directly: expect `403 "Access denied - different organization"`. With the capability: `200`.

## What you'll see

Billing's `403` bodies: `{"error":"PERMISSION_DENIED","message":"Access denied - different organization","details":{"required":"billing.cross_tenant"}}` and `"Access denied - missing resource organization"`. Payment's: `"Access denied to organization data"`, `"Organization access denied"` (plan checkout). Both prove isolation works; neither is something your customers should ever see.

## If it goes wrong

- Usage from several users lands on one org: your `Identity` returns the service's own org or a shared parent. Log the pair for one request and compare with the token's claims.
- A customer sees another customer's plan list: `GET /checkout/{org}/plans` is public; make sure you pass **your** org (the plan owner), not the caller's, and return only what you intend to sell.
- `403` for your own org on a money-in route (`credit`, `tier`): the self-funding rule; call it as your service identity for a *customer* org.
- A gauge leaks across tenants after a crash: pair every acquire with a release on all exit paths and wire `ObservedUsageProvider` so reconcile can repair (SOP 13).

## Coming

- **A bounded cross-customer grant on billing** (serve only the orgs you serve), as payment already models with `payment.cross_org.{org_id}`. *Today:* the capability is not yet limited to the orgs you serve, so rules 1 and 2 are what keep each customer's money on their own org; the server's `403` still names legacy permission ids.
- **Gateway-managed payment methods bound to the customer's Stripe customer.** *Today:* portal only.
- **Tier inheritance down the org tree.** *Today:* per org.
- **Legacy names removed from server error bodies.** *Today:* `details.required` says `billing.cross_tenant`.

## Next

SOP 13, observability, alerts, the kill switch and reconciliation.
