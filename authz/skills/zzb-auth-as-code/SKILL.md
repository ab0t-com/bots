---
name: zzb-auth-as-code
description: Go from nothing to working, safe, multi-tenant authorization — provisioned, modeled, audited, and callable from your app — as ONE declarative slice. Use when someone is starting authorization for a new app or tenant and wants the whole thing (accounts/login + the permission model + the runtime read/write wiring) instead of just one piece; when they ask to "set up auth end to end", "scaffold auth for my app", "go from zero to auth", "connect authsetup and zzb", "what is auth.yaml", run `zzb plan` / `zzb apply`, `zzb init --with-tenancy --with-sdk go`, bridge authsetup creds into zzb (`zzb auth login --from-authsetup`), or wire the app-side tuple WRITES (create/share/delete), not just Check. This is the blueprint/onboarding skill that ties the four systems together. For managing an EXISTING model over time (versioning, migration, day-2) use zzb-lifecycle; for the model file + pattern language use zzb-modeling; for whole sized setups use zzb-authorization-recipes; for a risk review use zzb-audit; for the raw command reference use zzb.
---

# zzb — auth as code (nothing → working, safe, multi-tenant auth)

**The promise.** In one declarative slice you go from *nothing* to *working, safe,
multi-tenant authorization* — the tenant orgs and login **provisioned**, the
permission model **published and proven**, the "must never" rules **audited**, and
the whole thing **callable from your app** (both the read `Check` and the tuple
writes). Not a demo against fake data — a real slice on tools you already have.

Most teams stall because authorization is really **four** systems and nobody
tells you how they connect. This skill connects them.

## The 4 systems (who owns what)

| System | Owns | You touch it via |
|---|---|---|
| **authsetup** | Accounts, orgs/tenants, login (SSO/password), teams — the **identity plane** | the `authsetup` CLI (auth-mesh onboarding) |
| **zzb** | The **authorization model**: types, roles, computed permissions, assertions | the `zzb` CLI (schema + ops, not the hot path) |
| **auth-go-sdk** (`auth-sdk-go`) | **Runtime**: `Check` (reads) **and app-originated tuple WRITES** (create/share/delete) | your app code |
| **templates** | The **blueprint** — a correct starting model + tenancy config + SDK wiring | `zzb init --template X` |

