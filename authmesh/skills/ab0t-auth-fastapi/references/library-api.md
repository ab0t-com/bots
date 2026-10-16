# Library API Reference (Quick Reference)

> Checked against ab0t-auth **v0.1.4**. The library's own README is the full reference: https://github.com/ab0t-com/auth_wrapper (install: `pip install "git+https://github.com/ab0t-com/auth_wrapper.git@v0.1.4"`).

## Core Imports and Signatures

```python
from ab0t_auth import (
    AuthGuard,              # Main coordinator
    AuthenticatedUser,      # User object after auth
    require_auth,           # Require any authenticated user
    require_permission,     # Require specific permission
    require_any_permission, # Require any of several permissions
    require_all_permissions,# Require all listed permissions
    optional_auth,          # Returns None if not authenticated
)

from ab0t_auth.middleware import (
    AuthMiddleware,                    # ASGI middleware
    setup_auth_middleware,             # Helper to add middleware
    get_user_from_request,             # Get user from request.state
    register_auth_exception_handlers,  # Register 401/403 handlers
)

from ab0t_auth.errors import (
    AuthError,              # Base error class
    TokenExpiredError,      # 401 - token expired
    TokenInvalidError,      # 401 - malformed or bad signature
    TokenNotFoundError,     # 401 - no token in request
    PermissionDeniedError,  # 403 - missing permission
    InsufficientScopeError, # 403 - missing scope
    AuthServiceError,       # 503 - auth service unavailable
    JWKSFetchError,         # 503 - JWKS fetch failed
    ConfigurationError,     # 500 - invalid config
    RateLimitError,         # 429 - rate limited
)

from ab0t_auth.tenant import TenantConfig
```

## Dependency Function Signatures

```python
def require_auth(
    guard: AuthGuard,
    *,
    allow_api_key: bool = True,
    check: AuthCheckCallable | None = None,
    checks: Sequence[AuthCheckCallable] | None = None,
    check_mode: Literal["all", "any"] = "all",
    check_error: str = "Authorization check failed",
    fresh: bool = False,                   # True = skip the validation cache for this route
) -> Callable[..., Any]:
    """Require authentication. Raises TokenNotFoundError if not authenticated."""

def require_permission(
    guard: AuthGuard,
    permission: str,
    *,
    allow_api_key: bool = True,
    check: AuthCheckCallable | None = None,                # Single check callback
    checks: Sequence[AuthCheckCallable] | None = None,     # Multiple check callbacks
    check_mode: Literal["all", "any"] = "all",
    check_error: str = "Authorization check failed",
    fresh: bool = False,
) -> Callable[..., Any]:
    """Require specific permission. Raises PermissionDeniedError if missing."""

def require_any_permission(guard, *permissions: str, allow_api_key=True,
                           check=None, checks=None, check_mode="all",
                           check_error="Authorization check failed", fresh=False): ...
    """Require ANY of the specified permissions."""

def require_all_permissions(guard, *permissions: str, allow_api_key=True,
                            check=None, checks=None, check_mode="all",
                            check_error="Authorization check failed", fresh=False): ...
    """Require ALL specified permissions."""

def optional_auth(guard, *, allow_api_key=True, check=None, checks=None, check_mode="all"): ...
    """Optional auth. Returns None if not authenticated."""
```

## AuthenticatedUser Object

```python
@dataclass(frozen=True, slots=True)
class AuthenticatedUser:
    user_id: str                        # Unique user ID
    email: str | None = None            # User email
    org_id: str | None = None           # User's organization
    permissions: tuple[str, ...] = ()   # Granted permissions (immutable)
    roles: tuple[str, ...] = ()         # Assigned roles (immutable)
    auth_method: AuthMethod             # JWT, API_KEY, or BYPASS
    token_type: TokenType               # BEARER, API_KEY, or NONE
    claims: TokenClaims | None = None   # Parsed JWT claims; claims.raw is the full dict
    metadata: dict[str, Any] = {}       # Not filled by the library; empty unless you build the user yourself

    # Frozen + slots: unknown attributes (e.g. user.id) raise AttributeError.

    def has_permission(self, permission: str) -> bool: ...
    def has_any_permission(self, *permissions: str) -> bool: ...
    def has_all_permissions(self, *permissions: str) -> bool: ...
    def has_role(self, role: str) -> bool: ...
```

## AuthGuard Class

