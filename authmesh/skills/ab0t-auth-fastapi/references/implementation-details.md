# Implementation Details Reference

## Full Auth Module Pattern (app/auth.py)

```python
"""
Authentication & Authorization for Your Service.

Uses ab0t-auth with:
- Global AuthGuard configuration
- Multi-tenant isolation via TenantConfig
- Permission-based access control
- Check callbacks for resource-level ownership verification
"""
from typing import Annotated
from fastapi import Depends, Request

from ab0t_auth import (
    AuthGuard, AuthenticatedUser,
    require_auth, require_permission, require_any_permission, optional_auth,
)
from ab0t_auth.middleware import register_auth_exception_handlers
from ab0t_auth.errors import PermissionDeniedError
from ab0t_auth.tenant import TenantConfig

from .config import settings


# =============================================================================
# Global Configuration
# =============================================================================

auth = AuthGuard(
    auth_url=settings.AB0T_AUTH_URL,
    audience=settings.AB0T_AUTH_AUDIENCE,
    debug=settings.AB0T_AUTH_DEBUG,
    permission_check_mode=settings.AB0T_AUTH_PERMISSION_CHECK_MODE,
)

tenant_config = TenantConfig(
    enforce_tenant_isolation=True,       # Every resource belongs to exactly one org
    enforce_org_isolation=True,          # Strict — no accidental cross-org leaks
    allow_cross_tenant_admin=True,       # Your support staff need cross-org access
    cross_tenant_permission="myservice.cross_tenant",  # Must match config/permissions.json
    enable_org_hierarchy=False,          # Flat customers: no org-path checks (see TenantConfig below)
    allow_ancestor_access=False,
    allow_descendant_access=False,
)
```

### AuthGuard Parameters

| Parameter | Purpose |
|-----------|---------|
| `auth_url` | Auth service URL for JWKS fetch and server-side permission checks |
| `audience` | Only accept JWTs with this audience claim. Rejects tokens meant for other services. |
| `debug` | Enable verbose logging. (Auth bypass is separate: it needs both environment variables `AB0T_AUTH_BYPASS=true` and `AB0T_AUTH_DEBUG=true`; local development only.) |
| `permission_check_mode` | `"client"` (library default) = check JWT claims locally, `"server"` = ask the auth service on each check, so revocations bite within seconds |

### TenantConfig

**How to configure for your service:** Most services want both `enforce_tenant_isolation` and `enforce_org_isolation` as `True`. Leave org hierarchy off unless you have nested orgs and know what the two hierarchy flags actually do in the library (ab0t-auth 0.1.4, `ab0t_auth/tenant.py`):

| Setting | What the library does |
|---|---|
| `enable_org_hierarchy` | Turns on the org-path check below. Off = only the caller's own org (plus `cross_tenant_permission`) passes. |
| `allow_ancestor_access` | The caller may access an org that appears in **their own** ancestry path (the `org_path` / `organization_path` token claim): a user in a child org can reach its **parent and grandparent** orgs. It does **not** let a parent-org user into child orgs. The library default is `True`, so set it explicitly. |
| `allow_descendant_access` | Not enforced client-side: the library cannot see a target org's ancestry, so this flag grants nothing locally. Reaching **down** into child orgs is decided by the auth service (an ancestor org can act in its descendants there), not by `TenantConfig`. |

If you need "a parent-org admin manages its child orgs' resources", decide it on the server side (`permission_check_mode="server"`, checking against the target org) or in your Phase 2 code. Keep `allow_ancestor_access=False` unless child-org users really should see their parent's data.

## Check Callbacks

Functions with signature `(user: AuthenticatedUser, request: Request) -> bool`. Run AFTER permission verification, BEFORE route handler. Return `True` to allow, `False` to deny.

**Why needed beyond permissions?** Permissions answer "CAN this user do this type of action?" but not "SHOULD they right now?" A user might have the permission but be suspended, over quota, or requesting resources in someone else's org.

```python
def belongs_to_org(user: AuthenticatedUser, request: Request) -> bool:
    """
    User must belong to the org specified in path or query.
    Platform admins with cross_tenant bypass this.

    WHY: Used for operations where org membership is sufficient —
    reading, creating, listing. You don't need to own a specific resource
    to list resources in your org or create a new one.
    """
    org_id = request.path_params.get("org_id") or request.query_params.get("org_id")
    if not org_id:
        return True
    return user.org_id == org_id or user.has_permission("myservice.cross_tenant")


def is_resource_owner(user: AuthenticatedUser, request: Request) -> bool:
    """
    User must own the resource OR be admin in same org.

    WHY: Used for mutation operations (write, delete, scale, execute).
    Unlike belongs_to_org, this ensures you can only modify YOUR resources,
    not just any resource in your org. Admins bypass because they manage
    all resources in the org.
    """
    user_id = request.path_params.get("user_id")
    if not user_id:
        return True
    return user.user_id == user_id or user.has_permission("myservice.admin")


async def is_not_suspended(user: AuthenticatedUser, request: Request) -> bool:
    """
    Suspended users cannot create/write/delete.

    WHY: Suspension is an account-level override. A suspended user keeps their
    permissions (so reactivation is instant) but cannot mutate state or incur costs.
    Read operations are still allowed.
    """
    # Suspension is YOUR service's state: the library does not fill user.metadata.
    return not await accounts.is_suspended(user.org_id, user.user_id)


async def is_within_quota(user: AuthenticatedUser, request: Request) -> bool:
    """Preliminary quota check. Catches over-quota users before business logic."""
    return not await quotas.is_exceeded(user.org_id)
```

