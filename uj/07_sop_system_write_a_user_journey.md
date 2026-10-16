# 07 · Write a user journey, from intent to first run

**What this is for.** Turning one chosen promise (SOP 06) into a journey file that Maya can read top to bottom and uj can run: the story, the steps as plain intents, the mechanics under each intent, the checks, the cleanup, then explain, lint, validate and the first run. The example is Acme's "a customer sends their first invoice".

**Before you start.** SOP 04 (project), SOP 05 (setup gives every journey `{token}` and `{user}`), SOP 06 (you know the outcome and which risk ids from `.uj/risks.context` it covers; read `.uj/conventions.context` for the team's naming and folders). Acme's API (yours will differ): `POST /invoices` returns `201 {id, status: "draft", customer, amount, currency, owner_id, created_at}`; `GET /invoices/{id}`; `POST /invoices/{id}/send` returns `200 {id, status: "sent"}`; `GET /invoices` returns `200 {items: [...]}`; `DELETE /invoices/{id}` returns `204`; no token returns `401`. Write against `dev`.

## Steps

**1. Scaffold.**
```sh
uj new journey "A customer sends their first invoice"
```
It writes `journeys/A_CUSTOMER_SENDS_THEIR_FIRST_INVOICE.yaml` (the file name and `id` come from the title), works from any sub-folder of the project, and never overwrites. A long title makes a long name; choose a shorter one with `--id`: `uj new journey "A customer sends their first invoice" --id SEND_INVOICE` writes `journeys/SEND_INVOICE.yaml` with `id: SEND_INVOICE` (upper-cased, spaces become `_`). The file starts with tips and placeholders in `<…>` and example `/TODO` paths; replace every one. Until you do, `uj lint` reports JL012.

**2. Write the story (Maya).** `outcome` (a change in the customer's world), `persona` (who, and why now), `narrative` (a few sentences of prose), `success` (what a PASS proves), `covers` (risk ids from `.uj/risks.context`, for `uj coverage`), and optionally a journey-level `abuse:` naming the one thing that must never happen. SOP 06 step 9 shows how.

**3. Write every step as an intent first (Maya).** One line per thing the person does, no HTTP yet: drafts an invoice for their client · opens it to check · sends it · sees it in their list · a stranger tries to open it. Each becomes `- intent: …`. Every step must have one; uj refuses a file without.

**4. Fill the mechanics under each intent (Dev).** The finished Acme journey:
```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/ab0t-com/uj/main/schemas/journey.schema.json
id: A_CUSTOMER_SENDS_THEIR_FIRST_INVOICE
kind: epic
outcome: "a new Acme customer gets paid for their first job without help"
persona: "a freelancer who signed up this morning and has one client to bill"
narrative: |
  They create a draft invoice for their client, check it looks right, and send it.
  They expect the invoice to show up in their list as sent. If a stranger could open it,
  they would never put a client's details in Acme again.
success: "the invoice is in the customer's list, marked sent; an anonymous caller is refused"
covers: [activation, send-integrity]   # an anonymous refusal proves sign-in, not isolation (that needs a 2nd customer: SOP 09)
abuse: "a stranger reads a customer's invoice"
conflicts: tenant

vars:
  client: "Globex {rand}"

steps:
  - intent: the customer drafts an invoice for their client
    method: POST
    path:   /invoices
    bearer: "{token}"
    body:   { customer: "{client}", amount: 1200, currency: "EUR" }
    capture: { invoice_id: $.id }
    expect: { status: 201, body: { status: draft, customer: "{client}", currency: EUR } }

  - intent: they open it to check the details before sending
    method: GET
    path:   /invoices/{invoice_id}
    bearer: "{token}"
    expect: { status: 200, body: { id: "{invoice_id}", amount: 1200 } }

  - intent: they send it
    method: POST
    path:   /invoices/{invoice_id}/send
    bearer: "{token}"
    expect: { status: 200, body: { status: sent } }

  - intent: it shows up in their list
    method: GET
    path:   /invoices
    bearer: "{token}"
    expect: { status: 200, body: { items: { contains: "{invoice_id}" } } }

  - intent: someone who is not logged in tries to open it
    abuse:  an anonymous caller must not see a customer's invoice
    method: GET
    path:   /invoices/{invoice_id}
    bearer: "none"
    expect: { status: 401 }

finally:
  - intent: remove the invoice this journey created
    method: DELETE
    path:   /invoices/{invoice_id}
    bearer: "{token}"
```
- `method` + `path`: the path is joined to the target. `kind: epic` runs the steps in order, shares state, and stops at the first failure.
- `bearer: "{token}"` sends `Authorization: Bearer …`. `bearer: "none"` sends no token; leaving `bearer` out does the same, but write `"none"` so readers see it is deliberate.
- `body` is written as an object, no escaping. `ctype: form` sends it form-encoded instead of JSON.
- `conflicts: tenant` says this journey touches only its own data, so `--parallel` runs it alongside anything (SOP 12).
- Every key must be a uj field: a typo such as `expct:` stops the file from loading instead of being ignored. A top-level key starting with `_` (`_note: …`) is a comment.

**5. Pass state forward.** `capture: { invoice_id: $.id }` stores the response's `id`; later steps use `{invoice_id}`. Captures are append-only: a later step cannot overwrite a name. Prefix `secret:` to mask a value (`"secret:token": $.access_token`). `{rand}` makes a new value **every** time it appears, so set it once in `vars:` (`client: "Globex {rand}"`) and use `{client}` in both the request and the check. `{env:NAME}` reads an environment variable; `{base}` is the target URL.

**6. Assert what the customer would notice.** Every successful read or write checks more than the status: a `body` value, `fields`, or a `schema`. Refusals check the exact status. SOP 08 has every form.

**7. Clean up in `finally:`.** It always runs, even after a failure. A cleanup step with no `expect` also accepts `404` (already gone). If the create step got a `201` but a check failed, its capture is still kept, so cleanup can delete what was made. A cleanup step that fails for another reason (say `409` because a sent invoice cannot be deleted) shows `✗` in the output but never changes the verdict; give it an `expect` with the status your API really returns, or clean up in a way your API allows.

**8. Read it back as a story.**
```sh
uj explain journeys/A_CUSTOMER_SENDS_THEIR_FIRST_INVOICE.yaml
```
If Maya cannot follow it, fix the intents, not the mechanics.

**9. Lint it.**
```sh
uj lint journeys/A_CUSTOMER_SENDS_THEIR_FIRST_INVOICE.yaml
```
Advisory nudges, no service needed. Treat each as a design question (SOP 06, SOP 08). JL012 means scaffold placeholders are still in the file. JL013 means a journey of three or more steps has no step that must be refused; step 5 of the journey above is that step.

**10. Validate it.**
```sh
uj validate journeys/A_CUSTOMER_SENDS_THEIR_FIRST_INVOICE.yaml
```
It checks the file loads: every key is a known field, every step has an intent and a method (or `run:` / `browser:`), every `expect` is known, and every `within:` is a real duration (`800ms`, `2s`).

**11. First run, against `dev`.**
```sh
uj doctor
uj run journeys/A_CUSTOMER_SENDS_THEIR_FIRST_INVOICE.yaml
```
`doctor` first (it creates one setup customer, SOP 05), then the run. The run creates real records on the target; never point it at production. Trying something throwaway? `uj run scratch.yaml --no-history` keeps it out of run history. Reading verdicts in depth is SOP 11.

**12. Turn on editor autocomplete.** Files from `uj new` already start with the `# yaml-language-server: $schema=…` line; an editor with YAML language-server support (for example VS Code's YAML extension) then completes and underlines keys. Offline:
```sh
uj schema journey > journey.schema.json
```
and point the first line at it: `# yaml-language-server: $schema=../journey.schema.json`. `*.schema.json` files are never collected as journeys.

## What you'll see

`uj new` prints `wrote <path>/journeys/A_CUSTOMER_SENDS_THEIR_FIRST_INVOICE.yaml` (relative to where you stand, or absolute from outside the project) and a `next:` list (explain, lint, run). `uj lint` on the untouched scaffold: `warn     JL012` with `8 place(s) still hold scaffold placeholders (<…> text or /TODO paths) — replace them with the real story and endpoints`, an `info     JL007` about `conflicts:`, and `(journey authoring: 2 advisory finding(s))`. `uj explain` on the finished file prints the outcome, persona, narrative, `Must never happen: a stranger reads a customer's invoice`, `Success means: …`, `Runs alongside other journeys (touches only its own data)`, then `The story:` with numbered intents, `↳ must refuse: an anonymous caller must not see a customer's invoice` under step 5, and `Always, even on failure:` with the cleanup.

`uj lint` on the journey above:
```
lint: 1 journey file(s) + 0 bash-UJ file(s) · 0 critical/high finding(s), 0 authoring advisory — critical=0 high=0 medium=0 low=0
OK — no critical/high findings
```
`uj validate`: `✓ journeys/A_CUSTOMER_SENDS_THEIR_FIRST_INVOICE.yaml [journey]` and `validate: 1 ok, 0 invalid`.

`uj run` starts with `(target: <url> — from <source>)` and `(environment: environment.json)`, prints one line per step (`✓`, `✗`, or `–` for skipped, with `[METHOD status]`), the verdict line `### UJ-VERDICT v1 {"id":"A_CUSTOMER_SENDS_THEIR_FIRST_INVOICE","result":"pass",…}`, and the summary `journeys: N passed · N failed · N skip/void/inconclusive`. Exit `0` pass, `1` FAIL, `2` VOID.

## If it goes wrong

| you see | it means | do |
|---|---|---|
| `uj new: journeys/<FILE>.yaml already exists — pick another name (nothing overwritten)` | same title twice | another title |
| `<ID>: step N missing intent (every step must state what it means)` | a step with no `intent:` | add it |
| `<ID>: step N needs a method (HTTP), a run: command, or a browser: action` | mechanics missing | add `method` + `path` |
| `unknown expect alias "<x>" (use success\|denied\|not-found\|created or an object)` | typo in `expect:` | one of those, or an object |
| `references {invoce_id} which is not a fixture/journey var or a prior capture (typo? or an environment export)` (JL001) | a typo'd name | fix it; at run time it would VOID |
| `` capture session_token looks like a secret — prefix it `secret:` so it's redacted in evidence `` (JL006) | an unmasked secret | `"secret:session_token"` |
| `FAIL — 1 file(s) do not parse (cannot be tested); fix the syntax first` | YAML syntax error (JL000) | fix indentation or quoting |
| VOID with `unresolved {token} — not provided by environment.json setup, …` | setup gives no `{token}` | SOP 05, or sign up in the journey |
| ``<file>: unknown key "expct" — not a uj field (typo?); see `uj schema journey` or `uj schema environment` `` | a misspelled key | fix it; the schema line (step 12) underlines it as you type |
| `<ID>: step N within: "fast" is not a duration (use e.g. "800ms" or "2s")` | a budget uj cannot read | `800ms`, `2s` |
| `JL012 … place(s) still hold scaffold placeholders` | `<…>` text or `/TODO` paths left from `uj new` | fill them in |
| `JL013` `no refusal step — add one where an outsider or a wrong input must be REFUSED (abuse: + expect: denied); negative space is the most-skipped check` | nothing in the session must be refused | add an `abuse:` step with `expect: denied` or the exact `4xx` (SOP 06 step 8) |

## Coming

- **A dry run** that prints each resolved request without sending it. *Today:* `uj explain` + `uj lint`.
- **Drafting journey steps from an OpenAPI operation.** *Today:* `uj init --openapi` drafts setup only; write steps by hand.

## Next

SOP 08, assertions that catch bugs. Then SOP 11 to read the first run's verdict.
