---
name: zzb-authorization-recipes
description: Model real customer authorization setups with zzb at any size, end to end, with a "I'm building X" product-shapes map (Google Drive / file-sharing, Notion / workspaces, GitHub repos+branches, Slack, a two-sided marketplace, a reseller / B2B2B platform, a bank / Chinese wall, a data warehouse / classification, classified/compartments, multi-tenant SaaS) → recipe + the patterns it composes. Use when designing or standing up ReBAC for a customer — a small SaaS (documents + owner/editor/viewer), a mid-size multi-team org (teams as groups, group-based sharing, org hierarchy), a large multi-tenant platform (per-tenant store isolation, wildcard platform-admin grants, flat→ReBAC migration, bulk checks, audit via read/changes), or a DEEP NESTED ORG HIERARCHY / B2B2B (vendor→reseller→customer→workspace, delegated admin cascading down via arrows in ONE store). Provides copy-paste command sequences per size, sizing/pagination guidance, the hot-partition rules, and the load-bearing store-vs-nesting decision (an arrow cannot cross a store boundary). For the raw command reference use the zzb skill; for the pattern schemas use zzb-modeling; before go-live audit with zzb-audit.
---

# zzb — authorization recipes (real customer setups, by size)

## Install / update zzb

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/ab0t-zzb/main/install.sh | sh
zzb --version        # confirm
```

HTTPS-only, sha256-verified, idempotent. Update in place with `zzb update`.
Point at your environment with `--url` (prod `https://auth.service.ab0t.com`, dev
`https://auth.dev.ab0t.com`, local `http://localhost:8001`) or `ZZB_URL`.

---

## Shared setup (any size)

```sh
export ZZB_URL=https://auth.service.ab0t.com
zzb auth login --url "$ZZB_URL" --org <your-org-slug> \
  --email you@example.com --password ****
# ...or in CI/agents, skip login and export ZZB_TOKEN + ZZB_STORE.
```

A **store is one organization** (`store_id == org_id`). Everything below is a
relationship tuple `object#relation@subject`.

---

## Product shapes — "I'm building X" → recipe + the patterns it composes

The fastest path from a named product to the building blocks. Each recipe below is one
size; the **patterns** (the `+ & - ->` idioms) are in `zzb-modeling` (inline §1–§6)
and its `references/` (conditional-gates, ordered-levels, mutual-symmetric).

| I'm building… | Recipe | Composes these patterns |
|---|---|---|
| **Google Drive / file-sharing** | A → B | folder/parent arrow (§3) + role inheritance (§1) + group sharing (§2) + public link (§4) |
| **Notion / workspaces** | B | visibility modes private/org-shared/public + **domain trap** (§6) + team usersets + nested teams (§2) |
| **GitHub repos + branches** | B → E | role inheritance admin⊃maintain⊃write⊃read (§1) + **conditional step-up** on protected branches (conditional-gates §4) + org/team hierarchy |
| **Slack** | B | group/team usersets + nested teams (§2) + public channels via wildcard (§4) |
| **Two-sided marketplace** | D | multi-party UNION visibility + conditional escalation (Recipe D) |
| **Reseller platform / B2B2B** | E | nested-hierarchy arrows + delegated admin (Recipe E) + role inheritance (§1) |
| **A bank (Chinese wall)** | C or E | **information barrier** (conditional-gates §5) + ordered clearance levels + **dual-control** (§6) |
| **A data warehouse / classification** | C | **layered ABAC** class × purpose (conditional-gates §3) + ordered levels + compartment (§2) |
| **Classified / compartments (NOFORN)** | C | ordered levels + compartment/need-to-know (conditional-gates §2) + NOFORN exclusion (§1) |
| **Multi-tenant SaaS** | C | per-tenant store isolation + A/B/E inside each store |

> Read a row as: pick the **recipe** for the end-to-end command sequence + sizing, then open
> the named **patterns** in `zzb-modeling` for the schema idioms they compose.

---

## Recipe A — Small SaaS (a document app, tens–hundreds of users)

One org, documents with `owner` / `editor` / `viewer`, direct per-user shares.

**1. Publish the model** (`model.json`):
```json
{"schema_version":"1.1","type_definitions":[
  {"type":"document","relations":{
    "owner":{"allowed_subject_types":["user"]},
    "editor":{"allowed_subject_types":["user"]},
    "viewer":{"allowed_subject_types":["user"]}
  }}
]}
```
```sh
zzb model create --file model.json
```

