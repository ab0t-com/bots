# AB0T-AUTH Frequently Asked Questions

Organized by customer journey stage. Each answer is wrapped in grepable delimiters.
Search with: `grep -A 20 'FAQ:keyword' FAQ.md`

---

## Section 1: Getting Started & Overview

### Q: What is ab0t-auth and why can't I just validate JWTs myself?

<!-- FAQ:what-is-ab0t-auth -->
ab0t-auth is a wrapper library that handles JWT validation, API key authentication, permission checking, multi-tenant isolation, and check callbacks in a single package. You *could* validate JWTs yourself with PyJWT, but you'd need to:
- Fetch and cache JWKS keys, handle rotation
- Support both JWT and API key auth
- Build permission checking (client-side and server-side)
- Build multi-tenant isolation
- Handle token expiry, revocation, audience validation
- Return proper 401/403 JSON error responses

ab0t-auth does all of this with a single `AuthGuard` instance and type aliases. It's the difference between writing 400 lines of auth boilerplate or importing a library and writing 50 lines of configuration.
<!-- /FAQ -->

### Q: Do I need to run my own auth service?

<!-- FAQ:auth-service-hosting -->
No. The central auth service runs at `https://auth.service.ab0t.com` and is shared across all platform services. Your service connects to it — you don't deploy your own. The ab0t-auth library in your service talks to this central auth service for JWKS keys, token validation, and server-side permission checks.
<!-- /FAQ -->

### Q: What's the absolute minimum I need to get auth working?

<!-- FAQ:minimum-setup -->
Four things:
1. `pip install "git+https://github.com/ab0t-com/auth_wrapper.git@v0.1.4"`
2. Create an `AuthGuard` instance with `auth_url` and your `audience`
3. Add `async with auth.lifespan()` to your FastAPI lifespan
4. Use `Depends(require_auth(auth))` on a route

That gives you authentication. For authorization (permissions), you also need `config/permissions.json`, a registration run with `authsetup`, and type aliases. See the SKILL.md file checklist for the full sequence.
<!-- /FAQ -->

### Q: What's the difference between authentication, authorization, and ownership?

<!-- FAQ:authn-authz-ownership -->
- **Authentication (AuthN)**: "Who are you?" — validates the JWT or API key. Result: you know it's user X.
- **Authorization (AuthZ)**: "What can you do?" — checks if user X has `myservice.create.allocations`. Result: you know they're allowed to create allocations.
- **Ownership**: "Is this YOUR resource?" — checks if user X owns allocation ABC-123. Result: you know they're not accessing someone else's stuff.

All three are required. A valid user with the right permission can still be denied if the resource belongs to someone else in a different org.
<!-- /FAQ -->

### Q: How do tokens work? JWT vs API key?

<!-- FAQ:token-types -->
**JWT tokens** are short-lived (about 15 minutes), issued after login, and carry identity claims (user id, org id, audience). They're used for user sessions and web apps. Send via `Authorization: Bearer <token>` header; refresh with the refresh token.

**API keys** are long-lived, don't expire (but can be revoked), and are validated by calling the auth service. They're used for scripts, CI/CD, service-to-service calls, and testing. Send via `X-API-Key: ab0t_sk_live_...` header. A key's permissions are fixed when it is minted.

The ab0t-auth library handles both transparently — your route code doesn't need to know which was used. The `user.auth_method` field tells you if you need to know (`jwt`, `api_key`, or `bypass`).
<!-- /FAQ -->

---

## Section 2: Permission Design & Strategy

### Q: How do I figure out what permissions my service needs?

<!-- FAQ:designing-permissions -->
Walk through every route handler in your service and ask two questions:
1. **What verb is this?** — GET = read, POST = create/execute, PUT/PATCH = write, DELETE = delete
2. **What noun does it act on?** — allocations, instances, reports, config

The verbs become your `actions`, the nouns become your `resources`. Then ask: "Does every user need this, or only some?" That determines `default_grant` and `risk_level`.

Example thought process for an invoicing service (`invoicer`):
- `GET /invoices` → action: read, resource: invoices → `invoicer.read.invoices`, low risk, default yes
- `POST /invoices/{id}/refund` → action: write, resource: invoices → `invoicer.write.invoices`, high risk, default no
- `GET /reports/revenue` → action: read, resource: reports → `invoicer.read.reports`, medium risk, default no (only finance team)
<!-- /FAQ -->

### Q: What's the difference between `myservice.read` and `myservice.read.allocations`?

<!-- FAQ:permission-granularity -->
`myservice.read` is a broad permission — read anything. `myservice.read.allocations` is a scoped permission — read only allocations. Use broad permissions when you want simplicity (one read permission for everything). Use scoped permissions when different resources need different access levels.

The example in `assets/permissions-template.json` uses both: `myservice.read` grants read access to all resources, while `myservice.read.costs` is separate because cost data might be restricted to finance users even though everyone can read allocations.

Rule of thumb: start broad, add scoped permissions only when you discover real access control needs.
<!-- /FAQ -->

### Q: Why can't I just use roles instead of individual permissions?

<!-- FAQ:roles-vs-permissions -->
Your code always checks permissions; roles and teams are how people get them.

