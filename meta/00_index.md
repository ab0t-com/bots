# Meta: the bot that builds and keeps the bots

**Who this is for.** A business on the mesh that has published a service and wants a bot of its own, so *its* customers can use *its* product the way Ally and Penny let people use the mesh. And anyone adding the next bot to this repository (audit, compute, tools, comms…).

**What a bot is here.** One folder: plain-language numbered SOPs a person can follow alone, a named Claude Code agent that follows them, a routing skill, a manifest, an installer, and an honest list of what is not built yet (`GAPS.md`). The method is the `sop-aligned-agent-system` skill in `skills/`; these SOPs are that method applied to the job of making bots.

**How to use it.** Read 01 once (the contract is nine lines; the rest is defaults you may change). Building a bot: 07 → 02 → 05. Changing one: 04. Publishing yours: 06. Making bots cooperate: 08. Keeping them true: 03. Meta (`agent.md`) will do any of these with you, and it shows every file before it writes.

| # | SOP | one line |
|---|---|---|
| 01 | [What a bot is](01_sop_system_what_a_bot_is.md) | The folder, the nine-line contract, the defaults you may change, the manifest. |
| 02 | [Build a new bot](02_sop_system_build_a_new_bot.md) | Day zero: log → investigate → SOP set on paper → SOPs → agent, skill, manifest, installer, GAPS → gate. |
| 03 | [Keep bots honest](03_sop_system_keep_bots_honest.md) | GAPS lifecycle, re-verify on releases, and the lessons the first bots taught. |
| 04 | [Add or change an SOP](04_sop_system_add_or_change_an_sop.md) | Extending a shipped bot without breaking its voice, routing or honesty. |
| 05 | [Verify and ship a bot](05_sop_system_verify_and_ship_a_bot.md) | The gate: checks, scratch install, release from your repository, rollback. |
| 06 | [Publish your own bot](06_sop_system_publish_your_own_bot.md) | For a business on the mesh: a bot for your service, in your repository, listed in the catalogue. |
| 07 | [Investigate a product](07_sop_system_investigate_a_product.md) | Where facts come from: help, API spec, config schema, error strings, env vars, tests, SDKs; the fact sheet; API-only products. |
| 08 | [Bots working together](08_sop_system_bots_working_together.md) | Discover, hand off, ask (read-only), share by reference; the manifest; what bots want from each other. |

Also here: `bot.json`, `agent.md` (Meta), `skills/meta-bot-builder/SKILL.md` plus the four method skills, `README.md`, `install.sh`, `GAPS.md`. The catalogue of bots, shipped and wanted, is one level up: [`../BOTS_WANTED.md`](../BOTS_WANTED.md); the root [`../install.sh`](../install.sh) installs several bots at once.