**2. Share & check:**
```sh
zzb relationship write document:q3-report owner user:alice
zzb transact --write document:q3-report#viewer@user:bob \
                     --write document:q3-report#editor@user:carol   # atomic
zzb check user:bob viewer document:q3-report                 # ALLOW
zzb check user:dave viewer document:q3-report                # DENY
```

**3. Audit a document / a user:**
```sh
zzb read --object document:q3-report        # who has what on this doc
zzb read --user user:bob                     # everything bob can touch
zzb list-users document:q3-report viewer     # who can view it
```

Sizing: direct tuples, no groups — simplest possible. Fine to low-thousands of
shares per document before you want groups (Recipe B).

**Add roles the moment you have them.** Instead of granting `can_view` directly,
compute it so one role grant covers the umbrella action — grant `editor`, get
`can_view` + `can_edit` for free:
```json
"permissions":{"can_view":"viewer + editor + owner","can_edit":"editor + owner","can_delete":"owner"}
```
```
$ zzb relationship write document:spec editor user:carol
$ zzb check user:carol can_view document:spec     # ALLOW (editor ⇒ can_view)
$ zzb check user:carol can_edit document:spec     # ALLOW
```
The expression language (`+ & - ->`) is in **`zzb-modeling`**.

---

## Recipe B — Mid-size, multi-team org (teams as groups, thousands of users)

Stop granting per-user. Model **teams as groups** and share to a whole team via a
userset subject `team:<t>#member`.

**1. Model** — document relations accept a `team#member` userset:
```json
{"schema_version":"1.1","type_definitions":[
  {"type":"team","relations":{"member":{"allowed_subject_types":["user"]}}},
  {"type":"document","relations":{
    "owner":{"allowed_subject_types":["user"]},
    "viewer":{"allowed_subject_types":["user","team#member"]}
  }}
]}
```
```sh
zzb model create --file model.json
```

**2. Build teams, then share to a team once:**
```sh
zzb transact \
  --write team:finance#member@user:alice \
  --write team:finance#member@user:bob \
  --write team:finance#member@user:carol
# share the budget with the WHOLE team via a userset subject:
zzb relationship write document:budget viewer team:finance#member
```

**3. Check resolves through the group:**
```sh
zzb check user:bob viewer document:budget         # ALLOW (via team:finance)
zzb expand viewer document:budget --max-depth 5    # see the userset tree
zzb list-users document:budget viewer              # expands the group
```

**4. Org hierarchy** (parent org / workspaces), if you nest orgs:
```sh
zzb hierarchy setup --parent <parent_org_id> --workspace <workspace_id>
```

Sizing: adding/removing a person is ONE tuple on the team, not N re-shares.
Prefer group shares; keep per-user shares for exceptions only.

---

## Recipe C — Large multi-tenant platform (many tenants, migration, audit at scale)

Each customer/tenant is its **own store (org)** — that is your isolation boundary;
never mix tenants in one store. Add platform-level admin, migrate legacy flat
permissions, and drive audit/sync from the API.

**1. Per-tenant isolation:** run every command with that tenant's
`ZZB_STORE=<tenant_org_id>` (or `--store`). A token is org-scoped, so a
tenant's data can't be read from another store.

> **A store is a hard boundary — nothing crosses it, including groups.** A userset
> like `team:it#member` lives in ONE store; there is no tuple or userset that spans
> stores. So a "shared services" group (one IT team granted on every subsidiary's infra
> folder) can't be a single cross-tenant group — you **re-create the group and its
> grants in each tenant store**. If you genuinely need one group to span subsidiaries,
> that's the signal to model those subsidiaries as workspaces *inside one store*
> (Recipe B hierarchy) instead of as separate tenant stores — a real trade-off:
> shared-group convenience vs. hard tenant isolation. You can't have both across a
> store boundary.

**2. Platform-admin via wildcard grants** (distinct from relationship tuples):
```sh
zzb permission grant  user:ops-admin  admin  organization:<tenant_org_id>
zzb permission revoke user:ex-admin   admin  organization:<tenant_org_id>
```

**3. Migrate a tenant off flat permissions:**
```sh
zzb migrate setup-defaults                        # seed default namespaces
zzb migrate permissions user:legacy-user --permissions read,write,share
```

