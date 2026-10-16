# 19 · The rules for honest tests

**What this is for.** The short list of rules that keep a uj suite trustworthy: green means the product works, red means it does not, and nobody gets hurt by the tests themselves. Each rule says why, how uj helps, and what breaks it. Shown with Acme's `invoicer` (Acme's API; yours will differ), Maya (Acme's product manager) and Dev (Acme's engineer).

**Before you start.** Nothing. Read it once; come back when a review or an incident raises a question. Agents working on a uj project follow these rules without exception.

## The rules

**1. Never point journeys at production.** Journeys create real data: signups, invoices, sent emails. Use `dev` (`http://localhost:8080`) or `staging` (`https://invoicer.staging.acme.example`). uj never guesses a target, and every run starts with `(target: <url> — from <source>)`; read that line. Mark every production URL you know in `harness.toml` with `production = true` (SOP 04 step 7): `uj run` then refuses it, even through `--base` or `UJ_BASE`, and exits `2`, and `uj doctor` fails its target check. `uj doctor` runs your setup steps too, so the same rule applies to it. `--allow-production` exists for one thing, a read-only `uj doctor --no-setup --allow-production`; never pass it to `uj run`, and never put it in CI.

**2. Use throwaway identities, fresh every time.** Each journey gets its own setup (its own signup and token), and emails come from `vars:` with `{rand}` (`email: "qa+{rand}@acme.example"`), so re-runs never collide and journeys never share a customer. Never test with a real customer's account or a shared, seeded user: a test that passes only because of data someone else made is not a test. Where you need two people (owner and outsider), create both inside the journey.

**3. Secrets come from the environment, never from files.** Passwords and keys are `{env:ACME_QA_PASSWORD}` in `environment.json` and journeys; CI injects them from its secret store. On your own machine a `.env` file at the project root can hold them instead of exporting by hand; `uj init` git-ignores it: never commit it, never paste it. Mark captured tokens `secret:` (`capture: {"secret:token": $.access_token}`); uj masks them as `***redacted***` in text, `--json`, JUnit, CTRF and checkpoints, and masks names like `token`, `password` and `api_key` automatically. Lint rule JL006 flags a secret-looking capture you forgot to mark. The project memory in `.uj/` is committed and shared: never write a password or key there; lint rule JL011 flags one. `runs/` is git-ignored by `uj init`; keep it that way, and never paste `runs/**/secrets.json` anywhere.

**4. Never weaken a red test to make it green.** A FAIL is either a bug in the product or a wrong expectation in the test. Decide which by reading the step's reason and the response, then fix the product or correct the expectation with a reason in the commit. Deleting the step, loosening `status: 201` to `success`, removing a `body:` check or adding retries until it passes hides the bug from everyone. A test pinning a known bug stays red until the bug is fixed (SOP 14).

**5. No fake green.** A journey that checks nothing is INCONCLUSIVE, not PASS; `--strict` in CI makes INCONCLUSIVE and SKIP fail. A successful read that asserts only its status is lint rule JL004: add `fields`, `body` or `schema`. `{rand}` inside `expect` can never match (JL010). `uj verdict` never treats exit code 0 as a pass, and neither should your own scripts. A flaky journey is a real problem to fix, not a retry to add: `uj history --flaky` names it.

**6. VOID is not a bug report.** VOID means uj could not judge: the service did not answer (or its certificate did not verify), setup failed, a `{var}` or `{env:…}` was missing, or the journey file could not be loaded. Fix the environment (`uj doctor` names what broke) and re-run; do not file it against the product, and do not count it as a pass. In CI, exit `2` goes to whoever owns the environment, exit `1` to whoever owns the code.

**7. Clean up what you create.** Every journey that creates something deletes it in `finally:`, which runs even after a failure. A cleanup that finds the thing already gone (`404`) counts as done (`already gone (404) — fine for cleanup`), and one that needs an id the journey never captured is skipped, not failed. Lint rule JL003 flags a journey that creates without a `finally:`.

**8. Read every `run:` step before you run someone else's journey.** A `run:` step is a shell command executed on your machine (or the CI runner) with your permissions. Review `run:` lines in pull requests like code, keep them short, and call scripts that live in the repo rather than long inline commands.

**9. Declare shared state.** A journey that changes something every customer shares (a global setting, a rate limit, a feature flag) declares `conflicts: global:<name>`, so `uj run --parallel` never runs it alongside another journey with the same key. Journeys that touch only their own data say `conflicts: tenant` (or nothing) and run fully in parallel (SOP 16).