The load-bearing fact everyone misses: **the service org that authsetup provisions
IS your zzb store** (`store_id == org_id`). Same id, two tools. Bridge them with
one command — see [the S1 bridge](#the-bridge-authsetup--zzb-in-one-command).

## The identity join (the #1 thing that goes wrong)

The runtime plane has **two halves**, and the second is where Zanzibar adoptions
die:

1. **Read** — `sdk.Check(user, "can_edit", doc)`. Easy; every product has it.
2. **Write/sync** — when your app **creates / shares / moves / deletes** a
   resource it must write (or delete) the matching tuples. The subject of every
   tuple MUST be the **auth-service user id** — `user:<auth_user_id>` (the id from
   register / the JWT `sub`), **never** a local DB id or an email.

That mapping from "my app's user" to "the auth-service user id" is the **identity
join**, and it is yours to make explicitly. Template `seed.json` files use literal
names like `user:alice` for readable assertions — copy the *pattern*, not the
names, or checks pass in the demo and fail mysteriously in prod. `--with-sdk go`
emits `authz_writes.go` with this join already wired.

## Do it: the full slice from one template

```sh
zzb init --template drive --with-tenancy --with-sdk go
```

This scaffolds a complete, correct starting point into the current directory:

```
model.json            # the authorization model (see zzb-modeling)
assertions.json       # the "must never" rules, run through the live Check engine
seed.json             # example tuples the assertions expect (PLACEHOLDER subjects)
README.md             # the template's guide, incl. the two gotchas above
authsetup-config/     # --with-tenancy: a ready-to-run authsetup config for the
                      #   template's org/team/login layer
authz/                # --with-sdk go: runtime wiring —
                      #   RequireCan middleware (READ path) +
                      #   OnCreate/Share/OnDelete tuple writes (WRITE path),
                      #   with the identity join explicit
```

`--with-tenancy` + `--with-sdk go` are supported for `drive` and
`saas-multitenant` (the tenancy mapping is a per-template design decision, not
free generation). Other templates scaffold the model only, with a clear message.

## Provision, publish, wire — the three planes

### 1. Tenancy (authsetup) — provision the org + login
```sh
authsetup --config-dir ./authsetup-config --creds-dir ./authsetup-creds validate
authsetup --config-dir ./authsetup-config --creds-dir ./authsetup-creds run
```
This creates the service org (+ end-users org, teams, hosted login, OAuth) and
writes the credentials into `./authsetup-creds`. (Full detail: the
`auth-mesh-setup` skill.)

### The bridge: authsetup → zzb in ONE command
Point zzb at what authsetup just provisioned — no hand-copying the org id, no
hand-minting a token:
```sh
zzb auth login --from-authsetup ./authsetup-creds
zzb whoami        # confirm: subject, org == store, expiry
zzb model list    # confirm zzb is pointed at the provisioned store
```
`--from-authsetup` reads the service creds file, mints the **org-scoped** token,
and writes url + token + store to `~/.zzb/config.json`. If the dir holds several
provisioned services, add `--service <id>`.

### 2. Model (zzb) — publish it, audit-gated + proven
```sh
zzb init --template drive --publish     # model create + seed + assert run, in the active store
zzb audit                               # lint for risk (exit 3 at/above the gate)
```
`--publish` runs the assertions AND is **audit-gated** — it refuses (exit 3,
before any write) if the model+seed trips a high-severity finding; `--force`
overrides loudly. This "audit-clean, assertion-proven publish" is the whole point:
the gate is what makes it *safe*, not just *working*.

### 3. Runtime (auth-sdk-go) — read AND write from your app
The emitted `authz/` package wires both halves as methods on an `*Authz` handle
(`az := authz.New(authURL, storeID, orgScopedToken)`). Write path (create then
share) — every `...UserID` argument is the **auth-service user id**:
```go
// on create: owner tuple (docID lives in folderID; ownerUserID = auth-service id)
az.OnCreateDocument(ctx, docID, folderID, ownerUserID)
// on share: grant a role ("viewer" | "editor")
az.ShareDocument(ctx, docID, "viewer", granteeUserID)
```
Read path as net/http middleware (subject/object are extractor funcs; `subjectFn`
returns the caller's auth-service id from your validated JWT):
```go
mux.Handle("PUT /documents/{id}", az.RequireCan("can_edit",
        authz.ObjectFromPath("document", "id"), subjectFn)(updateHandler))
// RequireCan calls Check(user:<id>, "can_edit", document:<id>) → 403 on DENY (fails closed)
```
The golden-path proof: a share flips a `Check` from **DENY → ALLOW**, and a
viewer still can't edit. Runtime authorization lives in the **SDK/API**, never a
shell-out to the CLI (`zzb-lifecycle` covers the CLI-vs-SDK-vs-REST split).

## auth.yaml — the whole slice as one declarative artifact

Instead of remembering the steps, declare the desired state once. `auth.yaml`
names the three planes:

```yaml
# auth.yaml
tenancy:                       # the identity plane (authsetup's)
  service: drive               # authsetup service id
  org: <service-org-id>        # the provisioned service org (== the zzb store)
  teams: [eng, sales]          # teams expected to exist in that org
model:                         # the authorization plane (zzb's)
  template: drive              # an embedded template … OR:
  # file: model.json           #   a local model file (exactly one of the two)
runtime:                       # the plane your app lives on
  sdk: go
  service: https://auth.service.ab0t.com
```

The manifest is strict: unknown sections/keys are rejected and the error names
the allowed set. It describes **one tenant** (one service org + its teams) — see
[FUTURE](#not-yet) for the many-tenants/platform shape.

## plan → apply (preview, then converge safely)

This is "terraform for authorization." **Always `plan` before `apply`.**

```sh
zzb plan  -f auth.yaml     # read-only: diff declared (auth.yaml) vs the live store
zzb apply -f auth.yaml     # converge: plan first, confirm, then create/update
```

- **`zzb plan`** never writes. It prints the delta — `+` add, `~` changed, `-`
  live-but-undeclared (never deleted), `!` problem — and **audit-gates the
  declared model first** (exit 3 on findings ≥ high). Exit codes compose as a CI
  gate: `0` no drift · `2` drift · `3` audit-fail · `1` error.
- **`zzb apply`** computes the *same* plan, shows it, and requires confirmation
  (`--yes` in CI). It can never write something `plan` didn't preview; re-apply is
  a **no-op**. Safety gates:
  - **Ownership** — apply manages only what it created (tracked in
    `<manifest>.state.json`). It NEVER deletes identity-plane objects it didn't
    create; `--prune` (opt-in, previewed) removes only manifest-managed resources.
  - **Two credential planes, never crossed** — tenancy operations (teams,
    provisioning) and model publish each need their OWN credential. A missing one
    is a clear error and **nothing is done** — apply won't silently reuse a token
    across planes.
  - **Audit gate** — a declared model with findings ≥ high is refused (exit 3)
    unless `--force`.

From **zero** (no org yet), apply can drive `authsetup run` itself:
```sh
zzb apply -f auth.yaml \
  --authsetup-config ./authsetup-config --authsetup-creds ./authsetup-creds \
  --mint-org-token --yes
```

CI loop: `zzb plan -f auth.yaml && zzb apply -f auth.yaml --yes`, then
`zzb plan` again — a converged store re-plans clean.

## The safety gate (why this beats a hand-rolled setup)

Two artifacts make the slice *provably* safe, and both are gates, not
afterthoughts:

- **`assertions.json`** — your "must never" rules, run through the live Check
  engine (`zzb assert run <model_id>`; non-zero exit = CI fails). E.g. "a viewer
  never edits", "a document share never leaks its parent folder", "tenant B never
  sees tenant A".
- **`zzb audit`** — ranks risk (wildcard/public over-grants, dark-by-intersection
  resources, drift). `--publish`, `plan`, and `apply` all run it as a gate.

That is the wedge: not "we ship identity + authz" (others do) — we ship a
**blueprint that spans tenancy + model + runtime read/write AND proves its rules
with assertions and an audit-clean gate.**

## When to use this vs the sibling skills

| You are… | Use |
|---|---|
| **Starting** auth for a new app/tenant and want the WHOLE slice | **this skill** |
| Bridging authsetup creds into zzb | **this skill** (`auth login --from-authsetup`) |
| Declaring desired state + reconciling (`plan`/`apply`, `auth.yaml`) | **this skill** |
| Managing an EXISTING model over time — versioning, rollback, migration from RBAC/SpiceDB/OpenFGA, day-2 ops | **`zzb-lifecycle`** |
| Writing the model file / choosing a pattern (`+ & - ->`, arrows, usersets) | **`zzb-modeling`** |
| A whole setup sized to a customer (small SaaS → B2B2B), "I'm building X" | **`zzb-authorization-recipes`** |
| Reviewing a live store for over-grants / leaks / drift | **`zzb-audit`** |
| The raw command reference + tuple notation | **`zzb`** |

Rule of thumb: **this skill gets you TO a safe, working slice; `zzb-lifecycle`
keeps it healthy after.**

## Related skills
- **`zzb-lifecycle`** — schema-as-code, versioning, migration, day-2 (the after).
- **`zzb-modeling`** · **`zzb-authorization-recipes`** · **`zzb-audit`** · **`zzb`**.
- **`auth-mesh-setup`** — the authsetup CLI (the identity plane) in depth.
- Lost? Read `skills/README.md` (the router).
