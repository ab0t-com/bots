# 12 · Run journeys in CI and work on them as a team

**What this is for.** A CI job that runs your journeys on every change and tells three things apart: all good (`0`), the product or a journey is broken (`1`), the environment is broken (`2`). Plus the habits that keep a team's suite honest: who writes what, how journeys are reviewed, how pull requests stay fast, and how flaky journeys get caught. The running example is Acme's `invoicer` repo, with the uj project at the repo root (Acme's API; yours will differ).

**Before you start.** SOPs 04 (a `staging` target in `harness.toml`), 05 (setup reads `{env:ACME_QA_PASSWORD}`) and 11 (verdicts). A CI secret named `ACME_QA_PASSWORD`. Never point CI at production: journeys create users and invoices.

## Steps

**1. Pick the CI target.** `staging` (`https://invoicer.staging.acme.example`), named with `--target staging` on every command, so the job never depends on a teammate's default. Staging has sign-up switched off, so the job also passes its setup file, `--env environment.staging.json` (SOP 05 step 4). Mark any production URL in `harness.toml` with `production = true` (SOP 04 step 7): a job pointed at it by mistake then exits `2` before sending a request, instead of creating real data. Never add `--allow-production` to a CI job.

**2. Put secrets in the CI secret store, never in files.** `environment.staging.json` says `"qa_pass": "{env:ACME_QA_PASSWORD}"`; the job exports `ACME_QA_PASSWORD` from the secret store. Names that look secret (`…PASSWORD`, `…TOKEN`, `…API_KEY`) are masked in uj's output and in the JUnit/CTRF files. If the variable is missing, the journeys go VOID naming it, so the job exits `2`, not a false `1`. A `.env` file is for laptops only: it is git-ignored, never committed, and a variable the job sets always beats it.

**3. Install a pinned uj in the job.** The knobs go on `sh`, not on `curl`:
```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh | REF=v0.1.1 INSTALL_DIR=$HOME/.local/bin sh
uj --version        # uj 0.1.1-public; a curl | sh pipe cannot report a failed download, this line can
```

**4. Gate authoring first.** `uj lint journeys/` exits `1` when a file does not parse (bad YAML, an unknown key, an unreadable `within:`), so a typo is an authoring error caught before the run, not a VOID in the middle of it. Warnings are advisory. To make warnings block too:
```sh
uj lint journeys/ --json | jq -e '.journey_findings | map(select(.severity == "warn")) | length == 0'
```
Keep an OpenAPI spec in the repo? Gate how well it is documented too: `uj contract --spec openapi.json --min-documented 90` exits `1` when fewer than 90% of endpoints document a `2xx` response (SOP 15).

**5. Write the run script.** `scripts/ci-journeys.sh` in Acme's repo, plain POSIX shell, usable from any CI:
```sh
#!/usr/bin/env sh
# Run the journey suite against staging; translate uj's exit code for humans.
set -u
uj run --target staging --env environment.staging.json --strict \
  --junit results/uj-junit.xml --ctrf results/uj-ctrf.json "$@"
rc=$?
case $rc in
  0) echo "journeys: all passed" ;;
  1) echo "journeys: FAIL — the product broke, or a journey asserted nothing / was skipped (--strict); read the red journey" ;;
  2) echo "journeys: VOID — staging, the setup or the job is broken, not the code; run: uj doctor --target staging --env environment.staging.json" ;;
  *) echo "journeys: unexpected exit $rc" ;;
esac
exit $rc
```
`--strict` turns INCONCLUSIVE and SKIP into `1`: in CI, a journey that proved nothing is not green. uj creates the `results/` folder; if a report still cannot be written the run exits `2`, so a missing report never hides behind a green job. A `--tag` or `--persona` that matches nothing also exits `2`: a selection that runs nothing is not a pass. Extra arguments (`--changed-base …`, `--shard …`, `--tag smoke`) pass straight through.

**6. Wire it into the CI.** A GitHub Actions example; any CI that runs shell works the same way:
```yaml
name: journeys
on:
  pull_request:
  push:
    branches: [main]
jobs:
  journeys:
    runs-on: ubuntu-latest
    env:
      ACME_QA_PASSWORD: ${{ secrets.ACME_QA_PASSWORD }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }            # --changed-base needs the base branch's history
      - name: Install uj
        run: |
          curl -fsSL https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh | REF=v0.1.1 INSTALL_DIR=$HOME/.local/bin sh
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
      - run: uj --version && uj lint journeys/
      - uses: actions/cache@v4             # keeps runs/history.jsonl between runs for the flaky gate
        with: { path: runs/, key: "uj-runs-${{ github.run_id }}", restore-keys: "uj-runs-" }
      - name: Journeys (pull request = changed only, main = all)
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            sh scripts/ci-journeys.sh --changed-base "origin/${{ github.base_ref }}"
          else
            sh scripts/ci-journeys.sh
          fi
      - run: uj history --flaky
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: uj-results, path: results/ }
```
Point your CI's test-report viewer at `results/uj-junit.xml` (one test case per journey; FAIL → failure, SKIP → skipped, VOID and INCONCLUSIVE → error) or `results/uj-ctrf.json`.

**7. Route exit `1` and exit `2` to different people.** `1` blocks the merge and goes to the author. `2` is an environment problem: page whoever owns staging and re-run once it is back; do not ask the author to fix code. `sh scripts/ci-journeys.sh --failed` re-runs only the journeys that were not PASS last time; it reads `runs/history.jsonl`, so it needs the cache from step 6.

**8. Keep pull requests fast.** `--changed-base origin/main` runs only journey files changed since that ref. A change to a fragment, to an `environment*.json` or to `harness.toml` can change any journey, so it selects every journey. Nothing changed prints `no changed journeys — nothing to run (this is a clean pass in CI)` and exits `0`. Locally, `uj run --changed` runs what you changed since your last commit. The full suite on `main` (as above) or nightly is still the backstop.

**9. Go faster when the suite grows.** Run several journeys at once, or split the suite across machines:
```sh
sh scripts/ci-journeys.sh --parallel 4
sh scripts/ci-journeys.sh --shard 2/4          # this machine runs slice 2 of 4; slices never overlap
```
With `--parallel`, `conflicts: tenant` (or no `conflicts:`) means "touches only its own fresh data": it runs alongside anything, as lint JL007 suggests. `conflicts: global:<name>` marks a journey that changes something every journey sees (a global setting, a shared price list); journeys with the same `global:` name never run at the same time. `--parallel` is ignored with `--run-id`/`--resume`.

**10. Mind the certificates.** Journey requests verify TLS certificates, so staging with a broken certificate makes every journey VOID (exit `2`) with the reason. `UJ_INSECURE_TLS=1` accepts a self-signed certificate; set it only in a job that targets a dev environment, never in the staging job.

**11. Catch flaky journeys instead of retrying them.** `uj history --flaky` exits `1` when a journey has both passed and failed against the same target with the same content. It reads `runs/history.jsonl`, which lives on the runner: without the cache in step 6, a fresh runner has no history and the gate proves nothing. A flaky journey is fixed (SOP 14), not retried until green.

**12. Split the work: Maya writes the story, Dev writes the mechanics.** Maya writes `outcome`, `persona`, `narrative`, `success`, `covers` and every step's `intent`; Dev fills `method`, `path`, `body`, `capture`, `expect`. In the pull request, paste the story so non-engineers can review it without reading YAML:
```sh
uj explain journeys/sessions/MONTH_END_BILLING.yaml
```
Reviewers check three things: the story matches the product decision; the expectations are not weaker than before (SOP 14); every `run:` step is safe to execute on a CI machine.

**13. Keep `HARNESS.md` as the teammates' front door, and `.uj/` as the team's memory.** `uj init` wrote `HARNESS.md`: where things are, `uj where` first, how to run, how to write one, how to read a verdict. Put the team's testing rules (naming, folders, the tag list, who reviews) in `.uj/conventions.context`, the reasons behind choices in `.uj/decisions.md`, and pinned bugs in `.uj/findings.md` (SOP 14). They are committed, so CI, teammates and Quinn all read the same thing.

## What you'll see

The run's stderr starts with `(target: https://invoicer.staging.acme.example — from --target staging (…/harness.toml))`, then each journey, the summary `journeys: N passed · N failed · N skip/void/inconclusive`, and `wrote JUnit XML → results/uj-junit.xml` and `wrote CTRF JSON → results/uj-ctrf.json`. With `--changed-base`: `(changed: N journey(s))`. With `--shard`: `(shard 2/4: N journeys)`. `uj history --flaky` ends `N journeys · N FLAKY`.

## If it goes wrong

- `junit export failed: …` or `ctrf export failed: …` — the report could not be written (a read-only path, a full disk); the run exits `2`. Fix the path.
- `uj run --changed: git diff against "origin/main" failed (bad ref?): …` — a shallow clone; check out with full history (`fetch-depth: 0`).
- `uj run --changed: not a git repo (or git unavailable): …` — run from inside the checkout.
- `bad --shard "2-4", want i/n (e.g. 1/4)` — write `2/4`.
- Every journey VOID with `environment variable ACME_QA_PASSWORD is not set (referenced as {env:…}) — export it, or set it in your CI secrets` — the secret is not mapped into the job's environment.
- The browser journeys SKIP and `--strict` fails the job: run UI journeys in their own pack and job with a driver (SOP 10).
- `uj run: no journeys match persona="" tag="smok" — check the spelling (a selection that runs nothing is not a pass)` — exit `2`; fix the tag in the workflow.
- `uj run: target "prod" is marked production = true in harness.toml — journeys create real data; refusing. Pass --allow-production only if you really mean it` — exit `2`; the job (or an exported `UJ_BASE`) points at production. Point it at staging.
- `FAIL — 85% of endpoints document a 2xx response; --min-documented is 90%` — exit `1`; the spec lost documentation. Document the endpoints `uj contract` lists (SOP 15).
- `uj run --failed: nothing failed last time — nothing to re-run` — exit `0`; on a fresh runner without the `runs/` cache it means "no history", not "all green".
- `--parallel 8` is no faster: the journeys share one `conflicts: global:<name>`, or there are fewer journeys than slots (step 9).
- Every journey VOID on staging with `no response from the service (…)` while staging is up — its TLS certificate did not verify; fix the certificate, never add `UJ_INSECURE_TLS` to the staging job.

## Coming

- **History kept outside the runner** (a shared flake record). *Today:* cache or upload `runs/` between CI runs.
- **An exclude filter** (`--not-tag known-bug`). *Today:* `--tag`/`--persona` select only; keep pinned bugs in `journeys/findings/` (skipped by `uj run journeys/`) and run them in a non-blocking job (SOP 13).
- **A ready-made CI action.** *Today:* the shell script and workflow above.

## Next

SOP 13, manage many projects and suites. Or SOP 14 when a journey goes red because the API changed.
