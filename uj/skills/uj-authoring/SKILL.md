---
name: uj-authoring
description: Author uj user-journey test files (YAML or JSON) that a PMM can read and an engineer can run. Use when writing or editing a journey/epic, deciding what to assert on a step, passing captured state between steps (interpolation), asserting a response contract (expect.schema), marking secrets, structuring a multi-step epic with cleanup, or fixing a lint finding (JL/UJ rules). Covers the journey file model, the intent-first two-layer shape, capture/interpolation, the expect block, resumable epics, and the setup-before-every-journey Environment (incl. self-signup APIs and two-user isolation tests). For RUNNING journeys use uj-cli.
---

# Authoring uj journeys

## Install / update uj

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh | sh
uj --version        # confirm
```

HTTPS-only, sha256-verified, idempotent. Update in place with `uj update`
(checksum-verified, atomic; keeps the prior binary as `uj.previous`) or re-run
the one-liner. A mirror can be used with
`curl -fsSL .../install.sh | UJ_INSTALL_BASE=... sh`.

---

A journey is an **executable spec**: a person (or attacker) moving through a product over multiple
steps, carrying state. It is written so a PMM reads the *intent* top-to-bottom and an engineer
fills the *mechanics* underneath. Author in YAML (comments, no braces) or JSON — both parse to the
same model.

## The authoring loop (use the tool to help you write)

```bash
uj new journey "Invite a teammate"      # scaffold a ready-to-edit file with tips → journeys/
uj explain journeys/INVITE...yaml       # read it back as a plain-English story
uj lint journeys/INVITE...yaml          # authoring nudges (undefined vars, under-assertion, secrets)
uj validate journeys/INVITE...yaml      # confirm it's well-formed against the schema
uj run journeys/INVITE...yaml           # target from harness.toml (or add --base <url>)
```

Editor autocomplete: files from `uj new` start with a modeline pointing at the published schema
(`# yaml-language-server: $schema=https://raw.githubusercontent.com/ab0t-com/uj/main/schemas/journey.schema.json`).
Offline: `uj schema journey > journey.schema.json` and point the modeline at that file.

## Start from the OUTCOME (what the journey is for)

A journey is a person reaching an outcome, not a list of API calls. Fill these first — `uj explain`
leads with them, and they're what a manager reads:

```yaml
outcome:   "a new customer can start using the product on their own"   # a change in their world, not a task
persona:   "someone who just signed up and wants to try it today"
narrative: |
  They sign up, create their first project, and expect to see it straight away…
success:   "the customer sees their new project; a stranger is refused"  # what PASS proves
covers:    [signup, data-isolation]                                       # risks this protects (`uj coverage`)
```

## The shape (minimum viable journey)

```yaml
id: INVITE_A_TEAMMATE
kind: epic                       # single | epic (epic = ordered, shares state, aborts on first fail)
success: "an invited teammate can log in and see the shared org"   # what "worked" MEANS

steps:
  - intent: owner invites a teammate by email    # LINE 1 = human intent (a PMM writes this)
    method: POST                                 # the mechanics (an engineer fills these)
    path:   /organizations/{org}/invitations
    bearer: "{token}"
    body:   { email: "t-{rand}@x.test", role: member }
    capture: { invite_id: $.invitation_id }      # remember a value for later steps
    expect: { status: 200, fields: [invitation_id] }

  - intent: the teammate accepts (state from step 1 flows here)
    method: POST
    path:   /invitations/{invite_id}/accept      # {invite_id} came from the capture above
    expect: success                              # plain-language expectation

finally:
  - intent: remove the invitation
    method: DELETE
    path:   /organizations/{org}/invitations/{invite_id}
    bearer: "{token}"
    expect: success
```

## The two layers (why this is bilingual)

- **Intent layer** — every step's `intent:` names what a person is doing; `success:` states what a
  successful run proves; `abuse:` names the negative space a security step must refuse. A PMM writes
  and reads these without touching HTTP.
- **`notes:` (freehand, optional)** — an author's aside, on a step OR on the journey: why the step is
  here, a caveat, a grounding ref (`file:line`), a parity note, a TODO. Pure documentation — **ignored
  at run time**, surfaced by `uj explain` (journey-level as `Note:`, step-level as `↳ note:`). Use it
  for context that isn't the user-facing `intent` and isn't a security `abuse` — e.g. "PASSES on Go,
  surfaces divergence X on Python; see finding F5."
