# 09 · Test real sessions, mistakes, attacks and odd inputs

**What this is for.** Bugs rarely live in one call on a clean slate. They show up in the middle of an ordinary day: after a fumble, on the second user, with a name nobody expected, or when the old browser tab presses a button again. This SOP turns that into journeys. Each one is a **realistic session** of normal activity with the risky moment placed inside it as a **checkpoint**, plus the edge cases around it: missteps, abuse, two users, odd inputs, ordering bugs. Which sessions to write next comes from the gaps in your risk register (SOP 06). The running example is Acme's `invoicer` (Acme's API; yours will differ).

**Before you start.** SOP 05 (setup gives every journey a fresh user: `{token}`, `{user}`, `{email}`, `{pass}`), SOP 06 (the risk register in `.uj/risks.context`), SOP 07 (writing a journey) and SOP 08 (assertions). `ACME_QA_PASSWORD` exported in your shell. Build against `dev`; journeys create real data.

## Steps

**1. Pick the gap, then write the session as a story.** `uj coverage` lists the registered risks with no journey, P0 first. For the top one, Maya writes four lines: who, what they are doing today, the moment that would hurt, and what must still be true afterwards.

| a unit test in a journey costume | a realistic session |
|---|---|
| `POST /invoices/{id}/send` returns 200 | Sam logs in, glances at last month, starts an invoice, forgets the currency, fixes it, sends it, opens it again: it says sent. A stranger with the link sees nothing. |

The send is the **checkpoint**: the step that proves the risky behaviour. The browsing, the fumble and the re-open around it are what make a real bug show up (state left by an earlier step, a second read after a write).

**2. Put the normal activities in a fragment library.** A fragment is a file of steps under any `fragments/` folder. Sub-folders become groups. `needs`/`provides`/`tags` are documentation for the catalogue; only `steps` runs.
```yaml
# journeys/fragments/invoices/create_draft_invoice.yaml
id: create_draft_invoice
tags: [mutate]
needs: [token]
provides: [invoice_id]
steps:
  - intent: they create a draft invoice for a customer
    method: POST
    path: /invoices
    bearer: "{token}"
    body: { customer: "Globex Ltd", amount: 1200, currency: "EUR" }
    capture: { invoice_id: $.id }
    expect: { status: 201, body: { status: draft, customer: "Globex Ltd", owner_id: "{user}" } }
```
Add `browse_invoices` (a `GET /invoices` that expects `fields: [items]`) and `second_user_signs_in` (user B signs up and logs in, captures `"secret:b_token"`) the same way. List the library with `uj fragments journeys/`.

**3. Compose the session with `use:` and mark the checkpoint.** A `use:` step inlines the fragment's steps; captures flow on as if you had written them there.
```yaml
id: MONTH_END_BILLING
kind: epic
outcome: "a freelancer bills this month's client and knows the invoice really went out"
persona: "Sam, a freelance designer, doing month-end billing on a Friday afternoon"
success: "the invoice is in Sam's list, reads sent after sending, and an anonymous caller is refused"
covers: [send-integrity, invoice-isolation]
conflicts: tenant
steps:
  - use: browse_invoices
  - intent: Sam starts an invoice but forgets the currency
    misstep: true
    method: POST
    path: /invoices
    bearer: "{token}"
    body: { customer: "Globex Ltd", amount: 1200 }
    expect: { status: 422 }
  - use: create_draft_invoice
  - { intent: Sam sends it, method: POST, path: "/invoices/{invoice_id}/send", bearer: "{token}",
      expect: { status: 200, body: { status: sent } } }
  - intent: "CHECKPOINT: opening the invoice again shows it as sent"
    method: GET
    path: /invoices/{invoice_id}
    bearer: "{token}"
    expect: { status: 200, body: { id: "{invoice_id}", status: sent } }
  - intent: someone with the link but no login tries to open it
    abuse: an anonymous caller must never read an invoice
    method: GET
    path: /invoices/{invoice_id}
    bearer: "none"
    expect: { status: 401 }
finally:
  - { intent: remove the invoice, method: DELETE, path: "/invoices/{invoice_id}", bearer: "{token}" }
```
Add `narrative:` too (SOP 07). Checkpoints are ordinary steps; starting the intent with `CHECKPOINT:` makes them easy to spot in `uj explain`. `conflicts: tenant` means it touches only its own data, so it runs alongside anything under `--parallel`.

