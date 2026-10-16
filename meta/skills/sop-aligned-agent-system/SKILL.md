---
name: sop-aligned-agent-system
description: >-
  Build a client-facing "SOP-aligned agent system" for a product or mesh service: a folder of
  plain-language numbered SOPs (`<nn>_sop_system_<name>.md`) grounded in the real CLI/source,
  plus a Claude Code agent and a routing skill that drive those SOPs for the client, a one-page
  index, an installer, a README, and a GAPS.md spec list of everything marked Coming. Use when
  asked to "make an agent system like Ally", "write client SOPs + an agent for <service>",
  "turn these skills into SOPs an agent can follow", "SOP-driven agent", or to extend an
  existing SOP system with new SOPs. Covers the research order (approved plan → voice docs →
  CLI help → source structs/validators/steps/error strings → skills), the SOP template and
  voice rules, the Coming/Today contract, the agent + skill templates, and the verification
  checklist. The shipped bots in this repository are the worked examples.
---

# SOP-aligned agent system

One folder, three layers: **SOPs** a human can follow, a **skill** that routes an agent to the
right SOP, and an **agent** whose prompt enforces the safety rules while it runs the SOPs.
The reference implementation is the `authmesh/` bot in `github.com/ab0t-com/bots` (Ally, for
`authsetup`), including its `VERSION` file and `tests/sop_command_lint.sh`. `billing-quota/` (Penny,
a library plus two services) and `uj/` (Quinn, a test CLI) show the same shape for other kinds of
product. Copy the shape; do not copy the content.

Why this shape works: the SOP is the single source of truth for *procedure*; the agent adds
*judgement* (preview, confirm, never print secrets); the skill is only *routing*. When the tool
changes, you edit one SOP, not three prompts. When the tool lacks a verb, the SOP says
**Coming** + *Today:*, and `GAPS.md` becomes the product spec for free.

## Procedure

### 0. Pin the job and the rules (before reading anything)
- One sentence: which client, which tool(s), which lifecycle (onboard → wire → day-2 → leave).
- Hard rules for yourself: **no server calls, no builds, no tests**; offline `--help` only.
  Never read or print credential files; placeholders in every example. Write only inside the
  target folder (+ one line in the work log). Do not edit any doc the user has fixed as the
  reference for voice. Vocabulary bans (today: say **org** never "realm"; never introduce `cross_tenant` /
  `cross_org`; the cross-customer concept is `scope: "platform"`). Default-environment danger
  (authsetup defaults to **prod**) must be stated in every SOP that runs a command.
- Approved-but-unbuilt designs are always written as the ideal flow and marked **Coming**.

### 1. Read in this order (research is most of the work)
1. The **approved plan or brief**, if there is one — the SOP list and what is Coming are often
   decided there. Ask the user for it once.
