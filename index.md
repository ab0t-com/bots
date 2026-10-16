# ab0t bots

Assistants for the people who build on the ab0t mesh. Each one knows one part of the mesh inside out,
explains it in your words, and does the work with you: it shows you what it is about to change, waits
for your yes, and never touches a secret.

## Pick a bot

**Ally** — *"Put my service on the mesh."*
Sign-in for your customers, permissions, a branded login page, drop-in widgets, keys for your backend,
connections to other services. One tool (`authsetup`), one config folder, re-run forever.
→ [`authmesh/`](authmesh/00_index.md) · install: `curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/authmesh/install.sh | sh`

**Penny** — *"Meter it, limit it, charge for it."*
Free and paid tiers, usage counters, Stripe checkout and the customer portal, sign-up credit, a ledger
per customer. One JSON file, two keys, a shadow day, then enforce.
→ [`billing-quota/`](billing-quota/00_index.md) · install: `curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/billing-quota/install.sh | sh`

**Zee** — *"Who may do what, inside my app?"*
Owners, editors, viewers, folders whose members inherit access, approvals that need a second person.
Say it in plain words; Zee models it, audits it, and previews who gains and who loses before any change.
→ [`authz/`](authz/README.md) · install: `curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/authz/install.sh | sh`

**Quinn** — *"Does my product really work for the people using it?"*
Readable user-journey tests for any HTTP service: realistic sessions, edge cases and isolation checks,
end-to-end and API checks, one honest verdict each (PASS, FAIL, or VOID when the environment broke),
in CI. One tool (`uj`), one project folder in your repo, no global setup.
→ [`uj/`](uj/00_index.md) · install: `curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/uj/install.sh | sh`
(the `uj` tool's own public repository is coming soon; Quinn's SOP 03 has its install line)

**Meta** — *"Make a bot like these for my service."*
For a business on the mesh that wants its customers to have an assistant for its product, and for
anyone adding the next bot here. Meta reads your tool's source and help, writes the SOPs, the agent, the
installer and the honest gaps list, and checks the result against the contract.
→ [`meta/`](meta/00_index.md) · install: `curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/meta/install.sh | sh`

**More on the way** — audit and compliance, integrations, compute and realtime workspaces, tools and
the MCP gateway, events, voice and email, go-live and support bots. The list, with what each is for,
and the services an agent-OS mesh will need next: [`BOTS_WANTED.md`](BOTS_WANTED.md).

## How every bot works

1. **SOPs you can read without the bot.** Numbered, one job each: what it is for, what to have ready,
   the exact commands, what you will see, what to do if it goes wrong, what is not built yet (marked
   **Coming**, with today's way), and where to go next.
2. **An agent that follows them.** Install it into Claude Code, say what you want in plain words, and
   it walks the SOP with you, previewing every change.
3. **An honest gaps list.** `GAPS.md` in each folder is everything the SOPs had to mark **Coming**.
   It is also our build list.

## Where to start

New to the mesh: read Ally's `01` and `02` (ten minutes), then let Ally run `03` → `06` with you. Your
service already signs people in: go straight to Penny's `01` and `02`.

Install several bots at once: `curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/install.sh | sh -s -- authmesh billing-quota`
(or `sh -s -- all`; with no names it lists the bots).

## For the people who build bots

`BOTS_WANTED.md` has the rules; the method is the `sop-aligned-agent-system` skill in
[`meta/`](meta/00_index.md). Keep it human, keep it exact, mark what is not there yet.

Licence: MIT ([`LICENSE`](LICENSE)); third-party parts: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
Questions: platform-team@ab0t.com.
