---
name: zzb-lifecycle
description: >-
  Manage ab0t authorization over time and integrate it with an existing system. Use when deciding CLI vs SDK vs REST API, treating the schema as config-as-code (model.json + assertions in git, applied in CI/CD), versioning and rolling back authorization models, migrating from RBAC/roles or from SpiceDB/OpenFGA, backfilling existing grants in bulk, dual-running old-vs-new during cutover, and running day-2 operations (audit with read, change-data-capture with changes, break-glass, cleanup). Explains what customers with existing apps actually do: SDK for runtime authorization, this CLI for schema + ops. For the schema language use zzb-modeling; for the command reference use zzb; for sized setups use zzb-authorization-recipes; for a risk audit (over-grants, public exposure, dark-by-intersection) use zzb-audit.
---

# zzb — lifecycle & integration (managing authz over time)

## Install / update zzb

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/ab0t-zzb/main/install.sh | sh
zzb --version        # confirm
```

HTTPS-only, sha256-verified, idempotent. Update with `zzb update`.

---

## CLI vs SDK vs REST — who does what

Authorization has two clocks. Get this split right and nothing else is confusing.

| Clock | What happens | Surface |
|---|---|---|
| **Runtime** (every request) | "can this user do this?" `check`; write a tuple when a user shares/invites/leaves | your **app** via the **SDK** (`auth-sdk-go` for Go) or the **REST API** |
| **Change-time** (deploys, ops, rarely) | publish/evolve the schema; run assertions in CI; migrate; bulk-load; audit; debug | **`zzb`** (this CLI) |

So a typical customer: the **CLI publishes `model.json` in CI/CD**, and the **SDK
does `check` + tuple writes inside the running app**. The CLI is not in the
request path. Don't put a shell-out to the CLI on your hot path — call the SDK/API.

## Schema as config-as-code (the core practice)

Treat the model like source. Keep it in your repo and apply it through CI:

```
repo/
  authz/
    model.json          # the schema (see zzb-modeling)
    assertions.json     # model tests
```

CI/CD pipeline step (fails the build on a bad model):
```sh
export ZZB_URL=https://auth.service.ab0t.com
export ZZB_TOKEN="$CI_ADMIN_TOKEN" ZZB_STORE="$ORG_ID"

