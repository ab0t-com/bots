# 06 · Publish your own bot (for a business on the mesh)

**What this is for.** You run `invoicer` on the mesh. Your customers, and other services' agents, would onboard faster if there were an **Ally for invoicer**: SOPs in plain words, an agent that follows them, one install line. This is how you make one, keep it in your own repository, and get it listed next to ours.

**Before you start.** Your service is live on the mesh (Ally SOPs 03–06) and, if others call it, open to consumers (Ally SOP 12). A public GitHub repository for the bot (the installer downloads without credentials). Claude Code on your side to run Meta, or a person willing to follow SOP 02 by hand.

## Steps

**1. Decide the jobs.** The client journey for *your* product: get access (usually `authsetup connect invoicer --as <them>`, which Ally already documents; hand off, do not re-write), describe (your config or first API calls), first run, wire into their app, customise, their users, change safely, keys, troubleshooting, security. As many SOPs as jobs your clients come back for; a product with only an API still has jobs (SOP 07 step 5).

**2. Build it with Meta** (`@agent-meta "build a bot for invoicer from this repo"`) or by hand with SOP 02. Meta investigates your product (SOP 07: CLI `--help`, OpenAPI, config schema, source for the exact messages, env vars, tests) and writes the folder **at the top level of your repository**, e.g. `invoicer/` in `acme/invoicer-bots`, with `bot.json`, `00_index.md`, SOPs, `agent.md` (your agent's name and persona), `skills/<routing>/SKILL.md`, `install.sh`, `README.md`, `GAPS.md`. Keep the work log out of the published folder (or make it one a client may read).

**3. Keep the contract, change the rest.** The nine lines in SOP 01 (seven headings, verified facts, Coming/Today, secrets never printed, dangerous defaults stated, preview-then-apply, "org" not "realm", hand-offs, a download-and-link installer) are what make a bot trustworthy to a stranger, and the listing requires them. Everything else is yours: the example company, the agent's name and persona, the tone, the sizes, the model.

**4. Point the installer at your repository.** Copy a shipped `install.sh` (Meta's is a good start) and set the four names at the top. They must match the layout, because the installer downloads `https://github.com/<REPO>/archive/refs/heads/<REF>.tar.gz` and extracts only the top-level `<BOT>/` folder:

| in `install.sh` | set it to | must match |
|---|---|---|
| `REPO="${REPO:-acme/invoicer-bots}"` | your GitHub `owner/repo` | a **public** repository |
| `BOT="invoicer"` | the bot folder's name | a folder at the **top level** of the repository (not `bots/invoicer/`) |
| `AGENT="ivy"` | your agent's name | keep it equal to the `name:` in `agent.md` (Claude Code uses that for `@agent-ivy`); the link is `~/.claude/agents/ivy.md` |
| `ROUTING_SKILL="ivy-invoicer"` | your routing skill | the folder `skills/ivy-invoicer/` holding `SKILL.md` with `name: ivy-invoicer` |

`REF` defaults to `main` and must be a **branch** name; tags do not work with this download URL. A client can override `REPO`, `REF`, `AB0T_BOTS_HOME` (default `~/.ab0t/bots`), `CLAUDE_HOME` (default `~/.claude`) and `FORCE=1` on the command line. Run from a checkout (`./install.sh`), the installer uses the folder it is in when that folder has `agent.md` and `skills/<ROUTING_SKILL>/`, and downloads nothing. If the bot must live in a bigger repository, keep its folder at that repository's top level; a private repository needs your own distribution.

**5. Hand off to the mesh bots instead of duplicating them.** Keys and environments → Ally; metering and charging through the mesh → Penny; relationship modelling → Zee; user-journey tests of your service → Quinn. Your routing table lists those rows with their install lines, so a client who installs yours can install theirs.

**6. Verify with SOP 05**, then list it: open a pull request to `github.com/ab0t-com/bots` that adds one row to `BOTS_WANTED.md` (bot, name, for a client who wants to…, your services, status `third-party`) and one entry to `index.md` with your own install line. The review checks the contract (SOP 05 steps 1–5) and safety (no credential reading, no hidden network calls in `install.sh`), not your product claims.

**7. Keep it honest.** When your service ships a Coming item, update the SOP and delete the GAPS row, in your repo; the listing points at your `main`.

## What you'll see

A client types `curl -fsSL https://raw.githubusercontent.com/acme/invoicer-bots/main/invoicer/install.sh | sh` and sees the installer's lines: `→ downloading https://github.com/acme/invoicer-bots/archive/refs/heads/main.tar.gz`, `✓ installed to /home/<you>/.ab0t/bots/invoicer (previous copy kept as invoicer.previous)`, one `✓ agent` line and one `✓ skill` line per skill. Then `@agent-ivy`, and the same experience Ally gives them for the mesh: plain words, previews, exact commands, honest gaps.

## If it goes wrong

- `error: the tarball has no 'invoicer' folder (REPO/REF right?)`: the bot folder is not at the top level, the folder name differs from `BOT`, or `REPO`/`REF` points elsewhere. A `curl: (22) … 404` before it: the repository is private, misspelt, or `REF` is a tag or a missing branch.
- Your SOPs re-document `authsetup`: delete those steps and hand off; they will drift the day a flag changes.
- Your installer does more than download, symlink and print: the listing review will refuse it. Put CLI installs in your SOP 03 with the user's consent, like Ally does.
- Your agent lacks a `GAPS.md`: it is a brochure, not a bot; the review will ask for it.

## Coming

- **A `bots` registry on the mesh directory** (your `run 08` publishing a `bot_install_url` next to `docs_url`), so `authsetup providers` shows "install the assistant" and Ally can offer it when a client connects to you. *Today:* the pull request in step 6.
- **A verification badge** (the SOP 05 gate run on your repository by CI). *Today:* review by hand.
- **A master installer / updater CLI** (`bots install invoicer`, `bots update`) that also reaches bots in other repositories. *Today:* the root `install.sh` installs only bots in `ab0t-com/bots`; your bot's own `install.sh` installs and updates it.
- **Private-repo distribution.** *Today:* public GitHub tarball only.
- **Installs pinned to a tag.** *Today:* a branch name in `REF`.

## Next

SOP 08 so your bot hands off and answers questions well; SOP 03 to keep it honest.
