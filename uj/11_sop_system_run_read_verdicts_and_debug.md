# 11 · Run journeys, read the verdict, debug a red one

**What this is for.** Running your journeys against a real service and knowing, without guessing, what happened: it worked, the product is broken, or the environment is broken. Then finding the exact step and response behind a red result, and retrying from that step. The running example is Acme's `invoicer` on `dev` (Acme's API; yours will differ).

**Before you start.** SOP 04 (a target in `harness.toml`), SOP 05 (setup and `uj doctor`), at least one journey (SOP 07). The service running on `dev`. `ACME_QA_PASSWORD` exported, or set in the project's `.env` (SOP 05). Every run creates real data (users, invoices): dev or staging only, never production.

## Steps

**1. Orient, then pre-flight once.**
```sh
uj where
uj doctor
```
`uj where` is offline: which project, which target and where it came from, the setup, how many journeys, the last run, the risk gaps. `uj doctor` contacts the target: it checks the project, the environment file, that the target answers, and runs your setup steps for real (so it creates one test user). It ends ``doctor: OK — ready to `uj run` `` or ``doctor: FAIL — fix the above before `uj run` (a journey would VOID here)`` with a `fix:` line under each `✗`. To check the target answers without creating that user, `uj doctor --no-setup`.

**2. Run.** Pick the scope:
```sh
uj run                                                   # every journey in journeys/, default target
uj run journeys/sessions/MONTH_END_BILLING.yaml          # one journey
uj run journeys/security/                                # one folder
uj run --target staging                                  # another [target.NAME] from harness.toml
uj run journeys/ --base http://localhost:8080            # an explicit URL, overrides everything
uj run --project invoicer                                # a remembered project, from any folder (SOP 13)
uj run --failed                                          # only journeys whose last result was not PASS
uj run --timeout 90s                                     # a slower per-request limit (default 30s; or UJ_TIMEOUT=90s)
```
Files and folders starting with `_` or `.`, and `fragments/` and `findings/` folders inside the folder you give, are not run.

**3. Read the two header lines first.** Before any result, uj prints where it is pointed:
```
(target: <url> — from <source>)
(environment: environment.json)
```
`<source>` is `--base`, `$UJ_BASE`, `--target staging (…/harness.toml)` or `target "dev" (…/harness.toml)`. If the URL is not the service you meant, stop (Ctrl-C) and fix the target (SOP 04).

**4. Read each journey's block.** One block per journey, then a summary. The shape, with Acme values (the format is uj's; the values are illustrative):
```
FAIL  MONTH_END_BILLING [epic]  (passed=5 failed=1 skipped=1)
   step 6: field "status" = "draft", wanted "sent"
   ✓ 1. [browse_invoices] they glance at their invoice list  [GET 200]
   ✓ 2. Sam starts an invoice but forgets the currency  [POST 422]
   ...
   ✗ 6. CHECKPOINT: opening the invoice again shows it as sent  [GET 200]  — field "status" = "draft", wanted "sent"
       ↳ response: {"id":"inv_…","status":"draft","customer":"Globex Ltd",…}
   – 7. someone with the link but no login tries to open it  — skipped — a prior step failed
   ✓ 8. [finally] remove the invoice  [DELETE 204]
   ### UJ-VERDICT v1 {"id":"MONTH_END_BILLING","result":"fail","passed":5,"failed":1,"skipped":1}
```
`✓` passed, `✗` failed, `–` not run. Line two is the first failing step's reason. `↳ response:` is what the service actually returned, with secrets masked. `[finally]` steps always run and do not count toward the verdict. Steps from a fragment carry its name in brackets.

**5. Name the verdict.**

| verdict | it means | do |
|---|---|---|
| PASS | every assertion held | nothing |
| FAIL | the service answered and an expectation did not hold | step 7 |
| VOID | uj could not judge: setup failed, no response, an unresolved `{var}` or unset `{env:…}`, or the journey file could not be loaded | step 8; not a product bug |
| SKIP | a `capability:` the journey needs is absent (`capability absent: browser`) | expected where the capability is missing |
| INCONCLUSIVE | `no steps executed an assertion` | add steps that assert something |

**6. Use the exit code, not the colour.**
```sh
uj run; echo "exit $?"
```
`0` all passed (SKIP and INCONCLUSIVE included) · `1` at least one FAIL (outranks VOID) · `2` a VOID or a usage error. `--strict` also turns INCONCLUSIVE and SKIP into `1` (SOP 12). A journey file that cannot be loaded (bad YAML, an unknown key, an unreadable `within:`) is VOID, not FAIL: the test never ran, so it says nothing about the product. `uj validate journeys/` before `uj run` catches those.

**7. Debug a FAIL: bug or wrong expectation?** Read the step's reason and `↳ response:`. For the full body of every step, ask for JSON:
```sh
uj run journeys/sessions/MONTH_END_BILLING.yaml --json \
  | jq '.results[0].steps[] | select(.ran and (.pass | not)) | {n, intent, method, status, reason, resp_body}'
```
Then ask, in order: does the response match what Maya wrote in `success:`? If not, it is a **bug**: leave the journey red and file it. Is the expectation wrong (a field path, an id from the wrong step, a rule nobody agreed)? Fix the journey, and say why in the pull request. Never loosen an expectation to get green (SOP 14).

**8. Debug a VOID.**
```sh
uj doctor
```
Match the reason:

