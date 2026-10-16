# Bots the mesh still needs (client-facing)

Each bot is a separate business's assistant for *using* one part of the mesh: plain-language SOPs, a
named agent that follows them, and a skill that routes. Built with the `sop-aligned-agent-system`
method (SOPs first, grounded in source; agent and skill on top; every gap listed in `GAPS.md`).

| bot | name | for a client who wants to… | core services | status |
|---|---|---|---|---|
| `authmesh/` | **Ally** | put their service on the mesh: sign-in, permissions, hosted login, widgets, users, keys | auth, `authsetup` | shipped |
| `billing-quota/` | **Penny** | meter usage, enforce tiers, charge customers | billing, payment, `ab0t-quota` | shipped |
| `authz/` | **Zee** | model "who can do what" in their own app (owner/editor/viewer, inherited access) without learning ReBAC; preview every change | `zzb` (Zanzibar) | shipped (agent + 6 skills; client SOPs + GAPS.md still to write) |
| `meta/` | **Meta** | build, change, verify and ship a bot like these; publish a bot for *their own* mesh service so their customers get one | the bot contract, `sop-aligned-agent-system` | shipped (dev bot; customer-facing via SOP 05) |
| `uj/` | **Quinn** | test their service the way real users use it: readable user journeys, realistic sessions and edge cases, end-to-end and API checks, honest PASS/FAIL/VOID verdicts, CI, OpenAPI drift | `uj` (user-journey test tool) | shipped (SOPs 00–19, agent, skill, GAPS.md); the `uj` tool's public repository is coming soon |
| `audit/` | *Audie* | write audit events, pull compliance reports, answer a GDPR access/erasure request | audit service | wanted |
| `connect/` | *Connie* | plug third-party integrations into their product; publish their own integration as a provider | connect / integration service, connect-vault | wanted |
| `compute/` | *Rex* | provision sandboxes, cloud browsers and desktops, and realtime workspaces for their users or agents; meter them | resource service, sandbox platform, realtime workspaces, agent compute | **products exist**; bot wanted |
| `tools/` | *Reggie* | publish tools, skills and schemas; expose their API through the MCP gateway so any agent can call it with mesh identity and metering | tool registry, schema registry, MCP gateway | **products exist**; bot wanted |
| `events/` | *Echo* | subscribe to mesh events, receive signed webhooks, replay and backfill safely | ab0t-events, auth events | wanted |
| `llm/` | *Gabby* | call models through the gateway with their keys, budgets and audit | llm-gateway | wanted |
| `comms/` | *Ivy* | send email and place or receive calls from their product, with consent and logs | agentemail, agentphone (voice SDK) | **products exist**; bot wanted |
| `upgrade/` | **migrationbot** (ships in `github.com/ab0t-com/auth-sdk-go`, `migrations/agent/`) | move to a new SDK/library version mechanically, with a worklog | auth-sdk-go kits; later quota-go, Python wrappers | exists for the Go auth SDK (Ally SOP 15); widen |
| `launch/` | *Skipper* | run the go-live checklist across every service they use (doctor for the whole mesh), then watch day one | all of the above | wanted |
| `support/` | *Sam* | "my customer says X": walk the chain across auth, billing, payment and quota and name the fix | all, read-only | wanted |

## Rules for any new bot
- One client job per SOP; `<nn>_sop_system_<name>.md`; the same seven headings; one running example company.
- Source first, skills second; every message quoted verbatim; everything unbuilt marked **Coming** with *Today:*.
- Say **org**, never "realm"; cross-customer reach is `scope: "platform"`; never recommend legacy names.
- Default environments and dangerous defaults stated in every SOP that runs a command; secrets never printed.
- An `install.sh` that only downloads, symlinks and prints; a `GAPS.md`; a `README.md`; the agent in `agent.md`.
- Hand off to the bot that owns a thing (keys → Ally; money → Penny) instead of re-documenting it.

## Bots for services that do not exist yet (the agent-OS view)

Today the mesh sells the parts a SaaS needs: sign-in, permissions, money, compute, tools, audit. An
agent-OS mesh is different in one way that changes everything: the *callers* are increasingly agents
acting for people and for other businesses, at machine speed, with money attached. Each row below is a
service the mesh does not have yet, the client question that will arrive first, and the bot that
answers it. Ordered by how soon a paying client asks.