- Permissions make enforcement precise: your code checks `myservice.delete`, not "is admin" — because admins in different services have different capabilities.
- Today a role in `permissions.json` sets a name only (exactly one is the default role new signups get). What a new user can actually do comes from the `default_grant` permissions, delivered through your users' default team.
- To give a group of people more than the defaults, put them in a team that carries the permissions, or grant directly (`POST /permissions/grant`). See authmesh SOPs 04, 09 and 10.

Think of roles and teams as the HR-facing concept and permissions as the engineering-facing concept.
<!-- /FAQ -->

### Q: Should every route have its own permission?

<!-- FAQ:permission-per-route -->
No. Group routes by the operation they perform, not by URL. Multiple routes can share one permission:

- `GET /allocations`, `GET /allocations/{id}`, `GET /allocations/{id}/metrics` → all use `myservice.read`
- `POST /allocations/{id}/scale`, `PUT /allocations/{id}/instances` → both use `myservice.write` or `myservice.scale`

Create a new permission only when you need to grant different access. If everyone who can read allocations should also be able to read instances, one `myservice.read` permission is fine.
<!-- /FAQ -->

### Q: What happens when I add new permissions later?

<!-- FAQ:adding-permissions-later -->
Three steps:
1. Add the new permission to `config/permissions.json` (its action and resource must be in `registration.actions` / `registration.resources`, or it is dead) and run `authsetup --config-dir ./config validate`
2. Re-run `authsetup --env dev --config-dir ./config up` (preview with `--dry-run` first). It is idempotent and re-registers your permission list.
3. **Important**: existing API keys are NOT updated. A key's permissions are fixed when it is minted, so mint a new service key and roll it out (authmesh SOP 14). `authsetup --env dev doctor` tells you when the key holds fewer permissions than you declared.

If the new permission is `default_grant: true`, new and existing users get it through the default team after a fresh login. Otherwise grant it to the people who need it (team or `POST /permissions/grant`).
<!-- /FAQ -->

### Q: What does `implies` actually do?

<!-- FAQ:implies-field -->
`implies` is documentation for humans and admin tooling: "admin covers these". It does **not** grant anything by itself, and the implied permissions are not added to anyone's token.

So in your code, check the specific permission **or** the admin permission explicitly, e.g. `require_any_permission(auth, "myservice.delete", "myservice.admin")`, or `user.has_permission("myservice.admin")` in Phase 2.

Never list `cross_tenant` (or any `scope: platform` permission) under `implies`; it is always a conscious, separate grant.
<!-- /FAQ -->

### Q: How do I decide `default_grant: true` vs `false`?

<!-- FAQ:default-grant -->
Ask: "Should a brand new user who just joined this org be able to do this without anyone explicitly approving it?"

- `true`: Reading data, viewing logs, creating their own resources — basic operational access
- `false`: Admin operations, SSH access, cross-tenant access, cost management — needs explicit approval

When in doubt, default to `false`. It's easier to grant a permission than to revoke one after a security incident.
<!-- /FAQ -->

---

## Section 3: Registration & Service Setup

### Q: Why does each service need its own org?

