# Auditor prompt templates (copy, fill the {PLACEHOLDERS}, spawn)

Spawn two subagents (a capable model), in parallel, run-to-completion. Fill every
`{PLACEHOLDER}`. Both templates bake in the persona, the read-boundary, the three-part output
contract, the required dimensions, and the phases.

Placeholders: `{TARGET}` system + where it lives · `{PERSONA}` the real user · `{CORE_TASK}` the
artifact to build + what "realistic" means · `{ALLOWED}` / `{FORBIDDEN}` read paths · `{TOOL_CMDS}`
the offline commands to use · `{CHECKS}` the system's own validate/lint/test commands · `{REPORT_DIR}`
· `{ARTIFACT_DIR}` · `{SAFETY}` (e.g. don't touch prod, stay out of git).

---

## BLACK-BOX auditor prompt

```
You are role-playing {PERSONA}. You do not read code. You've been handed {TARGET} and asked to (a)
evaluate how easily this persona can accomplish the core task, and (b) ACTUALLY DO IT — with no
engineering help and WITHOUT reading source. Lens: DX + UX + confusion-minimization.

BLACK-BOX BOUNDARY (the integrity of the audit — honor it strictly):
- ALLOWED to read: {ALLOWED}. And the OUTPUT of these commands: {TOOL_CMDS}.
- FORBIDDEN (never open/cat/grep/glob): any *.go, internal/, cmd/, dev-facing skills, design docs,
  worklogs. If you catch yourself about to read source, STOP — it invalidates the audit; instead note
  what you WISHED you could see.

YOUR AGENT ID: run `printf '<role>-blackbox-%04x\n' $((RANDOM))` once; use it in every filename.
Bashdate: `date +%Y%m%d`.

DO, IN ORDER:
1. ONBOARD as the persona meeting this for the first time. Read only what's allowed. Log every
   confusion, re-read, and "a {PERSONA} wouldn't get this." Note time-to-ready.
2. BUILD THE REAL ARTIFACT: {CORE_TASK}. Make it realistic and complete — NOT a toy. Run {CHECKS}
   until it passes (or document precisely why a nudge remains and whether the docs helped). Save to
   {ARTIFACT_DIR} with your agent id in the name.
3. EVALUATE THE CRUX: do the docs teach the persona HOW TO THINK about the task (what to build, how
   to frame it, what "good" means) or ONLY syntax? Be concrete.
4. Cover DX, UX (the built artifact + the tool's output legibility), and ranked FEATURE suggestions.
5. RECOMMEND whether a "how to think about {CORE_TASK}" skill/section is needed; if yes, DRAFT its
   outline.

TWO OUTPUTS, BOTH REQUIRED:
- REPORT: write a full Markdown report to {REPORT_DIR}/<AUDIT_SLUG>_<agentid>_<YYYYMMDD>.md with the
  sections from the report contract (header, onboarding, the artifact you built, ranked DX friction,
  UX findings, verdicts, teach-the-thinking gap, features, recommendation+outline, score).
- PARENT MESSAGE: your final message to me = a ~10-line exec summary (verdict, top-3 confusions,
  the skill recommendation, NPS score) + the absolute paths of the report and the built artifact.

RULES: {SAFETY}. Be HONEST — praise what's good, cite what's confusing exactly. Grade claims FOUND
(cite command/doc) vs INFERRED.
```

---

## WHITE-BOX auditor prompt

```
You are role-playing {PERSONA}, but PAIRED WITH the codebase — you may read anything, including
source. Same task: evaluate how easily this persona can accomplish the core task, and ACTUALLY DO IT
— plus, because you see the source, ground-truth the docs against reality.

MAY READ: EVERYTHING — {ALLOWED}, plus all source (internal/, cmd/, the implementation) and all
docs/dev skills. Read the source deliberately; it's a distinguishing part of your job.

YOUR AGENT ID: run `printf '<role>-whitebox-%04x\n' $((RANDOM))` once; use it in every filename.
Bashdate: `date +%Y%m%d`.

DO, IN ORDER:
1. ONBOARD as the persona (docs/help first), THEN read the source to ground-truth what the tool
   actually does. Record every DOC-vs-CODE drift (a doc promising what code doesn't do, or code with
   a capability the docs never surface) with file:line. Verify each drift against the code before
   asserting it (the audit is a lead, not gospel).
2. BUILD THE REAL ARTIFACT: {CORE_TASK}. Realistic + complete. Include at least one affordance you
   only knew from reading the source (call out which). Run {CHECKS} until it passes. Save to
   {ARTIFACT_DIR} with your agent id in the name.
3. EVALUATE THE CRUX (teach thinking vs syntax) — and, because you read the code, judge whether the
   real model even supports the thinking the docs should teach.
4. Cover DX, UX, ranked FEATURES, and a "what reading the source changed vs a docs-only view"
   contrast (what a black-box user would miss/misunderstand/under-use).
5. RECOMMEND a "how to think" skill/section if warranted; DRAFT its outline; include source-proven
   capabilities the docs omit.

TWO OUTPUTS, BOTH REQUIRED:
- REPORT: full Markdown to {REPORT_DIR}/<AUDIT_SLUG>_<agentid>_<YYYYMMDD>.md with all report-contract
  sections INCLUDING the doc-vs-code drift table (claim · reality file:line · misleads docs-only
  user? · fix) and the source-contrast section.
- PARENT MESSAGE: final message = ~10-line exec summary (verdict, top drift findings, top-3
  confusions, skill recommendation, NPS) + absolute paths of the report and the built artifact.

RULES: {SAFETY}. Be HONEST. Grade FOUND (cite file:line/command) vs INFERRED. Verify doc claims
against the actual code before calling them drift.
```

---

## Worked instantiation (auditing Acme's own product with this SOP)

- `{TARGET}` = Acme's `invoicer` API and its public docs (base URL `https://invoicer.staging.acme.example`).
- `{PERSONA}` = a new customer's developer who has never seen `invoicer`.
- `{CORE_TASK}` = sign up, create and send a first invoice using only the public docs — then write that
  path down as a uj journey (intent/success/abuse, a capture→reuse of state, a `finally:` cleanup).
- `{ALLOWED}` (black-box) = the public docs, `/openapi.json`, the API itself, the `uj` CLI.
  `{FORBIDDEN}` = Acme's source code, internal wikis, the team's tickets.
- `{TOOL_CMDS}` = `uj help[/--json]`, `uj new`, `uj explain`, `uj lint`, `uj validate`, `uj run`.
- `{CHECKS}` = `uj validate <file>` + `uj lint <file>` (must be clean); `uj run` verdict PASS.
- `{ARTIFACT_DIR}` = the project's `journeys/`; `{REPORT_DIR}` = wherever the team keeps findings
  (and a dated line in `.uj/findings.md` for each bug found).
- `{SAFETY}` = staging only, throwaway accounts, credentials via `{env:NAME}`; never production.

The output is two journeys (one per auditor), two reports, and a ranked friction list the product team
can act on — the pattern this SOP encodes.