| service (does not exist) | bot | the client's first question | why an agent OS needs it, not just a SaaS | build on |
|---|---|---|---|---|
| **Agent identity and delegation** — an agent as a first-class principal: who made it, who it acts for, what it may do, for how long | *Marshal* | "My customer's agent calls my API. Who is liable, and how do I scope it?" | humans delegate to agents, agents to sub-agents; today this is a service account plus OBO glue | OBO token exchange, service accounts, `delegation/`, auth events |
| **Mandates and machine payments** — a spending authority an agent carries (cap, scope, expiry); settlement between services without a human checkout | *Mint* | "Can an agent pay my service per call, inside a budget its owner set?" | agent commerce is pay-per-action; Stripe checkout assumes a browser and a person | billing reservations, payment, quota |
| **Policy and guardrails** — org-wide rules for what agents may touch, with approval steps and kill switches | *Warden* | "Our agents may read customer data but never export it, and spend over $50 needs a human." | permissions say *may*; policy says *under what conditions*; approvals need a human loop | zzb (ReBAC), quota kill switch, audit, a policy engine |
| **Durable workflows** — long-running agent jobs with retries, timeouts, resume, scheduled runs | *Flow* | "My agent runs for hours across three services. What happens when one hiccups?" | agents are workflows; without durability every retry double-charges or half-finishes | outbox/idempotency patterns in quota-go, events, schedule |
| **Memory and state** — per-user, per-agent durable memory with access control, retention and erasure | *Mnemo* | "Where does my agent keep what it learned about this customer, and how do I delete it on request?" | memory is personal data at scale; it needs the same org isolation as everything else | resource service, audit retention, GDPR erasure paths |
| **Agent observability and evaluation** — traces of what an agent did and why, judged against expectations, regression over time | *Tracer* | "My agent got worse last week. Where, and against which prompt or tool?" | you cannot support or bill what you cannot trace; quality is the SLA | event history and evaluation tooling, audit |
| **Protocol interop beyond MCP** — A2A and whatever comes next, with mesh identity and metering riding along (the MCP gateway and tool system already exist; *Reggie* covers them) | *Bridge* | "Make my API callable by any agent on any protocol, with my permissions and my pricing attached." | the tool call is the new API call; each new protocol must inherit identity and metering, not re-invent them | MCP gateway, tool registry, schema registry, quota, auth-sdk |
| **Marketplace and discovery** — list a service or agent with pricing, tiers, SLAs, terms; connect in one click | *Scout* | "How do other businesses' agents find and buy my service?" | the provider directory exists; pricing, terms and reputation do not | `authsetup providers`/`connect`, run 08, payment plans |
| **Trust, reputation and attestation** — verified publishers, signed agent manifests, abuse reports, revocation | *Sentinel* | "How do I know the agent calling me is who it says, and not banned elsewhere?" | open ecosystems get abused; a mesh needs shared trust signals | API keys, audit, events, the platform-grant record (who granted what, when, why) |
| **Human approvals and inbox** — a place where people see what agents did and approve what they want to do next | *Herald* | "I want a daily digest and a yes/no button, not a log." | the human loop is the product; without it nobody turns agents loose | comms (agentemail/agentphone), events, widgets |
| **Data access and secrets for agents** — grant an agent scoped access to a data source or a credential, revocable, logged | *Keeper* | "My agent needs read access to our customer's CRM for one task." | agents need data grants the way humans need logins; vaults today are per service | connect-vault, connect providers, OBO |
| **Legal and consent** — terms acceptance, DPAs, data residency, consent records per org and per agent | *Clerk* | "Which terms did this customer's agent accept, and where may its data live?" | cross-business agent calls need enforceable terms and provable consent | legal-terms runbook, audit, org settings |
| **Portability and exit** — export everything, migrate between providers, delete across the mesh | *Porter* | "If we leave, how do we take our users, balances and history?" | trust requires an exit; multi-service deletion today is manual | users self-delete, billing ledger, audit export |
| **Cost and finance view** — one view of what a client spends across every mesh service and every agent | *Thrift* | "Which agent is burning our budget, and on which service?" | per-agent cost is the new per-seat cost | billing reports, quota usage, payment invoices |
| **Status and incidents** — mesh-wide status, degradation notices, incident comms to clients' own customers | *Beacon* | "Billing is slow. Is it me?" | one client's outage is many businesses' outage | doctor/health endpoints, events, comms |

### Order to build (a suggestion)
1. **Marshal + Mint** first: agent identity and spend mandates are what every other row leans on.
2. **Warden + Herald**: nobody deploys agents at scale without rules and a human yes/no.
3. **Flow + Tracer**: durability and traces turn demos into supportable products.
4. **Bridge + Scout**: interop and discovery make the mesh a market, not a vendor.
5. **Mnemo, Keeper, Sentinel, Clerk, Porter, Thrift, Beacon**: the trust and operations layer that
   enterprise clients ask about on the first call and buy on the third.

Each one should start the way the shipped bots did: a day-zero story for Acme, SOPs grounded in whatever
exists, and a `GAPS.md` that doubles as the service's spec.
