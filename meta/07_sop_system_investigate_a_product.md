# 07 · Investigate a product so its SOPs are true

**What this is for.** Where the facts in an SOP come from, in the order that finds them fastest and most reliably, for any product: a CLI, a service with an API, an SDK, or all three. The output is a **fact sheet** of verbatim strings; the SOPs are written from it and from nothing else.

**Before you start.** Read access to the product's repository (or at least its public API spec and CLI). A scratch file for the fact sheet. No running services; everything here is reading and offline help.

## Steps

**1. Inventory the surfaces, in this order.**

| surface | where to look | what to take |
|---|---|---|
| CLI | `tool --help`, `tool <cmd> --help` for every command; the dispatcher in source (the `switch` on the command name, cobra/click/commander registrations) | every command, flag, default, exit code; which commands mutate; which default to a dangerous target |
| API spec | `/openapi.json` or `/openapi.yaml` on the live host (read it from the repo if you must not hit the server), `docs/API*.md`, GraphQL schema, proto files | paths, methods, auth scheme and header name, request fields (required/optional), response fields, declared error codes |
| Config | `*.example`, `*.schema.json`, the loader struct/class (`json:"…"` tags, pydantic models, zod schemas) | every field, enum values, defaults, which are required, which are validated vs silently accepted |
| Validation and error strings | grep the source for the framework's error constructor: Go `fmt.Errorf`/`errors.New`; Python `HTTPException(status_code=`, `raise …Error(`, `detail=`; Node `throw new`, `res.status(`; plus `Warnf`/`logger.warning` | the exact text, with `file:line`; these become "If it goes wrong" |
| Env vars | grep `os.Getenv`, `os.environ`, `process.env`, `BaseSettings`/`pydantic_settings`, `viper`, `.env.example` | exact names, defaults, which are secrets |
| State and secrets | where credentials, tokens, caches and locks are written (`~/.<tool>/…`, `0600`, lockfiles) | paths and file names; never the contents |
| Behaviour oracle | the product's own tests and user-journey scripts (`tests/`, `scripts/curl_tests/user_journeys/`, `e2e/`) | the happy-path sequence of calls and the asserted responses; this is the most honest "What you'll see" |
| Change history | `CHANGELOG.md`, `CLIENT_CHANGES.md`, release notes, migration guides | action-required changes; breaking patches; what version you are documenting |
| SDKs | the SDK README quick start (verify it compiles against exported names), `doc.go`, `__init__.py` exports | the minimal snippet; the three rules (fail closed, set audience, check the boolean) |
| Docs and skills | README, `docs/`, `llms.txt`, any existing skills | read **last**, and only to find what you missed; every claim checked against the rows above |

**2. Record the version you are documenting.** Binary `--version`, the git tag, `go.mod`/`pyproject.toml`/`package.json`, and the commit of the checkout. Write them into the log and, later, `bot.json`'s `verified_against`.

**3. Build the fact sheet.** One table per surface; columns `string (verbatim) · meaning · file:line or URL`. Add a section **Disagreements**: every place docs, skills or examples say something the code does not (an API in a README that does not exist; an env var the code never reads; a reserved field an example sets). These feed the SOPs' warnings and the GAPS "(docs)" rows.

**4. Derive the jobs from the client's life, not from the endpoint list.** Group the surfaces into the moments a client meets them: get access, configure, first run, wire into their app, customise, their users, their team, other services, opening up, changing, keys, migrating, debugging, staying safe. An endpoint that fits no job is either internal (leave it out) or a gap (a job clients will want and cannot do; Coming).

**5. Products with no CLI (API-only).** The steps are the calls. For each: method and path; the auth header and where the key comes from (hand off to the bot that mints it); required and optional body fields with one realistic example; the success response fields the client needs; the idempotency key if any mutation can be retried; the verbatim error bodies. Prefer the product's SDK snippet when one exists and you have verified its names. Never paste a curl you have not derived from the spec.

**6. Products with a CLI or SDK.** Prefer the verb (`tool connect …`) over the HTTP it wraps; the SOP says what the verb does and prints. When a job has no verb, the step is Coming and *Today:* is the API call from step 5.

**7. Capture the dangerous defaults.** The target environment when none is given; whether a check command connects or creates; whether a missing config key means "off" or "allow everything"; whether a delete is reversible. Each becomes a sentence in every SOP that runs the command.

**8. Capture hand-offs.** Which jobs belong to another bot (keys, money, relationships)? Write the row for `bot.json`'s `hands_off_to` and do not document those jobs here.

## What you'll see

A fact sheet long enough that every "What you'll see" and "If it goes wrong" line in the finished SOPs can be traced to a row. A Disagreements list with at least a few entries; a product with none has usually not been read closely enough.

## If it goes wrong

- The spec and the code disagree (a response field in `/openapi.json` that the handler never sets): the code wins; note it as a disagreement.
- The CLI help lists a command the dispatcher rejects, or vice versa: the dispatcher wins.
- You cannot reach the live spec and the repo has none: ask the product team for an export; do not write API steps from memory.
- The product has many surfaces and little time: do the CLI/spec and the error strings first; they are what clients hit; the behaviour oracle second.

## Coming

- **A fact-sheet generator** (`meta facts <repo>`: help, spec, config schema, error strings, env vars, versions into one file). *Today:* the table above, by hand or with read-only research subagents, one per surface.
- **Spec-to-SOP diff** (which paths in `/openapi.json` no SOP mentions). *Today:* `grep` the SOPs for each path.

## Next

SOP 02 step 4, fix the SOP set. SOP 08 for how your bot will work with the others.