**4. Add missteps: a real user's wrong turn.** `misstep: true` marks a legitimate customer fumbling (missing field, double click, stale tab). Expect the friction (`422`, `409`), then let the next step recover. If the app accepts the bad input, the step fails: that is a missing validation, a real finding.

**5. Add the negative space: what an attacker tries.** `abuse:` names what must be refused. For every endpoint in the session ask: no login (`bearer: "none"`, expect `401`), a forged or stale token (`bearer: "not-a-real-token"`, expect `401`), someone else's id (step 6). Use `expect: denied` when any 4xx refusal is fine (a `5xx` fails it: a crash is not a refusal), an exact status when the status is the contract. A session of three or more steps with no refusal step at all (no `abuse:`, no `expect: denied`, no expected `4xx`; a misstep expecting `422` counts) gets lint JL013.

**6. Test two users: isolation.** Setup gives you user A. Create user B inside the journey with a unique email in `vars:` and the fragment from step 2, then try everything B must not do:
```yaml
vars: { b_email: "qa-b+{rand}@example.test" }
steps:
  - use: create_draft_invoice
  - use: second_user_signs_in
  - { intent: B tries to open A's invoice, abuse: cross-customer read, method: GET,
      path: "/invoices/{invoice_id}", bearer: "{b_token}", expect: { status: 404 } }
  - { intent: "B's list does not include A's invoice", method: GET, path: /invoices,
      bearer: "{b_token}", expect: { status: 200, body: { items: { not_contains: "{invoice_id}" } } } }
  - { intent: B tries to delete A's invoice, abuse: cross-customer delete, method: DELETE,
      path: "/invoices/{invoice_id}", bearer: "{b_token}", expect: denied }
  - { intent: "A's invoice is untouched", method: GET, path: "/invoices/{invoice_id}",
      bearer: "{token}", expect: { status: 200, body: { status: draft, owner_id: "{user}" } } }
```
The last step matters most: a refused delete that deleted anyway is the bug. Multi-tenant products (orgs, workspaces): setup creates a fresh org per journey (SOP 05); B creates their own org inside the journey and tries to reach into A's.

**7. Add the edge inputs.** Decide with Maya what `invoicer` *should* do first; uj checks the rule, it does not invent it.