2. **Voice reference docs** (e.g. a shipped bot's `01_*.md`, `02_*.md`) — match their register.
3. **CLI help**: `tool --help` and `tool <cmd> --help` for every command. Help text is the
   client's contract; quote it.
4. **Source, in this order**: `main.go`/dispatcher (commands, flags, guards, exit codes) →
   config structs + `Validate()` (the *exact* error strings) → steps/actions (what each creates,
   what it writes where, what it refuses) → the API client's error formatting (`HTTP %d: %s`) →
   creds/store (file names per env, archive, lock) → example configs and JSON schema.
   Collect every user-visible string verbatim into a scratch list; the troubleshooting SOP is
   built from it.
5. **Skills** that touch the surface. Expect overlap and contradictions; resolve against source
   and note unresolved ones in your report ("could not verify").
6. **Adjacent tools** the SOPs must hand off to (SDKs, widgets, migration kits): read their
   README/quick start only as deep as the SOP needs.
Check the installed binary version vs source; write for source, note the lag.

### 2. Fix the SOP set (lifecycle order, one job per SOP)
Default spine (rename to the product): install/sign-in/environments → describe (config) →
check + first run (what each step creates, where secrets land) → wire into the app (backend +
frontend, each supported SDK) → customise (branding/UI) → end users → own team + privileged
grants → consume other services → open your service to others → change safely → keys
(rotate/offboard/disconnect) → migrations/upgrades → troubleshooting + recovery → security
rules. Plus `00_index.md`. Keep 01/02-style concept docs separate from procedure SOPs.

### 3. Write each SOP with the template (`references/sop-template.md`)
Sections, always in this order: **What this is for · Before you start · Steps · What you'll
see · If it goes wrong · Coming · Next.** Rules:
- One running example company + service, used in every SOP (Ally: Acme / `invoicer`).
- Every command exact and copy-pasteable, with the environment flag written out.
- Every message in "What you'll see" / "If it goes wrong" is a verbatim string from source or
  help, in the tool's own words, followed by meaning and fix.
- Tables for "which file drives which object" and "message → meaning → do".
- **Coming** items each carry a *Today:* workaround (or "none"). If the workaround is raw HTTP,
  say which org's admin, which endpoint, and to re-run the read-only status command after.
- Short, human, concrete. No internal paths, ticket ids, or team names in client-facing text.

### 4. Write the system files
- `00_index.md`: who it's for, how to use it, the two global warnings, one line per SOP.
- `agent.md` (`references/agent-template.md`): frontmatter `name`, `description` with trigger
  phrases, `tools`, `skills: [<routing-skill>]`, `model`, `effort`, `color`. Body: coordinates
  (what the tool is, install URL from source, default env, where state lives, the org model,
  what is Coming), numbered operating rules (plain words first; preview → yes → apply; confirm
  env every time; never print secrets; never delete the creds dir; CLI not HTTP; never
  automation-bypass flags without written consent; vocabulary bans), a "how you work a request"
  loop, a routing table (intent → SOP file), and a report shape.
- `skills/<routing-skill>/SKILL.md`: frontmatter + non-negotiables + a table linking every SOP by
  **relative path `../../<file>`** (so a symlinked skill dir keeps working) + companion skills to
  load by name. Short; the SOPs are the references.
- `install.sh`: copied from a shipped bot; downloads the folder, symlinks `agent.md` to
  `~/.claude/agents/<name>.md` and each skill to `~/.claude/skills/<skill>`, prints next steps;
  nothing else (layout rules: the meta bot's SOP 06).
- `README.md`: what is here, the install line, what the bot will and will not do. You write the
  installer and the README; you never run the install for the user.
- `GAPS.md`: table `# · item · SOP · why users want it · today`; dedupe across SOPs; tag items
  that belong to an approved design. This is the product team's spec list.

### 5. Verify before you hand back
- `grep -rni "<banned words>"` over the folder: only the rules themselves may match.
- Every command and flag you wrote appears in `--help` or the dispatcher; every quoted message
  appears in source. Anything you could not verify goes in the report, not silently in the SOP.
- Every SOP has all seven sections; every Coming has a Today; every SOP's Next points somewhere.
- No credential content, no `rm -rf` of a creds dir, no example that targets prod implicitly.
- Append one dated work-log line listing files written + unverified items.
- Report under ~250 words: files, could-not-verify, top 5 gaps.

## Anti-patterns (seen while building Ally)
- Writing procedure from a skill instead of from source: skills lag and contradict each other.
- Inventing a verb because it "should" exist. If it is not in the dispatcher, it is **Coming**.
- Describing the approved design as shipped. Mark it; give today's path; the user will try it.
- Suggesting `rm -rf ~/.authmesh/<svc>/` or any "clean slate" that spans environments.
- Printing or `cat`-ing a credentials file to "show the user where the key is".
- Long SKILL.md bodies. Routing only; depth lives in the SOPs.

## References
- `references/sop-template.md` — the SOP skeleton with notes per section.
- `references/agent-template.md` — agent.md and routing SKILL.md skeletons.
- Worked examples: the shipped bots beside this one (`authmesh/`, `billing-quota/`, `uj/`); read
  their `00_index.md`, `agent.md` and `GAPS.md` to see the method applied end to end.
