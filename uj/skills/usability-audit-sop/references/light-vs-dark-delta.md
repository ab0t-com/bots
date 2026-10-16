# The light-vs-dark delta — the usability measurement

The two auditors differ in ONE variable: source access. Dark (black-box) sees only docs; light
(white-box) sees everything. So the DIFFERENCE between their findings isolates exactly what the
documentation does and doesn't convey. Producing this delta is the orchestrator's job, and it is the
second core takeaway of every audit (the first is the report content itself).

Read it as an experiment with one controlled variable: hold the persona and task fixed, vary only
"can read source." Every gap that appears is attributable to that variable — i.e. to the docs.

## The three buckets

Classify every finding (from both reports) into exactly one:

| Bucket | Definition | What it measures | Priority |
|---|---|---|---|
| **CONVERGENT** | dark AND light found it independently | a REAL tool defect observable from the surface | fix first — two independent confirmations |
| **DARK-ONLY confusion** | dark stumbled / had to guess / was misled; light did NOT (it just checked the code) | **documentation quality** — the info exists, the docs fail to convey it | doc fix; this bucket's size = how well docs teach |
| **LIGHT-ONLY finding** | dark structurally could not find it (needs source): drift, hidden capability, or a silent trap | **how much the docs mislead or omit** | rank by "would a dark user hit this SILENTLY?" |

## The most important cell: silent traps

The scariest finding is a **LIGHT-ONLY** item that a **DARK user would trip over silently** — the
docs actively lead them into a broken state with no error and no path to the cause. The dark auditor
doesn't report these as "confusion" (it can't — it doesn't know it's wrong); light catches them by
reading the code. Surface these to the top: they are the highest-value docs/UX fixes because the
victim never even knows to file a bug.

Distinguish two dark failure modes — they are NOT the same severity:
- **Dark got confused** (felt friction, re-read, asked "what does this mean?") → recoverable; a
  motivated user pushes through. A documentation clarity gap.
- **Dark got silently wrong** (followed the docs confidently, produced a broken result, moved on) →
  unrecoverable without source. A documentation *correctness* defect. Far worse.

## Producing the delta artifact

1. List every finding from both reports; dedupe by the underlying issue (not the wording).
2. Assign each a bucket (above). For DARK-ONLY, note what dark did to work around it. For LIGHT-ONLY,
   note whether a dark user would hit it loudly (error) or silently (no signal).
3. Write the delta table: `issue · dark saw? · light saw? · bucket · silent for dark? · fix`.
4. Add the three scores it yields:
   - **Convergent count** — real surface defects (independent-confirmation strength).
   - **Dark-only count** — documentation clarity gaps.
   - **Light-only-silent count** — documentation correctness defects (the docs mislead). **This is
     the number that should most alarm you** — every one is a user who fails and can't tell why.
5. One-paragraph verdict: *where did dark get confused compared to light, and what does that say
   about the docs?*

## Why this beats a single score

An NPS of 6/10 tells you the tool is "ok." The delta tells you *why*: "dark scored low ONLY because
of doc drift light proved false — the tool is good, the docs mislead." Or the opposite: "dark and
light both struggled → it's the tool, not the docs." The delta separates a documentation problem
from a product problem — which is the decision the score can't make for you.
