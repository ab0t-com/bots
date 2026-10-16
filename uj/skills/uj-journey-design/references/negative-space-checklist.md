# Negative-space checklist — choosing the abuse cases that matter

A journey that only tests the happy path proves the feature works for people who follow the rules.
The value is often in proving it fails safely for people who don't. Don't test zero abuse cases, and
don't copy the one example blindly — pick the 1–2 that matter for THIS journey.

## The taxonomy (scan all, pick the ones that apply)

| Class | The attacker's move | When it applies to your journey | `abuse:` step shape |
|---|---|---|---|
| **Cross-tenant access** | use org A's identity to read/act on org B | any multi-tenant resource | A's token hits B's resource → `expect: denied` |
| **Privilege escalation** | a low-role user does an admin-only action | anything role-gated | member token does an owner action → `denied` |
| **Unauthenticated access** | no credentials at all on a protected resource | every protected read/write | `bearer: "none"` → `denied` |
| **Revoked / expired credential** | use a credential AFTER it should be dead | logout, revoke, offboard, plan-downgrade flows | revoke → reuse same credential → refused on the next check |
| **IDOR** | guess/enumerate another object's id | anything addressed by id in the path | swap in another id → `denied`/`not-found` |
| **Feature/paywall bypass** | use a paid/gated feature without the entitlement | plan/quota/tier boundaries | free-tier tries premium action → `denied` |
| **Quota / rate bypass** | exceed a limit the product promises to enforce | metered or rate-limited actions | drive past the limit → `429`/`denied` |
| **Replay / race** | reuse a one-time token, or two ops at the same instant | one-time links, idempotency, concurrent writes | reuse the token → `denied` |

## How to choose (don't test all — test the ones that matter)

Ask: **"If this abuse succeeded, would a customer or auditor care?"** For a billing/paywall journey,
the paywall-bypass and privilege cases matter most. For an offboarding journey, revoked-credential
reuse IS the point. For a shared-resource journey, cross-tenant is the one. One or two well-chosen
abuse steps beat five arbitrary ones.

## Writing the abuse step

- State the `abuse:` line as the negative-space promise: *"a just-revoked key must be refused on the
  very next check — no propagation delay."*
- Assert the refusal precisely: `expect: denied` (any 4xx), or a specific `body: { valid: false }`
  when the API answers 200-with-a-verdict rather than an HTTP error.
- Put the abuse step where the state makes it real (e.g. AFTER the revoke, not before).
- A revoked-credential check is the strongest abuse case in most lifecycle journeys — it proves the
  system fails *closed*, which is the property that actually protects the customer.

## The one every journey should at least consider

**Unauthenticated access** (`bearer: "none"`) on the resource the journey creates. It's one line, it
applies almost everywhere, and a surprising number of real defects are "this was readable without a
token." If nothing else, add that one.
