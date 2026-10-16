---
name: zzb-audit
description: Audit your own ab0t authorization setup for risks and misconfigurations with zzb — find over-grants, accidental public exposure, resources that are dark to everyone, dead/unreachable permissions, schema drift, and stale grants, then fix them. Use when reviewing an authorization model for safety before or after go-live, doing a security/access review of your ReBAC setup, answering "is my model safe / who can see this / did I over-grant", wiring an authz lint into CI, investigating a suspected leak or a permission that "should work but doesn't", or periodically checking a live store. Covers the one-command `zzb audit` checker, the risk classes it flags (wildcard/domain over-grant, dark-by-intersection, unreachable permission, self-approval / separation-of-duties (a naive `&` dual-control gate one person can self-approve), cross-org grant residue, undeclared-type drift, expired grants, missing assertions, broad admin, depth), how to read and fix each, and the manual "who can do X" spot-checks (list-users / list-objects / expand). For writing the model use zzb-modeling; for the command reference use zzb.
---

# zzb — audit your authorization setup

Find the risks in your own model + grants before they become an incident.

## Install / update

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/ab0t-zzb/main/install.sh | sh
zzb --version
export ZZB_URL=https://auth.service.ab0t.com   # or your env
```

## The one command

```sh
zzb audit                 # ranked risk findings for the active store
zzb audit --json | jq .   # machine-readable (CI, dashboards)
```

`audit` reads your store's **active model + relationship tuples**, analyzes them, and prints
findings ranked **blocker → high → medium → low → info**, each naming the exact
`object#relation` / permission, **why** it's a risk, and **the fix**. It exits non-zero when a
finding is at or above a threshold (default: high) — so it doubles as a **CI gate**:

```sh
zzb audit || { echo "authz audit failed"; exit 1; }   # fail the build on a high-risk finding
```

Run it: before go-live, in CI on every model change, after a bulk grant import, and on a
schedule against production. It is **read-only** — it never mutates your store.

## The risk classes (what it flags, and how to fix each)

Even without the command, these are the checks to run by hand. Each is a real
misconfiguration that ships silently.

### 1. Wildcard / public over-grant — and THE DOMAIN TRAP  (high)
A `user:*` tuple grants **literally everyone, including strangers off your domain**.
```sh
zzb read --user 'user:*' --json | jq '.tuples[].key'   # every public grant
```
For each, confirm it's *meant* to be world-readable (a public page, a link share). **The
trap:** "anyone on my company domain" is **NOT** `user:*` — that opens it to the whole
internet. Model domain access as a materialized userset (`domain->member`, filled by your
SSO/JIT), never `user:*`. → Fix an unintended one: `relationship delete <obj> <rel> 'user:*'`.

### 2. Dark-by-intersection — private by accident  (high)
A permission like `can_view: role & clearance->cleared` denies **everyone** for any resource
that has no `clearance` tuple (the `&` term resolves empty). A whole class of objects can be
invisible and you won't know. Find it: for each `&`-gated permission, check that the gating
relation/flag is actually set on your resources —
```sh
zzb list-users <object> <permission>   # empty for a resource that SHOULD be visible? that's the smell
```
→ Fix: set the gating tuple (e.g. an "open" sentinel `user:*` for public resources), or move
the gate off resources that shouldn't require it. See `zzb-modeling` (conditional
intersection).

### 3. Unreachable / dangling permission — a dead route  (high)
A permission whose expression references a relation or permission that **isn't defined** →
nobody can ever satisfy it, so the feature it guards is unreachable by every principal.
```sh
zzb model get <model_id> --json    # read the expressions; check every name resolves
```
→ Fix: define the missing relation/permission, or correct the expression, and re-publish.

### 4. Self-approval / separation-of-duties — dual-control one person can satisfy  (high)
A permission whose expression conjoins **two or more per-subject approver relations** with
`&` (e.g. `can_execute: approver_a & approver_b`) is a **backwards** dual-control gate. `&`
is a **same-subject** AND — it asks "does the SAME subject satisfy both?" — so **one** person
holding both slots **self-approves**, and it can never require two *distinct* approvers. audit
flags every such permission **high**, and **blocker** when tuples show a single subject already
holding all operands on some object (self-approvable *right now*).
```sh
zzb audit --json | jq '.findings[]|select(.check=="self-approval-sod")'
```
**The SAFE pattern (not flagged):** distinctness is your **app's** job — verify N *distinct*
approvers signed, then write ONE subject-independent `user:*` approval flag, and gate on
*actor role* `&` *the flag* (`maintainer & approved_flag`). One per-subject operand + a flag ⇒
no self-approval. → Fix: see `zzb-modeling` / `references/conditional-gates` §6.