```python
class AuthGuard:
    def __init__(
        self,
        auth_url: str | None = None,
        *,
        config: AuthConfig | None = None,       # takes precedence
        settings: AuthSettings | None = None,   # AuthSettings() reads AB0T_AUTH_<FIELD> env vars, so the URL is
                                                # AB0T_AUTH_AUTH_URL there. This skill reads AB0T_AUTH_URL (what
                                                # `authsetup settings` writes) in your own Settings and passes it.
        org_id: str | None = None,
        audience: str | tuple[str, ...] | None = None,
        issuer: str | None = None,
        debug: bool = False,
        permission_check_mode: str = "client",  # "client" or "server"
    ) -> None: ...

    # Lifecycle
    async def initialize(self) -> None: ...
    async def shutdown(self) -> None: ...
    def lifespan(self) -> AsyncContextManager: ...

    # Authentication
    async def authenticate(self, authorization=None, api_key=None) -> AuthResult: ...
    async def authenticate_or_raise(self, authorization=None, api_key=None) -> AuthenticatedUser: ...

    # Authorization
    def check_permission(self, user: AuthenticatedUser, permission: str) -> bool: ...
    def require_permission(self, user: AuthenticatedUser, permission: str) -> None: ...

    # Cache
    def invalidate_token(self, token: str) -> bool: ...
    def invalidate_user_permissions(self, user_id: str) -> int: ...
    def invalidate_api_key(self, api_key: str) -> bool: ...
    def clear_caches(self) -> None: ...

    @property
    def is_initialized(self) -> bool: ...
    @property
    def metrics(self) -> AuthMetrics: ...
```

## Permission Checking Functions

```python
from ab0t_auth.permissions import (
    # Client-side checks (pure functions, fast)
    check_permission,           # Single permission
    check_any_permission,       # Any of several
    check_all_permissions,      # All required
    check_permission_pattern,   # Glob pattern (e.g., "admin:*")

    # Guard functions (raise on failure)
    require_permission_or_raise,
    require_any_permission_or_raise,
    require_all_permissions_or_raise,

    # Predicate builders (higher-order functions)
    has_permission,             # Returns Callable[[User], bool]
    has_any_permission,
    has_all_permissions,
    has_permission_pattern,
    has_role,

    # Filtering
    filter_permissions,         # Get permissions matching pattern
    get_permission_categories,  # Get permission prefixes
)

# Usage
result = check_permission(user, "myservice.admin")
if result.allowed:
    # proceed

# Predicate usage
is_admin = has_permission("myservice.admin")
if is_admin(user):
    show_admin_panel()
```

## TenantConfig

```python
@dataclass(frozen=True, slots=True)
class TenantConfig:
    extraction_strategies: tuple[TenantExtractionStrategy, ...] = (TOKEN, HEADER, PATH)
    tenant_header: str = "X-Tenant-ID"
    org_header: str = "X-Org-ID"

    enforce_tenant_isolation: bool = True
    enforce_org_isolation: bool = True     # default since 0.1.4 (fail-closed)
    allow_cross_tenant_admin: bool = True
    cross_tenant_permission: str = "admin:cross_tenant"

    enable_org_hierarchy: bool = True
    allow_ancestor_access: bool = True    # caller may reach orgs in THEIR OWN ancestry path (parents)
    allow_descendant_access: bool = True  # not enforced client-side; grants nothing locally
```

## Error Types

| Error Class | Status | When |
|---|---|---|
| `TokenNotFoundError` | 401 | No token in request |
| `TokenExpiredError` | 401 | JWT `exp` claim is past |
| `TokenInvalidError` | 401 | Malformed JWT or bad signature |
| `PermissionDeniedError` | 403 | User lacks required permission |
| `InsufficientScopeError` | 403 | Token lacks required scope |
| `AuthServiceError` | 503 | Cannot reach auth service |
| `JWKSFetchError` | 503 | Cannot fetch JWKS keys |
| `ConfigurationError` | 500 | Invalid auth configuration |
| `RateLimitError` | 429 | Rate limit exceeded |

### PermissionDeniedError Constructor

```python
PermissionDeniedError(
    message: str = "Permission denied",
    *,
    required_permission: str | None = None,
    user_permissions: list[str] | None = None,
)
```

Usage in Phase 2:
```python
raise PermissionDeniedError(
    "Access denied to this allocation",
    required_permission="myservice.admin",
)
```

## Additional Library Features

The library also provides these capabilities (see the library README for details):

- **Decorator pattern** — `@protected(auth)`, `@permission_required(auth, "perm")` for Flask-style syntax
- **Middleware pattern** — `AuthMiddleware` for automatic auth on all requests
- **Role dependencies** — `require_role(auth, "admin")`, `require_any_role(auth, "admin", "mod")`
- **Org dependencies** — `require_org_membership(auth)`, `require_org(auth, org_id)`
- **Permission patterns** — `require_permission_pattern(auth, "admin:*")` for glob matching
- **JWT utilities** — `parse_token_header()`, `decode_token_unverified()`, `validate_token_pipeline()`
- **Logging module** — `configure_logging()`, `log_auth_attempt()`, `log_permission_check()`, `AuthMetrics`
