# uj/ — Quinn, the uj test assistant

A complete, client-facing system for testing any HTTP service the way real users use it, with the
**uj** tool, built the same way as the other bots here with the `sop-aligned-agent-system` method:

- `00_index.md` — start here; the journey and one line per SOP.
- `01_…` to `19_sop_system_*.md` — plain-language SOPs, one per job: setting up, deciding what to
  test, writing realistic and edge-case journeys, end-to-end across services, running and reading
  verdicts, CI, managing many suites, keeping tests current, API drift, performance, everything else
  uj can do, troubleshooting, rules.
- `agent.md` — **Quinn**, a Claude Code agent that follows the SOPs for the user.
- `skills/quinn-uj/SKILL.md` — the skill Quinn loads; it routes to the SOPs.
- `skills/uj-cli`, `skills/uj-authoring`, `skills/uj-journey-design`, `skills/usability-audit-sop` —
  uj's own skills (driving the binary, the file format, what to test, auditing a product as a
  stranger), loaded by name when an SOP points there.
- `GAPS.md` — every **Coming** item across the SOPs.

## Install Quinn

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/uj/install.sh | sh
```
It downloads this folder to `~/.ab0t/bots/uj`, symlinks `~/.claude/agents/quinn.md` and
`~/.claude/skills/<each skill>` (the routing skill `quinn-uj` plus the uj skills under `skills/`),
leaves any skill folder you already have alone (`FORCE=1` replaces it after moving yours to
`~/.ab0t/bots/.skill-backups/`), and prints what to do next.
It talks to no service, reads no credentials, and does not install the uj tool itself. From a
checkout, `./install.sh` uses the folder you are in. Re-running is safe. The routing skill links the
SOPs by relative path (`../../<file>`), so keep the folder whole and symlinked, not copied piecemeal.

Then install uj if you have not (Quinn's SOP 03 walks you through it):
```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh | sh
uj --version
```
The `uj` tool's public repository (`github.com/ab0t-com/uj`) is coming soon; until it is live, that
install line will not work yet.
Start a new Claude Code session and say `@agent-quinn`, or "write a user journey for my sign-up
flow", "what should I test first", "my test is VOID", "run my journeys in CI".

## What Quinn will and will not do

- Explains in plain words first; shows every journey or change before writing it, and asks before
  anything runs against your service (`uj run`, `uj doctor`).
- Names the target URL before every run; never tests production; keeps secrets in `{env:NAME}` and
  never prints one.
- Never weakens a failing test to make it pass, never deletes a red journey to get green, and treats
  VOID as an environment problem, not a bug.
- Writes realistic sessions (a person doing several normal things, with the risky part checked along
  the way), with an outcome, persona and success line a manager can read.
- Hands sign-in and keys for a service on the ab0t mesh to Ally, tiers and billing to Penny,
  in-app permission models to Zee.

## Keeping it honest

Every command, flag and message in the SOPs was checked against uj 0.1.1's help output and source,
and the outputs were captured from the real binary run offline; nothing was run against a live
service while writing. Where uj does not do something yet, the SOP says **Coming** and gives today's
workaround; `GAPS.md` collects them. When a gap ships, update the SOP and remove the row.