`accounts` and `quotas` stand for your own data access. Callbacks may be sync or `async`; a callback that raises or returns a non-`bool` counts as a failure (403).

`is_resource_owner` above only sees path parameters, so it can only compare a `{user_id}` in the path. For `/items/{item_id}` routes the real ownership check is Phase 2, after you load the item.

### Using Check Callbacks

**Single check** — `check=callback`:
```python
ResourceReader = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.read", check=belongs_to_org)
)]
```

**Multiple checks (ALL must pass)** — `checks=[...], check_mode="all"`:
```python
ResourceAllocator = Annotated[AuthenticatedUser, Depends(
    require_any_permission(
        auth,
        "myservice.create.allocations",
        "myservice.create.deployments",
        checks=[belongs_to_org, is_not_suspended, is_within_quota],
        check_mode="all",
    )
)]
```

## Complete Type Alias Listing

### Basic Auth

```python
# Any authenticated user (JWT or API key)
CurrentUser = Annotated[AuthenticatedUser, Depends(require_auth(auth))]

# Optional auth — returns None if not authenticated
OptionalUser = Annotated[AuthenticatedUser | None, Depends(optional_auth(auth))]
```

### Permission-Based with Checks

`implies` in `permissions.json` is documentation only: the auth service does not expand it. Where an org admin should pass, list `myservice.admin` as an alternative (`require_any_permission`), or grant admins the specific permissions through a team.

```python
# Read operations — must be in same org
ResourceReader = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.read", check=belongs_to_org)
)]

# Create operations — org check + not suspended + within quota
ResourceAllocator = Annotated[AuthenticatedUser, Depends(
    require_any_permission(
        auth, "myservice.create.allocations", "myservice.create.deployments",
        checks=[belongs_to_org, is_not_suspended, is_within_quota], check_mode="all",
    )
)]

# Write/update — must own resource or be admin
ResourceWriter = Annotated[AuthenticatedUser, Depends(
    require_any_permission(auth, "myservice.write", "myservice.admin", check=is_resource_owner)
)]

# Delete/terminate — must own resource or be admin
ResourceTerminator = Annotated[AuthenticatedUser, Depends(
    require_any_permission(auth, "myservice.delete", "myservice.admin", check=is_resource_owner)
)]

# Execute commands — must own resource, not suspended
ResourceExecutor = Annotated[AuthenticatedUser, Depends(
    require_any_permission(
        auth, "myservice.execute.instances", "myservice.execute.containers",
        checks=[is_resource_owner, is_not_suspended], check_mode="all",
    )
)]

# Scale operations — must own resource or be admin
ResourceScaler = Annotated[AuthenticatedUser, Depends(
    require_any_permission(auth, "myservice.scale", "myservice.admin", check=is_resource_owner)
)]

# Admin — org-level access
ResourceAdmin = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.admin", check=belongs_to_org)
)]

# Platform admin — your own operators; myservice.admin.config is declared "scope": "platform" (no org check)
PlatformAdmin = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.admin.config")
)]
```

### Specialized Access

```python
# SSH/console access — explicit permission, not default-granted
SSHUser = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.ssh.instances",
        checks=[is_resource_owner, is_not_suspended], check_mode="all")
)]

# Log viewer
LogViewer = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.logs", check=is_resource_owner)
)]

# Metrics viewer
MetricsViewer = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.metrics", check=is_resource_owner)
)]

# Workflow executor — org check + not suspended
WorkflowExecutor = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.execute.workflows",
        checks=[belongs_to_org, is_not_suspended], check_mode="all")
)]

# Workflow creator
WorkflowCreator = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.create.workflows", check=belongs_to_org)
)]

# Cost admin — org-level cost management
CostAdmin = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.admin.costs", check=belongs_to_org)
)]

# Cost reader
CostReader = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.read.costs", check=belongs_to_org)
)]

# Quota admin
QuotaAdmin = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.admin.quotas", check=belongs_to_org)
)]

# Quota reader
QuotaReader = Annotated[AuthenticatedUser, Depends(
    require_permission(auth, "myservice.read.quotas", check=belongs_to_org)
)]
```

### Type Alias Selection Table

