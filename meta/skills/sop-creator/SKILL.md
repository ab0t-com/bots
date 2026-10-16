---
name: sop-creator
description: >-
  Turn a process, task, runbook, or rough description into a high-quality, typed
  Standard Operating Procedure (SOP) — inline, no fan-out. Use when the user
  wants to "write an SOP", "document this procedure", "create a standard
  operating procedure for X", "turn this into a repeatable runbook/SOP",
  "formalize how we do X", or "we need an SOP for onboarding/deploys/incidents".
  Produces a structured, testable SOP with typed steps (action · command ·
  expected · on-failure), preconditions, verification, rollback, and ownership.
  For operational incident response specifically, frame it as a runbook. For a
  client-facing bot's SOPs (seven fixed headings, Coming/Today), use
  sop-aligned-agent-system instead.
---

# SOP Creator (typed, testable Standard Operating Procedures)

Produce an SOP someone unfamiliar can execute correctly the first time — every
step has an action, the exact command, the expected result, and what to do when
it fails. Inline, single-pass, strongly typed. No fan-out.

## Procedure

1. **Pin the procedure.** What recurring task does this SOP standardize, who runs
   it, how often, and what does "done" look like? If the source is a rough
   description or a past chat, gather the real steps first; if vague, ask before
   writing — a guessed SOP is worse than none.
2. **Establish preconditions + roles.** What must be true before starting (access,
   tools, state), and who owns / who executes / who approves.
3. **Write typed steps.** Each step is an action with its exact command, the
   observable expected result, and an on-failure branch. No "etc." — if a step
   has variants, enumerate them. Number them; keep one action per step.
4. **Add verification + rollback.** A done-criteria check that proves the
   procedure succeeded, and a rollback/recovery path if it half-completes.
5. **Capture pitfalls + cadence.** The non-obvious traps, and how often the SOP
   should be reviewed/refreshed.
6. **Validate against the checklist** (below) before declaring it done.

## Typed schema (the SOP)

```
SOP {
  title:         string
  purpose:       string          # the recurring task this standardizes
  scope:         string          # what's in / out of scope
  owner:         string          # accountable role
  cadence:       string          # how often it runs / is reviewed
  roles:         Role[]          # { role, responsibility }
  preconditions: string[]        # must be true before step 1
  steps:         Step[]
  verification:  Check[]         # proves success
  rollback:      string[]        # recovery if it half-completes
  pitfalls:      string[]        # non-obvious traps
  references:    string[]        # linked docs/tickets/runbooks
}
Step {
  n:         integer
  action:    string              # imperative — one action
  command:   string|null         # the EXACT command/click, if any
  expected:  string              # the observable result that means success
  on_failure:string              # what to do if expected isn't seen
  role:      string|null         # who performs this step, if multi-role
}
Check { check: string, expected: string }
Role  { role: string, responsibility: string }
```

## Output

`sop-<slug>.md` rendered from the schema:

```markdown
# SOP: <title>
**Owner:** <owner> · **Cadence:** <cadence> · **Scope:** <scope>

## Purpose
## Roles
| Role | Responsibility |
## Preconditions
- [ ] ...
## Steps
1. **<action>** — `<command>` → expect: <expected>. If not: <on_failure>.
## Verification
- [ ] <check> → <expected>
## Rollback
## Pitfalls
## References
```

To make it loadable by an agent, wrap it as a skill (`skill-creator`): a
`sop-<slug>/SKILL.md` whose `description` says when to run it.

## Quality checklist (validate before done)

- [ ] A stranger could execute it with no tribal knowledge.
- [ ] Every step has an **observable** expected result + an on-failure branch.
- [ ] Commands are exact and copy-pasteable; no placeholders left unexplained.
- [ ] Preconditions are complete (it won't fail at step 1 for a missing tool).
- [ ] Verification actually proves success (not just "looks done").
- [ ] Rollback exists for any step that mutates state.
- [ ] No secrets inline; reference where credentials come from.
- [ ] Owner + review cadence set (an unowned SOP rots).

## Compliance / grounding

- **Real steps only** — base the SOP on the actual procedure; don't invent steps
  to fill the template. Mark anything assumed as `ASSUMPTION:` for the SOP's
  accountable person to confirm.
- **Testable** — prefer observable expected-results over vague "verify it
  worked."
- **No secrets** — reference credential sources; never embed them.
