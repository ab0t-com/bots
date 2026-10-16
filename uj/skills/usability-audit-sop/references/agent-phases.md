# Agentic workflow phases — the full SOP

Two actors: the **parent/orchestrator** and each **auditor subagent**. Run the auditors in parallel.

## Parent (orchestrator) phases

| # | Phase | Do |
|---|---|---|
| P0 | **Scope** | Name the `{TARGET}`, the real `{PERSONA}`, the `{CORE_TASK}` artifact each auditor must build, and the read-boundary (`{ALLOWED}`/`{FORBIDDEN}`). Decide the report + artifact output dirs. |
| P1 | **Spawn** | Launch BOTH auditors (black-box + white-box), in parallel, run-to-completion (you need results to verify + synthesize). Use the templates. |
| P2 | **Verify deliverables** | For each auditor: confirm the report file exists, the built artifact exists, and **re-run the system's own checks on the artifact yourself** (validator/linter/test) — never trust the agent's "it passes." |
| P3 | **Confirm findings** | Independently reproduce every headline finding, especially convergent ones (both auditors → high confidence) and any bug claim. The audit is a LEAD, not gospel. |
| P4 | **Synthesize** | Merge + rank findings; separate confirmed-defect from opinion; build a scorecard; relay to the user. |
| P5 | **Fix (optional)** | Fix only the clearly-correct, low-risk, confirmed defects; surface the rest as choices. Record in a worklog. |

## Auditor subagent phases

| # | Phase | Do | Exit when |
|---|---|---|---|
| A0 | **Assign identity** | Generate your agent id (`printf '<role>-%04x\n' $((RANDOM))`); compute bashdate (`date +%Y%m%d`). Use both in every filename. | id + date fixed |
| A1 | **Onboard (in persona)** | Read ONLY what your boundary allows. Behave as the real user meeting this for the first time. Log every point of confusion, every re-read, every "a non-technical person wouldn't get this." Note time-to-ready. | you feel ready to attempt the task (or you're stuck — that's a finding) |
| A2 | **Build the real artifact** | Actually perform `{CORE_TASK}` using ONLY the documented flow. Make it REALISTIC and complete (a real long-form user journey; a working integration) — never a toy. Run the system's own checks until it passes (or document precisely why a check still complains and whether the docs helped you fix it). | the artifact exists and passes the system's checks |
| A3 | **Probe** | Stress the flow: try the confusing paths, the error cases, the "what if I do it wrong." Test doc claims against the tool's actual behavior. (White-box: also read source and record doc-vs-code drift with file:line.) | you've covered the core surface + the friction you hit |
| A4 | **Score** | Fill the rubric honestly (report-contract.md), including the OUTPUT-CONTRACT gate (did you build the artifact? write the report? send the message?). | rubric complete |
| A5 | **Write the report artifact** | Bashdated MD, agent id in filename, all required sections, full and complete. FOUND vs INFERRED on load-bearing claims. | report written to `{REPORT_DIR}` |
| A6 | **Return the parent message** | A ~10-line executive summary: verdict, top-3 findings, the teach-the-thinking recommendation, the score, and the absolute paths of the report + artifact. | message sent |

## The dimensions each auditor must cover (in A3/A5)

- **DX** — onboarding, discoverability, help/error quality, time-to-first-success.
- **UX** — is the built artifact a real user's flow? Is the tool's output legible to the target
  audience? (First-class, not folded into DX.)
- **Features** — ranked concrete additions, each tied to the friction that motivated it.
- **Teach-the-thinking** — do the docs teach WHAT/HOW-TO-FRAME, or only syntax? Usually the top find.
- **Drift** (white-box) — claim vs code (file:line) vs "misleads a docs-only user?" vs fix.

## Timing & parallelism

Black-box and white-box are independent — spawn together. Each is a multi-step run (onboard → build
→ probe → report), so expect minutes, not seconds. The parent blocks on both only to verify +
synthesize; if the harness supports it, run them to completion synchronously so P2–P4 can proceed in
the same turn.

## Failure modes to catch in P2/P3

- Artifact missing or doesn't pass the system's checks → the audit's central claim ("a user can
  succeed") is unproven → send the auditor back or down-score.
- Report present but no built artifact (or vice-versa) → INCOMPLETE per the output contract.
- A "bug" that doesn't reproduce → drop it or re-grade as INFERRED.
- Black-box findings that could only come from source → boundary breach → discard, re-run.
