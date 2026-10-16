# Report contract & scoring rubric

Each auditor produces TWO outputs (both required) and scores itself against the rubric.

## The dual-output contract (both mandatory)

| Output | Form | Purpose |
|---|---|---|
| **Report artifact** | a Markdown file, bashdated, agent id in the filename: `<AUDIT>_<agentid>_<YYYYMMDD>.md` | the durable, complete audit record |
| **Parent message** | ~10-line executive summary returned to the orchestrator | the routing signal + pointers |

Neither substitutes for the other. The report is what a human/agent reads later; the message is how
the parent decides what to do next. **An auditor that returns only a chat summary and writes no file
has FAILED the contract** — and vice-versa.

**Plus a THIRD artifact the PARENT produces after both auditors return:** the light-vs-dark delta
(`LIGHT_VS_DARK_DELTA_<date>.md`) — the second core takeaway, classifying every finding into
CONVERGENT / DARK-ONLY / LIGHT-ONLY. See [light-vs-dark-delta.md](light-vs-dark-delta.md). It is not
optional; it is the analysis that turns two reports into a documentation-vs-product verdict.

## Required report sections

1. **Header** — persona, agent id, read-access (black/white-box + what was allowed/forbidden), bashdate.
2. **Onboarding walkthrough** — zero → built-artifact, the actual steps taken, friction quoted verbatim, time-to-ready.
3. **The artifact you built** — path to it, a note on how the tooling helped/hindered, and confirmation it passes the system's own checks.
4. **Ranked confusion / DX friction** — severity-ordered; each = the exact command/doc line + why it confused + a concrete fix.
5. **UX findings** — the end-user experience of the built artifact and of the tool's output (distinct from DX).
6. **Verdicts** — can the persona add (a) a test, (b) a doc, (c) the core artifact? One verdict each, with evidence.
7. **Teach-the-thinking gap analysis** — do the docs teach WHAT/HOW-TO-FRAME or only syntax?
8. **Feature suggestions** — ranked; each tied to the friction that motivated it.
9. **(White-box) Doc-vs-code drift table** — claim · reality (file:line) · misleads a docs-only user? · fix.
10. **(White-box) What reading the source changed** — explicit contrast vs a docs-only view.
11. **Recommendation** — including, if warranted, a drafted outline for a missing "how to think" skill.
12. **Score** — the rubric below, with the single highest-leverage change.

Grade load-bearing claims **FOUND** (you saw it — cite the command/file) vs **INFERRED**.

## Scoring rubric (0–10 NPS-style, with hard gates)

Start from the dimension scores, THEN apply the output-contract gate.

| Dimension | Weight | 0 | 5 | 10 |
|---|---|---|---|---|
| Time-to-first-success | ×2 | never succeeded | succeeded after re-reading | succeeded smoothly first try |
| Discoverability / help | ×1 | had to guess | found it eventually | self-evident, examples present |
| Docs teach thinking | ×2 | syntax only | some discipline taught | teaches what/how-to-frame |
| Error/verdict legibility | ×1 | misleading | ok | clear + honest |
| UX of built artifact | ×1 | toy / unrealistic | plausible | a real user's flow |

**Output-contract gate (double-scored — apply AFTER the dimension score):**
- Built a REAL artifact that passes the system's checks? — if **no**, cap the final score at **3**
  (the audit did not prove a user can succeed).
- Wrote the report file? — if **no**, the audit is **INCOMPLETE** (score void).
- Returned the parent message? — if **no**, the audit is **INCOMPLETE** (score void).

Report the final NPS and the ONE change that would raise it most.

## Naming conventions

- Report: `<AUDIT_SLUG>_<agentid>_<YYYYMMDD>.md` in `{REPORT_DIR}`.
- Built artifact: a name carrying the agent id, in `{ARTIFACT_DIR}` (so parallel auditors never
  collide and provenance is obvious).
- Agent id: `<role>-<4 hex>` (e.g. `pmm-blackbox-7f7a`), generated once at A0.
