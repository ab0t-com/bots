# Permission Design Reference

## The `config/permissions.json` file

Every service describes itself in one file, `config/permissions.json`. It serves three purposes:
1. **Documentation** — describes all permissions the service uses
2. **Registration** — `authsetup` reads it to register your service with the auth service
3. **Reference** — other services know what permissions exist

**Why a JSON file instead of inline code?** Permissions span three concerns: the auth service needs them for registration, `authsetup` reads them, and your Python code enforces them. One file is the source of truth all three consume.

`authsetup init --publish` writes a safe starter for you; or start from `assets/permissions-template.json` (a full, validated example). Check it offline with `authsetup --config-dir ./config validate` before anything touches a server. The full walk-through is authmesh SOP 04: https://github.com/ab0t-com/bots/blob/main/authmesh/04_sop_system_describe_your_service.md

### Minimal template

```json
{
  "$schema": "https://auth.service.ab0t.com/schemas/permissions/v2",

  "service": {
    "id": "myservice",
    "name": "My Service",
    "description": "What this service does",
    "version": "1.0.0",
    "audience": "myservice",
    "maintainer": "<your-team>@example.com"
  },

  "registration": {
    "service": "myservice",
    "actions": ["read", "write", "create", "delete", "admin", "cross_tenant"],
    "resources": ["items", "config"]
  },

  "permissions": [
    {
      "id": "myservice.read",
      "name": "Read",
      "description": "View items in your org",
      "intent": "Why this permission exists and who needs it",
      "risk_level": "low",
      "cost_impact": false,
      "default_grant": true
    },
    {
      "id": "myservice.write",
      "name": "Write",
      "description": "Create and edit items in your org",
      "risk_level": "medium",
      "cost_impact": false,
      "default_grant": true
    },
    {
      "id": "myservice.admin",
      "name": "Administrator",
      "description": "Administer myservice inside your own org",
      "risk_level": "critical",
      "cost_impact": true,
      "default_grant": false,
      "security_notes": "Admins can access all resources in their org but not other orgs.",
      "implies": ["myservice.read", "myservice.write", "myservice.delete"]
    },
    {
      "id": "myservice.cross_tenant",
      "name": "Cross-Tenant Access",
      "description": "Access resources in any customer's organization",
      "risk_level": "critical",
      "default_grant": false,
      "scope": "platform",
      "security_notes": "Log every cross-tenant access. Grant one person at a time."
    }
  ],

  "roles": [
    { "id": "myservice-user",  "name": "User",  "permissions": ["myservice.read", "myservice.write"], "default": true },
    { "id": "myservice-admin", "name": "Admin", "permissions": ["myservice.admin"], "default": false }
  ],

  "end_users": {
    "default_role": "myservice-user",
    "default_team_name": "Default Users",
    "org_structure": { "pattern": "flat", "config": {} }
  }
}
```

### Key fields