**4. Bulk checks** (authorize a batch in one fan-out) — `checks.json`:
```json
[{"subject":"user:alice","permission":"viewer","object":"document:a"},
 {"subject":"user:bob","permission":"editor","object":"document:b"}]
```
```sh
zzb check bulk --file checks.json --concurrency 16 --json
```

**5. Audit & change-data-capture at scale** — always paginate:
```sh
# page a tenant's tuples for an object or user (cursor in the output)
zzb read --user user:alice --page-size 500 --json
zzb read --user user:alice --page-size 500 --cursor "<continuation_token>"
# stream the durable change feed into your sync pipeline (resumable, no replay)
zzb changes --limit 1000 --json
zzb changes --cursor "<continuation_token>" --json
```

Sizing / DB rules:
- **Never do a relation-only `read`** (no object, no user) — the CLI rejects it;
  it would hit the org-wide hot partition. Scope every read by object or user.
- **Paginate** (`--page-size` + `--cursor`) for anything that can grow; don't
  assume one page.
- **`changes`** is your CDC/reconcile source — persist the `continuation_token`
  and resume from it; it returns only events after the token (no replay).
- **`transact` is atomic + create-only** — batch related writes so a partial
  failure rolls the whole thing back (HTTP 409).

---

## Recipe D — Two-sided marketplace (multi-party access + escalation)

When ONE object is legitimately seen by DIFFERENT parties (a buyer AND the seller of
their order), and access can be GRANTED by an event (a dispute brings in a mediator).
Do NOT reach for `&` here — that's a same-subject AND (see the dual-control note); this
is a UNION of independent parties.

**Multi-party (counterparty) visibility** — the object names its direct party AND
arrows to the counterparty's *role*:
```json
{"type":"order","relations":{
   "buyer":{"allowed_subject_types":["user"]},
   "store":{"allowed_subject_types":["store"]}},
 "permissions":{"can_view":"buyer + store->fulfil_orders"}}
```
`buyer` is the direct party; `store->fulfil_orders` reaches the seller side via the
store's role permission. Exactly two sides resolve, nobody else:
```
$ zzb check user:bianca can_view order:o1   # ALLOW (buyer)
$ zzb check user:sofia  can_view order:o1   # ALLOW (seller/fulfil)
$ zzb check user:ben     can_view order:o1   # DENY  (another buyer)
```

**Escalation — a conditional GRANT via an optional arrow** (the dual of the NOFORN
conditional-exclusion): add an optional relation whose arrow yields nothing until the
event writes the tuple:
```json
"can_view":"buyer + store->fulfil_orders + dispute->mediator"
```
No `dispute` tuple → the `dispute->mediator` branch resolves empty → no extra access.
When a buyer opens a dispute, write it and the platform mediator gains read; close it
(delete the tuple) and the access is gone:
```sh
zzb transact --write order:o1#dispute@dispute:d1 --write dispute:d1#mediator@user:mia
zzb check user:mia can_view order:o1     # ALLOW (escalated)
zzb relationship delete dispute:d1 mediator user:mia   # → DENY again
```
Keep the escalation OFF the sensitive object: a `payout` that only arrows to
`store->owner_only` (never to `dispute`) can never be reached by a mediator — least
privilege by construction.

---

## Recipe E — Deep nested org hierarchy / B2B2B (many layers in ONE store)

When you have a **multi-layer org tree** where access and admin rights must **cascade DOWN**
the layers — vendor → reseller → customer → workspace → resource, or holding → division →
department → team → document. This is NOT Recipe C: C isolates *independent* tenants into
*separate stores*; here the layers are **related** and a higher layer must reach INTO the
lower ones.

> **THE LOAD-BEARING RULE — read this before you pick stores.** An arrow (`parent->…`) and a
> userset (`team#member`) resolve **only inside one store**; they CANNOT cross a store
> boundary. So: **you cannot have both an arrow AND a store boundary between the same two
> layers.** If layer B must inherit from / be administered by layer A via `A->`, then A and B
> live in the **same store**. Reach for separate stores (Recipe C) only between layers that
> need **hard isolation with NO cross-access at all**. Choosing "one store per tenant"
> reflexively for a delegation-heavy hierarchy makes the down-chain cascade *unrepresentable*
> — and you find out only at check time.

