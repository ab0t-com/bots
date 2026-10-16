---
name: usability-audit-sop
description: Run a paired black-box + white-box usability audit of a developer-facing system (a CLI, API, SDK, skill, or its docs) using two role-playing subagents, to find DX/UX friction, doc-vs-code drift, and whether the docs teach thinking not just syntax. Use when asked to audit usability/onboarding/DX/UX of a tool, to validate that a new or non-technical user can accomplish the core task, to stress-test documentation against reality, or to produce a scored usability report. Orchestrates two auditors (one docs-only, one with source access), each of which must ACTUALLY perform the system's core task, then produce a scored report artifact AND a message to the parent.
---

# Paired usability audit — SOP

Audit a developer-facing system by having two subagents role-play its real user (e.g. a
non-technical PMM, a new SDK integrator, an on-call engineer) and actually TRY to do the core task
using only what the system provides. One works black-box (docs/help only); one works white-box
(also reads source). The contrast is the signal: black-box exposes onboarding/DX truth, white-box
exposes doc-vs-code drift and hidden capability.

## When this fires (the shape)

You have a target system + its documentation, and you need to know: *can the intended user succeed
with only what's provided, where do they get confused, and do the docs lie or under-sell?* The
deliverable is two scored report artifacts + your synthesis — not a vibe check.

## The two core takeaways (why anyone reads the output)

Everything this SOP produces distills to two things — design the whole run to deliver both:

1. **The usage report — the actual content.** The substantive findings each auditor surfaces while
   really using the system: the confusions, the friction, the silent traps, the feature gaps. The
   VALUE is the content, not the score — a "7/10" tells no one what to fix; "the doc's `export`
   example uses `{braces}` that silently no-op" does. Score is a summary; content is the product.