### 5. Cross-org / foreign-org grant residue  (medium)
A wildcard `permission grant … organization:<id>` whose `<id>` is **not this store** is
written to *your* store's partition — it is a **silent no-op** for the named org (it grants
nothing there), yet reads like a cross-org grant. → Fix: run the grant against that org's own
store, or drop it if it was never meant for a foreign org.

### 6. Undeclared-type drift  (medium)
Tuples whose object type isn't in the active model. Writing an undeclared type is rejected
now, but a model rollback can strand old tuples. → Fix: re-declare the type or clean the
tuples.

### 7. Expired-but-present grants  (info)
Time-bound grants (`--expires`) past their deadline are denied at check time but still stored
(audit sees them). Clutter, not danger. → Clean up: `zzb purge --user <subject>` or a
paged delete.

### 8. No assertions — no CI gate  (medium)
If your model has no stored assertion suite, nothing catches a bad publish. → Fix: write
`assertions.json` (the key ALLOW/DENY facts) and `assert put <model_id> --file …`, then
`assert run <model_id>` in CI. See `zzb-lifecycle`.

### 9. Over-broad admin  (medium)
Wildcard/org-wide admin grants that reach more than intended. Review every
`permission grant … admin` and confirm the scope (the `organization:<id>` target). A
mismatched revoke can leave access on — verify with
`zzb check wildcard <user> admin <resource>`.

### 10. Deep chains near the cap  (low)
Arrow/inheritance chains resolve to **25 hops**; beyond that a check fails closed. If your org
tree or classification ladder is very deep, keep the longest chain ≲25 hops (a resource under
N nested nodes is N+1 hops).

## Manual "who can actually do X" spot-checks

The authoritative answers — always agree with these over your mental model:
```sh
zzb list-users  <object> <permission>            # WHO can do X on this object
zzb list-objects <subject> <permission> <type>    # WHAT can this subject do
zzb expand <permission> <object> --max-depth 10   # the full grant tree (why)
zzb check bulk --file checks.json --concurrency 16 --json   # verify a batch of expectations
```
Spot-check your most sensitive objects ("who can view this confidential record?", "who can
approve a wire?", "can an off-domain user reach this?") and confirm the answer is *exactly*
who you expect — no more.

## Periodic certification — `access-review`

Where `audit` lints the **model** for latent traps, **`zzb access-review`** is its
periodic-**certification** companion: it enumerates the **live effective access** to a
permission so an auditor can certify or revoke each grant. For every effective subject it
shows the derived grant **path** (WHY — `direct:editor`, `via team:eng#member → editor`, or
an inherited `via folder:root#parent → can_view`) and audit-style **risk flags**
(`wildcard`, `expiring-soon`, `direct-bypass`, `broad-admin`) so a reviewer can rubber-stamp
the safe rows and act on the risky ones. It is **read-only** — a client-side lens over
`expand` + `read` + `list-objects`, adding nothing to the engine.

```sh
zzb access-review document:q3-report can_view            # who has it, WHY, + risk flags
zzb access-review document:q3-report can_view --flagged-only   # just the rows needing attention
zzb access-review --type document --permission can_edit  # sweep every document's can_edit
zzb access-review --subject user:contractor              # reverse: everything a subject can reach
zzb access-review document:q3 can_view --revoke-plan > revoke.sh   # commented delete lines to curate
zzb access-review --type document --permission can_edit --json | jq '.[]|select(.flags|length>0)'
zzb access-review --type document --permission can_edit --fail-on-flagged   # CI gate (exit 3)
```

Use it for an **access certification round** (SOC 2 / periodic entitlement review): sweep the
sensitive types, hand the `--csv`/`--json` to the reviewer, and turn the un-certified rows into
`relationship delete` lines with `--revoke-plan` (it never auto-deletes — the human curates the
subset). `--fail-on-flagged` makes it a CI gate the same way `audit --max-severity` is.

## Audit cadence

| When | What |
|---|---|
| **In CI, every model change** | `zzb audit` (fail on high) + `assert run <model_id>` |
| **Before go-live** | full `audit` + spot-check every sensitive object with `list-users` |
| **After a bulk grant import / migration** | `audit` + a `check bulk` diff against expectations |
| **Scheduled (prod)** | `audit --json` into your dashboard; alert on new high findings |
| **Periodic certification (SOC 2 / entitlement review)** | `access-review --type <t> --permission <p> --csv` per sensitive type; curate revocations with `--revoke-plan` |

## Related skills

- **`zzb-modeling`** — the patterns behind the fixes (visibility modes + the domain
  trap, conditional intersection, exclusion, arrows) and how to express them safely.
- **`zzb-lifecycle`** — assertions as a CI gate, day-2 audit with `read`/`changes`,
  cleanup/offboarding with `purge`.
- **`zzb`** — the command reference (flags, `--json`, exit codes).
- Lost? Read `skills/README.md` (the router).
