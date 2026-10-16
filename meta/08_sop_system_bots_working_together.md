# 08 · Bots working together

**What this is for.** A client installs several bots. Penny needs to know whether the billing key Ally minted is live; Ally wants to tell a client who is about to meter that Penny exists; Meta needs to know what every bot can do. This SOP is the small set of conventions that let bots find each other, hand off, ask questions and share what they may share, without ever passing a secret or acting for one another.

**Before you start.** `bot.json` present in each bot folder (SOP 01). Installed bots live side by side under `~/.ab0t/bots/<bot>/` (or in one checkout), which is how they find each other.

## The three ways bots interact

| way | when | how |
|---|---|---|
| **Hand off** | the job belongs to another bot | the SOP says so (`→ Ally SOP 11`); the agent tells the user which bot and SOP and, if that bot is not installed, prints its install line from the catalogue |
| **Ask** | you need one fact the other bot can read (not change) to continue | run the other bot as a **read-only subagent** with a bounded question; it answers citing its SOP; nothing is mutated |
| **Share** | both need the same reference | the manifest (`bot.json`) and the user's own files by **path and field**, never by value |

## Steps

**1. Discover who is installed.**
```sh
ls ~/.ab0t/bots/*/bot.json 2>/dev/null; cat ~/.ab0t/bots/*/bot.json | jq -r '"\(.name)\t\(.bot)\t\(.for)"'
```
In a checkout: `ls */bot.json` from the bots root. An agent reads the manifests, never guesses a sibling's commands.

**2. Hand off properly.** Name the bot, the SOP and the first command; stop. Do not run the other bot's commands yourself unless the SOP you are following says to (Penny runs `authsetup connect` because her SOP 03 says so, and her coordinates carry the prod-default warning).

**3. Ask a question (agents with the `Agent` tool).** Spawn the sibling agent with: one paragraph of context, the exact question, the constraint **"read-only: run no command that mutates; print no secret"**, and what shape you want back. Good questions are facts the sibling can read from its own tools:
- Penny → Ally: *"For service `invoicer` on env `dev`, is the billing consumer key live, and which tier does it hold? Read-only."* (Ally runs `authsetup --env dev status --verify`, answers with tier and state.)
- Ally → Penny: *"Does `invoicer` meter usage? If yes, which billing write permissions should I ask the provider for?"* (Penny answers from SOP 03 step 5.)
- Meta → any bot: *"Which jobs do you cover, and what do you hand off?"* (answered from `bot.json`.)
- Quinn → Ally: *"For service `invoicer` on env `dev`, which credentials file holds the client id? Path and field only, never the value. Read-only."* (one of the questions Ally's `bot.json` lists under `answers`.)
- Support (future) → all: *"Customer org `org_…` paid but sees the free tier; which link in the chain is yours to check?"*
Bad questions: anything that asks the sibling to change state ("rotate the key for me"), anything that needs a secret value, anything the asking bot's own SOP already answers.

**4. Answer a question when you are asked.** Confirm it is read-only; run only read commands; quote the output; cite the SOP; name the next safe step for the user. Never return a key, a password, a token or the contents of a credentials file. If the question needs a mutation, say which SOP the user should run with the owning bot.

**5. Share by reference.** When two bots need the same thing (the service name, the environment, the path of a credentials file), pass the path and field: `~/.authmesh/invoicer/billing-consumer.dev.json`, `.api_key.key`. The user moves values; bots move names.

**6. Keep the manifest true.** When a bot gains a job, a hand-off or an answerable question, update `bot.json` with the SOP. Meta's gate (SOP 05) checks that every `sops` entry exists and every `hands_off_to.bot` is in the catalogue.

## What you'll see

A hand-off reads: *"That's a Penny job: SOP 03, Get your keys. Install: `curl … /billing-quota/install.sh | sh`, then `@agent-penny`."* An ask returns a few lines of quoted tool output plus "per Ally SOP 16". A client never sees two bots disagree on a command, because neither re-documents the other.

## If it goes wrong

- Two bots document the same command differently: one is stale; the owning bot wins; the other hands off (SOP 04).
- A sibling asked for a secret: refuse and say why; file it as a bug in the asking bot's SOP.
- The sibling is not installed: print its install line from the catalogue; do not improvise its procedure.
- An ask turned into a mutation: stop; the user runs the owning bot's SOP themselves.

## Coming

- **The `Agent` tool on Ally, Penny, Zee and Quinn** so they can ask each other. Each bot's maintainers add it deliberately, because it widens what a bot can do in a session. *Today:* only Meta has it; the others hand off by telling the user which bot and SOP to use.
- **`bots ask <bot> "<question>"`** from the shell, with the read-only constraint built in. *Today:* the subagent prompt in step 3.
- **A shared, user-visible session note** (which service, which env, what was changed) that any bot in the session appends to. *Today:* each bot's closing report.
- **A bot registry on the mesh directory** so a provider's bot is discoverable where the provider is (`authsetup providers` shows "install the assistant"). *Today:* the catalogue.
- **Manifest validation in the gate** (`meta check`). *Today:* the two greps in step 6, by hand.

## Next

Back to `00_index.md`; or SOP 06 to publish a bot that hands off well.