2. **The light-vs-dark delta — where DARK got confused that LIGHT did not.** The difference between
   the docs-only (dark) auditor and the source-aware (light) auditor IS the usability measurement.
   Every place dark stumbled but light sailed through is a place the *documentation* failed — the
   information existed, the docs just didn't convey it. Producing this delta is the ORCHESTRATOR's
   job (not the sub-auditors'), and it is a required output. Method + the three buckets:
   [references/light-vs-dark-delta.md](references/light-vs-dark-delta.md).

## The two auditors (why paired)

| Auditor | May read | Surfaces | Cannot |
|---|---|---|---|
| **Black-box** | docs, help, examples, the tool's own output — **NO source** | true onboarding friction, DX/UX confusion, what a real user actually experiences | see why something breaks, or capabilities the docs omit |
| **White-box** | everything **including source** | doc-vs-code drift, under-sold/hidden features, root cause of each friction | un-see the source — must consciously judge what a docs-only user would miss |

Run BOTH. Black-box alone misses drift; white-box alone can't feel real onboarding pain because it
knows too much. Details + boundary enforcement: [references/blackbox-vs-whitebox.md](references/blackbox-vs-whitebox.md).

## The non-negotiable output contract (score gates these)

Each auditor MUST deliver ALL THREE, or its score is capped/zeroed:
1. **A real artifact built with the system** — actually perform the core task using ONLY the
   documented flow (for a journey tool: author a REAL long-form multi-step user journey, not a toy;
   for an SDK: write a working integration; for an API: complete an end-to-end call chain). This is
   the dogfood — the proof the user could succeed. It must pass the system's own checks.
2. **A report artifact** — a bashdated Markdown file with the auditor's agent id in the filename,
   full and complete, following the report contract.
3. **A message to the parent** — a ~10-line executive summary returned to the orchestrator (verdict,
   top findings, recommendation, score, the file paths). The report is the durable output; the
   message is the routing signal.

A report without the built artifact, or a built artifact without the report, is an INCOMPLETE audit
— the rubric double-scores this explicitly. Rubric + report structure:
[references/report-contract.md](references/report-contract.md).

## Required audit dimensions (every auditor covers all)

- **DX** — developer experience: onboarding, command discoverability, help quality, error messages,
  time-to-first-success.
- **UX** — end-user experience of the thing being BUILT/TESTED (not just the tool): does the
  artifact the user produces reflect a real user's flow? Is the tool's own output (reports, verdicts)
  understandable by the intended audience? **UX is a first-class dimension, not folded into DX.**
- **Feature suggestions** — concrete additions that would remove friction (ranked, with the trigger
  that motivated each).
- **"Teach the thinking, not just the syntax"** — do the docs teach the user HOW TO THINK about the
  task (what to build, how to frame it, what "good" means), or only the mechanics? This is usually
  the highest-leverage finding.
- **(White-box only) Doc-vs-code drift** — a table: claim · reality (file:line) · does it mislead a
  docs-only user? · fix.

## The workflow — phases

**Parent (orchestrator) phases:** Scope → Spawn (both, in parallel) → Verify deliverables exist →
Independently confirm headline findings (audit is a lead, not gospel) → Synthesize + rank →
(optional) fix the clearly-correct confirmed defects.

**Each auditor's phases:** Assign identity → Onboard (as the persona) → Build the real artifact →
Probe/stress the documented flow → Score against the rubric → Write the report artifact → Return the
parent message.

Full phase-by-phase SOP for both roles: [references/agent-phases.md](references/agent-phases.md).

## Spawning the auditors

Use two subagents (a capable model), in parallel, run to completion so you can verify
and synthesize. Copy-paste, parameterized prompt templates for each role (they bake in the persona,
the read-boundary, the three-part output contract, the dimensions, and the phases):
[references/auditor-prompt-template.md](references/auditor-prompt-template.md).

Parameterize: `{TARGET}` (system under audit), `{PERSONA}` (who the real user is), `{CORE_TASK}` (the
artifact they must build), `{ALLOWED}` / `{FORBIDDEN}` read paths, `{REPORT_DIR}`, `{ARTIFACT_DIR}`.

## After both return — the parent's job (produces takeaway #2)

1. **Verify the files exist** and the built artifact actually passes the system's checks — do NOT
   trust the agent's word (re-run the validator/linter/test yourself).
2. **Independently reproduce the headline findings** before acting on them — especially any that
   converge across both auditors (high confidence) or claim a bug.
3. **Produce the light-vs-dark delta** (a required artifact — this is your job, not the auditors').
   Classify every finding into three buckets and write it to a `LIGHT_VS_DARK_DELTA_<date>.md`:
   - **CONVERGENT** — both dark and light found it independently → highest-confidence REAL tool
     defect (observable from the surface; fix first).
   - **DARK-ONLY confusion** — dark stumbled, light did not → a pure DOCUMENTATION gap (the info
     exists; the docs fail to convey it). This bucket is the documentation quality score.
   - **LIGHT-ONLY finding** — dark structurally couldn't find it → drift, hidden capability, or (the
     scariest) a SILENT TRAP a docs-following user hits and can't diagnose. Rank these by "would a
     dark user trip over this silently?" — those are the most urgent docs/UX fixes.
   Full method: [references/light-vs-dark-delta.md](references/light-vs-dark-delta.md).
4. **Synthesize + relay**: merge + rank, separate confirmed-defect from opinion, hand the user a
   scorecard + the delta. **The executive summary you relay MUST include the delta's one-line
   verdict** — the documentation-vs-product call (e.g. "the tool is sound; the gaps were docs, proven
   by light having none of dark's confusions"). That verdict, not the number, is the decision the
   audit exists to make; a summary without it is incomplete.
5. **Fix as intended — never downgrade to meet honesty.** Every finding is an opportunity to IMPROVE
   the feature, not to shrink the promise. When a doc says X and the code does Y, the DEFAULT is to
   make the code do X (implement the feature as it was intended), NOT to edit the doc down to Y.
   Downgrade the doc/behaviour ONLY when X was genuinely never intended — and say so explicitly.
   Examples of the right call: a doc referencing a `doctor` command that doesn't exist → **build
   `doctor`**, don't strike the reference; a config field whose documented `{brace}` form silently
   no-ops → **make the braces work**, don't rewrite the doc to the broken bare form; a `capture:` that
   a `run:` step drops → **wire capture on `run:`**, don't just forbid it. Only fix the clearly-correct,
   low-risk items yourself; surface the rest as feature work.

## Anti-patterns (this SOP exists to prevent them)

- **A toy artifact.** "Wrote a 2-step hello-world" doesn't prove a real user can succeed. Demand a
  realistic, complete artifact — the dogfood is the audit.
- **Black-box peeking at source.** It invalidates the onboarding-truth signal. Enforce the boundary
  in the prompt and check the transcript if in doubt.
- **Report XOR message.** Both are required; the report is durable evidence, the message routes.
- **Taking findings as gospel.** Confirm before you fix. A confident wrong finding is worse than
  none (the audit is a lead, not gospel).
- **DX-only.** UX and "teach the thinking" are where the real product gaps hide — require them.
- **Downgrading to meet honesty.** Editing the doc down to the code's current limitation "so they
  match" is the wrong reflex — it makes the promise smaller instead of making the product bigger. A
  drift finding is a feature request in disguise; implement the intended feature (see parent job #5).
- **Relaying a number, not the verdict.** "6/10" routes nothing. The delta's documentation-vs-product
  verdict is the takeaway — always relay it.
