# 03 · Keep bots honest

**What this is for.** A bot is a promise that its pages match the tools. Tools move. This is the routine that keeps the promise, and the lessons the first three bots taught about where it breaks.

**Before you start.** The bot's `GAPS.md` and `bot.json`, its log (`WORKLOG.md` or your team's), and the changelogs/release notes of the tools it documents. A calendar reminder.

## Steps

**1. When a Coming item ships** (a gap row closes): rewrite the SOP step as fact, quote the new real output in "What you'll see", delete the Coming line and the GAPS row, log the tool version. Never leave a shipped feature described as Coming; clients stop believing the rest.

**2. When a tool releases** (`authsetup update --check`, a new library tag, a service's release notes): re-run SOP 07 for the changed surface only; diff the verbatim strings; fix the SOPs; bump `verified_against` in `bot.json` and the README line; log it.

**3. Quarterly, read one bot as a stranger** (SOP 05 step 6) and run the SOP 05 gate. Fix wording before fact; fact before structure.

**4. When a client reports a wrong step**, treat it as a defect, not a question: reproduce against source or help text, fix the SOP, add the message to the troubleshooting table, note it (and thank them) in the log.

**5. Keep `GAPS.md` as the backlog it is.** Every row is a spec item with a user reason and a workaround; service teams should be able to pick one up without asking. When a row has no user reason, delete it.

## Lessons from the first bots (keep these in mind while writing)

- **The default is the danger.** `authsetup` defaults to prod; `enforcement.enabled` absent means allow everything. State the default in every SOP that runs the command, not only in SOP 03.
- **Published tiers decide onboarding, not docs.** Both billing and payment publish read-only self-serve tiers; the day-zero story is false until a human grants writes. Check what a provider actually publishes (`authsetup providers`, its tiers) before promising "one command".
- **READMEs lie; dispatchers do not.** quota-go's README documented `quota.Config`, `Mount`, `CheckBundle` and an env table; none exist. The real surface was `quota.Setup`, `q.Middleware`, `q.Spend`, and `QUOTA_CONFIG_PATH`. Always find the code path.
- **Skills contradict each other and the code.** `org` vs `orgSlug`; `LOCAL:{org_id}` vs `service.audience`; "in-memory only (v0.1.0)" vs Redis in v0.1.9; `AB0T_QUOTA_CONFIG_PATH` vs `QUOTA_CONFIG_PATH`. Resolve against source; record the disagreement in the report.
- **"Only checks" tools may mutate.** `quotactl capabilities|doctor` connect to Redis and may create DynamoDB tables; `authsetup run 06` creates a user. The agent must ask before them.
- **Servers still speak the old vocabulary.** `403` bodies name `billing.cross_tenant`. Quote it in backticks as a server string; never recommend it; file the rename as a gap.
- **Name heuristics bite the client.** `invoicer.admin` and anything with `read_all` are "privileged" by name today, so a fresh service's key mint 403s. The SOP must say who to call and what the fix will be.
- **Reserved fields hide in examples.** A skill's top-up example set `metadata.type`, a payment-reserved key. Cross-check example bodies against the model's reserved list.
- **Idempotency is the whole money story.** `request_id`, `reservation_id`, `settlement_key`, `idempotency_key`, `event.id`: every write has one; "retry with the same key" belongs in every money SOP.
- **One folder holds every environment's secrets.** Never write "delete `~/.authmesh/<svc>/`"; write "move one file aside".
- **Two copies drift.** A bot kept in two folders and edited separately ends up with newer work in the copy that looks older. Keep one master per bot (its repository), reconcile file by file before retiring a copy, and generate any other copy (a CLI's embedded bundle) from the master with a test that fails on drift.
- **Pin the tool version and lint the commands.** A `VERSION` file names the release the pages match; a command lint (Ally's `tests/sop_command_lint.sh`) checks every command and flag against that binary's `--help`, and lets an unbuilt verb through only when `GAPS.md` lists it.
- **Relative links make the installer work.** The routing skill links `../../<file>`; copying one file breaks it; symlinking the folder keeps it. Say so in every README.
- **Agents guess when information is far away.** Put the object and the authority inline (`whois <id>`, the file and field for a key, the SOP number for a hand-off) instead of "see docs".

## What you'll see

A `GAPS.md` that shrinks over time; a work log with one line per re-verification; READMEs whose "checked against" version matches the installed tool.

## If it goes wrong

- A client followed a step that no longer exists: step 4; also check whether the same tool change broke other bots (from the root of your bots checkout: `grep -rn "<old flag>" .`).
- The GAPS list grows but nothing ships: it is a prioritisation problem, not a documentation one; sort by "why users want it" and give the top five to the service team.

## Coming

- **Automatic drift detection**: a job that diffs each bot's quoted strings against the tool's current help/source and opens an issue. *Today:* step 2 by hand.
- **"Verified against" footer per SOP.** *Today:* README line.
- **A shared `LESSONS.md` across bots** that every new bot's author reads first. *Today:* this section.

## Next

Back to `00_index.md`. If you are building the next bot, SOP 02.
