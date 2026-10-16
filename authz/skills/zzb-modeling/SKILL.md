---
name: zzb-modeling
description: >-
  Write the authorization model (schema) for the ab0t auth service — the JSON model file and the computed-permission expression language (+ union, & intersection, - exclusion, relation->permission inheritance). Use when designing a schema, translating roles/RBAC or a SpiceDB/OpenFGA model into this format, adding a computed permission, or modeling any of these patterns: role inheritance (editor implies viewer), folder/parent inheritance (Drive), group/team sharing via usersets + nested teams (Slack), public/wildcard access, ban/exclusion, resource visibility modes private/org-shared/public + the domain trap (Notion/workspaces), ordered clearance levels, mutual/symmetric relations (friends), conditional exclusion (NOFORN), conditional intersection/compartments (need-to-know), layered ABAC classification (data warehouse), conditional step-up (protected branches, GitHub), information-barrier/Chinese-wall (bank), or dual-control/separation-of-duties (N distinct approvers). Starts with a "which pattern do I need?" index. Common patterns are inline; specialized ones live in references/. Covers relations vs permissions, allowed_subject_types, usersets (type#relation), the expression grammar with precedence, versioned+immutable model publishing, and testing a model with assertions. For running the CLI commands use zzb; for whole sized setups use zzb-authorization-recipes.
---

# zzb — modeling (the schema + permission language)

## Which pattern do I need? (start here)

Find your problem or product shape, jump to the pattern. **Common patterns are
inline below; specialized ones live in `references/`** (progressive disclosure).
For a whole sized/product setup, see `zzb-authorization-recipes`.

| I want to model… | Product shape | Pattern | Where |
|---|---|---|---|
| a role that implies a lesser one (editor ⇒ viewer) | any RBAC | role inheritance | §1 inline |
| share to a whole team; teams inside teams | Slack, workspaces | group/team userset + nested teams | §2 inline |
| a doc inherits its folder's access | Google Drive, file-sharing | folder/parent arrow | §3 inline |
| "anyone with the link" / public | public pages | wildcard / public | §4 inline |
| bar a named person regardless of other grants | any | ban / exclusion (`-`) | §5 inline |
| private / shared-to-org / public-link modes; "anyone on our domain" | Notion, workspaces | visibility modes + domain trap | §6 inline |
| ordered clearance ≥ classification (Confidential < Secret) | classified, gov | ordered levels (recursive `higher`) | [references/ordered-levels.md](references/ordered-levels.md) |
| deep inheritance / self-referential hierarchy; the 25-hop cap | deep org trees | recursive & multi-level arrows | [references/ordered-levels.md](references/ordered-levels.md) |
| two-way friends / mutual connections | social | mutual / symmetric (denormalize inverse) | [references/mutual-symmetric.md](references/mutual-symmetric.md) |
| bar a group only when a resource opts in (NOFORN) | classified | conditional exclusion | [references/conditional-gates.md](references/conditional-gates.md#1-conditional-exclusion-noforn) |
| require need-to-know only when a resource has a compartment | classified/compartments | conditional intersection | [references/conditional-gates.md](references/conditional-gates.md#2-conditional-intersection-compartment--need-to-know) |
| gate on a column/dataset attribute (PII, purpose) | data warehouse | layered ABAC classification | [references/conditional-gates.md](references/conditional-gates.md#3-layered-attribute-gates-abac-classification--purpose) |
| a marker forces a STRICTER role (protected branch, prod) | GitHub, CI/CD | conditional step-up | [references/conditional-gates.md](references/conditional-gates.md#4-conditional-step-up--require-a-stricter-role-when-a-marker-is-present) |
| two groups mutually exclusive (deal team vs trading) | bank, Chinese wall | information barrier | [references/conditional-gates.md](references/conditional-gates.md#5-information-barrier--chinese-wall--two-sided-mutual-exclusion) |
| N *distinct* approvers must sign | approvals, deploys | dual-control / SoD | [references/conditional-gates.md](references/conditional-gates.md#6-dual-control--separation-of-duties-n-distinct-approvers) |
| a multi-layer org tree where admin cascades DOWN | B2B2B, reseller | nested hierarchy | recipes → Recipe E |
| independent tenants, hard isolation | multi-tenant SaaS | per-tenant store | recipes → Recipe C |

The conditional/marker family (NOFORN ↔ compartment ↔ step-up ↔ Chinese-wall ↔
dual-control) all share ONE shape — see the intro of
[references/conditional-gates.md](references/conditional-gates.md).

## Install / update zzb

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/ab0t-zzb/main/install.sh | sh
zzb --version        # confirm
```

HTTPS-only, sha256-verified, idempotent. Update with `zzb update`. Point
at your environment with `--url`/`ZZB_URL` (prod
`https://auth.service.ab0t.com`).

---

## Relations vs permissions

Your model is a **JSON file** with one entry per object `type`. Each type has:

- **`relations`** — the *written facts* you store as tuples (e.g. `owner`,
  `editor`, `viewer`, `member`, `parent`). Each declares `allowed_subject_types`.
- **`permissions`** — *computed* names derived from relations by an expression.
  You `check` permissions; you `write` relations.

```json
{"schema_version":"1.1","type_definitions":[
  {"type":"document",
   "relations":{
     "owner":{"allowed_subject_types":["user"]},
     "editor":{"allowed_subject_types":["user"]},
     "viewer":{"allowed_subject_types":["user"]}
   },
   "permissions":{
     "can_view":"viewer + editor + owner",
     "can_edit":"editor + owner",
     "can_delete":"owner"
   }}
]}
```
```sh
zzb model create --file model.json      # publish (immutable, versioned)
```

> **Publish the model before writing any tuples of these types.** A
> `relationship write` for a `type` no active model declares fails with a `404`
> that names the cause ("Object type is not declared … Publish a model that defines
> it first"). Order is always `model create` → `relationship write`.

## The permission expression language

Operators, precedence **high → low**: `( )` → `&` → `-` → `+`.

| Operator | Meaning | Example |
|---|---|---|
| `+` | union / OR | `can_view: viewer + editor + owner` |
| `&` | intersection / AND | `can_publish: editor & approved` |
| `-` | exclusion / AND NOT | `can_view: viewer - banned` |
| `relation->permission` | inherit *through* a relation (tuple-to-userset) | `can_view: viewer + parent->can_view` |
| `( )` | grouping | `can_edit: (editor + owner) - suspended` |

An atom is a relation name, a permission name, or an arrow `rel->perm`. Malformed
expressions fail **closed** (deny), never crash.

> **⚠ SECURITY: `&` is SAME-SUBJECT AND — do NOT use it for "two people must approve".**
> `can_execute: approver_a & approver_b` asks "does the **same** subject hold both?", so ONE
> person granted both slots satisfies it (**self-approval** — a dual-control bypass), and the
> DENY/ALLOW reason won't warn you. For **N DISTINCT approvers / separation-of-duties**, use the
> dual-control pattern (an app-verified approval flag) in
> [references/conditional-gates.md §6](references/conditional-gates.md#6-dual-control--separation-of-duties-n-distinct-approvers)
> — never a naive `&`. (`zzb audit` flags an `&`-gated permission a single subject can
> fully satisfy.)

## Patterns that come up constantly (all live-verified)

**1. Role inheritance — editor implies viewer.** Grant one role, get the umbrella
permission:
```json
"permissions":{"can_view":"viewer + editor + owner","can_edit":"editor + owner"}
```
```
$ zzb relationship write document:spec editor user:carol
$ zzb check user:carol can_view document:spec
ALLOW  reason: Via computed permission can_view: Direct editor relationship
$ zzb check user:carol can_edit document:spec
ALLOW
```
A plain `viewer` gets `can_view` but is **denied** `can_edit`.

**2. Group / team sharing — share to a whole team via a userset.** Allow a
`team#member` userset as a subject, then grant the team once:
```json
{"type":"team","relations":{"member":{"allowed_subject_types":["user"]}}},
{"type":"document","relations":{
  "viewer":{"allowed_subject_types":["user","team#member"]}}}
```
```
$ zzb relationship write document:budget viewer team:finance#member
$ zzb check user:bob viewer document:budget
ALLOW  reason: Member of team:finance#member which has viewer
```
Add/remove a person = one tuple on the team, not N re-shares.

**Nested teams (a team inside a team).** Let a team's `member` relation accept another
team's `#member` userset, and membership resolves transitively — an org-chart of groups:
```json
{"type":"team","relations":{"member":{"allowed_subject_types":["user","team#member"]}}}
```
```sh
zzb relationship write team:eng#member@team:backend#member   # backend ⊆ eng
zzb relationship write team:backend member user:dave
zzb check user:dave viewer document:budget   # ALLOW (dave → backend → eng → viewer)
```
The same `type#relation` userset that shares to a document also nests one group in another;
there is no depth limit beyond the usual arrow/recursion cap.

*See also: a multi-layer org tree of groups where admin cascades DOWN is Recipe E (nested
hierarchy / B2B2B) in `zzb-authorization-recipes`.*

**3. Folder / parent inheritance — arrow.** A document inherits its folder's access:
```json
{"type":"folder","relations":{"viewer":{"allowed_subject_types":["user"]}}},
{"type":"document","relations":{
  "parent":{"allowed_subject_types":["folder"]},
  "viewer":{"allowed_subject_types":["user"]}},
 "permissions":{"can_view":"viewer + parent->viewer"}}
```
```
$ zzb transact --write document:readme#parent@folder:handbook \
                       --write folder:handbook#viewer@user:erin
$ zzb check user:erin can_view document:readme
ALLOW  reason: Via computed permission can_view: Inherited from parent: Direct viewer relationship
       path: [user:erin folder:handbook document:readme]
```

**4. Public / everyone — wildcard.** Let a relation be granted to "anyone":
```json
"viewer":{"allowed_subject_types":["user"],"allows_wildcard":true,"allows_anyone":true}
```
`allows_wildcard` permits the typed wildcard `user:*` (anyone *of that type*);
`allows_anyone` permits the untyped public marker. For a public/"anyone-with-the-link"
relation set **both** and write the `user:*` tuple below — that's the combination the
engine resolves for every subject.
Make an object public by writing the tuple with the `user:*` wildcard subject — this
is the write syntax (any user then resolves that branch):
```sh
zzb relationship write post:launch viewer 'user:*'   # public
zzb check user:anyone viewer post:launch             # ALLOW
```

**5. Ban / exclusion — subtract a relation.** `-` removes even if another branch grants:
```json
"permissions":{"can_view":"(viewer + editor + owner) - banned"}
```
A `banned` user is denied `can_view` regardless of any other grant. Put the `-` outside
the parens (as here) so it overrides **every** branch, including a public/wildcard one.

> **Gate by clearance (`&`), don't try to exclude the un-cleared (`-`).** `-` subtracts a
> **known, enumerated** set (the users written as `banned`). "Hide this from *everyone*
> who is NOT explicitly cleared" is the *complement* of a set — `-` cannot express it
> (there is no tuple listing "everyone uncleared"). Use **intersection with a positive
> clearance relation** instead:
> ```json
> {"type":"segment","relations":{
>    "record":{"allowed_subject_types":["record"]},
>    "cleared":{"allowed_subject_types":["user"]}},
>  "permissions":{"can_view":"record->can_view & cleared"}}
> ```
> Now a sensitive segment is visible only to someone who **both** inherits access from the
> record **and** carries an explicit `cleared` grant — every otherwise-authorized viewer is
> hidden until you opt them in. Reach for `-` to remove *named* offenders; reach for `&`
> to require an *affirmative* credential.

*See also: subtracting through an **arrow** (a marker/compartment/other side) instead of a
direct relation is the whole conditional family — NOFORN, compartment, step-up, Chinese wall,
dual-control — in [references/conditional-gates.md](references/conditional-gates.md).*

## Arrows recurse, chain, and cap at 25 hops (compact)

The folder arrow (§3) generalizes:

- **An arrow may reference the permission recursively** — `eligible: holder +
  higher->eligible` walks a ladder of arbitrary length and terminates when the chain runs out.
- **Arrows chain across levels** — the target of an arrow can be a permission that itself
  contains an arrow, so grandparent → parent → child inheritance resolves in one check.
- **Depth cap = 25 hops.** A chain deeper than 25 `->`/membership hops fails **closed** with a
  DENY reason `max evaluation depth (25) exceeded`. A resource under N nested nodes is N+1 hops.

Full treatment — including the ordered-levels (clearance ≥ classification) recursive-`higher`
pattern — in [references/ordered-levels.md](references/ordered-levels.md).

## Specialized patterns → references/

The conditional/marker family and the ordinal/attribute patterns live in `references/`
(they share the shapes above; each is one hop away):

- **[references/conditional-gates.md](references/conditional-gates.md)** — the whole conditional
  family in one place: conditional exclusion (**NOFORN**), conditional intersection
  (**compartment / need-to-know**), layered **ABAC** (classification × purpose),
  **conditional step-up** (protected branches / prod deploys), **information barrier /
  Chinese wall**, and **dual-control / separation-of-duties** (N distinct approvers). Start at
  its intro — they're all the same `- marker->member` / `& caveat->member` shape with exempt
  roles unioned outside.
- **[references/ordered-levels.md](references/ordered-levels.md)** — ordered clearance levels,
  recursive & multi-level arrows, the 25-hop cap.
- **[references/mutual-symmetric.md](references/mutual-symmetric.md)** — two-way friends /
  connections.

## Resource visibility modes (private / shared-to-org / public) + the domain trap

Every workspace/SaaS product needs a resource that can be **private**, **shared to the whole
org/domain**, or **public link**. Express the mode with markers, and gate on membership — do
NOT confuse the modes:

```json
{"type":"page","relations":{
   "workspace":{"allowed_subject_types":["workspace"]},
   "viewer":{"allowed_subject_types":["user","team#member"]},
   "org_shared":{"allowed_subject_types":["user"],"allows_wildcard":true},  // marker: shared to the org
   "public":{"allowed_subject_types":["user"],"allows_wildcard":true,"allows_anyone":true}}, // link
 "permissions":{"can_view":"viewer + (workspace->member & org_shared) + public"}}
```
- **Private** (default): no marker → only explicit `viewer`s (people, teams) resolve.
- **Shared to the org**: write `page:x#org_shared@user:*` → the `& workspace->member` term now
  passes for **workspace members** (and only them — the `&` keeps non-members out). Un-share by
  deleting the one marker tuple.
- **Public / anyone-with-link**: write `page:x#public@user:*` → the union's `+ public` branch
  resolves for everyone. Toggle off by deleting it.

> **⚠ THE DOMAIN TRAP (security).** "Anyone on the company domain" is **NOT** `user:*`. `user:*`
> means *literally everyone, including off-domain strangers* — grant it as a domain gate and you
> ship an everyone-can-join workspace. Model domain membership as a **materialized userset**: a
> `domain` object whose `member` relation your SSO/JIT provisioning fills per on-domain user,
> then gate on it — `workspace.can_join = ... + domain->member`. The engine has no native
> email-suffix predicate; the `& workspace->member` above is the org-scoped share, and
> `domain->member` is the domain-scoped one. Never substitute `user:*` for either.

A middle "discoverable but not readable" mode (see it exists, request to join) is a SEPARATE
permission: keep `can_view` as above and add `can_discover: ... + (workspace->member &
closed_marker)` — visibility and readability are two questions, so two permissions.

*See also: the domain trap is a wildcard/over-grant risk — audit for it with
**`zzb-audit`**. The `& workspace->member` gate is a conditional intersection
([references/conditional-gates.md §2](references/conditional-gates.md#2-conditional-intersection-compartment--need-to-know));
`user:*` public is §4 above. To gate a data column/dataset on a classification attribute, see
layered ABAC ([references/conditional-gates.md §3](references/conditional-gates.md#3-layered-attribute-gates-abac-classification--purpose)).*

## Two schema commands: `model` vs `namespace` — use `model`

`--help` shows both `model` and `namespace`; they overlap, so pick deliberately:

- **`model create --file` (recommended, use this):** publishes a whole schema as a
  **versioned, immutable** unit — testable with assertions, rollback-friendly, and
  it refreshes what Check reads. This is the config-as-code path.
- **`namespace create` (lower-level primitive):** registers/updates a **single**
  object type's relations + permissions in place (not versioned). Reach for it only
  to tweak one type ad-hoc; for anything you keep in git, use `model`.

Both feed the same Check engine. When in doubt, `model`.

## Reading a DENY (the reason enumerates the failed union)

A `check` that returns `DENY` prints a `reason` that enumerates the failed **union**
branches — e.g. `can_view = viewer + editor + owner` reports
`not satisfied — none of [viewer, editor, owner] hold`, so you see the whole union at
once. **Caveat for chained exclusions:** with multiple `-` terms
(`(...) - policyholder - related_party`) the reason names only *one* contributing
exclusion and may not distinguish "base never held" from "excluded by X" — treat the
reason for exclusions as a hint, not the whole story. For the authoritative picture
use `zzb expand <permission> <object> --max-depth N` (the full tree renders
every `excluded` node), or inspect the underlying relations with `read --object`.

## Test the model (assertions)

Ship model tests alongside the schema and run each through the live engine.
`assertions.json`:
```json
{"assertions":[
  {"tuple_key":{"object":"document:spec","relation":"can_view","user":"user:carol"},"expectation":true},
  {"tuple_key":{"object":"document:spec","relation":"can_edit","user":"user:bob"},"expectation":false}
]}
```
```sh
zzb assert put   <model_id> --file assertions.json
zzb assert run   <model_id>      # ✓/✗ per assertion + overall PASS/FAIL
```

## Versioning

Every `model create` publishes a new **immutable** version with its own
`authorization_model_id`; `model list` shows them newest-first. You evolve schema
by publishing a new version (never mutating one) — which makes rollback a
repoint, not a rewrite. Lifecycle detail: **`zzb-lifecycle`**.

## Translating from other systems

**Fastest path — the DSL does OpenFGA for you.** `zzb model create --dsl model.fga`
transpiles an OpenFGA `.fga` model to JSON and publishes it; `model dsl-check model.fga`
transpiles + prints without publishing. So for OpenFGA you often don't hand-translate at all.

Hand-translation mapping (SpiceDB `.zed`, or to understand what the DSL does):

| From | To (zzs) | Note |
|---|---|---|
| OpenFGA `X from Y` (tuple-to-userset) | `Y->X` | **word order REVERSES** — OpenFGA "perm FROM relation" → zzs "relation->perm" |
| SpiceDB arrow `parent->view` | `parent->view` | same order — `.zed` ports more literally than `.fga` |
| `or` / `and` / `but not` | `+` / `&` / `-` | put `-` OUTSIDE the parens so it overrides every branch |
| userset `[team#member]` | `team#member` subject | same |
| wildcard `[user:*]` | `allows_wildcard` + a `user:*` tuple | public/anyone |
| RBAC role table | one relation per role + `can_X: role_a + role_b` | `zzb migrate permissions …` for flat PERM# rows |

**The one real decision (no 1:1):** OpenFGA lets a single "relation" be BOTH directly-assignable
AND computed. zzs SPLITS these — a **relation** is writable (you `write` tuples to it); a
**permission** is computed-only (writing to it is a 400). So an OpenFGA relation that is both
assigned AND unioned becomes a writable relation PLUS a separately-named computed permission
(`viewer` the relation + `can_view: viewer + editor + …` the permission).

Before cutover, **dual-run:** `check bulk` the same questions against old and new and diff (see
`zzb-lifecycle`).

## Related skills

- **`references/`** — specialized patterns:
  [conditional-gates](references/conditional-gates.md) (NOFORN, compartment, ABAC, step-up,
  Chinese wall, dual-control), [ordered-levels](references/ordered-levels.md),
  [mutual-symmetric](references/mutual-symmetric.md).
- **`zzb-authorization-recipes`** — whole setups by customer size + a product-shapes
  map (Drive, Notion, GitHub, Slack, bank, data warehouse, marketplace, reseller).
- **`zzb-audit`** — audit your model + grants for over-grants, accidental public
  exposure, and dark-by-intersection resources (the domain trap and `&`-gate fixes above).
- **`zzb-lifecycle`** — schema-as-code, versioning, migration, CLI vs SDK vs API.
- **`zzb`** — the command reference.
- Lost? Read `skills/README.md` (the router).
