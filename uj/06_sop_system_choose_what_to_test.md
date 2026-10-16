# 06 · Decide what to test, and what not to

**What this is for.** Choosing which journeys are worth writing for Acme's `invoicer`, which kind of test each one is, and in what order, before anyone opens a YAML file. The backbone is the project's **risk register**: a short table in `.uj/risks.context` of what would hurt customers if it broke. You write the risks first, then journeys that cover them; `uj coverage` compares the two and lists the gaps, and the top gap is always your next journey. A handful of realistic journeys that each protect a named risk beats a hundred calls that each prove a status code.

**Before you start.** SOP 01 (journeys and verdicts), SOP 04 (`uj init` created `.uj/`). Thirty minutes with Maya (PM) and Dev (engineer). Bring what Acme promises customers (pricing page, onboarding emails, support macros), the last few incidents and bug reports, and the API list (`openapi.json`).

## Steps

**1. List the promises, not the endpoints.** Write what Acme tells its customers, in their words:
- you can bill your first client within minutes of signing up
- an invoice says exactly what you typed, and "sent" means sent
- nobody else can see your invoices
- deleting an invoice removes it

Each line is a candidate `outcome:`. If a line starts with a verb like create, get or delete, it is a task; ask "so that… what?" until it describes a change in the customer's world. `POST /invoices` is a task. "A freelancer gets paid for their first job" is an outcome.

