---
name: uj-journey-design
description: >-
  Think like a PMM/product-test-engineer to DESIGN a user journey worth testing — before writing any
  uj YAML. Use when deciding WHICH journey to write, framing the persona and their real goal, writing
  a strong success criterion, decomposing a flow into steps, choosing which abuse/negative-space cases
  matter, or self-reviewing a journey before handoff. This is the "what to test and how to think
  about it" layer; for the file SYNTAX use uj-authoring, for RUNNING use uj-cli. Answers the question
  a blank `uj new` can't — "what do I even test, and how do I know it's good?"
---

# Designing a user journey (think first, then write)

`uj-authoring` teaches the syntax. This teaches the **design thinking** a PMM needs BEFORE opening
`uj new` — the part that decides whether a journey is worth writing and whether it proves anything
a customer would notice. Skipping it produces two failure modes: paralysis ("what do I even test?")
or a shallow one-happy-path journey that passes while the product is broken in ways that matter.

## The method (work top-to-bottom, then write the YAML)

**START from the OUTCOME — not a task.** A user journey (per customer-journey-mapping / jobs-to-be-
done) is organized around a *change in the person's world*, told as prose. "Create an org" is a TASK
(a system verb); the OUTCOME is what it's *for* — "a founder can safely grow their team." If your
`outcome:` starts with create/get/delete/update, go up a level: ask **"so that… what?"** (lint JL009
flags this). Capture it in the journey's `outcome:`, `persona:`, and `narrative:` (prose) fields —
`uj explain` renders them as the human story.

| # | Step | The question to answer | Output |
|---|---|---|---|
| 1 | **Brainstorm the OUTCOME** | What change in the person's world/business is this for? (not a system verb) | `outcome:` — a business fact ("a business can trust a departed contractor's access is gone") |
| 2 | **Name the persona + write the narrative** | WHO, in what circumstance, and what's their story start-to-finish? | `persona:` + `narrative:` (prose) |
| 3 | **Write `success:` as observable proof** | If this passes, what real promise/KPI held? | a sentence that ties to the outcome, not "returned 200" |
| 4 | **Decompose into steps (reuse fragments)** | What meaningful state changes realize the outcome? Which blocks recur? | AS MANY steps as it takes to simulate a real session (no upper cap — long is realistic); pull recurring normal-activity blocks into `use:` fragments so length stays readable |
| 5 | **Choose the abuse case(s)** | What's the worst thing someone could try here? Pick the 1–2 that matter. | 1–2 `abuse:` steps from the checklist, not zero and not arbitrary |
| 6 | **Design the cleanup** | What residue would this leave? (billing state, invites, sessions, API keys) | a `finally:` that returns the world to zero |
| 7 | **Assert what a customer would notice** | Does each step prove something real, or just "200"? | `fields`/`body`/`schema` on the steps that carry value |
| 8 | **Self-review, then hand off** | Is this journey DONE? | run the checklist below, then `uj explain` → `lint` → `validate` |

Deep dives: scenario selection + the `success:` rubric + step-decomposition →
[references/success-and-scenarios.md](references/success-and-scenarios.md); the abuse taxonomy →
[references/negative-space-checklist.md](references/negative-space-checklist.md); the operational
truths for pointing uj at YOUR service → [references/operational-reality.md](references/operational-reality.md).

## Worked example (the shape of good design thinking)

> **1. Journey:** partner-offboarding — a trust-critical action (a revoked partner must lose access).
> **2. Persona+goal:** "ops wants a partner's API key to stop working the instant the partnership ends."
> **3. success:** "the moment ops offboards the partner, the same key stops validating on the very
> next check — no grace window, no cached 'still good'." (a promise, not a status code)
> **4. Steps:** issue key → key validates → revoke key → **same key now rejected** (the value moment).
> **5. Abuse:** a never-issued look-alike key must be refused; a just-revoked key must fail immediately.
> **6. Cleanup:** none needed if the tenant is per-run isolated; else delete the key in `finally:`.
> **7. Assert:** on issue, `schema` the key shape; on the revoke-then-check, assert `valid: false`.

That is a journey a customer would care about — designed before a line of YAML.

## The PMM self-review checklist (run before `uj lint`)

- [ ] The journey is named by its **business stake**, not an endpoint.
- [ ] The **persona and goal** are one clear sentence; the steps trace ONE coherent person's path.
- [ ] `success:` ties to a **real promise/KPI**, not "step N returned 200."
- [ ] Steps are **meaningful state changes**, not a dump of API calls.
- [ ] At least **one abuse case** was consciously chosen (or you can say why none applies).
- [ ] `finally:` leaves **no residue** (or per-run isolation genuinely covers it).
- [ ] Value-carrying steps assert **more than status** (`fields`/`body`/`schema`).
- [ ] You read the **lint findings as design questions**, not chores to silence (see below).

## Read lint nudges as design signals, not chores

Each JL finding is really a design question:
- **JL004** (status-only) → "does this step prove anything a customer would notice?"
- **JL002** (unused capture) → "why did I fetch this if no step depends on it?"
- **JL008** (no success) → "can I even state what 'worked' means in business terms?"
- **JL003** (no cleanup) → "what residue does this leave in a real tenant?"

Silencing them by deleting content is the wrong fix; answering the question is the design work.


## Test the specific thing INSIDE a realistic session — never as a unit test

A journey is a persona living a realistic slice of their day, doing SEVERAL normal activities, with
the behavior-under-test woven in as a **checkpoint along the way** — not the whole test. To test
"does the permission gate enforce?", don't write three `validate-token` calls; write a developer's
"set up and ship an integration" session (orient → create a team → issue a key → wire the gate) and
put the enforcement check where they'd actually hit it. The surrounding activity is the point: it
builds real state and is where interaction/ordering bugs surface. Compose the normal activities from
`use:` fragments; declare what the session exercises with `covers: [risk, …]`; check the risk→session
matrix with `uj coverage`. (Prior art: session-based test management, model-based testing, stateful
property testing — all assert invariants along realistic sequences, not in isolation.)

## Where this fits

Design here → author with `uj-authoring` (syntax) → run with `uj-cli` (verdicts). A journey
designed well but written sloppily still fails lint; a journey written cleanly but designed
thoughtlessly passes lint and proves nothing. You need both — this skill is the half a blank
`uj new` can't give you.
