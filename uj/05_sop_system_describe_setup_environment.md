# 05 · Describe what runs before every journey (environment.json)

**What this is for.** Deciding how each test starts (a fresh logged-in customer, or nobody at all), writing that down once in `environment.json`, keeping passwords out of git, and proving the setup works with `uj doctor`. For Acme, every invoice journey should start as a brand-new customer who is already logged in.

**Before you start.** SOP 04 (a project with a target). Know how your API makes a user. Acme's API (yours will differ): `POST /signup {email, password, name}` returns `201 {user_id, email}`; `POST /login {email, password}` returns `200 {access_token, user_id}`. Build against `dev` first.

## Steps

**1. Decide what goes in setup and what goes in the journey.** Setup is what every journey needs but is not the point of the test. It runs before **each** journey, fresh every time, so journeys never share a user.

| your situation | put in setup | put in the journey |
|---|---|---|
| signup is the story (Maya's onboarding journey) | nothing: `"setup": []` | sign up, log in, capture the token |
| every journey needs a logged-in user (Acme's invoice journeys) | sign up + log in, capture `secret:token` | start from `{token}` |
| multi-tenant product (orgs, workspaces) | log in + create a fresh org, capture `{org}` | work inside `{org}` |
| signup is closed on staging | log in as a QA account, password from `{env:NAME}` | work only on data the journey creates |

One `environment.json` serves every journey in a run. A journey that signs up its own user still works with Acme's setup; it simply ignores `{token}`.

**2. Write the setup.** Acme's `environment.json`:
```json
{
  "name": "invoicer",
  "notes": "Every journey gets a fresh Acme customer, signed up and logged in.",
  "vars": { "email": "qa+{rand}@example.test", "pass": "{env:ACME_QA_PASSWORD}", "name": "QA Customer" },
  "setup": [
    { "intent": "sign up a fresh customer", "method": "POST", "path": "/signup", "bearer": "none",
      "body": { "email": "{email}", "password": "{pass}", "name": "{name}" },
      "capture": { "user": "$.user_id" }, "expect": { "status": 201, "fields": ["user_id"] } },
    { "intent": "log in as that customer", "method": "POST", "path": "/login", "bearer": "none",
      "body": { "email": "{email}", "password": "{pass}" },
      "capture": { "secret:token": "$.access_token" }, "expect": { "status": 200, "fields": ["access_token"] } }
  ]
}
```
Setup steps are ordinary journey steps (SOP 07). `{rand}` in `vars` is expanded once per journey, so `{email}` is the same address in both steps and a new one for the next journey. Even this throwaway user's password comes from the environment (`export ACME_QA_PASSWORD=…`, or a line in the project's `.env`), so the rule "no passwords in files" has no exceptions and lint never has to judge which ones are real (step 4).

**3. Know what journeys receive.** Every `vars` entry and every capture becomes a `{name}` in every journey: here `{email}`, `{pass}`, `{name}`, `{user}`, `{token}`. `secret:token` is stored as `{token}` and masked as `***redacted***` everywhere uj records it. Names that look secret (`token`, `password`, `pass`, `secret`, `api_key`, `bearer`, `credential`) are masked even without `secret:`. To rename a capture for journeys, add `"export": {"token": "{session_token}"}`; you rarely need it.

**4. Keep real passwords out of git with `{env:NAME}`.** Acme's staging has signup switched off, so staging journeys log in as a QA account. Write the reference, not the value, in `environment.staging.json`:
```json
{
  "name": "invoicer-staging",
  "notes": "Staging: log in as the shared QA account; its password comes from the CI secret store.",
  "vars": { "qa_email": "qa@acme.example", "qa_pass": "{env:ACME_QA_PASSWORD}" },
  "setup": [
    { "intent": "log in as the QA account", "method": "POST", "path": "/login", "bearer": "none",
      "body": { "email": "{qa_email}", "password": "{qa_pass}" },
      "capture": { "secret:token": "$.access_token", "user": "$.user_id" },
      "expect": { "status": 200, "fields": ["access_token"] } }
  ],
  "capabilities": ["email-delivery"]
}
```
Before a run: `export ACME_QA_PASSWORD='<your-password>'`, or put it once in a `.env` file at the project root (next to `harness.toml`):
```sh
# .env — this machine only; uj init added it to .gitignore
ACME_QA_PASSWORD='<your-password>'
```
`uj run` and `uj doctor` read `.env` (`KEY=VALUE` lines, whole-line `#` comments, optional quotes, an optional `export ` prefix; a `#` after a value is part of the value) and set only variables that are not set already: your shell and CI always win. Never commit `.env`; in CI the secret store sets the variable (SOP 12). A shared account is not isolated: journeys see each other's invoices, so assert on what each journey created, never on totals, and mark journeys that change shared settings with `conflicts: global:<name>`.

**5. Use an alternate file with `--env`.**
```sh
uj doctor --target staging --env environment.staging.json
uj run    --target staging --env environment.staging.json
```
Files named `environment*.json` are never collected as journeys, so they can sit at the project root.

**6. Declare capabilities.** `"capabilities": ["email-delivery"]` says "this environment can do this". A journey with `capability: [email-delivery]` runs on staging and is SKIP on dev with the reason `capability absent: email-delivery`; never a false PASS or FAIL. `browser` is present automatically when a browser driver is configured (SOP 10).

**7. Two users for isolation tests.** Setup gives user A (`{token}`). Create user B inside the journey, reusing `{pass}`:
```yaml
vars: { b_email: "b+{rand}@example.test" }
steps:
  - intent: a second customer signs up
    method: POST
    path:   /signup
    bearer: "none"
    body:   { email: "{b_email}", password: "{pass}", name: "B" }
    expect: { status: 201, fields: [user_id] }
  - intent: the second customer logs in
    method: POST
    path:   /login
    bearer: "none"
    body:   { email: "{b_email}", password: "{pass}" }
    capture: { "secret:b_token": $.access_token }
    expect: { status: 200, fields: [access_token] }
```
Then B tries A's invoice with `bearer: "{b_token}"` and `expect: not-found` (SOPs 08 and 09).

**8. Check offline, then against the target.**
```sh
uj validate environment.json
uj doctor --no-setup        # target + reachability only; creates nothing
uj doctor
```
`validate` checks the file without a service, and refuses a key uj does not know (a typo such as `"setpu"`). It knows the file is an environment by its name: keep the `environment` prefix (`environment.json`, `environment.staging.json`), or pass `--kind environment` — under another name it is checked as a journey and the errors make no sense; `name`, `notes`, `vars`, `setup`, `export` and `capabilities` are the fields used here, and a key starting with `_` is a comment. `uj lint` skips environment files; it is for journeys. `uj doctor` resolves the target, finds the file, checks the service answers, and **runs the setup for real**: each `uj doctor` creates one Acme customer on the target. `--no-setup` skips that step and creates no data, for a target where you do not want a stray user. Point it at `dev` or `staging`, never production.

**9. Write down the environments and test-data rules in `.uj/product.context`.** `uj init` created it. Fill its `## Environments` table (each target, what it is, whether it is safe to create data: `dev` yes, `staging` throwaway accounts only, production never) and `## Test data rules` (Acme: every journey creates its own users; emails `qa+{rand}@example.test`; the staging QA account's password is `{env:ACME_QA_PASSWORD}`, never the value). Change `# Last updated:` to today's date. The next person, or Quinn, reads this before writing a journey instead of asking you again. `uj lint` flags a credential written into `.uj/` (JL011).

## What you'll see

`validate`: `✓ environment.json [environment]` then `validate: 1 ok, 0 invalid`.

`uj doctor` prints one line per check: `✓ project — harness.toml at .`, `✓ environment — environment.json`, `✓ reachable — <url>/health responds (HTTP 200)`, then either `✓ setup — ran; every journey gets fresh values for: {email}, {name}, {pass}, {token}, {user}` or, with no vars and no steps, `✓ setup — no setup steps — each journey starts anonymous and signs up / logs in itself`. With `--no-setup`: ``✓ setup — skipped (--no-setup) — no data created; `uj validate environment.json` checks the file offline``. It ends `` doctor: OK — ready to `uj run` `` (exit `0`) or `` doctor: FAIL — fix the above before `uj run` (a journey would VOID here) `` (exit `1`). A failed check reads `✗ <name>`, the problem, and `fix: …`.

When `.env` filled in anything, `uj run` says so first: `(read 1 variable(s) from .env)`. Each `uj run` names the file in its header: `(environment: environment.json)`, or `(environment: none — journeys start with no pre-made user/token …)` when there is none.

## If it goes wrong

| you see | it means | do |
|---|---|---|
| `✗ setup` with `environment setup failed: environment step N (<intent>): <reason> [status S]` | a setup step's check failed | fix that step; every journey is VOID until it passes |
| `` environment setup failed (<env>): environment step N (<intent>): <reason> [status S] — fix the setup step, then `uj doctor` to confirm `` | the same, inside `uj run` | as above |
| `capture failed: no value at $.access_token` | the field has another name | read the login response; fix the path |
| `[status 409]` on the signup step | the email is not unique | put `{rand}` in the email var |
| `environment variable ACME_QA_PASSWORD is not set (referenced as {env:…}) — export it, or set it in your CI secrets` | the variable is missing in this shell or job | export it, or add it to `.env` (step 4) |
| a value in `.env` is not used | the variable is already set in your shell or CI (that wins), or `.env` is not next to `harness.toml` | `unset NAME`; move `.env` to the project root |
| `unresolved {token} — not provided by environment.json setup, the journey's vars:, or an earlier capture: …` | the journey uses a name setup never captured | compare with the `doctor` list; fix the name |
| `✗ environment` with `<path> does not exist` / `` uj run: environment environment.staging.json does not exist (fix --env, or `uj init`) `` | wrong `--env` path | fix the path |
| `✗ reachable` with `no HTTP response from <url>` | service down or wrong target | start it, or fix the target (SOP 04) |
| `{token}` missing from the `✓ setup` list | no step captures it | add the capture |
| ``<file>: unknown key "setpu" — not a uj field (typo?); see `uj schema journey` or `uj schema environment` `` | a misspelled key in `environment.json` | fix the spelling; `uj schema environment` lists the fields |
| `JL011 … looks like a credential written into project memory — remove it and reference {env:NAME} instead` | a password landed in `.uj/` | delete it, rotate it, write `{env:NAME}` (step 9) |

## Coming

- **Setup teardown** (remove the users setup created). *Today:* none; setup users stay on the target. Use a `dev`/`staging` you can reset, and clean up records in each journey's `finally:`.
- **A setup file bound to each target.** *Today:* `--env FILE` on every command.

## Next

SOP 06, decide what to test. Signing users in through the ab0t auth mesh? Get the test org and keys from Ally (`../authmesh/`) first.