| reason starts with | fix |
|---|---|
| `environment setup failed (…)` | a setup step failed; `uj doctor` shows which, then fix that step (SOP 05) |
| `no response from the service (…) — is it running at …?` | start the service or fix the target |
| `unresolved {…} — not provided by environment.json setup, the journey's vars:, or an earlier capture:` | a typo or a missing capture; `uj lint` (JL001) finds most |
| `environment variable ACME_QA_PASSWORD is not set (referenced as {env:…})` | export it, or add it to CI secrets; the same reason appears for a `run:` step's `{env:NAME}` |
| `journey file could not be loaded: <error> — fix it (uj validate <file>)` | the file itself is broken (SOP 07); fix it, then re-run |
| `no response from the service (…)` on an `https` target that is up | the TLS certificate did not verify; fix it, or `UJ_INSECURE_TLS=1` for a self-signed dev target only |

**9. Retry from the failed step, state intact.** Checkpoint a run, then resume it after you fix the service or the environment:
```sh
uj run journeys/sessions/MONTH_END_BILLING.yaml --run-id dbg
uj run journeys/sessions/MONTH_END_BILLING.yaml --resume dbg
```
Setup and the passed steps are not repeated; captured values come back. One journey per run-id. To retry the whole red set after a fix instead, `uj run --failed`: it runs every journey whose last recorded result was not PASS (FAIL, VOID, SKIP or INCONCLUSIVE) and any file that no longer loads; journeys with no history yet are left out. Checkpoints live in `runs/<journey>/<run-id>/`, secrets masked; the real secrets sit in a `secrets.json` readable only by you, deleted when the run finishes cleanly.

**10. Keep experiments out of history.**
```sh
uj run scratch.yaml --no-history
```
Every normal run appends to `runs/history.jsonl` (with the target and a fingerprint of the journey's expanded steps, fragments included), which feeds flaky detection. It also records the run's counts in your project list, so `uj where` and `uj projects` show the last run.

**11. Read the history.**
```sh
uj history
uj history MONTH_END_BILLING
uj history --flaky
uj history --prune 50        # keep the newest 50 records per journey
```
One line per journey: `FLAKY` when it has both passed and failed against the same target with the same content, the run count, counts per verdict, and the last twelve verdicts oldest→newest (`·` pass, `X` fail, `-` skip, `!` void, `?` inconclusive). `--flaky` exits `1` if any journey is flaky. `runs/history.jsonl` grows with every run; `--prune N` rewrites it keeping the newest N records per journey (keep enough for flaky detection).

## What you'll see

The summary after the blocks: `journeys: N passed · N failed · N skip/void/inconclusive`, then one `next:` line. All green: ``next: `uj history` to track flakes over time · add `--strict --junit results.xml` in CI``. A FAIL: `next: re-run a red journey with --json to see the failing step; --run-id X then --resume X to retry from it`. A VOID: ``next: VOID = the environment broke (fix it, then re-run) — `uj doctor` pinpoints what; INCONCLUSIVE = add assertions``. A resumed run prints `(resuming dbg from step 6)` first. `--json` prints one object: `summary {passed, failed, other, void}`, top-level `base`, and per journey `result` in capitals (`PASS`) with `steps` carrying `n, intent, method, status, ms, ran, pass, reason, resp_body` (`ms` is the step's time in milliseconds). `uj run --failed` names its selection first: `(--failed: 2 journey(s) not PASS last time)`. `uj history --prune 50`: `history: kept K of T record(s) (newest 50 per journey)`. The `### UJ-VERDICT v1` line uses lower case. History with nothing yet: `no run history yet (run some journeys first; history is written unless --no-history)`.

## If it goes wrong

- `uj run: no target service — pass --base <url> …` — no target anywhere; SOP 04.
- `… has several targets (dev, staging) and no default — pass --target NAME, or set default_target = "NAME" under [project]` — add `default_target = "dev"`.
- `uj run: no journeys found` — wrong folder, or every file starts with `_`.
- `uj run --failed: nothing failed last time — nothing to re-run` — exit `0`: every journey with history passed last time.
- `uj run: target "prod" is marked production = true in harness.toml — journeys create real data; refusing. Pass --allow-production only if you really mean it` — exit `2`; the URL is a marked production target (SOP 04 step 7). Pick `dev` or `staging`.
- A VOID with no response on an endpoint you know is slow (a big export, a report) — the 30-second request limit ran out. `--timeout 90s` or `UJ_TIMEOUT=90s`; if a customer would also wait that long, that is a finding.
- `uj run: --run-id/--resume target a single journey (got 6); pass one journey file` — give one file.
- `no checkpoint for run-id dbg: …` (VOID) — that run-id was never saved for this journey, or it failed on step 1 before any checkpoint.
- `run-id dbg already finished (…)` (SKIP) — it passed; run without `--resume`.
- `uj run: no journeys match persona="…" tag="…" — check the spelling (a selection that runs nothing is not a pass)` — exit `2`; fix the tag or persona.
- `` uj: no project "invoicer" in your project list — `uj projects` lists them; `uj projects --scan <dir>` finds more `` — `--project` with a name this machine has not seen; exit `2`.
- A FAIL on a cleanup step only (`[finally]`) does not change the verdict; a `404` there reads `already gone (404) — fine for cleanup`.
- `skipped — nothing to clean up (unresolved {invoice_id} was never captured)` — the journey stopped before the create returned an id; nothing leaked from that step.

## Coming

- **Resume across a whole folder.** *Today:* `--run-id`/`--resume` take one journey file.
- **An HTML run report.** *Today:* the text output, `--json`, and JUnit/CTRF files for your CI's viewer (SOP 12).

## Next

SOP 12, CI and the team workflow. Or SOP 14 when the red is the journey's fault.
