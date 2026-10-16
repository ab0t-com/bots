# Route Protection Patterns Reference

## Pattern Selection Guide

For each route, ask:
- Returns a collection? → **Pattern 1** (list + filter)
- Fetches specific resource by ID? → **Pattern 2** (get + Phase 2)
- Creates something new? → **Pattern 3** (create, no Phase 2)
- Deletes/terminates? → **Pattern 4** (destructive + Phase 2)
- Nested resource (instance in allocation)? → **Pattern 5** (verify parent)
- Org-wide admin action? → **Pattern 6** (admin-only)
- Works without auth? → **Pattern 7** (optional auth)

## Pattern 1: List Operation (read + tenant filtering)

```python
from ..auth import ResourceReader, get_user_filter

@router.get("/allocations")
async def list_allocations(user: ResourceReader):
    filters = get_user_filter(user)
    return await db.list_allocations(**filters)
```

## Pattern 2: Get Single Resource (read + Phase 2)

```python
from ..auth import ResourceReader, verify_allocation_access

@router.get("/allocations/{allocation_id}")
async def get_allocation(allocation_id: str, user: ResourceReader):
    allocation = await db.get_allocation(allocation_id)
    if not allocation:
        raise HTTPException(404, "Allocation not found")
    verify_allocation_access(allocation, user)
    return allocation
```

## Pattern 3: Create Operation (allocator checks)

Why does creation have more checks than reading? Creating resources has side effects: consumes cloud resources, incurs costs, counts against quotas. A suspended or over-quota user must be blocked before provisioning.

```python
from ..auth import ResourceAllocator

@router.post("/allocate")
async def allocate_resources(request: AllocationRequest, user: ResourceAllocator):
    # ResourceAllocator already checked: permission + org + not suspended + quota
    # No Phase 2 needed — we're creating, not accessing an existing resource
    allocation = await create_allocation(request, user.user_id, user.org_id)
    return allocation
```

## Pattern 4: Destructive Operation (delete + Phase 2)

```python
from ..auth import ResourceTerminator, verify_allocation_access

@router.delete("/allocations/{allocation_id}")
async def terminate_allocation(allocation_id: str, user: ResourceTerminator):
    allocation = await db.get_allocation(allocation_id)
    if not allocation:
        raise HTTPException(404, "Allocation not found")
    verify_allocation_access(allocation, user)
    await terminate(allocation)
    return {"terminated": allocation_id}
```

## Pattern 5: Nested Resource (instance within allocation)

Why verify at the allocation level for instance operations? Instances inherit access rules from their parent. Verify the parent first, then confirm the child belongs to that parent.

```python
from ..auth import ResourceWriter, verify_allocation_access

@router.post("/allocations/{allocation_id}/instances/{instance_id}/stop")
async def stop_instance(allocation_id: str, instance_id: str, user: ResourceWriter):
    allocation = await db.get_allocation(allocation_id)
    if not allocation:
        raise HTTPException(404, "Allocation not found")
    verify_allocation_access(allocation, user)

    instance = await db.get_instance(instance_id)
    if not instance or instance.allocation_id != allocation_id:
        raise HTTPException(404, "Instance not found")  # Prevents IDOR via mismatched IDs

    await stop(instance)
    return {"stopped": instance_id}
```

## Pattern 6: Admin-Only Operation

```python
from ..auth import ResourceAdmin

@router.post("/cleanup/terminate-all")
async def terminate_all(user: ResourceAdmin):
    # ResourceAdmin: myservice.admin + belongs_to_org
    await terminate_all_for_org(user.org_id)
    return {"success": True}
```

## Pattern 7: Optional Auth

```python
from ..auth import OptionalUser

@router.get("/public-stats")
async def get_stats(user: OptionalUser):
    if user:
        return {"stats": ..., "user": user.user_id}
    return {"stats": ...}
```

## Complete Route Examples

### Example imports in a route module

```python
from ..auth import (
    ResourceReader, ResourceWriter, ResourceScaler,
    ResourceTerminator, ResourceExecutor, MetricsViewer,
    AuthenticatedUser, verify_allocation_access, get_user_filter,
)
```

### Which type alias goes where (example compute service)

| Route module | Type aliases used |
|---|---|
| `resources.py` (create, list, costs) | ResourceAllocator, ResourceReader, CostReader |
| `allocations.py` (get, update, scale, delete, exec) | ResourceReader, ResourceWriter, ResourceScaler, ResourceTerminator, ResourceExecutor, MetricsViewer |
| `instances.py` (nested under allocations) | ResourceReader, ResourceWriter, ResourceExecutor, LogViewer |
| `admin.py` (org-wide cleanup, reports) | ResourceAdmin |

Audit every module the same way: one alias per operation type, Phase 2 on every route with a resource id in the path.
