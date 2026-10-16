# 15 · Check the API contract and catch drift

**What this is for.** Two questions about your API's promises. Does your OpenAPI document actually describe your endpoints, and does it still match what the service returns? And when a field is renamed, dropped or changes type, does a test go red before a customer's integration does? `uj contract` answers the first from the spec (and, optionally, a recording of real traffic). `expect.schema` in a journey answers the second on every run. The example is Acme's `invoicer` (Acme's API; yours will differ), whose invoices carry `id, status, customer, amount, currency, owner_id, created_at`.

**Before you start.** A project (SOP 04) with targets `dev` (`http://localhost:8080`) and `staging` (`https://invoicer.staging.acme.example`). Your OpenAPI document, JSON or YAML, either served at `<target>/openapi.json` or as a file in the repo. Journeys you already run (SOP 07). Work against `dev` or `staging`, never production.

## Steps

**1. Get the spec as a file, so the result does not depend on who runs it.**
```sh
curl -fsS http://localhost:8080/openapi.json -o openapi.json
```
Commit it, or regenerate it in CI. `uj contract` reads a file path or an `http(s)` URL, JSON or YAML (`--spec openapi.yaml` works as is). With no `--spec` it fetches `/openapi.json` from the project's default target (or `$UJ_BASE`); `uj contract --target staging` fetches `https://invoicer.staging.acme.example/openapi.json`. A spec served at another path (such as `/openapi.yaml`) needs `--spec <url>`.

