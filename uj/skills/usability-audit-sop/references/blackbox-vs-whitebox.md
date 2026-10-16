# Black-box vs white-box — the two personas

Both role-play the SAME real user (the persona). They differ only in what they may read. That single
difference produces two non-overlapping classes of finding.

## Black-box auditor

- **Reads:** the user-facing docs, the skill(s) meant for users, help output, examples, and the
  tool's own responses. **Never** source, internal design docs, or dev-facing skills.
- **Produces:** the truth about onboarding and DX/UX — where a real user gets confused, what the
  docs fail to teach, whether the happy path actually works with only what's provided.
- **Blind to:** why something breaks; capabilities the docs never mention; whether a doc claim is
  actually true in the code.
- **Integrity rule:** the moment it reads source, its onboarding-truth signal is contaminated —
  because it now knows things a real user wouldn't. Enforce the boundary hard (below).

## White-box auditor

- **Reads:** everything, including source (`internal/`, `cmd/`, the implementation), dev skills, and
  design docs — plus the code of the system-under-test if relevant.
- **Produces:** doc-vs-code drift (docs promising what the code doesn't do, or code hiding
  capabilities the docs never surface), root cause of each friction, and deeper feature ideas.
- **Blind spot to manage:** it knows too much to *feel* onboarding pain. It must consciously ask
  "what would a docs-only user miss/misunderstand here?" — and dedicate a report section to that
  contrast.

## Why you need both

| Finding class | Only black-box catches | Only white-box catches |
|---|---|---|
| Real onboarding confusion | ✅ | (knows too much) |
| Docs teach syntax not thinking | ✅ (feels it) | ✅ (can confirm the model supports it) |
| Doc claim is false / silently no-ops | (trusts the doc) | ✅ (reads the code) |
| Capability exists but undocumented | (can't know) | ✅ |
| A finding both report independently | **high-confidence** — this convergence is the strongest signal | |

Convergent findings (both auditors, independently) are your highest-confidence defects — prioritize
verifying and fixing those first.

## Enforcing the black-box boundary

In the black-box prompt, make the boundary prominent and specific:
- **ALLOWED:** exact paths to user docs / user skills / examples, and the exact tool commands whose
  OUTPUT it may read.
- **FORBIDDEN:** `*.go` / `internal/` / `cmd/` / dev skills / design docs / worklogs — by glob and by
  path. Tell it: *if you catch yourself about to read source, STOP — it invalidates the audit; note
  instead what you WISHED you could see.*
- **Verify in P3** (parent): if a black-box finding could ONLY come from reading source (e.g. cites a
  function name or file:line), that's a boundary breach — discard it and consider re-running.

## Choosing the persona

The persona is who the system's real user is — make it concrete and, where the point is
accessibility, deliberately non-expert:
- A journey/test tool → a **non-technical PMM / product test engineer** writing a real user journey.
- An SDK → a **new integrator** wiring their first call with only the README.
- An ops CLI → an **on-call engineer** at 3am with only `--help`.
The persona sets the bar: "can THIS person succeed with only what's provided?"