- **Mechanics layer** — `method`/`path`/`body`/`expect` (and `run:` for a shell escape hatch). An
  engineer fills these. `uj lint` enforces that `intent` is always present.

Keep it declarative. For real logic use a `run:` step (shell), NOT loops/conditionals in the YAML.

## Passing state between steps (the Context)

An epic is a state machine. Values flow forward:
- **Read** any var with `{name}`: fixture (`{org}`, `{token}`, `{user}`), journey `vars:`, or a
  prior `capture`.
- **Write** with `capture: { name: "$.jsonpath" }` — **append-only** (a step can't overwrite a key).
- **Uniqueness**: `{rand}` / `__RAND__` expands to a NEW value **every place it appears**. To use
  the same unique value twice (send it, then assert it), set it once in `vars:`
  (`vars: { pname: "proj-{rand}" }`) and use `{pname}` in both places. Lint JL010 flags `{rand}`
  inside `expect`.
- **Secrets**: `capture: { "secret:token": "$.access_token" }` — usable downstream as `{token}` but
  masked as `***redacted***` everywhere uj records it (text, `--json`, exports, checkpoints — including
  the response that first returned it). Marking secrets is a lint rule (JL006).
- **From the environment**: `{env:NAME}` reads an environment variable at run time — use it for
  passwords and keys so nothing secret is committed (`vars: { pass: "{env:ACME_QA_PASSWORD}" }`).
  Unset → the journey is VOID with "environment variable NAME is not set".
- **Auto-masked names**: vars/captures named like `token`, `password`/`pass`, `secret`, `api_key`,
  `bearer`, `credential` are masked even without `secret:` — including values that come from
  environment setup.
- **A `{var}` nothing provides** (typo, or setup didn't capture it) makes the journey **VOID** with a
  reason naming the var — not a FAIL. `uj lint` (JL001) catches most typos before a run.

Full field-by-field reference (all `expect` modes, body-as-object, `ctype`, `capability`,
`conflicts`, JSONPath-lite): [references/journey-format.md](references/journey-format.md).

## Assert MORE than status (the #1 authoring mistake)

A step that only checks `status: 200` passes even when the body is garbage. Strengthen it:
- `fields: [id, slug]` — these keys must be present.
- `body: { role: member }` — these key/values must match (interpolated). Keys are paths: `user.id`,
  `items[0].id` (a leading `$.` is fine too). A path that doesn't exist fails with "no field at …".
- **Is it in a list?** `body: { items: { contains: "{project_id}" } }` — passes when the array holds
  that value, or holds an object with a field equal to it (e.g. `[{id: …, name: …}]`).
  `not_contains` is the negation; on a string field both are substring checks.
- **Prove it's gone** (after a DELETE): `expect: not-found` on `GET /things/{id}`, then
  `body: { items: { not_contains: "{id}" } }` on the list.
- `absent: [password]` / `notcontains: ["{secret_value}"]` — the negative space of a response
  (`not_contains:` is accepted as the same key).
- `schema: { required: [id], properties: { id: {type: string} } }` — a tolerant **contract**
  assertion; catches the drop/rename/retype drift class. Extra fields are allowed.
- `deny: true` (or `expect: denied`) — the request must be REFUSED with a **4xx**; a 5xx crash FAILs
  (a crash is not a refusal).
- `within: "800ms"` — a latency budget (an unparsable value is a load error).
- Unknown keys are refused when the file loads (`unknown key "expct"`), so a typo can never switch an
  assertion off. Top-level keys starting with `_` (`_note`) are comments.

`uj lint` flags status-only *successful* reads as **JL004** (refusal / 4xx / not-found steps are
exempt — there the status IS the contract). Fixing it is the single biggest quality win.

## Epics, capability, isolation

- `kind: epic` runs steps in order and **aborts on the first failure** (don't drive a broken
  world); `finally:` steps always run (teardown). The whole epic is ONE verdict.
- `conflicts:` only matters for `uj run --parallel`: `tenant` (or nothing) = touches only its own fresh
  data and runs alongside anything; `global:<name>` = changes something shared, so journeys with the
  same key never run at the same time (lint JL007 reminds you).
- `capability: [enterprise]` → the journey SKIPs (honestly) when that capability is absent, never a
  false pass/fail.
- Each journey gets its OWN fresh setup run (see below) — never rely on a seeded shared account.
- `finally:` cleanup with no explicit `status` also accepts 404 ("already gone"). If a step's
  request SUCCEEDED (2xx) but a check failed, its `capture:` values are still kept, so cleanup can
  delete what it created; a cleanup that needs an id that was truly never returned is skipped.

## Resumable epics

A long epic that fails at step N can be retried from step N (state intact) — see uj-cli
`--run-id`/`--resume`. Author long journeys freely; you won't re-run setup to retry a late step.

## Fixing lint findings

`uj lint --rules` lists them. The journey (JL) rules and how to satisfy each:
[references/lint-rules.md](references/lint-rules.md). A worked example journey:
[assets/EXAMPLE_epic.yaml](assets/EXAMPLE_epic.yaml).

## The Environment — setup that runs before EVERY journey

`environment.json` (project root) lists `setup` steps — ordinary HTTP steps — that uj runs before
each journey. Whatever they `capture` becomes a `{var}` in every journey; `vars` (with `{rand}`) are
fresh per journey too. `uj doctor` runs the setup once and lists the `{vars}` journeys will get.

**What goes in setup vs. in the journey?**

| Your API / your test | Put in setup | Put in the journey |
|---|---|---|
| Self-service signup, and signup is part of the story | nothing — `"setup": []` | sign up → log in (`capture: {"secret:token": …}`) → … |
| Every journey needs a logged-in user, signup isn't the point | sign up + log in → `secret:token` | start from `{token}` |
| Multi-tenant product (orgs/workspaces) | log in → create a fresh org → `{org}` + `{token}` | work inside `{org}` |

```json
{ "vars":  { "email": "qa+{rand}@example.test", "pass": "{env:ACME_QA_PASSWORD}" },
  "setup": [
    { "intent": "sign up a fresh user", "method": "POST", "path": "/signup",
      "body": { "email": "{email}", "password": "{pass}", "name": "QA" }, "expect": { "status": 201 } },
    { "intent": "log in", "method": "POST", "path": "/login",
      "body": { "email": "{email}", "password": "{pass}" },
      "capture": { "secret:token": "$.access_token" }, "expect": { "status": 200 } } ] }
```

**Two users (isolation tests).** Setup gives you user A; create user B inside the journey:

```yaml
vars: { b_email: "b+{rand}@example.test" }
steps:
  - intent: user A creates a private project
    method: POST
    path: /projects
    bearer: "{token}"
    body: { name: "private" }
    capture: { pid: $.id }
    expect: { status: 201 }
  - intent: an unrelated person (user B) signs up
    method: POST
    path: /signup
    bearer: "none"
    body: { email: "{b_email}", password: "{pass}", name: "B" }
    expect: { status: 201 }
  - intent: user B logs in
    method: POST
    path: /login
    bearer: "none"
    body: { email: "{b_email}", password: "{pass}" }
    capture: { "secret:b_token": $.access_token }
    expect: { status: 200 }
  - intent: user B tries to read A's project
    abuse: another customer must never see A's data
    method: GET
    path: /projects/{pid}
    bearer: "{b_token}"
    expect: { status: 404 }
```

`uj init --openapi <url>` drafts `environment.json` from your spec (signup → login → token) and sets
the target in `harness.toml` — confirm it with `uj doctor`.

## Risks and gaps (the project memory)

`.uj/risks.context` holds the risk register: a table under `## Risk register` whose first column is
the id journeys put in `covers:`. `uj coverage` (and `uj where`) then list **registered risks with no
journey** (the gaps to write next), **covers ids that aren't registered** (typos — note a typo also
leaves the real risk showing as a gap), and the ids in its `## Not covered on purpose` table as
accepted (never counted as gaps). Read
`.uj/product.context` and `.uj/conventions.context` before writing journeys for a project; record
why things are the way they are in `.uj/decisions.md`, and bugs a journey pins in `.uj/findings.md`.
Never put a credential in `.uj/` (lint JL011).

## Words you'll see

**journey** — one test: a person reaching an outcome over steps · **epic** — a multi-step journey that
shares state and stops at the first failure · **environment / setup** — what runs before every
journey · **tenant** — an isolated account/org a multi-tenant product gives each customer (setup can
create a fresh one per journey) · **target** — the service URL under test (`harness.toml`) ·
**verdict** — PASS / FAIL / VOID / SKIP / INCONCLUSIVE.
