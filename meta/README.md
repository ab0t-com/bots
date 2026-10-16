# meta/ — Meta, the bot that builds and keeps the bots

Every assistant in this repository has the same shape: numbered SOPs a person can follow alone, a
named agent that follows them, a routing skill, a manifest, an installer, and an honest list of what is
not built yet. Meta is the bot that makes those: for a business on the mesh that wants a bot for its
own product so its customers get the same experience, and for anyone adding the next bot to this
repository.

- `00_index.md` — start here.
- `01`–`08` — the contract and its defaults; building a bot; keeping bots honest (with the lessons the
  first bots taught); changing an SOP; the gate; publishing your own; investigating a product (CLI, API
  spec, config, errors, env vars, tests, SDKs); bots working together (hand off, ask, share, `bot.json`).
- `agent.md` — **Meta**. It works out where it is (installed under `~/.ab0t/bots/meta`, or a checkout),
  finds its siblings through their `bot.json`, and can fan out read-only research subagents.
- `bot.json` — Meta's own manifest.
- `skills/meta-bot-builder/` — routing; `skills/sop-aligned-agent-system/`, `make-agent/`,
  `skill-creator/`, `sop-creator/` — the method skills, copied so the folder stands alone.
- `install.sh` — installs Meta into Claude Code.
- `GAPS.md` — Meta's own Coming list (the tooling a bot-builder should have and does not yet).

## Install Meta

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/meta/install.sh | sh
```
Downloads this folder to `~/.ab0t/bots/meta`, symlinks `~/.claude/agents/meta.md` and the skills,
leaves any skill folder you already have alone (`FORCE=1` replaces it with the link and moves your
folder aside to `~/.ab0t/bots/.skill-backups/`), prints what to do next. Talks to no service; reads no
credentials. From a checkout, `./install.sh` uses the folder you are in. The skills are symlinked, not
copied, because the routing skill links to the SOPs with relative `../../` paths; copying one file
breaks them. To install several bots at once:
`curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/install.sh | sh -s -- all`.

Then, in a new Claude Code session: `@agent-meta build a bot for <product>`, `@agent-meta investigate
this repo for SOPs`, "add an SOP to Penny", "check the authz bot", "publish my bot".

## What Meta will and will not do

- Reads help, spec and source before docs; quotes outputs verbatim; marks everything unbuilt **Coming**
  with today's path; writes "could not verify" rather than guessing.
- Enforces the nine-line contract and offers (never imposes) our defaults: your example customer, your
  tone, your sizes, your model.
- Shows every file before writing it; writes only in the bot folder, the catalogue and the log.
- Runs no servers, builds, tests or mutating commands; never reads a credentials file; research
  subagents are read-only.
- Does not release: it prepares the folder and the checks; committing and pushing to your repository
  is yours.

## For a business publishing its own bot

SOP 06. Keep the contract (headings, verified facts, Coming/Today, no secrets, "org", preview-then-apply,
an installer that only downloads and links), brand the rest, put the bot folder at the top level of a
public GitHub repository and point `install.sh` at it, hand off to Ally/Penny/Zee/Quinn instead of
re-documenting them, then open a pull request here that adds one row to `BOTS_WANTED.md` and one
entry to `index.md` with your install line.