**2. Check completeness.**
```sh
uj contract --spec openapi.json
```
For every endpoint uj checks two things: is a 2xx response body documented, and (for `POST`/`PUT`/`PATCH`) is a request body documented. Each gap is listed with its reason. A `POST` that takes no body (Acme's `POST /invoices/{id}/send`) is still listed as `no request schema`; that is expected, and you can note it and move on.

**3. Compare two versions of the spec (parity).**
```sh
uj contract --spec openapi.json --parity https://invoicer.staging.acme.example/openapi.json
```
"this" is `--spec`, "other" is `--parity`. uj lists endpoints that exist in both but where one documents a request or response body and the other does not. Use it before a release (your branch vs staging) or during a rewrite (old service vs new). It does **not** compare fields, types or which endpoints exist; step 4 and step 6 cover those.

**4. Spot added, removed and renamed things with a plain diff.**
```sh
diff <(jq -r '.paths | to_entries[] | .key as $p | .value | keys[] | "\(ascii_upcase) \($p)"' openapi.json | sort) \
     <(jq -r '.paths | to_entries[] | .key as $p | .value | keys[] | "\(ascii_upcase) \($p)"' openapi_next.json | sort)
diff <(jq -S . openapi.json) <(jq -S . openapi_next.json)
```
The first lists endpoints that appeared or disappeared; the second shows every schema change, including a renamed field. `openapi_next.json` is the new version (your branch's build, or a copy fetched from staging).

**5. Check real responses against the spec (conformance + coverage).**
Record a session as a HAR file: your browser's developer tools (Network tab, save as HAR) or a recording proxy in front of `dev`. Then:
```sh
uj contract --spec openapi.json --har session.har
```
uj validates each recorded JSON response against the endpoint's documented success schema, and counts how many spec endpoints the session touched. Record successful calls: uj does not read the status in the HAR, so a recorded `401` body is checked against the success schema and shows as non-conformant.

**6. Pin the contract inside the journeys that matter.** Add `expect.schema` to the steps a client depends on:
```yaml
  - intent: they create an invoice for a client
    method: POST
    path: /invoices
    bearer: "{token}"
    body: {customer: "Globex", amount: 120, currency: "EUR"}
    capture: {invoice_id: $.id}
    expect:
      status: 201
      schema:
        type: object
        required: [id, status, customer, amount, currency, owner_id, created_at]
        properties:
          id: {type: string}
          status: {type: string}
          amount: {type: number}
          currency: {type: string}
```
The check is tolerant: listed fields must be present with the right type; extra fields are fine (adding a field is not a breaking change). Nested objects use `properties`; lists use `items`, and every element is checked. If `type` is left out, `required` or `properties` means object and `items` means array. A dropped or renamed field fails `required`; a retyped field fails `type`. After an intentional rename, add `absent: [amount]` to prove the old name is really gone. Then `uj lint` and `uj validate` (SOP 07) and run it.

**7. Document the gaps instead of ignoring them, and gate on them in CI.** Save the completeness report next to the spec (`uj contract --spec openapi.json > contract-report.txt`) and diff it in pull requests, so the count of under-documented endpoints only goes down. To fail the build when documentation slips, set a floor:
```sh
uj contract --spec openapi.json --min-documented 85
```
It exits `1` when fewer than 85% of endpoints document a `2xx` response. Start at today's number (Acme: 88%) and raise it as you document more (SOP 12).

## What you'll see

Completeness, on Acme's spec (output captured from a local file):
```
== completeness (openapi.json) ==
  endpoints: 8 · 2xx response documented: 7/8 (88%) · request body documented: 3/4 POST-likes (75%)
  under-documented endpoints: 1
    POST   /invoices/{id}/send                           no request schema + no 2xx response schema
```
Parity, against a newer spec that documents the send response but dropped the single-invoice response:
```
== documentation parity (this spec vs openapi_next.json) ==
  endpoints documented differently: 2
    GET /invoices/{id} — response schema: this=true other=false
    POST /invoices/{id}/send — response schema: this=false other=true
```
Conformance, when the service already returns `total` but the spec still says `amount`:
```
== conformance (5 captured responses vs documented schemas) ==
    ✗ POST   /invoices                                $: missing required field "amount"
    ✗ GET    /invoices/{id}                           $: missing required field "amount"
    ✗ GET    /invoices                                $.items[0]: missing required field "amount"
  checked 5 responses against their schema · 3 non-conformant

== coverage (from this HAR) ==
  5/8 endpoints exercised (62%)
```
Exit codes: `0` for completeness and parity results (gaps are a backlog, not a failure); `1` when any HAR response is non-conformant, or completeness is below `--min-documented`, which adds a last line such as `FAIL — 88% of endpoints document a 2xx response; --min-documented is 90%`; `2` when a file or URL cannot be read. In a journey, a broken contract is a **FAIL** whose reason reads `response contract violated: $: missing required field "amount"` (or `$.amount: expected number, got string` for a type change); only the first violation is shown.

## If it goes wrong

- `uj contract: no spec — pass --spec <openapi.json file or URL>, or set a target in harness.toml (then <target>/openapi.json is used)` — no `--spec` and no target. Pass `--spec`.
- `uj contract: open openapi.json: no such file or directory` — wrong path; run from the folder that holds it or give the full path.
- `uj contract: yaml: line 1: did not find expected node content` (or another `yaml: line N:` message) — the file is neither valid JSON nor valid YAML, often a truncated download. Fetch it again.
- `uj contract: Get "<target>/openapi.json": …` — with `--target` or no `--spec`, the target does not serve its spec there. Pass `--spec <url>`.
- `FAIL — 88% of endpoints document a 2xx response; --min-documented is 90%` — exit `1`; document the endpoints listed above it, or agree a lower floor.
- `uj contract --parity: …` / `uj contract --har: …` — the second spec or the HAR could not be read; same fixes.
- Parity shows nothing, but you know a field was renamed — expected: parity compares only whether bodies are documented. Use step 4's diff and step 6's schema.
- Every HAR response is `✗` — the HAR holds error responses, or the spec is stale. Record successful calls; if the service is right, update the spec.
- `response is not JSON, cannot check schema` — the step's response has no JSON body (a `204`, HTML error page). Drop `schema` from that step or fix the expected status.
- A schema that should fail passes — `$ref` is not followed inside a journey (write fields inline), and `enum`, `format` and `pattern` are not checked. Pin exact values with `body:` (SOP 08).
- A schema fails on a `null` the API is allowed to send — `null` passes a `type` only where that property says `nullable: true`, as in OpenAPI 3.0. Add it to the property (SOP 08 step 6).

## Coming

- **Field-level breaking-change diff** (renamed, removed, retyped fields; endpoints only in one spec) in `--parity`. *Today:* step 4's `diff` + `jq`.
- **The list of endpoints a HAR did not touch.** uj prints only the count. *Today:* compare the HAR's URLs with step 4's endpoint list.
- **Endpoint coverage from your journeys**, not only from a HAR. *Today:* `uj coverage` for risks (SOP 06) and a HAR recorded while you click through.
- **Status-aware conformance** (check error bodies against documented error schemas). *Today:* record successful calls only.
- **`$ref`, `enum` and `format` in `expect.schema`.** *Today:* inline fields + `body:` for exact values.

## Next

SOP 14, edit and maintain journeys when the API changes. Or SOP 16 for speed instead of shape.
