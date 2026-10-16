# 02 · Build a new bot

**What this is for.** Going from "we need a bot for X" to a folder that passes SOP 05, in one or two working days. Works the same whether you are building a bot for your own product or adding one to this repository.

**Before you start.** A bot name and folder (`audit/`, agent `audie`). Read access to the product's source, CLI, API spec and docs (SOP 07 lists exactly what to look for). The `sop-aligned-agent-system` skill (in `skills/`). Someone who can answer "what is approved but not built?".

## Steps

**1. Open the log first.** A `WORKLOG.md` in the bot folder, or wherever your team already logs work. Sections: what was asked for (in the requester's words), the goal, the binding rules for this bot, the proposed SOP set, and the work log. Every session appends one dated line, *claimed → did → verified*.

**2. Pin the rules for this session**, in one line in the log: no builds, tests, servers or mutating commands; offline `--help` only; never read credential files; write only inside the bot folder, the catalogue and the log; the contract's nine lines (SOP 01).

**3. Investigate the product** (SOP 07 in full). The short version: CLI help for every command → API spec → source for the exact strings (dispatcher, validators, actions, error formatting, stores) → config examples and schema → env vars → tests as a behaviour oracle → docs and skills last, checked against what you found. Produce the **fact sheet**: a table of verbatim strings with where each came from, plus a list of doc-vs-code disagreements. Research subagents, if you use them, are read-only and return `file:line` facts.

**4. Fix the SOP set on paper.** Walk the client's lifecycle, not the API: get access → describe/configure → first run → wire into their app → customise → their users or tenants → their team and privileged grants → use other services → open to others → change safely → keys and offboarding → migrations → troubleshooting → security rules. Keep what the product has, drop what it lacks, add what it uniquely does. Write the list into the log. Six to eighteen SOPs is the range we have seen.

**5. Write the concept page and the day-zero story first.** If you cannot tell your example customer's first day in a dozen paragraphs, you do not understand the product yet; back to step 3.

**6. Write each procedure SOP from the template** (`skills/sop-aligned-agent-system/references/sop-template.md`). Exact commands with the environment written out; "What you'll see" and "If it goes wrong" only from the fact sheet; **Coming** with *Today:*; **Next** pointing somewhere. Hand off to the owning bot (`→ Ally SOP 11`) instead of re-documenting. For a product with no CLI, the steps are the API calls themselves (SOP 07 step 5).

**7. Write the system files**: `bot.json`, `00_index.md`, `agent.md` (persona, where-you-are, coordinates, rules, routing, report), `skills/<routing>/SKILL.md` (routes by `../../<file>`; lists companions), `README.md`. Copy companion skills into `skills/`; strip internal working files; scan for secret-like strings.

**8. Write `install.sh`** from a shipped one (`~/.ab0t/bots/meta/install.sh` or the checkout): change `BOT`, `AGENT`, `ROUTING_SKILL`, `REPO` (your repository, for a bot of your own; SOP 06 step 4 has the layout it expects), the closing hints. `chmod +x`, `sh -n`.

**9. Write `GAPS.md`** by collecting every Coming item across the SOPs, de-duplicated, tagged, with today's path.

**10. Run SOP 05's gate; log the session; add the bot to the catalogue.** A bot of your own, in your repository: by pull request (SOP 06). A bot added to this repository: `BOTS_WANTED.md` row, `index.md` entry, root `install.sh` list.

## What you'll see

A log that reads *claimed → did → verified*. A folder that matches SOP 01 file for file. A `GAPS.md` the product team can read as their backlog. A closing report: files, what could not be verified, top five gaps.

## If it goes wrong

- The SOPs read like the docs, not like the tool: you wrote from docs. Re-derive each command from help, spec or source.
- A step has no "What you'll see": you have not seen the output; find the print/log/response in source or spec and quote it.
- You wrote a verb that does not exist because it should: Coming, with the real path today.
- Two sources disagree and source cannot settle it: write "could not verify" in the SOP and in your report; never silently pick one.
- It is taking much longer than two days: the SOP set is too wide, or the product has no stable surface yet. Ship the first six SOPs and list the rest as Coming.

## Coming

- **`meta new <bot>`** scaffolding folder, log, installer, manifest and catalogue rows. *Today:* copy a shipped bot and replace.
- **The research recipe as reusable prompts** in `references/`. *Today:* SOP 07's checklist, written out each time.

## Next

SOP 07 to investigate; SOP 05 to verify and ship; SOP 04 if you are extending an existing bot instead.
