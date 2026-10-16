# 08 · Write checks that catch real bugs

**What this is for.** Making each step prove something a customer would notice, so a broken `invoicer` turns red instead of passing on a `200` with a wrong body. Every `expect:` form uj has, with Acme examples, plus how to tell a real bug from a wrong expectation.

**Before you start.** SOP 07 (a journey with steps). Acme's API (yours will differ): a created invoice is `201 {id, status: "draft", customer, amount, currency, owner_id, created_at}`; lists are `200 {items: [...]}`; missing or someone else's invoice is `404`; no token is `401`. Setup gives `{token}`, `{user}` and `{pass}` (SOP 05).

## Steps

**1. Find the value moment.** Each journey has one step that is the reason it exists (the invoice reaches `sent`; the stranger is refused). Give that step the strongest checks. Every other successful step still checks more than its status.

**2. Status: exact, or a plain-language alias.** `expect: { status: 201 }` passes only on `201`. With no `status`, any 2xx passes. Aliases, written as `expect: created`:

| alias | passes when |
|---|---|
| `success`, `ok` | any 2xx |
| `created` | `201` |
| `not-found`, `notfound` | `404` |
| `denied`, `forbidden`, `refused`, `unauthorized` | any 4xx; a `5xx` fails, because a crash is not a refusal |

**3. Fields that must be there.** `fields: [id, created_at]` fails if a key is missing.

**4. Values that must match.** `body:` keys are paths: `status`, `customer.name`, `items[0].id` (a leading `$.` is fine). Values are interpolated and compared as text, so `amount: 1200` matches `1200`.
```yaml
expect: { status: 201, body: { status: draft, customer: "{client}", amount: 1200, owner_id: "{user}" } }
```

