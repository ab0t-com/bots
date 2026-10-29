# authmesh/ — Ally, the ab0t auth mesh client assistant

This folder is a complete, client-facing system for using the ab0t auth mesh through `authsetup`:

- `00_index.md` — start here; the journey and one line per SOP.
- `01_…` to `17_sop_system_*.md` — plain-language SOPs, one per job.
- `agent.md` — **Ally**, a Claude Code agent that follows the SOPs for the user.
- `skills/ally-mesh-client/SKILL.md` — the skill Ally loads; it routes to the SOPs.
  The other folders under `skills/` are the companion skills Ally may load by name (copied here so
  the bot stands alone; `authsetup-cli` is the one the binary itself bundles).
- `VERSION` — the `authsetup` version these pages were checked against (`authsetup_version: 0.5.29`).
- `bot.json` — the manifest (jobs, SOPs, hand-offs, dangerous defaults, `verified_against`).
- `install.sh` — installs Ally into Claude Code (downloads this folder, symlinks agent + skills).
- `GAPS.md` — every **Coming** item across the SOPs; the `authsetup` spec list.
- `tests/` — `sop_command_lint.sh`, the check that every `authsetup` command and flag shown here exists in a given binary (`tests/README.md`).

## Install Ally

Already have `authsetup` 0.5.25 or later? It carries the matching Ally — no download:
```sh
authsetup bot install              # offline; the Ally that matches your authsetup version
authsetup bot status               # later: same version? anything changed?
```
(`--project` installs into the current repository's `./.claude/` instead; `--dry-run` shows what it would do;
`authsetup bot uninstall` removes only what it installed.) It lays Ally out exactly like the installer below.

Without `authsetup`:
```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/authmesh/install.sh | sh
```
It downloads this folder to `~/.ab0t/bots/authmesh`, symlinks `~/.claude/agents/ally.md` and
`~/.claude/skills/<each skill>`, leaves any skill you already have alone (`FORCE=1` to replace it; your folder is moved to
`~/.ab0t/bots/.skill-backups/`, never deleted), and
prints what to do next. It talks to no ab0t service and reads no credentials. From a checkout,
`./install.sh` uses the folder you are in. Re-running is safe (the previous copy is kept as
`~/.ab0t/bots/authmesh.previous`).

Then start a new Claude Code session and say `@agent-ally`, or "set up auth for my service",
"connect to billing", "my users get 403". Ally installs `authsetup` with you (SOP 03):
```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/clientsetup/main/install.sh | sh
authsetup version                  # should match VERSION here (0.5.29); older → authsetup update
authsetup skills install           # the bundled client skills (authsetup-cli and the rest), which Ally also uses
```
By hand instead: symlink `agent.md` to `~/.claude/agents/ally.md` (or `.claude/agents/ally.md` in one
project) and `skills/ally-mesh-client` to `~/.claude/skills/ally-mesh-client`. The skill links to the
SOPs by relative path (`../../<file>`), so symlink the whole folder rather than copying one file; if you
copy, copy the whole `authmesh/` folder somewhere stable and symlink from there.

## Matching versions

Ally's pages quote `authsetup`'s own messages, which change between releases. `VERSION` says which
release they match. Ally runs `authsetup version` at the start of a session: an older binary is
updated first (SOP 15), a newer one means these pages may lag (Ally then trusts `authsetup <cmd> --help`;
`authsetup bot install` — or re-running the installer — refreshes Ally).

## What Ally will and will not do

- Explains in plain words first; previews every change (`--dry-run`) and waits for your yes.
- Confirms the environment on every command, including NEXT lines it passes on; `authsetup` defaults
  to **prod** (only `up` asks instead).
- Never prints a secret; never deletes `~/.authmesh/<service>/`; never tests against prod; never
  routes around the tool's refusal to send credentials to another origin.
- Uses `authsetup`; falls back to a direct API call only where an SOP's *Today:* says so.
- Says "org", never "realm"; the cross-customer concept is `scope: "platform"`.

## Keeping it honest

Every command, flag and message in the SOPs was checked against `authsetup` 0.5.25 (its `--help`, its
source and its migration kits `migrations/v0.5.23-to-v0.5.24/` and `v0.5.24-to-v0.5.25/` in
`github.com/ab0t-com/clientsetup`). From 0.5.25 the binary embeds this folder (`authsetup bot install`), so each
release carries the Ally that matches it.
`tests/sop_command_lint.sh <path-to-authsetup>` re-checks every command and flag mechanically; run it
after each `authsetup` release. Where the tool does not do something yet, the SOP says **Coming** and
gives today's workaround; `GAPS.md` collects them. When a gap ships, update the SOP, remove the row, and
bump `VERSION` and `bot.json`'s `verified_against`.
