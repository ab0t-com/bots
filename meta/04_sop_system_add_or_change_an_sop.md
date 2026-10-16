# 04 · Add or change an SOP in a shipped bot

**What this is for.** A service grew a feature, a gap shipped, a client asked a question no SOP answers, or a step turned out wrong. Changing one page without breaking the bot's voice, routing or honesty.

**Before you start.** The bot's `00_index.md`, `agent.md` routing table, `skills/<routing>/SKILL.md` table and `GAPS.md` open. The source or help text that justifies the change. The bot's work log.

## Steps

**1. Decide: new SOP or new step?** A new *job* a client comes back for (e.g. "export my ledger") is a new SOP; a new way to do an existing job is a step in the existing one. Never let an SOP grow past ~180 lines; split by job.

**2. For a new SOP: pick the number by lifecycle position**, not by arrival. If it belongs between 11 and 12, renumber the rest (filenames, `00_index.md`, both routing tables, every `Next`, every cross-reference, `GAPS.md` SOP column). `grep -rn "SOP 1[2-8]\|1[2-8]_sop_system" <bot>/` finds them all. Renumbering is cheap today and impossible once clients have bookmarked links; if a bot is already published, prefer appending.

**3. Write or change the page from the template**, same seven headings, same example company, same tone as its neighbours. Quote outputs from source. If the change *removes* a Coming item because it shipped: rewrite the step as fact, delete the Coming line, delete the GAPS row, and add the verbatim new output to "What you'll see".

**4. Re-route.** Add or adjust the row in `agent.md`'s routing table and the routing skill's table; add the index line in `00_index.md`; fix the previous SOP's **Next**. The agent description's trigger phrases get the new job's words if a client would type them.

**5. Update `GAPS.md`** for any new Coming item (dedupe against existing rows; same tags).

**6. Run SOP 05's gate on the whole bot**, not just the page: headings, Coming/Today pairs, banned words, routing links resolve, manifest `sops` match the files, installer parses.

**7. Log it** (`WORKLOG.md` or your team's log): which SOP, why, the source line that justified it, what was verified. Update `bot.json` (`sops`, `answers`, `verified_against`).

## What you'll see

`grep -c "## Coming" <bot>/*_sop_system_*.md` equal to the SOP count; `grep -rn "<old name>"` empty after a rename; the index, both routing tables and the Next chain agreeing on the same list.

## If it goes wrong

- A client-facing SOP references an internal path, issue number or team name: remove it; the "why" lives in your log and the GAPS row.
- The routing tables disagree: the agent sends people to a page that does not exist. SOP 05 catches it; fix both tables from `00_index.md`, which is the master list.
- The change contradicts another SOP (two different commands for one job): one of them is stale; verify against source and make the other hand off.

## Coming

- **`meta renumber <bot> <from> <to>`** and **`meta check <bot>`**. *Today:* the greps above.
- **Per-SOP "verified against" footers** (tool version + date) so drift is visible. *Today:* the README's single statement and the work log.

## Next

SOP 05, verify and ship.
