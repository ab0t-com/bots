# Conditional gates & information barriers (one family)

These five patterns are **one family**: they gate access on a *marker, attribute,
or the other side's membership* rather than on a plain role. They share the same
two moves — subtract with `-` (or require with `&`) **through an arrow**, and put
the **exempt** roles *outside* the parens. Learn one and the rest fall out.

- [1. Conditional exclusion (NOFORN)](#1-conditional-exclusion-noforn) — bar a named group, only when a resource opts in
- [2. Conditional intersection (compartment / need-to-know)](#2-conditional-intersection-compartment--need-to-know) — require a caveat ONLY when the resource has one (+ the empty-`&` trap)
- [3. Layered attribute gates (ABAC): classification × purpose](#3-layered-attribute-gates-abac-classification--purpose) — gate on resource attributes on top of the hierarchy
- [4. Conditional step-up — require a STRICTER role when a marker is present](#4-conditional-step-up--require-a-stricter-role-when-a-marker-is-present) — protected branch / prod deploy / locked record
- [5. Information barrier / Chinese wall — two-sided mutual exclusion](#5-information-barrier--chinese-wall--two-sided-mutual-exclusion) — deal team vs trading desk
- [6. Dual-control / separation-of-duties (N distinct approvers)](#6-dual-control--separation-of-duties-n-distinct-approvers) — the obvious approach is BACKWARDS

> **The family in one sentence.** `X - marker->member` bars a group only when the
> marker tuple is present (NOFORN); `X & caveat->member` requires a caveat only
> when present (compartment/ABAC); `weak - user:* + strong` steps up the required
> tier when a marker is present (step-up); doing NOFORN once per side gives mutual
> exclusion (Chinese wall); and a subject-independent `user:*` flag gated by `&`
> gives dual-control. In every case, **union the exempt roles OUTSIDE the `-`/`&`**.

---

## 1. Conditional exclusion (NOFORN)

`-` can subtract through an **arrow**, and the arrow yields *nothing* when the tuple
is absent — so the exclusion only bites when you opt a resource in:

```json
{"type":"caveat","relations":{"member":{"allowed_subject_types":["user"]}}},
{"type":"document",
 "relations":{
   "viewer":{"allowed_subject_types":["user"]},
   "noforn":{"allowed_subject_types":["caveat"]}},
 "permissions":{"can_read":"viewer - noforn->member"}}
```

- No `noforn` tuple on the document → `noforn->member` resolves to **empty**, so
  nothing is subtracted and `can_read` = `viewer`.
- Point the document at a caveat (`document:x#noforn@caveat:foreign-nationals`) →
  every `caveat:foreign-nationals#member` is now subtracted from `can_read`, even if
  they are a `viewer`. Flip the whole marking on/off with a single tuple.

*See also: step-up (§4) subtracts `user:*` instead of a named group; Chinese wall
(§5) applies this once per side; the ban/exclusion `-` in the main SKILL subtracts
a direct relation instead of an arrow.*

---

## 2. Conditional intersection (compartment / need-to-know)

This is the **dual** of NOFORN above, and it's a trap. A required `& arrow->member`
term **DENIES every resource that lacks the tuple**, because the arrow resolves to
*empty* and `X & (empty)` is empty. So a naïve compartment gate —
```json
"can_read":"classification->eligible & compartment->member"
```
correctly requires clearance **and** need-to-know for a *compartmented* document, but it
also silently denies **every un-compartmented document** (no `compartment` tuple → the
`&` term is empty → DENY for everyone). Use one of two idioms:

**A. "Open compartment" sentinel (keeps one document type).** Give every
non-compartmented document an always-satisfiable compartment so the `&` term never
resolves empty for a cleared user:
```sh
# a public/default compartment that everyone is a member of:
zzb relationship write compartment:open member 'user:*'
# attach it to any document that is NOT specially compartmented:
zzb relationship write document:memo compartment compartment:open
# a genuinely compartmented doc points at a real compartment instead:
zzb relationship write document:crypto-doc compartment compartment:CRYPTO
```
Now `classification->eligible & compartment->member` means "cleared, AND in this
document's compartment" — and for an `open`-marked doc the compartment check is
satisfied by anyone, so clearance alone suffices. Toggle a document into a real
compartment by repointing its `compartment` tuple.

**B. Two permissions unioned (no sentinel).** Make the compartment an *additive*
requirement only where present: keep a base that needs just clearance, and add a
compartmented branch — but note you then can't *remove* base access for a compartmented
doc without also excluding it. Prefer **A** when "compartmented ⇒ MORE restrictive than
base" (the usual classified case); the sentinel makes the single-type model behave
correctly for both compartmented and un-compartmented resources.

*See also: NOFORN (§1) is the exclusion dual; ordered-levels supplies the
`classification->eligible` clearance ladder; ABAC (§3) `&`s the same way on a
column/dataset attribute.*

---

## 3. Layered attribute gates (ABAC): classification × purpose

To gate on resource ATTRIBUTES (a column's PII classification, a dataset's allowed purpose) in
addition to the hierarchy, `&` a clearance arrow onto the inherited access:
```json
"column.can_read": "parent->can_read & classification->cleared"     // needs table access AND the class clearance
"dataset.can_read": "((consumer + producer) & purpose->cleared) + parent->can_read"  // role AND purpose, steward exempt
```
- A **public** column: `classification:public#cleared@user:*` (the open-compartment sentinel) →
  anyone with table access reads it; a **PII** column names only cleared users → table access
  alone is not enough.
- The gate is **absolute and fail-closed**: an un-classified column (`& empty`) is dark to
  everyone, including admins — so classify *every* attribute, and if a steward/admin must bypass
  the gate, union them **outside** the `&` (`+ parent->can_read`), exactly like the Chinese-wall
  exemption. Deciding whether an admin bypasses a PII gate is a policy call — the engine will do
  either; be explicit.

*See also: the open-compartment sentinel is from §2; the "exempt outside the `&`"
move is the Chinese-wall exemption (§5); classification ladders come from
ordered-levels.*

---

## 4. Conditional step-up — require a STRICTER role when a marker is present

The third member of the conditional family (after conditional-*exclusion* / NOFORN and
conditional-*intersection* / compartment). Use it when the presence of a marker makes an action
require a **higher** role: pushing to a **protected** branch needs `maintain` (not `write`);
deploying to **prod** needs an approver (not just a deployer); editing a **locked** record needs
an admin. Pattern — subtract a `user:*` marker from the WEAKER branch, and union the STRONGER
role back **outside** the subtraction:
```json
{"type":"branch","relations":{
   "repo":{"allowed_subject_types":["repo"]},
   "protected":{"allowed_subject_types":["user"],"allows_wildcard":true}},
 "permissions":{"can_push":"repo->can_maintain + (repo->can_push - protected)"}}
```
- No `protected` tuple → `- protected` subtracts nothing → `can_push = maintain ∪ write` (normal
  branch: writers push).
- Mark it protected with ONE wildcard tuple → the subtrahend is *everyone*, nulling the weaker
  `write` branch, while `repo->can_maintain` (unioned outside the parens) still passes → only
  maintainers+ push:
```sh
zzb relationship write branch:main protected 'user:*'   # step up: writers barred
zzb check user:writer can_push branch:main              # DENY (writer, and it's protected)
zzb check user:maint  can_push branch:main              # ALLOW (maintain survives outside the `-`)
zzb relationship delete branch:main protected 'user:*'  # step down: writers restored
```
It's the dual of NOFORN: NOFORN subtracts a *named group* to bar them; step-up subtracts
`user:*` to bar *the weaker tier*, keeping the stronger tier unioned outside. `expand` shows a
first-class `exclusion` node; toggle the whole gate with one tuple.

*See also: NOFORN (§1) subtracts a named group; the GitHub repos+branches recipe
composes this over role inheritance.*

---

## 5. Information barrier / "Chinese wall" — two-sided mutual exclusion

Two groups must be **mutually exclusive**: being on side A bars you from side B's resource,
AND being on side B bars you from side A's — e.g. an investment bank's private deal team
(MNPI) vs the public trading desk for the same issuer. There is **no mutual-exclusion
primitive**; you build it as the NOFORN conditional-exclusion applied **once per side**, each
subtracting the *other* side's group:
```json
{"type":"sidegroup","relations":{"member":{"allowed_subject_types":["user"]}}},
{"type":"dealroom",     // PRIVATE side — barred to the public group
 "relations":{"desk":{"allowed_subject_types":["desk"]},
   "assigned":{"allowed_subject_types":["user"]},
   "public_bar":{"allowed_subject_types":["sidegroup"]},
   "cleared":{"allowed_subject_types":["user"]}},
 "permissions":{"can_view":"desk->member & assigned - public_bar->member + cleared + oversight->member"}},
{"type":"position",     // PUBLIC side — barred to the private group
 "relations":{"desk":{"allowed_subject_types":["desk"]},
   "private_bar":{"allowed_subject_types":["sidegroup"]},
   "cleared":{"allowed_subject_types":["user"]}},
 "permissions":{"can_view":"desk->trader - private_bar->member + cleared + oversight->member"}}
```
Wire each object at the barred group once (`dealroom:acme#public_bar@sidegroup:acme-public`,
`position:acme#private_bar@sidegroup:acme-private`), then membership on a side flips access:
```
$ zzb relationship write sidegroup:acme-private member user:a   # a joins the deal team
$ zzb check user:a can_view position:acme   # DENY  (now barred from the public desk)
$ zzb check user:t can_view dealroom:acme    # DENY  (t is public-side, barred from the room)
```

Three things this pattern relies on — the parts that surprise people:

1. **The engine does NOT enforce two-group exclusivity.** It won't stop you writing a user
   into BOTH `sidegroup`s. Mutual exclusion is *your app maintaining the two memberships* +
   the engine *resolving* the bar via `- otherSide->member`. Keep the two memberships
   consistent in your app (write/remove them as a pair).
2. **`-` overrides a group/userset-granted role, not just a direct grant.** `a`'s public view
   came from `trader@desk#member` (a userset), yet `- private_bar->member` still removes `a`.
   Exclusion beats *any* positive branch, however it was granted (`expand` shows the
   `excluded` node).
3. **Make oversight/ancestor roles EXEMPT by unioning them OUTSIDE the exclusion.** Compliance
   must see BOTH sides, and a division head must see their whole subtree — so add `+ cleared`,
   `+ oversight->member`, `+ parent->can_view` *after* the `- otherSide` term. Anything inside
   the subtracted parens is barred; anything unioned outside is exempt. (Whether oversight
   *should* cross the wall is a policy call — usually yes: compliance polices the wall.)

*See also: this is NOFORN (§1) applied per side; the mutual/symmetric pattern is a
different two-sided idea (denormalized inverse, not exclusion).*

---

## 6. Dual-control / separation-of-duties (N distinct approvers)

**Read this before you model an approval gate — the obvious approach is BACKWARDS.**

`&` is a **same-subject** set intersection: `a & b` asks "does the SAME subject
satisfy both `a` and `b`?" So a naïve `dual_approved: approver_a & approver_b` does
the OPPOSITE of what you want: with two *different* people in the two slots the
intersection is **empty → DENY**, while **one** person filling both slots →
**ALLOW** (i.e. it green-lights single-person self-approval — a security inversion).
`&` **cannot** express "two DISTINCT people"; there is no native M-of-N distinctness
operator today.

Correct pattern — **distinctness is the app's job; Zanzibar gates on a boolean flag.**
Your application verifies that N *distinct* approvers signed, then writes ONE
subject-independent approval flag (a `user:*` wildcard tuple). The deploy/publish gate
then checks *actor role* AND *the flag*:

```json
{"type":"approval",
 "relations":{"approved_flag":{"allowed_subject_types":["user"],
                               "allows_wildcard":true,"allows_anyone":true}},
 "permissions":{"is_approved":"approved_flag"}},
{"type":"prod_deploy",
 "relations":{"pipeline":{"allowed_subject_types":["pipeline"]},
              "approval":{"allowed_subject_types":["approval"]}},
 "permissions":{"can_deploy":"pipeline->maintainer_access & approval->is_approved"}}
```
```sh
# 1) your app confirms two DIFFERENT maintainers approved, THEN sets the flag once:
zzb relationship write approval:dep1 approved_flag 'user:*'
zzb transact --write prod_deploy:d1#pipeline@pipeline:p1 --write prod_deploy:d1#approval@approval:dep1
# 2) the gate = "actor is a maintainer" AND "approval flag is set":
zzb check user:mary can_deploy prod_deploy:d1     # ALLOW (mary is a maintainer + approved)
zzb check user:carol can_deploy prod_deploy:d1    # DENY  (approved, but not a maintainer)
# revoke to re-lock:
zzb relationship delete approval:dep1 approved_flag 'user:*'  # → can_deploy DENY again
```

> **Why the flag is a `user:*` wildcard:** the approval is a *property of the object*
> ("this deploy has cleared review"), not a grant to any specific user — so it must
> resolve for the actor regardless of who they are, gated by their role via the `&`.
> Distinctness (`approver_a ≠ approver_b ≠ …`) is enforced in the app BEFORE the flag
> is written; the engine can't. A first-class M-of-N distinct-approver primitive is an
> open enhancement.

*See also: the `user:*` subject-independent flag is the same trick step-up (§4) uses
to bar a whole tier; the dual-control gate composes with any role from the main
SKILL's role-inheritance pattern.*
