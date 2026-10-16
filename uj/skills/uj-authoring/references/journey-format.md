# Journey file — full field reference

A journey is YAML or JSON with the same model. Table of contents:
- [Journey (top level)](#journey-top-level)
- [Step](#step)
- [Expect](#expect)
- [Interpolation & capture](#interpolation--capture)
- [Environment](#environment-config-driven)

## Journey (top level)

| Field | Type | Notes |
|---|---|---|
| `id` | string | REQUIRED. Stable identifier; used in the verdict + run dirs. |
| `kind` | string | `single` or `epic`. Epic = ordered, shares state, aborts on first failure. |
| `outcome` | string | the BUSINESS OUTCOME this journey is for — a change in the person's world, NOT a task. Brainstorm first. Lint JL009 flags a task-shaped outcome. |
| `persona` | string | who is living this + their circumstance/motivation. |
| `narrative` | string | the prose story, start to finish (multi-line `\|`). `explain` renders outcome→persona→narrative. |
| `success` | string | Observable proof the outcome held (PMM-facing; lint JL008). |
| `tags` | string[] | selectors for `run --tag`/`--persona` (e.g. [founder, security]). |
| `covers` | string[] | risks/behaviors this journey exercises — feeds `uj coverage`. |
| `conflicts` | string | Only for `run --parallel`: `tenant` = touches only its own fresh data; `global:<name>` = shared state (same key never runs concurrently). Lint JL007. |
| `capability` | string[] | Required capabilities (e.g. `[enterprise]`). Absent → SKIP, never a false verdict. |
| `flow` | string | Optional grouping label (shown by `explain`). |
| `vars` | map | Journey-declared vars; values may reference earlier vars + `{rand}`. |
| `steps` | Step[] | The ordered steps. |
| `finally` | Step[] | Teardown; ALWAYS runs (even after a failure); not counted toward pass/fail. With no explicit `status`, a cleanup also accepts 404 (already gone). |

## Step

| Field | Type | Notes |
|---|---|---|
| `intent` | string | REQUIRED. What a person is doing (lint enforces it). Line 1 of every step. |
| `abuse` | string | Security negative-space: what an ATTACKER does that must be REFUSED. |
| `misstep` | bool | a LEGIT user's wrong turn (fumble) — expects friction then a recovery step; distinct from `abuse`. `explain` marks it. |
| `method` | string | HTTP method. Omit only when using `run`. |
| `path` | string | URL path; `{vars}` + `{rand}` interpolated; joined to `--base`. |
| `body` | object OR string | Request body. Write it as an OBJECT (no escaping) — or a JSON string (legacy). |
| `ctype` | string | `json` (default) or `form` (form-encodes the body; e.g. token/introspect). |
| `bearer` | string | Interpolated bearer token: `"{token}"`, or `"none"`/`""` for no auth. |
| `use` | string | COMPOSE: inline the steps of `fragments/<name>.(yaml\|json)` here (a reusable functional block). Shares the Context; `explain` expands it; provenance-tagged `[name]`. Cycle-detected. |
| `run` | string | ESCAPE HATCH: a shell command (interpolated). No HTTP; asserted via `expect.exit`. Can `capture:` from JSON stdout. |
| `browser` | object | UI step: `{open, click, type, into, expect_text}`. Dispatched to `UJ_BROWSER_CMD`; gate the journey on `capability: [browser]` so it SKIPs where no agent is configured. |
| `capture` | map | `name -> "$.jsonpath"`. Append-only. Prefix a key `secret:` to redact its value. Works on HTTP, `run:` (JSON stdout), and `browser:` steps. |
| `expect` | Expect | The assertion (below). |

A step is either an HTTP step (`method`+`path`) or a `run:` step — `Load` requires one of them plus
an `intent`.

## Expect

`expect` may be a STRING alias or an OBJECT.

String aliases: `success` (2xx), `denied` (4xx, i.e. `deny:true`), `not-found` (404), `created` (201).

Object fields (all optional; combine them):

| Field | Type | Passes when |
|---|---|---|
| `status` | int | status == this (omit → any 2xx) |
| `deny` | bool | true → status must be 4xx (REFUSED); a 5xx fails — a crash is not a refusal |
| `fields` | string[] | every named key is present in the JSON response |
| `body` | map | every `key: value` matches the response (value interpolated). Key = path (`a.b`, `items[0].id`, leading `$.` optional). Value may be `{contains: X}` / `{not_contains: X}` — see below |
| `schema` | object | response conforms to this inline JSON-Schema-lite (required + types), extra fields OK; `null` passes only where the property says `nullable: true` |
| `within` | duration | request took ≤ this (e.g. `"800ms"`) |
| `exit` | int | (for `run:` steps) the command's exit code equals this |
| `headers` | map | each response header CONTAINS the (interpolated) value; `""` = header present |
| `absent` | string[] | these JSONPath-lite fields must NOT be present (negative-space of a response) |
| `notcontains` | string[] | the raw body must NOT contain these substrings (e.g. a leaked secret/password). `not_contains` is accepted as the same key |

**Lists — "is my item in there?"**
```yaml
expect:
  status: 200
  body:
    items: { contains: "{project_id}" }     # an element equal to X, OR an object with a field equal to X
    tags:  { not_contains: "deleted" }
```
On a string field `contains` / `not_contains` are substring checks.

`schema` example — the contract-drift catcher:
```yaml
expect:
  status: 200
  schema:
    required: [id, created_at]
    properties:
      id:         { type: string }
      created_at: { type: string }
```
It infers `type: object` from `required`/`properties`, so a missing required key or a retyped field
FAILS — but new/extra fields do not (tolerant, forward-compatible).

## Interpolation & capture

- `{name}` → a Context value (environment setup / journey var / prior capture). Interpolated in
  `path`, `body`, `bearer`, `run`, and in `expect` (`body` values, `headers`, `notcontains`). An
  unknown `{name}` in path/body/bearer makes the journey **VOID** with a reason naming it (never a
  product FAIL) — lint JL001 catches typos before a run. `{base}` is the target URL (handy in `run:`).
- `{env:NAME}` → the value of environment variable NAME (for credentials; never commit them). Works in
  journeys and in `environment.json` (`vars`, setup steps). Unset → VOID naming the variable. A
  secret-looking NAME (`…PASSWORD`, `…TOKEN`, `…API_KEY`, …) is masked in all output.
- `{rand}` / `__RAND__` → a fresh random hex at EVERY occurrence (so `{rand}` in a body and again in
  an `expect` are different values — put it in `vars:` once to reuse it; lint JL010).
- `__SEQ__` → an incrementing counter within the journey.
- Capture path is JSONPath-lite: `$.a.b`, `a.b`, with `[i]` index (e.g. `$.items[0].id`).
- Capture is **append-only** — a step cannot overwrite a name a prior step set (prevents silent
  state clobber). Captured values flow to every later step, including `finally`.
- Secrets: `capture: { "secret:token": "$.access_token" }` stores under `token`, marks it secret;
  its value is masked as `***redacted***` everywhere uj records it — text output, `--json`
  `resp_body`, JUnit/CTRF, checkpoints — including the response that first returned it.

## Environment (setup before every journey)

`environment.json` (found at the project root, next to `harness.toml`) lists `setup` steps uj runs
before EACH journey; their captures become `{vars}` in the journey. `setup` may be empty (`[]`) —
then journeys start anonymous and sign up / log in themselves. With no environment.json at all, the
same applies. Top-level keys: `name`, `notes`, `vars`, `setup`, `export`, `capabilities`.
A multi-tenant example (Acme's `invoicer`: log in as a QA admin, create a fresh workspace per
journey; the password comes from the environment, never the file):
```json
{
  "name": "invoicer-staging",
  "vars": { "admin_email": "qa-admin@acme.example", "admin_pass": "{env:ACME_QA_ADMIN_PASSWORD}" },
  "setup": [
    { "intent": "the QA admin logs in", "method": "POST", "path": "/login", "bearer": "none",
      "body": { "email": "{admin_email}", "password": "{admin_pass}" },
      "capture": { "secret:session_token": "$.access_token" }, "expect": { "status": 200, "fields": ["access_token"] } },
    { "intent": "create a fresh workspace for this journey", "method": "POST", "path": "/workspaces",
      "bearer": "{session_token}", "body": { "name": "ws-{rand}" },
      "capture": { "workspace_id": "$.id" }, "expect": { "status": 201, "fields": ["id"] } }
  ],
  "export": { "token": "{session_token}", "org": "workspace_id" }
}
```
`uj run` uses `<project>/environment.json` automatically (`--env FILE` overrides). Point the target
(`harness.toml` / `--base`) at any deployment; the journeys don't change. Self-signup and two-user
patterns: see the uj-authoring SKILL.md "Environment" section.

**`export` renames a captured var to a canonical journey name**, `{ "canonicalName": "source" }`. The
source may be the interpolated `{braced}` form (`"token": "{session_token}"`) OR a bare capture name
(`"org": "workspace_id"`) — both resolve; journeys above then use `{token}` and `{org}`. If you don't need renaming, omit `export` entirely; captured names
are already available to journeys as `{name}`.

**`capabilities`**: list the capability names the environment declares present, e.g. `"capabilities":
["premium_tier"]`. A journey gating on `capability: [premium_tier]` then runs; otherwise it SKIPs
honestly. (`enterprise` is auto-probed and needs no declaration.)
