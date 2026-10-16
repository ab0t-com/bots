<!-- Copy to {REPORT_DIR}/<AUDIT_SLUG>_<agentid>_<YYYYMMDD>.md and fill every section.
     Delete this comment. Grade load-bearing claims FOUND (cite command/file:line) vs INFERRED. -->

# {AUDIT_SLUG} — {black-box|white-box} usability audit of {TARGET}

## Header
- **Persona:** {who the real user is}
- **Agent id:** {role}-{blackbox|whitebox}-{hex}
- **Read access:** {black-box: docs/help only — list allowed | white-box: full incl. source}
- **Date:** {YYYYMMDD}

## Onboarding walkthrough (zero → built artifact)
<!-- The actual steps you took. Quote friction verbatim. Note time-to-ready. -->

## The artifact I built
- **Path:** {ARTIFACT_DIR}/...
- **Passes the system's checks:** {yes — which commands | no — why, and did the docs help}
- **How the tooling helped / hindered:** ...

## Ranked confusion / DX friction (most → least severe)
1. **(SEV)** {exact command or doc line} — why it confused — concrete fix.

## UX findings
<!-- The end-user experience of the artifact you built AND the legibility of the tool's own output
     to the intended audience. Distinct from DX. -->

## Verdicts — can the persona add…
- **(a) a test:** {verdict + evidence}
- **(b) a doc:** {verdict + evidence}
- **(c) the core artifact:** {verdict + evidence}

## Teach-the-thinking gap analysis
<!-- Do the docs teach WHAT to build / HOW to frame it / what "good" means — or only syntax? -->

## Feature suggestions (ranked)
1. {feature} — motivated by {the friction above}.

<!-- WHITE-BOX ONLY -->
## Doc-vs-code drift
| Claim (doc/help) | Reality (file:line) | Misleads a docs-only user? | Fix |
|---|---|---|---|
| ... | ... | yes/no | ... |

## What reading the source changed vs a docs-only view
<!-- White-box only: what a black-box user would miss, misunderstand, or under-use. -->

## Recommendation
<!-- Including, if warranted, a drafted outline for a missing "how to think about {CORE_TASK}" skill. -->

## Score
- **Dimensions:** time-to-success __/10 · discoverability __/10 · teaches-thinking __/10 · legibility __/10 · UX-of-artifact __/10
- **Output-contract gate:** built real artifact that passes checks? {y/n} · wrote this report? {y/n} · sent parent message? {y/n}
- **Final NPS:** __/10
- **Single highest-leverage change:** ...