| input | Acme example | expect |
|---|---|---|
| unicode | `customer: "{cust}"` with `vars: { cust: "Zoë Café 東京 {rand}" }` | `201`, then `body: { customer: "{cust}" }` on the re-read |
| empty / missing | `body: {}` | `{ status: 422 }` |
| duplicate | sign up again with `{email}` (setup's user) | `{ status: 409 }` |
| forged / expired token | `bearer: "not-a-real-token"` | `{ status: 401 }` |
| boundaries | `amount: 0`, `amount: -50`, a three-letter currency nobody uses | the rule you wrote down |
| huge | a 200 KB customer name | `413` or `422`, never `500` |

A huge body is impractical in YAML. Build it in a `run:` step (SOP 10 explains `run:` steps):
```yaml
  - intent: a 200 KB customer name is refused cleanly
    run: |
      big=$(head -c 200000 /dev/zero | tr '\0' 'a')
      code=$(printf '{"customer":"%s","amount":1,"currency":"EUR"}' "$big" |
        curl -s -o /dev/null -w '%{http_code}' -X POST "{base}/invoices" \
          -H "Authorization: Bearer {token}" -H 'Content-Type: application/json' --data-binary @-)
      echo "status $code"; [ "$code" = 413 ] || [ "$code" = 422 ]
    expect: { exit: 0 }
```

**8. Hunt ordering and state bugs.** Do things in the order real people do them, then out of order: delete, then open (`expect: not-found`), list (`items: { not_contains: "{invoice_id}" }`) and send from the old tab (`misstep: true`, `expect: denied`). Send twice. Re-read after every write. These need `kind: epic`, which keeps state between steps and stops at the first failure. Long sessions stay long: when step 17 fails, `--run-id` and `--resume` retry from there with state intact (SOP 11).

**9. Close the gap and check it.**
```sh
uj coverage
uj explain journeys/sessions/MONTH_END_BILLING.yaml
uj lint journeys/
uj validate journeys/
```
The risk you wrote for leaves the GAPS list. A risk with one session is thin; a journey with no `covers:` is untracked. When a session finds a bug, add a dated line to `.uj/findings.md` (SOP 14).

## What you'll see

`uj fragments journeys/`:
```
Fragment library — 3 reusable normal-activity blocks under journeys/

[auth]
  second_user_signs_in     2 step(s)  needs {b_email}, {pass} → provides {b_token}  #setup #security
[invoices]
  browse_invoices          1 step(s)  needs {token} → provides —  #read
  create_draft_invoice     1 step(s)  needs {token} → provides {invoice_id}  #mutate

compose with `use: <name>` (resolves by name across grouped sub-folders)
```
`uj explain` tags fragment steps with their name (`1. [browse_invoices] they glance at their invoice list`), marks missteps with `~ (a wrong turn — the user fumbles here, then recovers)` and abuse with `↳ must refuse: …`. `uj coverage` on Acme's four journeys lists each covered risk with `N session(s)`, then:
```
GAPS — 2 registered risk(s) with no journey (.uj/risks.context):
  · amount-accuracy              P0  the amount on a sent invoice differs from the amount typed
  · invoice-email                P1  the client never receives the invoice email

4 behavior(s) covered across 4 session(s)
```
`uj lint` ends `OK — no critical/high findings`; `uj validate` ends `validate: 4 ok, 0 invalid`. Missteps and refusals asserting only a status are not flagged by JL004: there the status is the contract.

## If it goes wrong

- `fragment "create_draft_invoice" not found (searched fragments/ trees from journeys upward)` — wrong name, or the fragment is not under a `fragments/` folder at or above the journey. The name is the file name without `.yaml`.
- `fragment cycle: …` / `fragment nesting too deep (>10): …` — a fragment uses itself, directly or through others. Flatten it.
- `yaml: line N: did not find expected ',' or '}'` — a `[0]` inside `{ … }`. Quote the path: `capture: { message_id: "$.items[0].id" }`.
- `capture refused (append-only): <name>` at run time — two steps capture the same name, often the same fragment used twice in one journey. Write the second one inline with a new name (`invoice_id_2`).
- `unresolved {b_email} — …` (VOID) — a fragment needs a var nobody set. Add it to `vars:` before the `use:`.
- `expected a refusal (4xx), but the service errored with 500 — a crash is not a refusal` — the attack crashed the service. A real bug; keep it red.
- `JL013` `no refusal step — add one where an outsider or a wrong input must be REFUSED (abuse: + expect: denied); negative space is the most-skipped check` — the session never checks that something is refused. Add step 5's no-login check at least.
- A misstep or abuse step goes green when it should not, or red when it should be refused: read the response (SOP 11), confirm the rule with Maya, then fix the product, never the expectation (SOP 14).

## Coming

- **Fragment parameters** (`use: create_draft_invoice` with `customer: Initech`). *Today:* fragments read Context vars; set them in `vars:` and write the fragment against `{name}`.
- **`needs:`/`provides:` enforced.** *Today:* documentation for `uj fragments`; JL001 still catches an unknown `{var}` after expansion.
- **The same fragment twice in one journey.** *Today:* captures are append-only; inline the second copy with new capture names.
- **Data-driven steps** (one step, a table of edge inputs). *Today:* one step per input, or a `run:` loop.
- **Generated payloads** (huge, random, fuzzed bodies). *Today:* a `run:` step as in step 7.
- **Time travel** (an invoice due yesterday, a token that expired an hour ago). *Today:* a forged token for "expired"; anything date-based needs a test hook in your API.

## Next

SOP 10, end to end across services and the UI. Or SOP 11 to run these and read the verdicts.