| Field | Purpose |
|-------|---------|
| `service.id` | Unique service identifier: lowercase letters, digits and `_` only (no hyphens). Becomes the permission prefix and your service org's slug. Cannot be changed later. |
| `service.audience` | The audience your backend checks on every user token. Keep it equal to `service.id`. Fixed when your org is created. Without an audience check, a token minted for another service would be accepted by yours. |
| `registration.actions` / `registration.resources` | The registry registers `{service}.{action}` and `{service}.{action}.{resource}` for every combination. A permission whose action or resource is not in these lists is **dead**: it registers nothing and nobody can be granted it (`validate` warns). |
| `permissions[].id` | The permission string: `{service}.{action}` or `{service}.{action}.{resource}`. Only define the ones your routes actually check. |
| `permissions[].scope` | `"org"` (default: acts inside one customer's org) or `"platform"` (reaches across customers). Using `scope` on any permission puts the whole file in *declared* mode. See below. |
| `permissions[].default_grant` | Every person who signs up gets it, through the default team. Ask: "Should a brand-new user be able to do this without explicit approval?" Never for admin, delete, or anything cross-customer. |
| `permissions[].implies` | Documentation for humans and admin tooling: "admin covers these". It does **not** grant anything by itself; in your code, check the specific permission or the admin permission explicitly. |
| `roles[]` | Named personas. Exactly one may be `default: true`. Today a role sets a name only: what a new user can actually do comes from `default_grant` permissions and teams, not from the role's list. |
| `end_users.org_structure.pattern` | `flat` (users share one space) or `workspace-per-user` (each user gets a private org). See authmesh SOP 09. |

## Scope: `org` vs `platform`

Most permissions are `org`: they only ever act inside one customer's org, including `myservice.admin` ("admin of myservice inside your own org"). A few reach across all your customers (a support view of every customer, an operator kill switch): mark those `"scope": "platform"`.

In declared mode `authsetup validate` enforces:
- a permission whose name sounds cross-customer (`cross`, `global`, `platform`, `tenant_gateway`, `_wide`, `read_all`, `superadmin`) must be marked `platform`;
- a `platform` permission, or one with `risk_level` `high` or `critical`, may not be `default_grant`, in the default role, or on the default team.

Only admins of your own service org can hand out your `platform` permissions, one person at a time with a reason (`authsetup grant-platform`, authmesh SOP 10). Your customers' admins can grant your `org` permissions inside their own org, never `platform` ones. Background: authmesh SOP 01.

## Designing actions

**Agentic thinking process:** Scan every route handler and categorize:
- Routes that return data without side effects → `read`
- Routes that modify existing records → `write`
- Routes that create new records (especially if they cost money or consume resources) → `create`
- Routes that permanently remove data → `delete`
- Routes that run user-provided code or commands → `execute`
- Routes that change capacity or scale → `scale`
- Routes that provide interactive shell access → `ssh`

Then look at your domain models. Each top-level model is typically a resource. Don't create permissions for internal implementation details — only for things users interact with directly.

### Common actions

| Action | Intent | Typical risk level | Default grant |
|--------|--------|------------|---------------|
| `read` | View data | low | Yes |
| `write` | Modify existing data | medium | Yes |
| `create` | Create new records | medium | Yes |
| `delete` | Permanently remove | high | No (grant via a team or admin) |
| `execute` | Run code/commands | high | No |
| `scale` | Adjust capacity | medium | Yes |
| `ssh` | Shell access | high | No |
| `logs` | View logs | low | Yes |
| `metrics` | View monitoring data | low | Yes |
| `admin` | Full control inside one org | critical | No |
| `cross_tenant` | Reach across customers (`scope: platform`) | critical | Never |

`risk_level` `high`/`critical` cannot be a default in declared mode. If your product really needs everyday users to delete or execute, give it `risk_level: "medium"` deliberately and say why in `intent`.

### Design principles

1. **Not every action×resource combination is needed** — only define permissions that map to actual route handlers.
2. **Admin covers lower permissions in your code** — `implies` documents what admin covers, but enforcement is yours: check `myservice.admin` alongside the specific permission (see `require_any_permission` in implementation-details.md).
3. **`cross_tenant` is always separate** — `scope: platform`, never implied by `admin`, never default-granted. Org admins must never accidentally gain cross-org access.
4. **`ssh` defaults to false** — interactive access bypasses structured `execute` command logging. Most users don't need it; operators do.

## Defining roles

**How to think about roles:** Ask "Who are the distinct personas using this service?" Each persona becomes a role.

- **viewer** — read-only (auditors, stakeholders).
- **user** — everyday work on their own resources (the default role).
- **operator** — manage resources but not create (ops team): stop, restart, SSH, but no provisioning or new costs.
- **admin** — full access inside the org (team leads). Cannot cross org boundaries.

Cross-customer access is not a role: `platform` permissions are granted to individual people with `authsetup grant-platform`.

### Full example

`assets/permissions-template.json` is a complete, validated example for a compute-style service:
- **11 actions**: read, write, create, delete, scale, execute, admin, ssh, logs, metrics, cross_tenant
- **8 resources**: allocations, instances, deployments, containers, workflows, costs, quotas, config
- **22 permissions** (11 `default_grant`, 3 `scope: platform`)
- **4 roles**: myservice-user (default), myservice-viewer, myservice-operator, myservice-admin

Rename `myservice` to your own service id everywhere (permission ids, roles, audience) before you use it.
