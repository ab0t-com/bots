# Ordered levels, recursive & multi-level arrows, and the depth cap

Covers three related facts about arrows (`relation->permission`): how to model an
**ordered ladder** (clearance ≥ classification) with a self-referential permission,
why arrows may **recurse and chain** across levels, and the **25-hop depth cap**
that bounds all of it.

- [Ordered levels (clearance ≥ classification) — the recursive-`higher` pattern](#ordered-levels-clearance--classification--the-recursive-higher-pattern)
- [Recursive & multi-level arrows](#recursive--multi-level-arrows)
- [The max recursion depth (25 hops)](#the-max-recursion-depth-25-hops)

---

## Ordered levels (clearance ≥ classification) — the recursive-`higher` pattern

There is **no numeric / `≥` operator**. To model ordered levels (Confidential <
Secret < Top-Secret, or Tier-1 < Tier-2 < Tier-3), make each level an **object**,
chain them with a `higher` relation (level → the level just above it), and give the
level a **recursive** computed permission that walks the chain:

```json
{"type":"level",
 "relations":{
   "holder":{"allowed_subject_types":["user"]},
   "higher":{"allowed_subject_types":["level"]}},
 "permissions":{"eligible":"holder + higher->eligible"}},
{"type":"document",
 "relations":{
   "classification":{"allowed_subject_types":["level"]}},
 "permissions":{"can_read":"classification->eligible"}}
```

`eligible` reads: *you are eligible for this level if you hold it, OR you are
eligible for the level above it* — so a Top-Secret holder is eligible for every
level below. Wire the ladder once (top → down) and clear each user to their level:

```sh
# ladder: confidential < secret < topsecret  (each points at the one above)
zzb transact \
  --write level:confidential#higher@level:secret \
  --write level:secret#higher@level:topsecret \
  --write level:secret#holder@user:alice \
  --write document:memo#classification@level:confidential
```
```
$ zzb check user:alice can_read document:memo   # Secret clearance ≥ Confidential doc
ALLOW
```
A Confidential-only user checked against a Secret document is **DENY**. This is THE
way to do ordered levels here — add a fourth level by extending the `higher` chain,
no schema change.

*See also: to add need-to-know compartments ON TOP of the clearance ladder, `&` a
`compartment->member` term — see conditional-gates §2 (compartment) and §3 (ABAC).*

---

## Recursive & multi-level arrows

Two facts the ordinal pattern relies on, true in general:

- **A computed permission MAY reference itself through an arrow.** `eligible:
  holder + higher->eligible` is legal and terminates when the chain runs out. This
  is how you walk an arbitrary-length ladder or a self-referential hierarchy.
- **Arrows CHAIN through computed permissions across more than one level.** The
  target of an arrow can itself be a permission that contains another arrow, e.g.
  `engagement` has `admin: parent->eng_admin` where the parent type's `eng_admin`
  is itself `owner + parent->partner` — so admin resolves up *two* org levels.
  Deep folder/org inheritance (grandparent → parent → child) depends on this
  chaining; each `->` hop steps one level and re-enters the next permission.

*See also: the folder/parent arrow in the main SKILL is the one-level case; Recipe
E (nested hierarchy / B2B2B) composes this across a whole org tree.*

---

## The max recursion depth (25 hops)

There is a **max recursion depth** on evaluation: an arrow/inheritance chain resolves
cleanly to **25 hops** (one `->` / `parent->` / membership hop = one unit, so the cap
equals the hop count, inclusive — 25 hops resolve, the 26th fails). A chain deeper than
25 hits the cap and **fails closed** — a DENY whose reason says
`max evaluation depth (25) exceeded — chain too deep` (not a silent or mislabeled
denial). Count every hop, including a leaf's own `parent->`: a `document` under N
nested org-nodes is **N+1** hops (the N org-node links plus the document→parent link),
so an 8-level holding→division→…→document tree is 7 hops — far inside the cap. For
authoritative "who/what" answers at depth use `list-users` / `list-objects` / `check`;
`expand` is a tree-inspection aid that honors `--max-depth` up to the same cap.
