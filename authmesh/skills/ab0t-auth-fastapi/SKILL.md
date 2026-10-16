---
name: ab0t-auth-fastapi
description: Integrate ab0t-auth authentication and authorization into FastAPI microservices. Use when creating a new service that needs auth, migrating from legacy auth patterns, designing permissions for a service, protecting routes with permission-based access control, implementing multi-tenant isolation, registering a service with the auth system, creating API keys for inter-service communication, or debugging auth failures (401/403). Covers the full lifecycle from permission design through config/permissions.json, service registration with the authsetup CLI, auth module implementation (AuthGuard, type aliases, check callbacks, Phase 2 verification), route protection patterns, and testing.
category: service-setup
tags: [auth, fastapi, integration, ab0t-platform]
---

# AB0T-AUTH FastAPI Integration

Integrate the `ab0t-auth` Python library (https://github.com/ab0t-com/auth_wrapper, checked against v0.1.4) into FastAPI services. The examples use a compute-style service called `myservice`; rename it to your own service id.

**What this is, in two sentences.** Your service never decodes or trusts a token itself: `ab0t-auth` asks the auth service who the caller is and whether they hold the permission, with your audience, on every route. You then add the one check only you can make, that the resource they asked for belongs to their org, so customers stay isolated without a hand-written auth layer.

## Agentic Workflow

When integrating auth into a new service, reason about **your** codebase at each stage:

1. **Audit routes** — read every route handler. Ask: "What can users DO? What data can they see? What can they modify or delete?"
2. **Map operations to verbs** — each handler implies an action (read, write, create, delete, execute, scale). Group them.
3. **Identify resources** — what are the nouns? (allocations, instances, jobs, reports). These become permission resources.
4. **Decide ownership granularity** — which operations need resource-level ownership checks vs org-level? Mutations need ownership; reads need org membership.
5. **Work backwards from attacks** — for each route: "What if User A calls this with User B's resource ID?" That determines Phase 2 needs.

## How Auth Works

```
User Request → ab0t-auth library (in your service)
  1. Extract token (Authorization: Bearer / X-API-Key)
  2. Validate JWT via JWKS (and its audience)
  3. Check permission (client-side or server-side)
  4. Run check callbacks (belongs_to_org, is_not_suspended, etc.)
  5. Return AuthenticatedUser
       → Your route handler
           6. Fetch resource from DB
           7. Phase 2: verify_resource_access()
           8. Process request
```

**Two token types:** JWT (`Authorization: Bearer <token>`, expires after about 15 minutes) and API Key (`X-API-Key: ab0t_sk_...`, revocable, permissions fixed when minted).

## Three Security Levels

1. **Authentication** — "Who are you?" (JWT/API key validation)
2. **Authorization** — "Do you have permission?" (permission check)
3. **Ownership** — "Is this YOUR resource?" (Phase 2 verification)

All three must pass. Why three? Authentication proves identity but not capability. Authorization proves capability but not scope — an admin in Org A shouldn't touch Org B. Ownership binds permission to a specific resource.

## Permission Design

**Format:** `{service}.{action}` or `{service}.{action}.{resource}` — e.g., `myservice.create.allocations`

Every service describes itself in `config/permissions.json`. It's the single source of truth consumed by `authsetup` (registration), the auth service, and your Python code. See `assets/permissions-template.json` for a full, validated example.

**Agentic thinking:** Scan your route handlers, categorize them:
- Return data without side effects → `read`
- Modify existing records → `write`
- Create new records (cost/resources) → `create`
- Permanently remove data → `delete`
- Run user-provided code → `execute`

Then look at domain models — each top-level model is a resource.

**Key principles:**
- Not every action×resource needs a permission — only define what routes actually check
- `implies` documents what `admin` covers; it grants nothing by itself, so your code checks admin explicitly
- `cross_tenant` (reaches across customers) is marked `"scope": "platform"`: never implied by admin, never a default, granted one person at a time
- `ssh` defaults to false — interactive access bypasses structured command logging

→ **Full schema, scope rules, actions table, roles:** See [references/permissions-design.md](references/permissions-design.md)

## Service Registration

Register with the **`authsetup`** CLI (https://github.com/ab0t-com/clientsetup). One idempotent run creates your service org, its admin account with a **randomly generated password**, your permission registry entry and your service key, and saves them mode `0600` under `~/.authmesh/<service>/` (one file per environment). Nothing is derived from your service name.

```sh
authsetup --config-dir ./config validate                    # offline check
authsetup --env dev --config-dir ./config up --dry-run      # preview
authsetup --env dev --config-dir ./config up                # apply
authsetup --env dev settings --env-file .env                # AB0T_AUTH_URL, AB0T_AUTH_AUDIENCE, AUTH_SERVICE_KEY, ...
```

Always pass `--env` (no `--env` means prod). Step by step: authmesh SOPs 03–06, https://github.com/ab0t-com/bots/tree/main/authmesh

→ **Granting/revoking permissions, platform permissions, API keys, calling other services:** See [references/registration.md](references/registration.md)

## Implementation

### Install

```
# requirements.txt
ab0t-auth @ git+https://github.com/ab0t-com/auth_wrapper.git@v0.1.4
```

or `pip install "git+https://github.com/ab0t-com/auth_wrapper.git@v0.1.4"`

### Config (app/config.py)

```python
class Settings(BaseSettings):
    AB0T_AUTH_URL: str = "https://auth.service.ab0t.com"   # dev: https://auth.dev.ab0t.com
    AB0T_AUTH_AUDIENCE: str = "myservice"                   # your service.audience (authsetup settings prints it)
    AB0T_AUTH_DEBUG: bool = False
    AB0T_AUTH_PERMISSION_CHECK_MODE: str = "server"         # "client" or "server"
```

These are your service's own settings, passed to `AuthGuard` below (they match what `authsetup settings --env-file` writes). Auth bypass for local development is separate and read by the library straight from the environment (`AB0T_AUTH_BYPASS=true` **and** `AB0T_AUTH_DEBUG=true`); never outside a local sandbox.

**Why `server` mode?** Revoking a compromised user's access takes effect within seconds (the library caches answers briefly: about 15 s for permissions, 60 s for API keys) — not when their JWT expires. For sensitive routes (admin, money, ownership) pass `fresh=True` to the dependency so that call always asks the auth service.

### Auth Module (app/auth.py)

**Why one centralized module?** Auth config must be consistent across all routes. One file = one import = one audit point.

```python
from ab0t_auth import AuthGuard, AuthenticatedUser, require_auth, require_permission, require_any_permission, optional_auth
from ab0t_auth.middleware import register_auth_exception_handlers
from ab0t_auth.errors import PermissionDeniedError
from ab0t_auth.tenant import TenantConfig
from .config import settings

auth = AuthGuard(
    auth_url=settings.AB0T_AUTH_URL,
    audience=settings.AB0T_AUTH_AUDIENCE,
    debug=settings.AB0T_AUTH_DEBUG,
    permission_check_mode=settings.AB0T_AUTH_PERMISSION_CHECK_MODE,
)
```

### Check Callbacks

Functions `(user, request) -> bool` (sync or `async`) that run AFTER permission check, BEFORE route handler. A callback that raises or returns a non-bool counts as a denial (403).

**Why needed?** Permissions answer "CAN this user do this action type?" but not "SHOULD they right now?" A user might have the permission but be suspended, over quota, or in the wrong org.

**How to decide which callbacks:** For each type alias, ask "What could go wrong even with the right permission?"
- Wrong org → `belongs_to_org`
- Someone else's resource → `is_resource_owner`
- Account suspended → `is_not_suspended` (your own suspension store; the library doesn't track it)
- Over limits → `is_within_quota`

### Type Aliases

Replace `Depends(get_current_user)` — encode permission + checks in the function signature. Self-documenting security.

```python
# Read — org membership sufficient
ResourceReader = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.read", check=belongs_to_org)
)]

# Create — org + not suspended + within quota
ResourceAllocator = Annotated[AuthenticatedUser, Depends(
    require_any_permission(auth, "myservice.create.allocations", "myservice.create.deployments",
        checks=[belongs_to_org, is_not_suspended, is_within_quota], check_mode="all")
)]

# Write/delete/scale — must own resource (admins pass too: implies is not expanded, so list admin explicitly)
ResourceWriter = Annotated[AuthenticatedUser, Depends(
    require_any_permission(auth, "myservice.write", "myservice.admin", check=is_resource_owner)
)]
```

**Choosing the right alias:** Ask these questions:
1. Read-only or mutates state? → Read gets `belongs_to_org`; mutation gets `is_resource_owner`
2. Creates something new (cost)? → Add `is_not_suspended` + `is_within_quota`
3. Accesses specific existing resource? → Need Phase 2 in route body
4. Org-wide admin operation? → `ResourceAdmin` with `belongs_to_org`
5. No org boundary (your own operators)? → `PlatformAdmin` on a `scope: platform` permission, no org check

### Phase 2 Verification

Phase 1 (dependency) runs before your route — it doesn't know WHICH resource. Phase 2 runs after DB fetch when you know the resource's `org_id` and `user_id`.

```python
def verify_allocation_access(allocation, user: AuthenticatedUser) -> None:
    if allocation.user_id == user.user_id: return          # Owner
    if user.has_permission("myservice.admin") and allocation.org_id == user.org_id: return  # Org admin
    if user.has_permission("myservice.cross_tenant"): return  # Your support staff (scope: platform)
    raise PermissionDeniedError("Access denied", required_permission="myservice.admin")
```

**When needed:** Any route with a resource ID in the path (`/allocations/{id}`). NOT needed for create (assigns ownership) or list (scoped by `get_user_filter()`).

### Database Query Scoping

```python
def get_user_filter(user: AuthenticatedUser) -> dict:
    if user.has_permission("myservice.cross_tenant"): return {}           # See everything
    if user.has_permission("myservice.admin"): return {"org_id": user.org_id}  # Org-wide
    return {"user_id": user.user_id, "org_id": user.org_id}            # Own only
```

### main.py Integration

```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    async with auth.lifespan():  # JWKS fetch, cache setup
        yield

app = FastAPI(title="My Service", lifespan=lifespan)
register_auth_exception_handlers(app)  # Proper 401/403/503 JSON responses
```

→ **Full check callbacks, all type aliases, TenantConfig (what the hierarchy flags really do), Phase 2 functions:** See [references/implementation-details.md](references/implementation-details.md)

## Route Protection

Choose the pattern by asking:
- Returns a collection? → **Pattern 1** (list + filter)
- Fetches specific resource by ID? → **Pattern 2** (get + Phase 2)
- Creates something new? → **Pattern 3** (create, no Phase 2 needed)
- Deletes/terminates? → **Pattern 4** (destructive + Phase 2)
- Nested resource (instance in allocation)? → **Pattern 5** (verify parent first)
- Org-wide admin action? → **Pattern 6** (admin-only)
- Works without auth? → **Pattern 7** (optional auth)

→ **All 7 patterns with code, route table by module:** See [references/route-patterns.md](references/route-patterns.md)

## Orgs, users and other services

Your service gets three orgs from `authsetup`: **your app** (the service org, slug = your service id), **your users** (`<service>-users`, where sign-ups land with your `default_grant` permissions) and, if you open your API to others, **your partners** (`<service>-api-consumers`). To call another mesh service, become its consumer with `authsetup connect <provider> --as <service>` and send the key it saves as `X-API-Key`. Background: authmesh SOPs 01 (scope model), 09 (your users), 10 (your team), 11 (using other services), 12 (opening your service to others).

## File Checklist

When integrating, create/modify in this order (each depends on previous):

| # | File | Action | Purpose |
|---|------|--------|---------|
| 1 | `config/permissions.json` | Create | Permission definitions, roles, end-user org structure (`authsetup init --publish` or the asset template) |
| 2 | — | Run | `authsetup validate`, then `authsetup --env dev up` (registration) |
| 3 | `.env` / secrets manager | Fill | `authsetup --env dev settings --env-file .env` (gitignored, 0600) |
| 4 | `app/config.py` | Add settings | `AB0T_AUTH_URL`, `AB0T_AUTH_AUDIENCE`, etc. |
| 5 | `app/auth.py` | Create | AuthGuard, TenantConfig, callbacks, type aliases, Phase 2 |
| 6 | `app/main.py` | Modify | `auth.lifespan()` + `register_auth_exception_handlers(app)` |
| 7 | `app/api/*.py` | Modify | Replace old auth with type aliases, add Phase 2 |
| 8 | `app/dependencies.py` | Clean up | Remove old `get_current_user` functions |
| 9 | `requirements.txt` | Add line | `ab0t-auth @ git+https://github.com/ab0t-com/auth_wrapper.git@v0.1.4` |

## Common Mistakes

1. **Forgetting Phase 2** — any authenticated user reads any resource by ID. Audit every route with a resource ID path param.
2. **Unfiltered list queries** — `list_allocations()` without `get_user_filter()` returns all orgs.
3. **Wrong permission level** — `ResourceWriter` for delete (should be `ResourceTerminator`). Write=modify, delete=remove.
4. **None before verify** — `verify_allocation_access(None, user)` → `AttributeError`. Always 404 before 403.
5. **`user.id` vs `user.user_id`** — old models use `.id`; `AuthenticatedUser` only has `.user_id`, and `user.id` raises `AttributeError` (it is a frozen, slotted dataclass).
6. **No audience set** — user tokens minted for another service are accepted by yours. Set `AB0T_AUTH_AUDIENCE` to your `service.audience`.
7. **Stale API key permissions** — a key's permissions are fixed when it is minted; re-running `authsetup` or granting later does not widen it. `authsetup --env <env> doctor` reports it; mint a new key (authmesh SOP 14).
8. **Trusting `implies`** — it is documentation only; check `myservice.admin` explicitly where admin should pass.

## What your customers notice

- `401` with no or a bad token (they sign in again), `403` when they lack the permission or the resource
  belongs to another org, `503` when the auth service could not be asked (retry; never treated as
  allowed). `register_auth_exception_handlers(app)` gives these a consistent JSON body.
- With `permission_check_mode="server"`, a revoked grant stops passing within 15 s and a revoked API
  key within 60 s (the library's default caches, 0.1.4); pass `fresh=True` on admin, money and
  ownership routes so those always ask. In client mode a revocation waits for the token to expire
  (15 minutes).
- One customer never sees another's data, provided every list is filtered and every by-id route runs
  Phase 2.

## Check it worked

```bash
authsetup --env dev --config-dir ./config run 06     # a throwaway sign-up holds the defaults; token audience matches
authsetup --env dev doctor                           # service key holds every declared permission
```
Then, with a real user token: `200` on a default-permission route, `403` on one you did not grant,
`404`/`403` when user A asks for user B's resource id, `401` with no token
([references/testing-troubleshooting.md](references/testing-troubleshooting.md) has the test set).
Still stuck: the failing request, the response body and `authsetup --env dev doctor --json` to
`platform-team@ab0t.com` (never a token or key).

## Reference Files

| File | Content | When to read |
|------|---------|--------------|
| [references/permissions-design.md](references/permissions-design.md) | Full `config/permissions.json` schema, `scope` (org vs platform), actions table, roles, design principles | Designing permissions for a new service |
| [references/registration.md](references/registration.md) | Registering with `authsetup`, granting/revoking permissions, platform grants, API keys, calling other services | Registering a service or managing permissions |
| [references/implementation-details.md](references/implementation-details.md) | All check callbacks, type aliases, Phase 2 functions, TenantConfig | Building app/auth.py |
| [references/route-patterns.md](references/route-patterns.md) | All 7 route protection patterns with code, route-module table | Protecting routes |
| [references/library-api.md](references/library-api.md) | Core imports, AuthenticatedUser, AuthGuard, permission functions, errors | Looking up function signatures |
| [references/testing-troubleshooting.md](references/testing-troubleshooting.md) | Security testing, auth bypass, troubleshooting table, debug checklist | Testing or debugging auth issues |
| [references/auth-service-api.md](references/auth-service-api.md) | Auth service REST API — login, validate tokens/keys, grant/revoke permissions, API keys, orgs, quotas | Testing auth flows, debugging with curl |
| [references/FAQ.md](references/FAQ.md) | Questions by stage: design, registration, implementation, keys, multi-tenancy, testing, debugging, security, migration | Quick answers; `grep -A 20 'FAQ:keyword'` |

Full library reference: the ab0t-auth README, https://github.com/ab0t-com/auth_wrapper. Live auth service contract: `https://auth.service.ab0t.com/openapi.json`.