**Model the whole tree in one store as nested objects with a `parent` arrow at each level:**
```json
{"schema_version":"1.1","type_definitions":[
  {"type":"vendor","relations":{"super_admin":{"allowed_subject_types":["user"]}},
   "permissions":{"admin_perm":"super_admin"}},
  {"type":"reseller","relations":{"parent":{"allowed_subject_types":["vendor"]},
     "reseller_admin":{"allowed_subject_types":["user"]}},
   "permissions":{"admin_perm":"reseller_admin + parent->admin_perm"}},
  {"type":"customer","relations":{"parent":{"allowed_subject_types":["reseller"]},
     "owner":{"allowed_subject_types":["user"]},"admin":{"allowed_subject_types":["user"]}},
   "permissions":{"can_admin":"owner + admin + parent->admin_perm"}},
  {"type":"workspace","relations":{"parent":{"allowed_subject_types":["customer"]}},
   "permissions":{"can_admin":"parent->can_admin"}},
  {"type":"resource","relations":{"parent":{"allowed_subject_types":["workspace"]},
     "owner":{"allowed_subject_types":["user"]}},
   "permissions":{"can_admin":"owner + parent->can_admin"}}
]}
```
```sh
# wire the tree once (each object names its parent):
zzb transact \
  --write reseller:acme#parent@vendor:relay \
  --write customer:globex#parent@reseller:acme \
  --write workspace:mktg#parent@customer:globex \
  --write resource:logo#parent@workspace:mktg
zzb relationship write vendor:relay super_admin user:root
zzb relationship write reseller:acme reseller_admin user:rita
zzb check user:root can_admin resource:logo   # ALLOW (cascades down 4 hops)
zzb check user:rita can_admin customer:globex  # ALLOW (her reseller's customer)
```

**DELEGATED ADMIN = the arrow, not `permission grant organization:`.** A `permission grant
… organization:<store>` is **store-WIDE** — it cannot express "reseller-admin over only THEIR
customers." Per-subtree delegation is exactly what `parent->admin_perm` gives you: rita
administers her subtree and **nothing else**. **Sibling isolation is structural** — two
subtrees share no arrow, so a sibling reseller's customers are unreachable:
```sh
zzb check user:rita can_admin customer:other-resellers-cust   # DENY (different subtree)
```
Depth: each `parent->` hop costs 1 (cap 25) — a 5-layer tree is 4 hops, far inside. Add
time-bound cross-layer support with a conditional grant (`+ support` with `--expires`, per
`zzb-lifecycle`) so a vendor engineer reaches ONE customer temporarily without standing
access to all of them.

---

## Choosing a recipe

| Signal | Recipe |
|---|---|
| one org, per-user shares, low volume | A (small SaaS) |
| shares by team/role, membership churns | B (teams as groups) |
| INDEPENDENT tenants, hard isolation, no cross-access | C (multi-tenant, separate stores) |
| two legitimate parties on one object / event-driven escalation | D (two-sided marketplace) |
| RELATED layers where admin/access cascades DOWN the tree (B2B2B, deep org) | E (nested hierarchy, one store) |

Start at A; graduate to B the first time you copy the same share to many users. Then the
key fork:

> **C vs E — the store decision (get this right first).** Both C and E have "many orgs,"
> but they are opposites. Ask: *does a higher layer need to reach INTO a lower one (inherit,
> administer, audit) via an arrow?* **Yes → Recipe E, one store, nested objects+arrows** (an
> arrow cannot cross a store boundary). **No — the tenants are strangers that must never see
> each other → Recipe C, separate stores.** You cannot have both an arrow AND a store boundary
> between the same two layers. Picking "one store per tenant" for a delegation-heavy hierarchy
> makes the down-chain cascade unrepresentable — the classic B2B2B mistake.

The recipes compose: a nested hierarchy (E) uses roles (A) and team usersets (B) at each
layer; a multi-tenant platform (C) uses A/B/E inside each store.

> **Before go-live, audit it.** Run `zzb audit` (see the **`zzb-audit`** skill)
> to catch over-grants, accidental public exposure, and dark-by-intersection resources, and use
> `assert run <model_id>` as your CI gate.

## Related skills

- **`zzb-modeling`** — how to express these schemas + the `+ & - ->` language.
- **`zzb-lifecycle`** — apply schema in CI, migrate an existing system,
  CLI vs SDK vs API, audit/CDC.
- **`zzb-audit`** — audit a live store for over-grants, public exposure, and
  dark-by-intersection risks before and after go-live.
- **`zzb`** — the command reference.
- Lost? Read `skills/README.md` (the router).
