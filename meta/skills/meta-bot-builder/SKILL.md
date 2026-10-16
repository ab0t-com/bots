---
name: meta-bot-builder
description: >-
  SOPs for building, changing, verifying, shipping and maintaining client-facing bots (one folder each:
  numbered SOPs + agent.md + routing skill + companion skills + bot.json + install.sh + README + GAPS.md),
  for investigating a product's CLI / API spec / config / error strings / env vars / tests into a fact
  sheet, for bots handing off and asking each other read-only questions, and for a business publishing
  its own bot for its own mesh service. Use when asked to "build a bot for <product>", "make an Ally for
  my service", "investigate this repo for SOPs", "add or change an SOP", "renumber SOPs",
  "check/verify/ship this bot", "publish my bot", "bot.json", "update GAPS.md", "a gap shipped",
  "re-verify after a release", "which bots exist / are wanted", or anything about the sop-aligned agent
  system. Hands product usage questions to Ally (authmesh), Penny (billing-quota), Zee (authz) and
  Quinn (uj).
---

# meta-bot-builder

Eight short SOPs for making bots, plus the method skills they apply. This file only routes.

## Non-negotiables (restated from the SOPs)
- Log first (`WORKLOG.md`, or wherever the user's team logs work); one dated line per session.
- Investigate before writing (SOP 07): help → spec → source → config → env → tests → docs last. Verbatim strings only.
- No side effects: offline `--help`, `sh -n`, greps; scratch installs in `/tmp` homes; never read credentials.
- Show every file before writing; write only in the bot folder, the catalogue, the log.
- Never invent a verb: not in the dispatcher/help/spec → **Coming** + *Today:*. Unsettled disagreement → "could not verify".
- Enforce the nine-line contract (SOP 01); offer, do not impose, the defaults (example company, sizes, model, tone).
- Vocabulary by grep: `realm` and legacy `cross_*` only inside quoted server strings or rule lines.
- Hand off to the bot that owns the job; ask siblings read-only; never commit or push unless the user says so.

## The SOPs (relative to this file)
| job | file |
|---|---|
| map | [../../00_index.md](../../00_index.md) |
| what a bot is: contract, defaults, manifest | [../../01_sop_system_what_a_bot_is.md](../../01_sop_system_what_a_bot_is.md) |
| build a new bot | [../../02_sop_system_build_a_new_bot.md](../../02_sop_system_build_a_new_bot.md) |
| keep bots honest + lessons | [../../03_sop_system_keep_bots_honest.md](../../03_sop_system_keep_bots_honest.md) |
| add or change an SOP | [../../04_sop_system_add_or_change_an_sop.md](../../04_sop_system_add_or_change_an_sop.md) |
| verify and ship (the gate) | [../../05_sop_system_verify_and_ship_a_bot.md](../../05_sop_system_verify_and_ship_a_bot.md) |
| publish your own bot (customers) | [../../06_sop_system_publish_your_own_bot.md](../../06_sop_system_publish_your_own_bot.md) |
| investigate a product (the fact sheet) | [../../07_sop_system_investigate_a_product.md](../../07_sop_system_investigate_a_product.md) |
| bots working together | [../../08_sop_system_bots_working_together.md](../../08_sop_system_bots_working_together.md) |
| the catalogue: shipped, wanted, future services | [../../../BOTS_WANTED.md](../../../BOTS_WANTED.md) |
| Meta's own gaps | [../../GAPS.md](../../GAPS.md) |

## Method skills (in this bot's `skills/`, load by name)
`sop-aligned-agent-system` (the method; its `references/` hold the SOP template and the agent
template) · `make-agent` (agent.md frontmatter and body) · `skill-creator` (SKILL.md anatomy,
progressive disclosure, the Agent Skills spec) · `sop-creator` (typed steps, verification, rollback).

## Shipped bots to copy from (siblings; read their `bot.json` first)
`../../../authmesh/` (Ally, 17 SOPs, `authsetup`) · `../../../billing-quota/` (Penny, 18 SOPs, money) ·
`../../../uj/` (Quinn, 19 SOPs, `uj`) · `../../../authz/` (Zee, agent + skills, SOPs pending).