**5. Is it in the list?**
```yaml
expect: { status: 200, body: { items: { contains: "{invoice_id}" } } }
```
`contains` passes when the array holds that value, or holds an object with a field equal to it (Acme's `items` are objects with an `id`). `not_contains` is the opposite. On a string field both are substring checks.

**6. The contract: shape, not just values.** A tolerant schema catches a dropped, renamed or retyped field; extra fields are allowed.
```yaml
expect:
  status: 201
  schema:
    required: [id, status, customer, amount, currency, owner_id, created_at]
    properties:
      id:         { type: string }
      amount:     { type: number }
      created_at: { type: string }
```
It checks `required`, `type`, nested `properties` and array `items`. A `null` value fails a `type` unless that property says `nullable: true` (for example `paid_at: { type: string, nullable: true }` on a draft). The whole API against its spec is SOP 15.

**7. What must NOT be in the response.** `absent: [password, owner.password]` fails if those paths exist. `notcontains: ["{pass}"]` fails if the raw body contains that text anywhere, here the customer's password (`not_contains:` is accepted too).

**8. Headers.** `headers: { Content-Type: application/json }` passes when the header contains that text; `""` means "present at all".

**9. A latency budget.** `within: "800ms"` fails the step if the request took longer. Write a duration (`800ms`, `2s`); `uj validate` refuses anything else. One user, one request: a budget, not a load test (SOP 16).

**10. Refusals: say exactly how.** Prefer the exact status: `{ status: 401 }` for no token, `not-found` when another customer opens your invoice. `denied` accepts any 4xx and fails on a `5xx`; use it when several refusal codes are all correct (`401`, `403` or `404`).
```yaml
  - intent: another customer tries to open the invoice
    abuse:  another customer must never read this invoice
    method: GET
    path:   /invoices/{invoice_id}
    bearer: "{b_token}"
    expect: not-found
```

**11. Certificates count too.** uj verifies TLS certificates on every journey request. An expired or wrong certificate on `https://invoicer.staging.acme.example` means no response, so the journey is VOID with the reason, never a silent PASS. For a dev target with a self-signed certificate only, `export UJ_INSECURE_TLS=1`.

**12. `run:` steps check an exit code.** `run:` runs a shell command (through `bash`); `expect: { exit: 0 }` is the default. Use it for checks outside the API, such as a database query in `dev`. Review any `run:` step written by someone else before you run it: it executes on your machine.

**13. Prove something is gone.** One `204` proves nothing; check from where the customer looks:
```yaml
  - intent: the customer deletes the draft
    method: DELETE
    path:   /invoices/{invoice_id}
    bearer: "{token}"
    expect: { status: 204 }
  - intent: it is gone when they open it
    method: GET
    path:   /invoices/{invoice_id}
    bearer: "{token}"
    expect: not-found
  - intent: it is gone from their list
    method: GET
    path:   /invoices
    bearer: "{token}"
    expect: { status: 200, body: { items: { not_contains: "{invoice_id}" } } }
```

**14. Let lint find the weak spots.**
```sh
uj lint journeys/
```
JL004 marks a successful step that checks only its status; refusal, error-path, `abuse:` and `misstep:` steps are exempt, because there the status is the contract. JL010 marks `{rand}` inside `expect:`; it is a new value each time, so it can never match. Set it once in `vars:` and reuse the name.

**15. On a FAIL, decide: bug or wrong expectation.** Read the step's reason and the `↳ response:` line under it (SOP 11). Then check the product's promise, not the test: Acme's docs say a new invoice is `draft`; if the API says `pending`, that is a bug or a contract change for Maya and Dev to decide. Change the expectation only when the product decision changed, in the same review as the API change. Never loosen a check just to get green (SOPs 14, 19).

## What you'll see

A failed check names itself. The reasons uj prints, with your values in place of the placeholders:

| check | FAIL reason |
|---|---|
| status | `status <got>, wanted <want>` (`2xx` when no status was set) |
| refusal | `expected the request to be REFUSED, but got <status>` · `expected a refusal (4xx), but the service errored with <status> — a crash is not a refusal` |
| fields | `response missing expected field: <name>` |
| body value | `field "<path>" = "<got>", wanted "<want>"` |
| body path | `` no field at "<path>" in the response (wanted "<want>") — check the path; list items are e.g. items[0].id, or use `items: {contains: ...}` `` |
| contains | `field "<path>" = "<got>", wanted to CONTAIN "<x>"` |
| not_contains | `field "<path>" = "<got>", wanted to NOT contain "<x>"` |
| schema | `response contract violated: <first violation>`, or `response is not JSON, cannot check schema` |
| absent | `field must be ABSENT but was present: <path>` |
| notcontains | `response must NOT contain "<text>" (but it does)` |
| headers | `response missing expected header: <name>` · `header "<name>" = "<got>", wanted to contain "<want>"` |
| within | `took <time>, wanted within <budget>` |
| run exit | `run exit <got>, wanted <want> — <first line of output>` |

Secrets are masked as `***redacted***` in all of it. Lint findings look like `warn     JL004  journeys/<file>.yaml [step 3]` followed by the advice line.

## If it goes wrong

| you see | it means | do |
|---|---|---|
| `expected a refusal (4xx), but the service errored with 500 — a crash is not a refusal` | the abuse attempt crashed the service | a real bug: keep it red and report the crash |
| `` `{rand}` inside expect: makes a NEW value each time it appears, so it never matches what the request sent — … `` (JL010) | `{rand}` in a check | move it to `vars:` |
| `no field at "items.id" …` | a list addressed like an object | `items[0].id`, or `items: { contains: … }` |
| `field "amount" = "1200.00", wanted "1200"` | the API sends the amount as a string; values are compared as text (a JSON number `1200.0` would match) | match the API's exact form, or check the type with `schema` |
| `` asserts only status — … `` (JL004) on a read | the step proves little | add `fields`, `body` or `schema` |
| ``<file>: unknown key "expct" — not a uj field (typo?); see `uj schema journey` or `uj schema environment` `` | a misspelled key; the file does not load | fix the key; the editor schema line flags it (SOP 07 step 12) |
| `<ID>: step N within: "fast" is not a duration (use e.g. "800ms" or "2s")` | a budget uj cannot read | write `800ms` or `2s` |
| a schema check fails on `null` | the field is legitimately empty sometimes | add `nullable: true` to that property, if the API promises it |
| VOID with `no response from the service (…)` on an `https` target that is up | the certificate did not verify | fix the certificate; `UJ_INSECURE_TLS=1` only for a self-signed dev target |
| a FAIL you are sure is "just the test" | maybe, maybe not | step 15; never weaken a check to go green |

## Coming

- **Number comparisons and ranges** (`amount > 0`, between). *Today:* exact values, and `type: number` in `schema`.
- **Pattern matches** (regex) and **list length**. *Today:* `contains` for substrings and members; `items[N].id` for a position.
- **`enum` and `format` in `schema`.** *Today:* `required`, `type`, `properties`, `items`; put allowed values in `body:`.
- **"Eventually" checks** (poll until true). *Today:* a `run:` step with a retry loop (SOP 10).

## Next

SOP 09, realistic sessions and edge cases. Or SOP 11 to run and read the verdicts.
