# SOP template (`<nn>_sop_system_<name>.md`)

Copy, fill, delete the notes. Keep the seven headings and their order; readers learn the shape
once and then skim.

```markdown
# <nn> · <Job, in the user's words>

**What this is for.** One or two sentences: the outcome, named in product terms. Mention the
running example (Acme / `invoicer`) if it sharpens it.

**Before you start.** Prerequisite SOPs by number; files/values to have at hand (say where they
come from, never their contents); the environment decision ("build on `dev` first").

## Steps

**1. <Imperative verb phrase>.**
```sh
tool --env dev --config-dir ./config <command>      # the exact, copy-pasteable form
```
One short paragraph of what it does. Bullets for the knobs that matter. Never more than one
action per step. Preview before apply where the tool mutates.

**2. …**

## What you'll see
The literal lines the tool prints on success (`✓ …`, `NEXT —`, summary tables), quoted. The
file(s) it wrote, by name and field, never by value. Exit codes if they matter. Timing notes
(caches, propagation).

## If it goes wrong
- `<verbatim error string>` — what it means — what to do. One line each; link the SOP that owns
  the fix if it is elsewhere. Order by likelihood.

## Coming
- **<Verb or capability>** — one line on why. *Today:* the workaround, or "none". Mark items
  from an approved design as such (e.g. "(scope model)").

## Next
SOP <nn>, <name>. Optionally a second branch ("or SOP <nn> if …").
```

## Notes per section

- **Title**: a job, not a feature ("Keys: rotate, offboard, disconnect", not "API key management").
- **Before you start**: if a value lives in a credentials file, give the `jq -r .field <file>`
  line the *user* runs; you never run it.
- **Steps**: environment flag on every command. Write `--dry-run` first for anything that
  mutates. Tables for file→object maps. Code blocks for config fragments, with the running
  example's real-looking values and `<placeholders>` for anything secret.
- **What you'll see**: only strings you found in source/help. If you paraphrase, drop the
  backticks.
- **If it goes wrong**: the message in backticks is the lookup key; the agent greps for it.
- **Coming**: the SOP describes the ideal; this section is the honesty ledger. Every entry
  becomes a GAPS.md row.
- **Length**: 80–180 lines. Longer means two jobs; split.
- **Voice**: short sentences, second person, no hedging, no internal references, no emoji.