<!-- FAQ:service-org-isolation -->
Permission isolation. Each service's permissions are registered by, and owned by, its own service org. This means:
- `myservice.read` (owned by your service org) is a completely different permission from `billing.read` (owned by the billing service's org)
- Compromise of one service's admin credentials doesn't affect other services
- Only admins of your service org can hand out your `platform` permissions

`authsetup` creates the service org for you; its slug is your service id. Think of orgs as security boundaries between services.
<!-- /FAQ -->

### Q: What happens if I run `authsetup` twice?

<!-- FAQ:idempotent-registration -->
It's safe — `authsetup up` (and `run`) is idempotent. On a second run it reads the live server, compares it with your config files and changes only what differs; when everything matches it says `already matches your config — nothing to change.`

The one thing it does not do is widen an existing service key: a key's permissions are fixed when it is minted. If you added permissions, mint a new key (authmesh SOP 14) and check with `authsetup --env dev doctor`.

Your credentials stay in `~/.authmesh/<service>/` (one file per environment, mode 0600); re-running never changes your org id.
<!-- /FAQ -->

### Q: Where do I find my org id and my audience after registration?

<!-- FAQ:org-uuid -->
Ask the tool:

```bash
authsetup --env dev info        # which file holds what, including your service org id
authsetup --env dev settings    # the values your backend and frontend need (key masked)
```

Your **audience** is not the org id: it is `service.audience` from `config/permissions.json` (e.g. `myservice`). That is the value for `AB0T_AUTH_AUDIENCE`.
<!-- /FAQ -->

### Q: What if the auth service is down when I try to register?

<!-- FAQ:auth-service-down-registration -->
`authsetup` stops at the first failure and tells you which step failed. Wait for the auth service to come back and run it again — it's idempotent, so a partial run is completed, not duplicated.

If the auth service goes down AFTER registration (during normal operation), your service's behavior depends on `permission_check_mode`:
- `"client"`: JWT validation continues with cached JWKS keys. New tokens can't be issued, but existing valid tokens still work until they expire.
- `"server"`: Permission checks fail with `503` (`AuthServiceError`). That is correct: fail closed, never turn "could not check" into an allow.
<!-- /FAQ -->

### Q: How do I register from CI/CD?

<!-- FAQ:cicd-registration -->
Usually you run `authsetup` from your own terminal and only deploy the resulting values. If you do automate it:

```bash
authsetup --env dev --config-dir ./config up --yes        # --yes: nobody is there to answer the confirmation
```

Always pass `--env` (prod is the default when you don't). Keep the credentials directory outside the repository (default `~/.authmesh/<service>/`), and put the service key into your CI/CD secrets manager, never into git. `authsetup --env <env> settings --env-file .env` writes the values into a 0600 file and refuses a `.env` that git does not ignore.
<!-- /FAQ -->

---

## Section 4: Implementation & Code Patterns

### Q: Why a single centralized app/auth.py instead of auth in each route file?

<!-- FAQ:centralized-auth-module -->
Three reasons:
1. **Consistency**: One AuthGuard instance, one TenantConfig, one set of check callbacks. If each route file had its own, settings could drift.
2. **Auditability**: Security reviewers look at one file to understand the entire auth posture. "Show me your auth" → `app/auth.py`.
3. **DRY**: Type aliases are defined once, imported everywhere. Changing a check callback affects all routes that use it.
<!-- /FAQ -->

### Q: What's the difference between `check=` and `checks=[]`?

<!-- FAQ:check-vs-checks -->
`check=` takes a single callback function. `checks=[]` takes a list of callbacks combined with `check_mode`.

```python
# Single check — just org membership
ResourceReader = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.read", check=belongs_to_org)
)]

# Multiple checks — ALL must pass (check_mode="all")
ResourceAllocator = Annotated[AuthenticatedUser, Depends(
    require_any_permission(auth, "myservice.create.allocations", "myservice.create.deployments",
        checks=[belongs_to_org, is_not_suspended, is_within_quota],
        check_mode="all")
)]
```

Use `check=` when you have one condition. Use `checks=[]` when multiple conditions must be met (or any, with `check_mode="any"`).
<!-- /FAQ -->

### Q: When do I use `require_permission` vs `require_any_permission` vs `require_all_permissions`?

<!-- FAQ:require-permission-variants -->
- `require_permission(auth, "perm")` — user needs exactly this one permission
- `require_any_permission(auth, "perm.a", "perm.b")` — user needs at least one of these (OR)
- `require_all_permissions(auth, "perm.a", "perm.b")` — user needs ALL of these (AND)

Most common: `require_permission` for single-action routes (read, write, delete). Use `require_any_permission` when an action can be satisfied by different permissions — e.g., creating allocations OR deployments both satisfy "can create resources."
<!-- /FAQ -->

### Q: Why `permission_check_mode="server"` instead of `"client"`?

<!-- FAQ:server-vs-client-mode -->
**Client mode** (the library default) checks permissions from the JWT claims. Fast (no network call), but stale — if you revoke a permission, the user keeps access until they get a new token (about 15 minutes).

**Server mode** asks the auth service. Slower on a cache miss (one extra HTTP call), but revocations take effect within the library's permission cache window (about 15 seconds by default). Pass `fresh=True` to a dependency on sensitive routes (admin, money, ownership) to always ask.

Choose server mode when:
- Your service manages expensive or sensitive resources
- Fast revocation matters (security incidents, billing disputes)
- You can tolerate a few milliseconds extra on cache misses

Choose client mode when:
- Latency is critical and permission changes are rare
- You're in development/testing
<!-- /FAQ -->

### Q: Why do I need `auth.lifespan()` in main.py?

<!-- FAQ:lifespan-requirement -->
AuthGuard fetches JWKS keys (public keys for JWT verification) on startup and caches them. Without `lifespan()`:
- The first request triggers a synchronous JWKS fetch, causing a timeout or blocking
- JWKS key rotation isn't handled
- Caches aren't initialized
- You get `AuthGuard not initialized` errors

The lifespan also handles graceful shutdown — clearing caches and closing HTTP connections.
<!-- /FAQ -->

### Q: What does `register_auth_exception_handlers(app)` do?

<!-- FAQ:exception-handlers -->
Without it, auth errors from the library (TokenExpiredError, PermissionDeniedError, etc.) bubble up as unhandled Python exceptions, returning raw 500 Internal Server Error responses.

With it, these errors are caught and converted to proper JSON responses:
- `TokenExpiredError` → `401 {"error": "TOKEN_EXPIRED", "message": "..."}`
- `PermissionDeniedError` → `403 {"error": "PERMISSION_DENIED", "message": "...", "details": {"required": "myservice.admin"}}`
- `AuthServiceError` → `503 {"error": "AUTH_SERVICE_ERROR", "message": "Authentication service unavailable"}`

This is both better UX and better security (no stack traces leaked).
<!-- /FAQ -->

### Q: What's `AB0T_AUTH_AUDIENCE` and what happens if I don't set it?

<!-- FAQ:audience-explained -->
The audience identifies which service a user token is meant for. Yours is `service.audience` from `config/permissions.json` (keep it equal to your service id, e.g. `myservice`). It is stamped on your org when it is created and cannot be changed afterwards. `authsetup --env <env> settings` prints it.

If you don't set it, your service accepts user tokens minted for ANY service. A token issued for the billing service would work on yours. That is a security vulnerability.

Setting `AB0T_AUTH_AUDIENCE=myservice` (passed to `AuthGuard(audience=...)`) ensures your service only accepts tokens meant for it. Mesh API keys from other services carry no audience. See authmesh SOP 06.
<!-- /FAQ -->

---

## Section 5: API Keys & Inter-Service Communication

### Q: Why does the key for calling another service come from THAT service?

<!-- FAQ:api-key-target-org -->
Permissions belong to the service that defines them. If your service needs to call another service (the provider), the key you send must hold the **provider's** permissions, so it is minted on the provider's side, not in your own org.

Think of it like needing a badge for the building you're visiting. You get the badge from the visited building's security desk, not from your own building.

On the mesh you don't do this by hand: `authsetup --env dev connect <provider> --as <your-service>` creates your consumer account at the provider, mints a key with exactly the tier's permissions, and saves it 0600 to `~/.authmesh/<your-service>/<provider>-consumer.<env>.json`. Send it as `X-API-Key`. See authmesh SOP 11; to let others call **your** service, SOP 12.
<!-- /FAQ -->

### Q: How do I rotate an API key without downtime?

<!-- FAQ:api-key-rotation -->
1. Mint a new key (your service key: authmesh SOP 14 step 1; a consumer key: `authsetup disconnect` then `connect`)
2. Update the calling service's config to use the new key and deploy
3. Verify the new key works (`authsetup --env <env> doctor` / `status --verify`)
4. Revoke the old key via `DELETE /api-keys/{old_key_id}` (irreversible)

Old keys stay valid until you revoke them, so there's no downtime. Read the key from an environment variable or secrets manager so it can be swapped without a code change.
<!-- /FAQ -->

### Q: What permissions should an inter-service API key have?

<!-- FAQ:inter-service-key-permissions -->
The absolute minimum the calling service needs. Typical shapes:

- **A service that provisions and cleans up resources in yours**: `myservice.create.allocations`, `myservice.read`, `myservice.delete`, `myservice.scale`
- **A reporting service**: `myservice.read.costs`, `myservice.read.quotas` (only reads cost data)
- **A health checker or router**: `myservice.read`

Publish these as tiers when you open your service to others (authmesh SOP 12). Never give inter-service keys `admin` or `cross_tenant` unless there's a specific, documented reason. A compromised inter-service key with admin access is a major security incident.
<!-- /FAQ -->

### Q: How do I test with API keys locally?

<!-- FAQ:testing-api-keys -->
After `authsetup` has run on dev, your service key is in the credentials file. Load it into a variable without printing it:

```bash
API_KEY=$(jq -r '.api_key.key' ~/.authmesh/myservice/myservice.dev.json)

# Test a protected endpoint on your local service
curl -s http://localhost:8000/resources/allocations \
  -H "X-API-Key: $API_KEY" | jq
```

For testing with different permission levels, create additional keys with restricted permissions as your service admin (and revoke them when you're done):

```bash
# Create a read-only test key
curl -X POST "$AUTH_URL/api-keys/" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "test-readonly", "permissions": ["myservice.read"]}'
```
<!-- /FAQ -->

---

## Section 6: Multi-Tenancy & Isolation

### Q: What is multi-tenant isolation in simple terms?

<!-- FAQ:multi-tenancy-simple -->
Every user belongs to an organization (tenant). Every resource belongs to an organization. Users can only see and interact with resources in their own organization.

If Company A and Company B both use the platform, Company A's employees cannot see Company B's resources, even if they have the same permissions. This is enforced at three layers: the auth dependency (Phase 1), the route handler (Phase 2), and the database query (get_user_filter).
<!-- /FAQ -->

### Q: What's the difference between `belongs_to_org` and `is_resource_owner`?

<!-- FAQ:belongs-vs-owner -->
They answer different questions:

**`belongs_to_org`**: "Is this user a member of the org referenced in this request?" Used for operations where org membership is enough — listing resources, creating new resources, reading org-wide data. Any user in the org can do these.

**`is_resource_owner`**: "Does this user own the specific resource they're trying to modify?" Used for mutation operations — writing, deleting, scaling, executing. Only the resource owner (or an admin) can do these.

Example: User A and User B are both in Org-1.
- User A can LIST all allocations in Org-1 (belongs_to_org passes)
- User A CANNOT delete User B's allocation (is_resource_owner fails)
- An admin in Org-1 CAN delete User B's allocation (is_resource_owner passes for admins)
<!-- /FAQ -->

### Q: What does `cross_tenant` actually allow?

<!-- FAQ:cross-tenant-explained -->
The `cross_tenant` permission bypasses all org boundaries in **your** code. A user with `myservice.cross_tenant` can:
- Read resources in ANY org (get_user_filter returns `{}` — no filter)
- Access specific resources in ANY org (verify_allocation_access allows it)
- Bypass belongs_to_org checks

This is reserved for your own support staff who need to troubleshoot customer issues. Declare it `"scope": "platform"` and grant it one person at a time with `authsetup grant-platform ... --reason "..."` (authmesh SOP 10). It should NEVER be:
- Implied by `admin` (admin is org-scoped)
- Default-granted or in any role or team
- Given to inter-service API keys (use specific permissions instead)

All cross-tenant access should be logged and auditable.
<!-- /FAQ -->

### Q: What happens if I forget `get_user_filter()` on a list endpoint?

<!-- FAQ:missing-user-filter -->
Your endpoint returns ALL resources across ALL organizations. This is a data leak — User A sees User B's resources, Org-1 sees Org-2's data.

This is one of the most common and dangerous mistakes. It "works" in development (you see data, tests pass) because you're usually testing with one user. It only becomes visible in production when multiple orgs exist.

Prevention: grep your route files for list/query endpoints and verify every one uses `get_user_filter()`. Add this to your security testing checklist.
<!-- /FAQ -->

### Q: How does TenantConfig's org hierarchy work?

<!-- FAQ:org-hierarchy -->
Organizations can have parent/child relationships. In ab0t-auth 0.1.4 the TenantConfig flags do this (`ab0t_auth/tenant.py`):

- `allow_ancestor_access=True`: the caller may access an org in **their own** ancestry path (from the `org_path` token claim). That means a user in a **child** org can reach its **parent** orgs. It does not let a parent-org user into child orgs.
- `allow_descendant_access`: not enforced client-side; the library cannot see a target org's ancestry, so it grants nothing locally. "Parent manages its children" is decided by the auth service (an ancestor org can act in its descendants), so check it server-side or in Phase 2.

If your customers are flat (most services), set `enable_org_hierarchy=False` and both flags to `False`. Note the library default for `allow_ancestor_access` is `True`, so set it explicitly.
<!-- /FAQ -->

---

## Section 7: Route Protection & Phase 2

### Q: Why do I need Phase 2 if Phase 1 already checked permissions?

<!-- FAQ:why-phase-2 -->
Phase 1 runs as a FastAPI dependency — BEFORE your route handler executes. At that point, all it knows is:
- Who the user is (user_id, org_id)
- What permissions they have
- What the request path looks like

It does NOT know which specific resource the user is trying to access. The `allocation_id` in `/allocations/{allocation_id}` is just a string — Phase 1 can't look it up in the database.

Phase 2 runs INSIDE your route handler, AFTER you've fetched the resource from the database. Now you know the resource's `org_id` and `user_id`, and you can verify: "Does this user actually own this resource, or are they trying to access someone else's?"

Without Phase 2, any user with `myservice.read` could read ANY allocation by guessing UUIDs.
<!-- /FAQ -->

### Q: Which routes need Phase 2 and which don't?

<!-- FAQ:phase-2-decision -->
**Needs Phase 2**: Any route that takes a resource identifier in the path and fetches a specific resource.
- `GET /allocations/{allocation_id}` — yes
- `DELETE /allocations/{allocation_id}` — yes
- `POST /allocations/{allocation_id}/scale` — yes
- `GET /allocations/{allocation_id}/instances/{instance_id}` — yes (verify parent allocation)

**Does NOT need Phase 2**:
- `POST /allocate` — creates a new resource (assigns ownership to the calling user)
- `GET /allocations` — list endpoint (scoped by `get_user_filter()` instead)
- `GET /health` — no resource access
- `GET /public-stats` — public data

Rule of thumb: if there's a `{resource_id}` in the URL and you fetch it from DB, add Phase 2.
<!-- /FAQ -->

### Q: Why 404 before 403? Does the order matter?

<!-- FAQ:404-before-403 -->
Yes, the order matters for both security and correctness:

```python
# CORRECT order
allocation = await db.get_allocation(allocation_id)
if not allocation:
    raise HTTPException(404, "Allocation not found")  # 1. Does it exist?
verify_allocation_access(allocation, user)              # 2. Can you access it?
```

Why security: if you return 403 for resources that exist and 404 for ones that don't, an attacker can enumerate valid resource IDs by checking which ones return 403. By always returning 404 for non-existent resources first, you don't leak existence information.

Why correctness: `verify_allocation_access(None, user)` crashes with `AttributeError` because `None` has no `.user_id` attribute.
<!-- /FAQ -->

### Q: How do I protect nested resources (instance within allocation)?

<!-- FAQ:nested-resources -->
Verify the parent, then verify the child belongs to that parent:

```python
# 1. Fetch and verify parent
allocation = await db.get_allocation(allocation_id)
if not allocation: raise HTTPException(404)
verify_allocation_access(allocation, user)

# 2. Fetch child and verify it belongs to parent
instance = await db.get_instance(instance_id)
if not instance or instance.allocation_id != allocation_id:
    raise HTTPException(404)  # Prevents IDOR: accessing instance via wrong allocation
```

The `instance.allocation_id != allocation_id` check is critical — without it, a user could access Instance-B (belonging to Allocation-B) by requesting `/allocations/{their-allocation-A}/instances/{instance-B}`.
<!-- /FAQ -->

---

## Section 8: Testing & Development

### Q: How do I test without the auth service running?

<!-- FAQ:testing-without-auth -->
Enable auth bypass by setting TWO environment variables (both required as defense-in-depth):

```bash
AB0T_AUTH_DEBUG=true
AB0T_AUTH_BYPASS=true
```

This creates a synthetic bypass user. Configure it:
```bash
AB0T_AUTH_BYPASS_USER_ID=test_user
AB0T_AUTH_BYPASS_EMAIL=test@localhost
AB0T_AUTH_BYPASS_ORG_ID=test_org
AB0T_AUTH_BYPASS_PERMISSIONS=myservice.read,myservice.create.allocations,myservice.admin
AB0T_AUTH_BYPASS_ROLES=myservice-admin
```

Your routes work as normal — the `AuthenticatedUser` object is populated from these env vars instead of a real token. Local sandbox only.
<!-- /FAQ -->

### Q: How do I write unit tests for my auth functions?

<!-- FAQ:unit-testing-auth -->
Mock the AuthenticatedUser and Request objects:

```python
from unittest.mock import Mock

def make_user(user_id, org_id, permissions=None):
    user = Mock()
    user.user_id = user_id
    user.org_id = org_id
    user._perms = permissions or []
    user.has_permission = lambda p: p in user._perms
    user.metadata = {}
    return user

def make_request(path_params=None):
    req = Mock()
    req.path_params = path_params or {}
    req.query_params = {}
    return req

# Test: same org user passes belongs_to_org
assert belongs_to_org(make_user("u1", "org1"), make_request({"org_id": "org1"}))

# Test: different org user fails
assert not belongs_to_org(make_user("u1", "org1"), make_request({"org_id": "org2"}))

# Test: admin in different org can't access allocation
with pytest.raises(PermissionDeniedError):
    alloc = Mock(user_id="u2", org_id="org2")
    verify_allocation_access(alloc, make_user("u1", "org1", ["myservice.admin"]))
```
<!-- /FAQ -->

### Q: How do I test that unauthorized access is properly denied?

<!-- FAQ:red-team-testing -->
Create test API keys with different permission levels and verify each endpoint returns the expected status code:

```bash
# No auth → 401
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/resources/allocations
# Expected: 401

# Read-only key trying to create → 403
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8000/resources/allocate \
  -H "X-API-Key: $READ_ONLY_KEY" -H "Content-Type: application/json" -d '{}'
# Expected: 403

# User A trying to access User B's resource → 403
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/resources/allocations/$USER_B_ALLOC \
  -H "X-API-Key: $USER_A_KEY"
# Expected: 403
```

Test all 7 attack vectors: no auth, invalid token, missing permission, cross-user, cross-org, path traversal, injection. See [testing-troubleshooting.md](testing-troubleshooting.md) for the full checklist.
<!-- /FAQ -->

### Q: Can I use auth bypass in staging/QA?

<!-- FAQ:bypass-in-staging -->
No. Auth bypass skips real token validation: every request becomes the synthetic bypass user with whatever permissions you configured. It doesn't test your real auth flow at all. Use it for:
- Unit testing business logic that isn't auth-related
- Local development when iterating on features

Do NOT use it for:
- Integration testing (you need real auth flows)
- Staging environments that mirror production
- Any environment accessible from outside your machine

For staging, use the `dev` environment with real tokens and API keys — this tests the actual auth flow.
<!-- /FAQ -->

---

## Section 9: Debugging & Troubleshooting

### Q: I'm getting 401 but my token looks valid. What's wrong?

<!-- FAQ:debug-401 -->
Check these in order:
1. **Token expired?** User JWTs expire after about 15 minutes; refresh them. Decode the payload locally to check `exp` (never paste a live token into a website).
2. **Wrong audience?** The token's `aud` must match your `AB0T_AUTH_AUDIENCE` (your `service.audience`, e.g. `myservice`). A token minted for another service is rejected. Users stuck in a login loop usually means the backend's audience and the org's audience differ (authmesh SOP 06, 16).
3. **JWKS not fetched?** If AuthGuard isn't initialized (missing lifespan), it can't verify signatures. Check for `AuthGuard not initialized` in logs.
4. **Wrong header?** JWT goes in `Authorization: Bearer <token>`, API key goes in `X-API-Key: <key>`.
5. **Auth service unreachable?** That is a `503`, not a `401`; see the timeout question below.

Debug by printing the user object in a working route:
```python
@app.get("/debug-auth")
async def debug(user: CurrentUser):
    return {"user_id": user.user_id, "auth_method": str(user.auth_method), "permissions": user.permissions}
```
<!-- /FAQ -->

### Q: I'm getting 403 but I have the permission. What's wrong?

<!-- FAQ:debug-403 -->
403 means authentication passed but authorization failed. Check:

1. **Check callback failing?** The permission check passed, but a callback like `belongs_to_org` or `is_resource_owner` returned False (or raised). Print the user's org_id and compare with the request's org_id.
2. **Phase 2 failing?** You have the permission but don't own the specific resource. Check `allocation.user_id == user.user_id` and `allocation.org_id == user.org_id`.
3. **Stale permissions?** In client mode, permissions come from the JWT. If a permission was just granted, the user needs a fresh login. A user who signed up through the global sign-up rather than your hosted page may not be in your users' org at all.
4. **API key?** A key's permissions are fixed when it is minted; grants made later don't reach it. Re-mint.
5. **Wrong permission string?** Permission strings are case-sensitive and exact. `myservice.Read` ≠ `myservice.read`. Check spelling.
6. **Suspended user?** If you use an `is_not_suspended` callback, check your own suspension store.
<!-- /FAQ -->

### Q: Permission changes aren't taking effect. What's going on?

<!-- FAQ:stale-permissions -->
This depends on your `permission_check_mode`:

**Client mode (`"client"`)**: Permissions are read from the JWT. Changes don't affect existing tokens — the user must get a new token (fresh login). That can take up to the token lifetime (about 15 minutes).

**Server mode (`"server"`)**: Permissions are checked against the auth service, with a short cache (about 15 seconds for permissions by default; `fresh=True` skips it). If changes still don't show:
- A newly registered permission can take up to about five minutes to appear (or shows at once on a fresh login).
- An API key keeps the permissions it was minted with. Check with `POST /auth/validate-api-key`.
- You might have granted the permission in the wrong org.

This is why server mode is recommended for production.
<!-- /FAQ -->

### Q: How do I check what permissions a user/key actually has?

<!-- FAQ:check-permissions -->
```bash
# A user token (with your audience)
curl -s -X POST https://auth.service.ab0t.com/auth/validate-token \
  -H "Content-Type: application/json" \
  -d '{"token": "'"$TOKEN"'", "expected_audience": "myservice"}' | jq '.permissions'

# An API key
curl -s -X POST https://auth.service.ab0t.com/auth/validate-api-key \
  -H "Content-Type: application/json" \
  -d '{"api_key": "'"$API_KEY"'"}' | jq '.permissions'

# A specific user's permissions (as an org admin)
curl -s "https://auth.service.ab0t.com/permissions/user/$USER_ID?org_id=$ORG_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.permissions'
```

Use `https://auth.dev.ab0t.com` for dev.
<!-- /FAQ -->

### Q: I see `AuthGuard not initialized` — what did I miss?

<!-- FAQ:authguard-not-initialized -->
You forgot to add the lifespan context manager in `main.py`:

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    async with auth.lifespan():   # ← This is missing
        yield

app = FastAPI(lifespan=lifespan)
```

The lifespan initializes JWKS fetching, cache setup, and HTTP clients. Without it, AuthGuard can't verify any tokens.
<!-- /FAQ -->

---

## Section 10: Security & Operations

### Q: What happens if someone steals a JWT?

<!-- FAQ:stolen-jwt -->
They can impersonate the user until the token expires (about 15 minutes). Mitigations:
- Short token expiry limits the window
- Server-mode permission checks mean revoking the user's permissions bites within seconds
- `POST /auth/revoke` revokes a specific token
- `DELETE /organizations/{org_id}/sessions` revokes all sessions for a user in an org

JWTs can't be "invalidated" in client mode because they're self-contained. This is why server mode is recommended for sensitive services.
<!-- /FAQ -->

### Q: What happens if someone steals an API key?

<!-- FAQ:stolen-api-key -->
API keys don't expire, so the exposure is indefinite until revoked. Revoke first, think second:
1. Revoke the key: `DELETE /api-keys/{key_id}` as an admin of the org that owns it (irreversible)
2. Mint a new key (authmesh SOP 14)
3. Update the service that uses it and deploy
4. Review your logs (and the `authsetup` journal) for the window of exposure

Prevention: limit API key permissions to the minimum needed. A key with only `myservice.read` is less damaging than one with `myservice.admin`. Never print a key into chat, a ticket or a log line.
<!-- /FAQ -->

### Q: Can I turn off audience checking?

<!-- FAQ:audience-skip -->
There is no audience-skip switch in ab0t-auth, and you shouldn't build one. Without an audience check your service accepts user tokens minted for ANY service, so any other service's tokens work on yours.

If you are migrating an older service whose org was created without an audience, fix the org instead (authmesh SOP 16) and then set `AB0T_AUTH_AUDIENCE`. If your routes must also accept other services' mesh API keys, that is fine: keys carry no audience, and the library only checks audience on JWTs.
<!-- /FAQ -->

### Q: How should I handle auth in health check endpoints?

<!-- FAQ:health-check-auth -->
Health check endpoints (`/health`, `/ready`, `/live`) should typically be public (no auth). They're called by load balancers, Kubernetes probes, and monitoring systems that don't have tokens.

```python
@app.get("/health")
async def health():
    return {"status": "healthy"}
```

If you use middleware-based auth, exclude these paths:
```python
setup_auth_middleware(app, auth, exclude_paths=["/health", "/ready", "/docs", "/openapi.json"])
```

For sensitive health endpoints (showing internal state), use admin-level auth:
```python
@app.get("/health/detailed")
async def detailed_health(user: ResourceAdmin):
    return {"db": "connected", "cache": "warm", "auth": "initialized"}
```
<!-- /FAQ -->

---

## Section 11: Migration & Upgrades

### Q: I'm using the old `Depends(get_current_user)` pattern. How do I migrate?

<!-- FAQ:migration-from-old-pattern -->
Replace step by step:

**Before:**
```python
from app.dependencies import get_current_user

@app.get("/resources")
async def list_resources(user = Depends(get_current_user)):
    return await db.list_all()  # No filtering!
```

**After:**
```python
from app.auth import ResourceReader, get_user_filter

@app.get("/resources")
async def list_resources(user: ResourceReader):
    filters = get_user_filter(user)
    return await db.list_resources(**filters)  # Tenant-filtered
```

Key changes:
1. Import from `app.auth` instead of `app.dependencies`
2. Use type alias (`ResourceReader`) instead of `Depends(get_current_user)`
3. Add `get_user_filter()` for list endpoints
4. Add `verify_*_access()` for single-resource endpoints
5. Replace `user.id` with `user.user_id`
<!-- /FAQ -->

### Q: What breaks when I switch from old User model to AuthenticatedUser?

<!-- FAQ:user-model-migration -->
| Old pattern | New pattern | What breaks if you don't change |
|---|---|---|
| `user.id` | `user.user_id` | `AttributeError` (500) on every request that reaches it |
| `user.name` | `user.claims.raw.get("name")` if your tokens carry it, or your own store | `AttributeError` |
| `user.permissions` (list) | `user.permissions` (tuple) | List mutations fail (`append`, `extend`) |
| `user.is_active` | your own suspension store | `AttributeError` |
| `if user.is_admin` | `if user.has_permission("myservice.admin")` | `AttributeError` |

`AuthenticatedUser` is a frozen dataclass with slots, so any attribute it doesn't define raises `AttributeError` rather than returning `None`. Find-and-replace `user.id` → `user.user_id` across all route files, and run your tests: the error is loud, which is good.
<!-- /FAQ -->

### Q: Can I migrate incrementally or do I have to do all routes at once?

<!-- FAQ:incremental-migration -->
You can migrate incrementally. The old `get_current_user` and new type aliases can coexist:

1. Create `app/auth.py` with AuthGuard, TenantConfig, type aliases
2. Add lifespan and exception handlers to `main.py`
3. Migrate one route file at a time — change imports and add Phase 2
4. Test each migrated file before moving to the next
5. Once all routes are migrated, remove old `get_current_user` from `dependencies.py`

The only hard requirement is that `main.py` has the lifespan and exception handlers before any route uses the new type aliases.
<!-- /FAQ -->

---

## Section 12: Edge Cases & Gotchas

### Q: Does `user.id` return None?

<!-- FAQ:user-id-none -->
It doesn't: `user.id` raises `AttributeError`. `AuthenticatedUser` is a frozen dataclass with slots; it has `user_id`, not `id`, and an undefined attribute is an error, not `None`.

The fix is always `user.user_id`. If you're migrating from an old `User(BaseModel)` that had `.id`, do a find-and-replace across all route files: `user.id` → `user.user_id`. Watch for code that catches `AttributeError` broadly or uses `getattr(user, "id", None)`: that *would* turn into a silent `None`, and an ownership comparison like `allocation.user_id == None` would then deny the real owner.
<!-- /FAQ -->

### Q: My service key doesn't have the new permissions I added.

<!-- FAQ:stale-api-key -->
A key's permissions are fixed when it is minted. Re-running `authsetup` re-registers your permission list but does not widen an existing key; grants made to the account later don't flow into it either.

To fix:
```bash
authsetup --env dev doctor     # reports "service key ◐ UNDER-PERMISSIONED" when the key holds fewer permissions than you declared
```
then mint a new service key, roll it out, and revoke the old one (authmesh SOP 14). Plan your deploy so the new key is in place before the old one is revoked.
<!-- /FAQ -->

### Q: Admin of Org A can see Org B's resources — how?

<!-- FAQ:cross-org-leak -->
Check these in order:
1. **Does the user have `cross_tenant`?** Check `user.permissions` — if they have `myservice.cross_tenant`, they intentionally bypass org boundaries.
2. **Is `get_user_filter()` used on the list endpoint?** Without it, the query returns all resources regardless of org.
3. **Is Phase 2 verification present?** Without `verify_allocation_access()`, any user with `myservice.admin` in Org A can access specific resources in Org B because the admin check doesn't verify same-org.
4. **Is `belongs_to_org` check present on the type alias?** If the type alias uses no check callback, org membership isn't verified at Phase 1 either.

Most common cause: missing `get_user_filter()` on a list endpoint. Second most common: Phase 2 verification missing.
<!-- /FAQ -->

### Q: I have two services that need to share permissions. How?

<!-- FAQ:shared-permissions -->
Services should NOT share permissions. Each service registers its own permissions, owned by its own service org. If Service A needs Service B to do something, it should:

1. Call Service B's API directly with a consumer key for Service B (`authsetup connect`, authmesh SOP 11)
2. Or ask the auth service about the user's permissions for Service B's permission ids

Anti-pattern: registering `billing.*` permissions from your own service. Only the service that owns a name may register it, and it breaks isolation.

If you need relationship-based checks ("can user X edit document Y?"), the auth service's Zanzibar API lives under a store: `/zanzibar/stores/{store_id}/...` (see the live OpenAPI at `https://auth.service.ab0t.com/openapi.json`).
<!-- /FAQ -->

### Q: What happens when the auth service is slow or timing out?

<!-- FAQ:auth-service-timeout -->
Behavior depends on your setup:

**Client mode**: No impact on request latency — tokens are verified locally with cached JWKS keys and permissions come from the JWT.

**Server mode**: Permission checks call the auth service on a cache miss. If the auth service is slow:
- Requests to your service are slow (waiting for the check)
- If the auth service is down, requests fail with `503 AuthServiceError`

Mitigations:
- The library caches answers briefly by default (permissions about 15 s, API keys 60 s); every TTL is configurable
- Monitor auth service latency as an SLI for your service
- Always fail closed: a `503` is the right answer when you could not check. Never turn an auth-service error into an allow, and don't silently fall back to weaker checks.
<!-- /FAQ -->

### Q: Can I use ab0t-auth with Flask instead of FastAPI?

<!-- FAQ:flask-support -->
Yes. The library ships a Flask extension in `ab0t_auth.flask`:

```python
from flask import Flask
from ab0t_auth.flask import Ab0tAuth, login_required, get_current_user

app = Flask(__name__)
auth = Ab0tAuth(app, auth_url="https://auth.service.ab0t.com")

@app.route("/protected")
@login_required
def protected_route():
    return {"user_id": get_current_user().user_id}
```

In Flask, check callbacks receive only the user (`def check(user) -> bool`; read the request from Flask's global `request`). This skill focuses on FastAPI; for Flask see the library README: https://github.com/ab0t-com/auth_wrapper
<!-- /FAQ -->