**10. Keep intents human.** Every step's `intent` says what a person is doing, in words Maya can read; `outcome` is a change in the customer's world, not a task (lint rule JL009); `success` says what "worked" means (JL008). `uj explain journeys/` must read like a story a manager understands. If it reads like a list of endpoints, the journey tests mechanics, not a user.

**11. Test what customers depend on, not what is easy.** Write the risks first, in the register in `.uj/risks.context`; then realistic sessions with the risky step checked along the way, abuse steps where an outsider must be refused (`expect: denied` passes only on a 4xx, never on a crash), and `covers:` naming the risk ids, so `uj coverage` lists what nothing watches yet (SOP 06). A gap you accept goes under "Not covered on purpose" with the reason, not out of sight.

**12. Know what uj does not check.** uj does not follow `$ref` inside a journey's `schema`, does not check `enum` or `format`, and waits 30 seconds per request unless you raise it (`--timeout`, `UJ_TIMEOUT`). Do not read a green suite as proof of any of those. Certificates it does check: never set `UJ_INSECURE_TLS=1` outside a dev target with a self-signed certificate, or the check is gone.

## How uj backs each rule

| rule | what uj does for you | what stays your job |
|---|---|---|
| 1 never production | no built-in target; the target line opens every run; a `production = true` target is refused | mark every production URL; never `--allow-production` on a run or in CI |
| 2 throwaway identities | fresh setup per journey; `{rand}`; UJ005 for old scripts | write `{rand}` emails into `vars:` |
| 3 secrets from env | `{env:NAME}`; `secret:` masking, `run:` commands included; auto-masked names; JL006; JL011 for `.uj/`; `runs/` and `.env` git-ignored | put secrets in the CI store |
| 4 never weaken a red | `uj history` records each journey's content fingerprint | review `expect:` changes |
| 5 no fake green | INCONCLUSIVE; `--strict`; JL004, JL010; `uj verdict` | read lint advisories |
| 6 VOID is not a bug | VOID kept apart from FAIL; exit `2`; `uj doctor` | route exit `2` to the environment owner |
| 7 clean up | `finally:` always runs; `404` accepted; JL003 | write the `finally:` |
| 8 review `run:` | none: uj runs what the file says | read every `run:` line |
| 9 shared state | `conflicts: global:<name>` serialises under `--parallel`; JL007 | name the shared thing |
| 10 human intents | intent required on every step; JL008, JL009; `uj explain` | write for Maya |
| 11 risk first | the risk register, `covers:`, the GAPS list in `uj coverage`; JL013 for a session with no refusal step | choose and rank the risks (SOP 06) |
| 12 limits | stated here; certificates verified | keep `UJ_INSECURE_TLS` out of staging and CI |

## Review checklist for a journey pull request

Paste it into the pull request and tick each line:

- [ ] `uj lint` is `OK`, and every remaining advisory has a reason.
- [ ] `uj validate journeys/` passes.
- [ ] `uj explain` on the changed journeys reads like a user's story.
- [ ] No unmarked production URL, real customer, or literal password anywhere, `.uj/` included; secrets are `{env:…}` or `secret:`; no `.env` committed.
- [ ] `covers:` uses ids from `.uj/risks.context`, and `uj coverage` shows no unregistered id.
- [ ] Everything created is deleted in `finally:`.
- [ ] Every `run:` line has been read and is safe.
- [ ] No expectation was loosened without a stated reason; known-bug pins are still red.
- [ ] Journeys that change shared state declare `conflicts: global:<name>`.
- [ ] The run in CI shows the intended target on its first line.

## What you'll see

A suite that keeps these rules: `uj lint` ends `OK — no critical/high findings` with few advisories; `uj history --flaky` lists nothing; CI separates exit `1` (code) from exit `2` (environment); `uj explain journeys/` reads like the product's user stories; `git status` never shows `runs/` or a password.

## If it goes wrong

- A real email went to a customer, or data appeared in production — the target was wrong (rule 1). Mark that URL `production = true` in `harness.toml`, remove it from every CI variable, then clean up by hand.
- A password appears in a commit — rotate it first, then move it to `{env:…}` (rule 3).
- A red journey went green with no product change — someone weakened it (rule 4). Revert, then decide bug or expectation properly.
- Staging fills up with test invoices — journeys without `finally:` (rule 7); `uj lint` lists them as JL003.
- `--parallel` runs break each other — undeclared shared state (rule 9).

## Coming

- **A lint rule for weakened expectations** (a step's assertions shrinking in a diff). *Today:* review diffs of `expect:` blocks in pull requests.

## Next

SOP 00, the index, to find the job you need next. Or SOP 06 to choose what to test.
