# 01 · What a bot is

**What this is for.** The small contract every bot in the catalogue keeps, so a person can open any of them and know where things are, and an agent can run any of them and know what it may do. The contract is short on purpose; everything else is a default you may change.

**Before you start.** Nothing. Ten minutes.

## The shape

```
<bot>/
  bot.json                         machine-readable manifest: name, agent, skill, jobs → SOPs, hand-offs, install line
  00_index.md                      who it's for · how to use it · the warnings · one line per SOP
  01_sop_system_<concept>.md       a concept page in plain words (what the thing is, who pays, the one new word)
  02_sop_system_day_zero_<...>.md  the whole first day for one example customer, in order
  03.. nn_sop_system_<job>.md      one job per SOP, in the order a client meets them
  agent.md                         the named agent: frontmatter + where-you-are + coordinates + rules + routing + report
  skills/<routing-skill>/SKILL.md  short; routes to the SOPs by relative path ../../<file>
  skills/<companion>/              copies of skills the agent may load by name (so the folder stands alone)
  install.sh                       downloads the folder, symlinks agent + skills, prints next steps; nothing else
  README.md                        what is here, how to install, what the bot will and will not do, how it stays honest
  GAPS.md                          every Coming item: # · item · SOP · why users want it · today
  WORKLOG.md (optional)            one dated line per session: claimed → did → verified  (or keep the log wherever your team logs work)
```

## The contract (what the catalogue checks)

1. **Procedure SOPs have seven headings**: What this is for · Before you start · Steps · What you'll see · If it goes wrong · Coming · Next. Concept pages and reference pages (troubleshooting tables, rules) may drop Steps; they keep Coming and Next.
2. **Every command, message and field is verified** against the tool's help text, source, or API spec, and outputs are quoted in the tool's own words. Nothing invented.
3. **Anything not built is marked Coming, with today's path** (or "none", when true). Approved designs are written as the ideal and marked.
4. **Secrets are never printed**; SOPs point at a file and field. No step deletes a credentials folder.
5. **Dangerous defaults are stated in every SOP that runs the command** (for the mesh: `authsetup` defaults to prod; `enforcement.enabled` absent means allow everything).
6. **Mutations are previewed and confirmed**, including tools that "only check" but connect or create state.
7. **Vocabulary**: say **org**, never "realm"; cross-customer reach is `scope: "platform"`; legacy names appear only inside quoted server output.
8. **Hand off to the bot that owns a job** instead of re-documenting it (keys → Ally, money → Penny, relationships → Zee); the manifest lists the hand-offs.
9. **The installer only downloads, symlinks and prints.** No CLI installs, no network calls to services, no credential reads.

Nine lines. A bot that keeps them can be listed; everything below is advice.

## Defaults we use (change them for your bot)

| default | ours | your choice |
|---|---|---|
| example customer | Acme, service `invoicer` | any customer-shaped example your readers recognise; keep one throughout |
| SOP length | roughly a screen or two; split by job when it grows | whatever a person reads in one sitting |
| agent model / effort | `opus`, `high` | what your harness offers |
| agent tools | `Bash, Read, Write, Grep, Glob` (+ `Edit`, `Agent` for builders) | the minimum the SOPs need |
| tone | short sentences, second person, no hedging, no emoji | yours, within "plain words first" |
| colour, persona | a name and four habits | yours |
| number of SOPs | 6–18 | as many jobs as clients come back for |

## The agent (what the body must contain)

Frontmatter: `name`, `description` with the phrases a client would type, `tools`, `skills: [<routing-skill>]`. Body: a persona paragraph; **where you are** (how the agent finds its own folder, its siblings and its update path); **coordinates** (what the tool is, where it installs from, defaults, where state lives, the entity model, what is Coming); numbered **operating rules**; **how you work a request**; the **routing table** (intent → SOP); **how to report**. The body replaces the harness's default prompt, so it must stand alone.

## The manifest (`bot.json`)

```json
{ "name": "ally", "bot": "authmesh", "owner": "ab0t", "repo": "github.com/ab0t-com/bots",
  "install": "curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/authmesh/install.sh | sh",
  "agent": "agent.md", "routing_skill": "ally-mesh-client", "tools": ["authsetup"],
  "for": "put a service on the ab0t auth mesh: sign-in, permissions, hosted login, widgets, users, keys",
  "sops": ["00_index.md", "01_…", "…"],
  "hands_off_to": [{"bot": "billing-quota", "for": "metering, tiers, charging"}],
  "answers": ["which environment am I on", "is my billing key live and on which tier"],
  "dangerous_defaults": ["authsetup targets prod when no --env is given"],
  "verified_against": {"authsetup": "0.5.24", "date": "2026-10-16"} }
```
Agents and installers read it; people do not have to. SOP 08 explains how bots use it.

## What you'll see

Open `~/.ab0t/bots/<any bot>/` (or the checkout) and the layout above is there, file for file.

## If it goes wrong

- A bot without `GAPS.md`, or with an SOP that promises a verb the tool lacks: not a bot yet; SOP 05's gate.
- An agent whose rules are longer than its routing table: the SOPs carry too little; move procedure into them.
- A third-party bot that re-documents `authsetup`: it will drift the day a flag changes; hand off.

## Coming

- **A linter for the nine lines** (`meta check <bot>`). *Today:* SOP 05's shell checks.
- **A template folder** to copy from. *Today:* copy `~/.ab0t/bots/billing-quota` (or the checkout) and replace.

## Next

SOP 02, build a new bot. SOP 07 if you want to see how a product is investigated first.