**2. Turn each promise into the risk of breaking it, and rank them.** Ask how bad it is (money, trust, someone else's data) and how likely (new code, complex rules, past incidents). These categories almost always rank high:

| category | the question | Acme risk |
|---|---|---|
| activation, first value | can a new customer reach the "aha" alone? | a new customer cannot send a first invoice |
| trust-critical | if this broke, would they leave? | another customer opens your invoice |
| money moment | does it bill, charge, send or pay? | the amount sent differs from the amount typed |
| two people, one boundary | where do two actors meet? | a stranger with the link reads it |
| lifecycle end | does "gone" mean gone? | a deleted invoice still shows up |

**3. Write the risk register.** Open `.uj/risks.context` (the recipe is `.uj/risks.context.example`). Replace the `example-risk` row with yours; the first column is a short, stable id that journeys will name in `covers:`:
```
## Risk register
| id | risk (in users' words) | priority | why it matters | notes |
|---|---|---|---|---|
| invoice-isolation | a customer sees another customer's invoices | P0 | trust, legal | |
| activation | a new customer cannot send a first invoice alone | P0 | no activation, no revenue | |
| amount-accuracy | the amount on a sent invoice differs from the amount typed | P0 | money, disputes | |
| send-integrity | "sent" is not really sent, or a sent invoice changes | P1 | clients dispute invoices | |
| delete-means-gone | a deleted invoice still shows up | P1 | trust | |
| invoice-email | the client never receives the invoice email | P1 | late payment | |
```
P0 would stop customers or leak data, P1 is serious and visible, P2 is annoying. Fill `# Sources:` and `# Last updated:` in the header. A risk you accept on purpose goes in the `## Not covered on purpose` table with the reason; `uj coverage` then reports it as `accepted, not covered on purpose:` instead of as a gap. Add a dated line to `.uj/decisions.md` saying why.

**4. Read the gaps: that is your list.**
```sh
uj coverage
```
With no path it reads the project's `journeys/`. On day zero every risk is a gap, P0 first. Write journeys for the P0s before anything else.

**5. Pick the test type for each risk.** The default is a realistic session; the others are usually checkpoints inside one.

| type | the question it answers | Acme example | in uj |
|---|---|---|---|
| **realistic session** (default) | does a real person reach the outcome, with the risk checked where they would hit it? | a freelancer's first afternoon: sign up, draft, fix a mistake, send, check the list | `kind: epic`, as many steps as the session takes, `covers:` |
| functional | does this feature do its job? | sending marks the invoice `sent` | a step that asserts `status: sent` |
| regression | does a fixed bug stay fixed? | amounts were rounded to whole euros last spring | a step pinned to the exact field, `tags: [regression]` |
| security (negative space) | is the wrong person refused? | no token → `401`; another customer → `404` | an `abuse:` step with the exact status |
| misstep | does a real user recover from a wrong turn? | forgets the currency → `422` → adds it → `201` | `misstep: true`, then the recovery step |
| contract | does the response keep its shape? | an invoice always has `id`, `status`, `owner_id`, `created_at` | `expect.schema` (SOP 08); the whole spec is SOP 15 |
| smoke | is the deployed thing alive and wired? | after a deploy: health, sign up, one invoice | one short journey, `tags: [smoke]`, `uj run --tag smoke` |
| performance | is it fast enough for one user? | the invoice list answers within 800 ms | `within: "800ms"` (load testing is SOP 16) |

**6. Apply the rule of three to auth, permissions and customer data.** Any change there gets a functional check (it works), a regression check (what worked before still works), and a security check (the wrong person is refused). Acme is adding "share an invoice with your accountant": the accountant can open it; the owner's own list is unchanged; a stranger with the link gets `404`. Put the three in one session as checkpoints, or in three journeys. Add the new risk to the register first.

**7. Weave the checks into a realistic session.** Do not write "open invoice 7 three ways". Write the freelancer's afternoon and put each check where a real person would hit it: sign up, draft for Globex, forget the currency (misstep), fix it, send, check the list, then a stranger tries the URL (abuse). The surrounding activity builds real state, and ordering and state bugs live there. Real sessions are long; `--resume` retries from the failed step (SOP 11). Activities that recur become fragments (SOP 09).

**8. Choose the one or two abuse cases that matter.** Ask: "if this succeeded, would a customer or an auditor care?" No token on what the journey created; another customer's token on your data; another object's id in the path; a credential used after logout; a lower role doing an owner's action; a one-time link used twice. Pick per journey; do not paste all six. Name the worst one at journey level with `abuse:` (SOP 07). `uj lint` reminds you: a journey of three or more steps with no refusal step (an `abuse:` step, `expect: denied`, or an expected `4xx`) gets JL013.

**9. Write the story before the mechanics, naming the risks it covers.** Maya scaffolds and fills the story; Dev fills the steps later (SOP 07).
```sh
uj new journey "A freelancer bills their first client"
```
```yaml
outcome: "a freelancer gets paid for their first job the day they sign up"
persona: "a designer who just finished a logo for Globex and wants the money this week"
narrative: |
  They sign up, draft an invoice for Globex, forget the currency and fix it, send it,
  and check it shows as sent. If Globex could not trust the amount, they would go
  back to spreadsheets.
success: "the invoice reaches 'sent' with the amount they typed"
covers: [activation, amount-accuracy]
```
`covers:` uses the register's ids exactly, and only for risks the journey really exercises: `invoice-isolation` needs a second customer trying to reach the first one's invoice (SOP 09), so it gets its own session. `success:` is a promise a non-engineer can judge: "the amount sent is the amount typed", not "the endpoints return 200".

**10. Re-run the gap report after every journey.** `uj coverage` again: the covered risks move up into the matrix, the gap list shrinks, and a misspelled id shows as "not in the risk register". Repeat steps 4 to 10 until no P0 or P1 is left; `uj where` shows the count at a glance.

**11. Leave out what a journey is the wrong tool for.** A journey that makes one call and checks its status is a unit test in a costume: slow, and it proves nothing a customer would notice. Leave these to unit tests: every validation permutation of one field, internal functions, anything you cannot observe through the API. Never point journeys at production. Throughput with many users is SOP 16.

## What you'll see

`uj coverage` with two journeys written, one with a typo in `covers:`:
```
GAPS — 3 registered risk(s) with no journey (.uj/risks.context):
  · invoice-isolation            P0  a customer sees another customer's invoices
  · delete-means-gone            P1  a deleted invoice still shows up
  · invoice-email                P1  the client never receives the invoice email

1 covers id(s) not in the risk register (typo, or add the risk):
  · invoice-isolaton
```
Read the two lists together: the typo `invoice-isolaton` is why the real P0 `invoice-isolation` still shows as a gap.
The report also prints a coverage matrix above these lists: each covered id with `N session(s)` and the journey ids; at the end `4 behavior(s) covered across 2 session(s)` (the count includes the typo'd id). A risk in the `## Not covered on purpose` table prints as `accepted, not covered on purpose: <ids>`. When nothing is missing: `every registered risk (6) has at least one journey (.uj/risks.context)`. With no register: `(no risk register — list your risks in .uj/risks.context and this report shows the gaps)`. `uj coverage --json` adds `risk_register`, `uncovered_risks`, `accepted_risks` and `unregistered`. The report always exits `0`; gaps are a backlog, not a failure.

`uj explain` on Maya's draft leads with the story: `Outcome: …`, `Persona: …`, `Must never happen: …` (the journey-level `abuse:`), `Success means: …`.

## If it goes wrong

| sign | it means | do |
|---|---|---|
| `example-risk` is listed as a gap | the scaffold row is still there | replace it (step 3) |
| an id under "not in the risk register" | a typo in `covers:`, or a risk nobody registered | fix the spelling, or add the row |
| `outcome starts with 'create' — that's a TASK, not an OUTCOME; ask 'so that… what?' (a change in the user's world)` (lint JL009) | the journey is about an endpoint | step 1 |
| `` no `success:` — a PMM should state what "worked" means `` (JL008) | nobody decided what PASS proves | step 9 |
| every journey passes, bugs still reach customers | the register lists endpoints, not risks | steps 1–3 |
| one journey per endpoint, or two-step journeys | unit tests in a costume | step 11; fold them into a session |
| `JL013` `no refusal step — add one where an outsider or a wrong input must be REFUSED (abuse: + expect: denied); negative space is the most-skipped check` | a session with no step that must be refused | step 8; at least "no token" |

## Coming

- **`uj new` scaffolding the rule-of-three trio** (functional, regression, security). *Today:* write them by hand, or as three checkpoints in one session.
- **Load testing built from your journeys.** *Today:* `within:` budgets, `--parallel` as a smoke, an external load tool; SOP 16.

## Next

SOP 07, write the journey for your top gap. Then SOP 08 for assertions and SOP 09 for longer sessions and edge cases.
