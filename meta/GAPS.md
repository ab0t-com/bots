# GAPS — Meta's own Coming items (the tooling a bot-builder should have)

| # | item | SOP | why users want it | today |
|---|---|---|---|---|
| 1 | **`meta check <bot>`**: one command running the gate (headings, Coming/Today pairs, banned words, routing links resolve, manifest valid, installer parses, scratch install) with a pass/fail table | 01, 04, 05, 08 | the gate is a dozen shell lines nobody remembers | the shell lines in SOP 05 |
| 2 | **`meta new <bot>`**: scaffold folder, log, manifest, installer, catalogue rows from a template | 01, 02 | the first hour of every bot is copying and renaming | copy a shipped bot and replace |
| 3 | **`meta facts <repo>`**: a fact-sheet generator (help, spec, config schema, error strings, env vars, versions into one file) | 07 | investigation is most of the work and is repetitive | SOP 07's table by hand or with read-only subagents |
| 4 | **Spec-to-SOP diff** (paths in `/openapi.json` no SOP mentions) | 07 | finds forgotten jobs | grep the SOPs per path |
| 5 | **`meta renumber <bot> <from> <to>`** | 04 | inserting an SOP touches eight files | the greps in SOP 04 |
| 6 | **Research recipe in `references/`** (the read-only subagent prompts per surface) | 02, 07 | consistent, fast research | rewrite them each time |
| 7 | **"Verified against" footer per SOP** (tool version + date) | 03, 04 | drift visible on the page | `bot.json.verified_against` + the log |
| 8 | **Automatic drift detection** (diff quoted strings against current help/source/spec; open an issue) | 03 | tools move; pages rot silently | quarterly read-through |
| 9 | **Release workflow** (changelog, tags, installs pinned to a tag; installers accept a branch only) | 05 | a branch moves under clients; no record of what changed | commit to the branch the installer downloads; changes in the commit message |
| 10 | **A master installer / updater CLI** (`bots install`, `update`, `list`, `ask`), including bots that live in other repositories | 06, 08 | one line per bot today; no update notice; the root `install.sh` only reaches bots in this repository | root `install.sh` (installs several from this repository), each bot's `install.sh` (updates itself), a third-party bot's own install line |
| 11 | **Bot registry on the mesh directory** (`run 08` publishes `bot_install_url`; `authsetup providers` shows it; Ally offers it on `connect`) | 06, 08 | a client finds a provider's assistant where they find the provider | pull request to the catalogue |
| 12 | **Verification badge** (the gate run by CI on third-party bot repos) | 06 | trust without a human review | review by hand |
| 13 | **Private-repo distribution** for third-party bots | 06 | not every business publishes to public GitHub | public tarball only |
| 14 | **The `Agent` tool on Ally, Penny, Zee and Quinn** so bots can ask each other read-only questions | 08 | Penny wants Ally's `status`; Ally wants Penny's tier advice | only Meta has it; hand-offs by telling the user |
| 15 | **`bots ask <bot> "<question>"`** with the read-only constraint built in | 08 | shell-level questions between bots | the subagent prompt in SOP 08 |
| 16 | **A shared, user-visible session note** any bot appends to (service, env, what changed) | 08 | continuity across bots in one session | each bot's closing report |
| 17 | **Manifest validation in the gate** (`sops` exist, `hands_off_to.bot` in catalogue) | 08 | manifests drift | two greps by hand |
| 18 | **Shared `LESSONS.md`** across bots, read by every new bot's author | 03 | the lessons live in one SOP | SOP 03's list |
| 19 | **SOPs and GAPS.md for Zee** (the `authz` bot predates the method) | catalogue | Zee's knowledge is in skills, not client SOPs | its six skills |