MID="$(zzb --json model create --file authz/model.json | jq -r .authorization_model_id)"
zzb assert put "$MID" --file authz/assertions.json
zzb assert run "$MID"        # non-zero exit ⇒ CI fails on a wrong model
```

`assert run` evaluates against the store's **active** model; an unknown/typo'd
`model_id` is a **404** (not a pass), so a stale or mistyped id fails the CI gate
loudly instead of green-lighting the wrong version.

Because every publish is a new **immutable** version, this is safe to re-run and
easy to reason about.

## Versioning & rollback

```sh
zzb model list                 # newest-first; the head is the active version
zzb model get <model_id>        # fetch any prior version, byte-for-byte
```
- Evolve schema by publishing a **new** version — never mutate one.
- Roll back by re-publishing (or repointing to) the last-good `model.json` from
  git. The old version still exists and is retrievable, so a rollback is a
  re-apply, not a reconstruction.
- Relationships (data) are unaffected by a model version change — they're
  evaluated against the active model.

## Migrating from an existing system

The general shape (RBAC, SpiceDB, OpenFGA, or a homegrown table):

1. **Model it** — express your existing roles/policies as `model.json` (see
   `zzb-modeling`: one relation per role, computed permission per action).
   Validate with assertions before touching data.
2. **Backfill grants in bulk** — export your current grants, emit `transact`
   batches (create-only, atomic, ≤100 tuples each). **The model from step 1 must be
   published first** — a `transact`/`write` for an undeclared `type` returns a `404`
   that names the cause ("Object type is not declared … Publish a model that defines
   it first"):
   ```sh
   zzb transact \
     --write document:a#viewer@user:alice \
     --write document:a#editor@user:bob
   # …or drive many batches from a script over your export.
   ```
   RBAC role-holders: `zzb migrate permissions user:alice --permissions read,write,share`.
   Seed default namespaces first: `zzb migrate setup-defaults`.
3. **Dual-run / verify** — before cutover, compare the old decision to the new one
   with a batch check and diff:
   ```json
   [{"subject":"user:alice","permission":"can_view","object":"document:a"},
    {"subject":"user:bob","permission":"can_edit","object":"document:b"}]
   ```
   ```sh
   zzb check bulk --file checks.json --concurrency 16 --json > new.json
   # diff new.json against your legacy system's answers; investigate mismatches.
   ```
4. **Cut over** — switch the app's runtime decisions to the **SDK/API**; keep the
   CLI for schema + ops. Decommission the old path once the diff is clean.

## Day-2 operations

> **Risk audit (do this on a schedule + in CI).** For an opinionated safety review —
> over-grants, accidental `user:*` public exposure, **dark-by-intersection** resources,
> undeclared-type drift, stale grants — run `zzb audit` and see the
> **`zzb-audit`** skill. The `read`/`changes`/`list-users` calls below are the raw
> primitives; `audit` ranks the findings for you.

- **Audit** — who can do what, paginated (never a relation-only read):
  ```sh
  zzb read --object document:q3-report        # everyone on this object
  zzb read --user user:alice --page-size 500   # everything this user has
  zzb list-users document:q3-report can_view   # expands groups + computed perms
  ```
- **Access certification (periodic entitlement review)** — `zzb access-review` turns the
  raw primitives above into a certifiable report: a row per effective subject with the
  grant **path** (WHY) and risk flags, plus a `--revoke-plan` of commented `relationship
  delete` lines to curate. It is read-only — the periodic-certification companion to `audit`:
  ```sh
  zzb access-review document:q3-report can_view          # who has it, WHY, + risk flags
  zzb access-review --type document --permission can_edit --csv   # sweep a type for a reviewer
  zzb access-review --subject user:contractor            # reverse: everything a subject can reach
  ```
- **Change-data-capture / sync** — the durable, resumable change feed. Persist the
  `continuation_token`; you get only events after it (no replay, no gaps):
  ```sh
  zzb changes --limit 1000 --json
  zzb changes --cursor "$LAST_TOKEN" --json
  ```
  Use it to mirror grants into a data warehouse, trigger notifications, or
  reconcile a cache.
- **Time-bound / just-in-time access** — `relationship write` takes `--expires
  <RFC3339>` to grant access that **auto-expires**. The engine denies at check time
  once the clock passes `expires_at` — no external scheduler or cleanup job needed:
  ```sh
  zzb relationship write document:x viewer user:contractor --expires 2026-12-31T00:00:00Z
  zzb check user:contractor can_view document:x   # ALLOW while now < expires_at
  # a tuple whose --expires is already in the past checks DENY (it's excluded from every authz path)
  zzb read --object document:x                     # the tuple's expires_at is shown here
  ```
  The tuple still shows in `read` (audit sees it) but never counts toward
  check/expand/list once expired. Use it for temp contractors, break-glass with a
  built-in deadline, or time-boxed shares.
- **Break-glass / incident** — grant/revoke a wildcard admin permission fast, then
  revoke when done:
  ```sh
  zzb permission grant  user:oncall admin organization:<org_id>
  zzb permission revoke user:oncall admin organization:<org_id>
  ```
  The `organization:<org_id>` target scopes the grant to that org (store). To
  verify it took, `check wildcard <user_id> <permission>` asks "does this user hold
  the wildcard grant?" — it takes **no object argument** (it is the org-wide grant,
  not a per-object check) and wants the bare id (`oncall`, not `user:oncall`).
  `grant` flips it to ALLOW, `revoke` flips it back to DENY:
  ```sh
  zzb check wildcard oncall admin        # ALLOW after grant, DENY after revoke
  ```
- **Cleanup / offboarding** — use the first-class **`purge`** verb: it deletes EVERY
  tuple a subject appears in (all their grants), atomically batched, in one command:
  ```sh
  zzb purge --user user:erin --dry-run   # preview: how many grants, no change
  zzb purge --user user:erin             # remove them all; prints the count
  # verify: `read --user user:erin` is empty and every `check` for erin is DENY
  ```
  If you need to filter which grants go (e.g. only one object type) rather than remove
  all of them, page-and-delete instead — cursor-paginate, since a heavily-shared user
  won't fit one page:
  ```sh
  cur=""
  while :; do
    page=$(zzb --json read --user user:erin --page-size 100 ${cur:+--cursor "$cur"})
    echo "$page" | jq -r '.tuples[]?|"\(.key.object) \(.key.relation) \(.key.user)"' \
      | while read -r o r s; do zzb relationship delete "$o" "$r" "$s"; done
    cur=$(echo "$page" | jq -r '.continuation_token // empty'); [ -n "$cur" ] || break
  done
  ```

## Multi-tenant note

Each tenant is its **own store** (`--store`/`ZZB_STORE = <tenant_org_id>`)
— that is the isolation boundary. Publish the shared `model.json` into each
tenant's store; never mix tenants in one store. Sized detail:
`zzb-authorization-recipes` (Recipe C).