| Operation | Type Alias | Permission | Checks |
|-----------|------------|------------|--------|
| View resources | `ResourceReader` | `myservice.read` | belongs_to_org |
| Create/deploy | `ResourceAllocator` | `myservice.create.*` | belongs_to_org, not_suspended, within_quota |
| Update/modify | `ResourceWriter` | `myservice.write` or `myservice.admin` | is_resource_owner |
| Delete/terminate | `ResourceTerminator` | `myservice.delete` or `myservice.admin` | is_resource_owner |
| Run commands | `ResourceExecutor` | `myservice.execute.*` | is_resource_owner, not_suspended |
| Scale up/down | `ResourceScaler` | `myservice.scale` or `myservice.admin` | is_resource_owner |
| View logs | `LogViewer` | `myservice.logs` | is_resource_owner |
| View metrics | `MetricsViewer` | `myservice.metrics` | is_resource_owner |
| SSH access | `SSHUser` | `myservice.ssh.instances` | is_resource_owner, not_suspended |
| Org admin | `ResourceAdmin` | `myservice.admin` | belongs_to_org |
| Platform admin | `PlatformAdmin` | `myservice.admin.config` | (none — cross-tenant) |
| View costs | `CostReader` | `myservice.read.costs` | belongs_to_org |
| Manage costs | `CostAdmin` | `myservice.admin.costs` | belongs_to_org |

## Phase 2 Verification Functions

Phase 1 (dependency) checks permission and basic conditions. Phase 2 checks access to a **specific resource** after fetching it from the database.

**Why can't Phase 1 handle everything?** Phase 1 runs before your route handler — before any database query. It knows who the user is and what permissions they have, but not which resource they're accessing. Only after you fetch the allocation do you know its `org_id` and `user_id`.

**When to think about Phase 2:** Any route that takes a resource ID in the path (e.g., `/allocations/{allocation_id}`). Routes that create new resources or list with filters do NOT need it.

```python
def verify_allocation_access(allocation, user: AuthenticatedUser) -> None:
    """
    Verify user can access this specific allocation.
    Rules:
    1. Owner can always access their allocation
    2. Admin in same org can access org's allocations
    3. Platform admin (cross_tenant) can access any allocation
    """
    if allocation.user_id == user.user_id:
        return
    if user.has_permission("myservice.admin") and allocation.org_id == user.org_id:
        return
    if user.has_permission("myservice.cross_tenant"):
        return
    raise PermissionDeniedError(
        "Access denied to this allocation",
        required_permission="myservice.admin",
    )


def verify_org_access(resource_org_id: str, user: AuthenticatedUser) -> None:
    """Verify user can access resources in this org."""
    if user.org_id == resource_org_id:
        return
    if user.has_permission("myservice.cross_tenant"):
        return
    raise PermissionDeniedError(
        "Access denied - different organization",
        required_permission="myservice.cross_tenant",
    )


def verify_instance_access(instance, allocation, user: AuthenticatedUser) -> None:
    """Instance access inherits from allocation access."""
    verify_allocation_access(allocation, user)
```

### Critical: Always Check for None Before Phase 2

```python
# WRONG — crashes if allocation is None
allocation = await db.get_allocation(allocation_id)
verify_allocation_access(allocation, user)

# RIGHT — 404 before 403
allocation = await db.get_allocation(allocation_id)
if not allocation:
    raise HTTPException(404, "Allocation not found")
verify_allocation_access(allocation, user)
```

## Database Query Scoping (Multi-Tenant)

**Why filter at the database layer?** Phase 2 only works for single-resource access. List endpoints return many resources — you can't run `verify_allocation_access()` on hundreds of results. Scope the query so the database only returns what the user can see.

```python
def get_user_filter(user: AuthenticatedUser) -> dict:
    """
    Three tiers:
    - Regular users see only their own resources
    - Org admins see everyone's resources in their org
    - Platform admins see everything across all orgs
    """
    if user.has_permission("myservice.cross_tenant"):
        return {}
    if user.has_permission("myservice.admin"):
        return {"org_id": user.org_id}
    return {"user_id": user.user_id, "org_id": user.org_id}
```

Usage:
```python
@router.get("/allocations")
async def list_allocations(user: ResourceReader):
    filters = get_user_filter(user)
    return await db.list_allocations(**filters)
```

## main.py Integration

Two things must happen:

1. **Lifespan** — AuthGuard fetches JWKS keys on startup and caches them. Without initialization, the first request fails.
2. **Exception handlers** — Without these, auth errors bubble up as unhandled 500s instead of structured 401/403 JSON responses.

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from .auth import auth, register_auth_exception_handlers

@asynccontextmanager
async def lifespan(app: FastAPI):
    async with auth.lifespan():
        # ... other startup code ...
        yield
        # ... shutdown code ...

app = FastAPI(title="My Service", lifespan=lifespan)
register_auth_exception_handlers(app)
```

## Migration from Old User Model

`AuthenticatedUser` is a frozen dataclass with slots: reading an attribute it does not have (e.g. `user.id`) raises `AttributeError`, it does not return `None`.

| Old (your own user model) | New (`AuthenticatedUser`) |
|---|---|
| `user.id` | `user.user_id` |
| `user.email` | `user.email` (may be `None`, e.g. for API keys) |
| `user.name` | not carried; read it from `user.claims.raw` if your tokens include it, or from your own store |
| `user.permissions` (list) | `user.permissions` (tuple, immutable) |
| `user.is_active` | your own store (the library does not track suspension) |
| — | `user.has_permission("myservice.admin")` |
| — | `user.has_role("myservice-admin")` |
| — | `user.auth_method` (JWT or API key) |
