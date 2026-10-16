# 17 · Everything else uj can do

**What this is for.** uj is built to run user journeys, but its parts are useful on their own: an honest scorer for any test's output, a linter for old shell tests, a story printer, a risk map, a way to compare two versions of a service, and a JSON surface for agents. This page lists those "off-label" uses with the exact commands, using Acme's `invoicer` (Acme's API; yours will differ).

**Before you start.** uj installed (SOP 03). Most uses below need no running service; the ones that run journeys need a project with targets `dev` (`http://localhost:8080`) and `staging` (`https://invoicer.staging.acme.example`) (SOP 04). Journeys create real data: point them at `dev` or `staging`, never production.

| use | command | needs a service |
|---|---|---|
| score any test's output honestly | `uj verdict <file\|->` | no |
| lint old shell test scripts | `uj lint <dir>` | no |
| living documentation | `uj explain journeys/` | no |
| risk map and gaps | `uj coverage` | no |
| "where are my tests, and how did they last run?" | `uj where`, `uj projects` | no |
| compare two implementations / migration parity | `uj run --target …` twice + `uj contract --parity` | yes |
| smoke check after a deploy to staging | `uj run --tag smoke --target staging --strict` | yes |
| dogfood your product as a stranger | `uj new journey …` from public docs only | yes, to run |
| check anything scriptable | a `run:` step | depends |
| drive uj from an agent or script | `--json`, `uj help --json`, `uj schema` | no |

## Steps

**1. Score any test's output honestly.** Pipe the output of any test (a shell script, another runner) into `uj verdict`:
```sh
./scripts/old_invoice_test.sh | uj verdict -
```
uj looks, in order, for a `### UJ-VERDICT v1 {…}` line, a `Result:` line (`PASS`/`FAIL`/`GREEN`/`RED`/`VOID`/`SKIP`/`INCONCLUSIVE`), a `Success Rate: N%` line (100 is PASS, anything else FAIL), then environment or skip signals. It never treats exit code 0 as a pass. Exit codes: `0` pass · `1` fail · `2` void · `3` skip · `4` inconclusive, so CI can gate on them. Add one line at the end of your own scripts to make them scoreable: `echo '### UJ-VERDICT v1 {"id":"INVOICE_SMOKE","result":"pass","passed":4,"failed":0,"skipped":0}'`.

**2. Lint old shell test scripts.**
```sh
uj lint scripts/
```
Every `.sh` file is checked against the UJ rules (`uj lint --rules` lists them): status capture corrupted by `2>&1` (UJ001), no unique suffix so a re-run collides (UJ005), creates without deleting (UJ006), fixed `sleep` where a poll belongs (UJ010), missing execute bit (UJ015), no verdict line (UJ017). UJ016 expects files named `UJ-<number>-…`, UJ011 a specific local port, and UJ002–UJ004 a seeded-fixture style; read those as advice for that convention and ignore them if your scripts follow another.

**3. Print living documentation.**
```sh
uj explain journeys/ > JOURNEYS.txt
```
Every journey becomes a plain story: outcome, persona, success, the numbered steps, what must be refused, what is always cleaned up. Regenerate it in CI and attach it to release notes; it cannot drift from the tests because it is the tests.

**4. Print the risk map.**
```sh
uj coverage journeys/
uj coverage journeys/ --json
```
Each risk named in a journey's `covers:` is listed with the sessions that exercise it; journeys that declare none are flagged as untracked. With a risk register in `.uj/risks.context` it also lists the registered risks no journey covers, most important first (SOP 06). It is not code coverage; it answers "which of our fears does a test watch, and which does nothing watch?".

**5. Compare two implementations of one API.** Same pack, two targets, results side by side (a rewrite, a new region, a vendor's clone of your API):
```sh
uj run journeys/ --target dev --json > dev.json
uj run journeys/ --target staging --json > staging.json
diff <(jq -r '.results[] | "\(.id) \(.result)"' dev.json) <(jq -r '.results[] | "\(.id) \(.result)"' staging.json)
```
Any line in the diff is a behavioural difference. Run history keeps the targets apart, so a journey that passes on one and fails on the other is not marked flaky. Every step in the JSON carries `ms`, so compare speed the same way: `jq -r '.results[] | .id as $j | .steps[] | "\($j) \(.n) \(.ms)ms"' dev.json`.

**6. Prove a migration kept its promises.** Before switching traffic from the old service to the new one:
```sh
uj contract --spec old-openapi.json --parity new-openapi.json
uj contract --spec new-openapi.json --har old-session.har
```
The first shows endpoints documented differently; the second checks responses recorded from the **old** service against the **new** spec, so a field the new spec requires (or types differently) that today's responses do not match shows as `✗`. Fields the new spec dropped are extra fields and pass, and endpoints it dropped are skipped, so also run SOP 15 step 4's diffs. Then run step 5 with the old and new services as the two targets.

**7. Smoke-check a deploy to staging.** Tag a short session `tags: [smoke]` (health, sign up, log in, list invoices, anonymous refused), then after each staging deploy:
```sh
uj run journeys/ --tag smoke --target staging --strict
```
`--strict` makes INCONCLUSIVE and SKIP fail too. A tag that matches nothing stops with `uj run: no journeys match persona="" tag="smoke" — check the spelling (a selection that runs nothing is not a pass)` and exit `2`, so a typo cannot pass as green. uj verifies TLS certificates on journey requests, so an expired or wrong certificate on staging makes the smoke VOID (exit `2`) with the reason. Production is not a smoke target: with `production = true` on it in `harness.toml` (SOP 04 step 7), `uj run` refuses it (exit `2`). After a production deploy, `uj doctor --target prod --no-setup --allow-production` checks that it answers, without creating anything.

**8. Dogfood your product as a stranger.** Ask someone who has never seen `invoicer`'s code to write a journey from your public docs only:
```sh
uj new journey "A stranger sends their first invoice using only the docs"
```
Every place they get stuck is a finding: a step marked `misstep: true` for a wrong turn a real user takes, a docs fix, or a confusing error. `uj explain` the result and hand it to Maya; it reads like a usability report.

**9. Check anything scriptable with a `run:` step.** A step can run a shell command instead of an HTTP call; uj expects the exit code you name:
```yaml
  - intent: the release did not leave the ledger out of step
    run: "./scripts/check_ledger.sh {email}"
    expect: {exit: 0}
```
Use it for a database check, Acme's own CLI, a queue, another service (`{base}` is the current target). To capture from it, the command must print JSON on stdout. A `run:` step runs on the machine running uj, with your permissions: read every `run:` line in a journey you did not write before running it (SOP 19).

**10. Drive uj from an agent or a script.**
```sh
uj help --json                    # every command: name, group, summary, usage, examples, needs_service
uj schema journey > journey.schema.json
uj lint journeys/ --json          # blocking, parse_failures, findings, journey_findings
uj run journeys/ --json           # base, summary {passed, failed, other, void}, results[] with steps[] (each with ms)
```
`coverage`, `fragments`, `history`, `where` and `projects` take `--json` too; `uj where --json` is the one-call orientation for an agent arriving in a project. Parse the JSON, not the text; the exit codes (SOP 11) carry the verdict.

## What you'll see

`uj verdict` on a script that only prints "all good":
```
result:  INCONCLUSIVE
source:  none
reason:  no verdict line and no Success Rate — cannot conclude (exit 0 is NOT accepted as pass)
```
exit `4`. On a `Result: RED` line: `result:  FAIL`, `source:  result-line`, exit `1`. `uj lint` on an old script ends with `lint: 0 journey file(s) + 1 bash-UJ file(s) · 6 critical/high finding(s), …` and `FAIL — critical/high findings present (fix before commit)` (exit `1`). `uj coverage journeys/` ends with `3 behavior(s) covered across 2 session(s)`.

## If it goes wrong

- `usage: uj verdict <file|->   (scores a journey's captured stdout)` — no input given; pass a file or `-` and pipe.
- `reason:  environment signal in output` with `result:  VOID` — the output contains a phrase such as `service unhealthy` or `preflight failed`; uj reads it as "could not judge". Fix the environment, or print an explicit verdict line.
- `UJ016` on every script — your scripts are not named `UJ-<number>-…`. Ignore it or rename.
- Step 5's diff is empty but one side was VOID everywhere — the service was down; check both files' `.summary.void` first.
- `run exit 1, wanted 0 — <first line of output>` — the command failed; the first line of its output is quoted.
- `run capture failed: no value at $.x (the command must emit JSON on stdout to capture from it)` — the command printed text, not JSON.

## Coming

- **First-class multi-service journeys** (one journey, several targets). *Today:* `run:` steps that call the other service with `{env:…}` or captured URLs (SOP 10).
- **A built-in comparison report** for two targets. *Today:* step 5's `jq` + `diff`.
- **A read-only smoke mode for production** (journeys that only read). *Today:* the reachability check in step 7; smoke staging, and use your monitoring for production.

## Next

SOP 18, troubleshooting. Or SOP 19, the rules for honest tests.
