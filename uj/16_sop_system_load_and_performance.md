# 16 · Speed, latency and load: what uj can and cannot do today

**What this is for.** Knowing whether `invoicer` is fast enough, and stays correct when several customers use it at once, without being misled by a tool that was not built for your service. The honest summary first: uj's `load` and `probe` commands are **not usable on your service yet**. They were built for one specific benchmark (two implementations of an authentication service compared side by side), and they assume that service's endpoints, accounts and setup. A generic load mode driven by your journeys is **Coming**. Today you get three useful things: latency budgets on journey steps, a concurrency smoke with `--parallel`, and your journeys as the script for a dedicated load tool.

**Before you start.** Journeys that pass on `dev` (SOP 11). Acme's targets: `dev` (`http://localhost:8080`) and `staging` (`https://invoicer.staging.acme.example`). Performance numbers from a laptop against `dev` are only good for spotting regressions; measure real capacity on `staging`, and never generate load against production or a shared environment without its owner's agreement.

## Steps

**1. Put a latency budget on the steps customers wait for.** Add `within:` to a step's `expect`:
```yaml
  - intent: they create an invoice for a client
    method: POST
    path: /invoices
    bearer: "{token}"
    body: {customer: "Globex", amount: 120, currency: "EUR"}
    capture: {invoice_id: $.id}
    expect: {status: 201, fields: [id, status], within: 800ms}
```
The value is a duration: `800ms`, `2s`, `60s`; `uj validate` and `uj lint` refuse anything else (`within: fast`). uj times the request (sending it and reading the whole response). Slower than the budget is a **FAIL**, so a slow regression blocks the merge like a functional bug. Set budgets from what customers tolerate, with headroom for a noisy CI runner; a budget that flaps is worse than none (SOP 14, flaky triage).

**2. Run the suite with several journeys at once (a concurrency smoke, not a load test).**
```sh
uj run journeys/ --target staging --parallel 8
```
Up to 8 journeys run at the same time, each with its own fresh setup (its own signup and token), so `invoicer` sees several customers signing up, creating and deleting invoices together. This catches races: duplicate ids, two customers seeing each other's invoices, `500`s under contention, deadlocks. Journeys marked `conflicts: tenant` (or with no `conflicts:`) touch only their own data and run alongside anything; journeys that share a `conflicts: global:<name>` never run at the same time, so keep that on journeys that change something every customer shares.

**3. Repeat it to surface intermittent failures.**
```sh
for i in 1 2 3 4 5; do uj run journeys/ --target staging --parallel 8 || break; done
uj history --flaky
```
A journey that passes alone but fails under concurrency shows up as `FLAKY` (the same journey, unchanged, against the same target, with both PASS and FAIL). Treat it as a concurrency bug until proven otherwise.

**4. Run one journey as several customers at once.** uj does not de-duplicate the paths you give it, so naming one file several times runs that many independent copies:
```sh
uj run journeys/SMOKE_AFTER_DEPLOY.yaml journeys/SMOKE_AFTER_DEPLOY.yaml \
       journeys/SMOKE_AFTER_DEPLOY.yaml journeys/SMOKE_AFTER_DEPLOY.yaml --target staging --parallel 4
```
Each copy signs up its own customer (`{rand}` gives fresh emails). The journey must not declare a `conflicts: global:<name>`, or the copies run one after another; `tenant` is fine. Concurrency is capped by the number of journeys you pass; this is still a smoke, not a load profile.

**5. Collect per-step timings.** In `--json` every step carries `ms`, its time in milliseconds:
```sh
uj run journeys/ --target staging --json \
  | jq -r '.results[] | .id as $j | .steps[] | select(.ran) | "\($j)  \(.n). \(.intent)  \(.ms)ms"'
```
Save that per run to watch a step slow down across releases. The CTRF export (`--ctrf results.json`) carries the same times in its per-step log lines, shaped `<mark> <n>. <intent> [<METHOD> <status>, <ms>ms]`, for a CI viewer.

**6. For real load, drive a dedicated load tool with your journeys' calls.** k6, Locust, Gatling, vegeta and similar tools generate sustained traffic and report percentiles. Use your journeys as the script, so load exercises what customers actually do:
```sh
grep -E '^\s+(- )?(intent|method|path):' journeys/SMOKE_AFTER_DEPLOY.yaml
```
That prints each step's intent, method and path in order (a `run:` step shows only its intent). Recreate the session in the load tool (sign up once per virtual user, then the steps), point it at `staging`, and keep the uj journeys as the correctness check you run straight after the load test.

**7. Give a legitimately slow call more time.** Each request may take 30 seconds before uj gives up and the journey goes VOID. A call that is slow by design (a year-end export) can have more:
```sh
uj run journeys/ --target staging --timeout 90s     # or UJ_TIMEOUT=90s
```
The limit applies to every request in the run. Use `within:` (step 1) for what customers tolerate; raise the timeout only so a slow step can be judged at all.

**8. If you are curious about `load` and `probe`, read their help, do not run them.**
```sh
uj help load
uj help probe
uj catalog
```
`uj help load` describes it as a throughput / latency / memory benchmark that needs a running service. `uj catalog` lists the built-in scenarios: they are endpoints of that authentication service (`validate_token`, `org_create`, `apikey_mint` …), not yours. `load` and `probe` provision their own accounts through that service's registration and login endpoints, take one URL per implementation (`--py-url`, `--go-url`), sign in with an admin account, and default to that service's local addresses. Pointed at `invoicer` they fail during setup or measure nothing meaningful.

## What you'll see

A step over budget: **FAIL**, reason `took <elapsed>, wanted within 800ms` (for example `took 1.204s, …`). Under `--parallel`, output is printed in a stable order after all journeys finish, then the usual summary `journeys: N passed · N failed · N skip/void/inconclusive`. `uj history --flaky` lists `FLAKY` rows and ends `<n> journeys · <n> FLAKY`; it exits `1` if any journey is flaky.

`uj init` also creates a `scenarios.d/` folder with an `example.json`. It belongs to the benchmark above; nothing in your journeys reads it. Leave it alone. (`uj check scenarios.d/` on a fresh project prints `OK: 1 scenario(s) parse + validate cleanly (0 duplicate-key warnings)`.)

## If it goes wrong

- `took 1.204s, wanted within 800ms` on CI but never locally — the runner is slower or farther from the service. Raise the budget for CI or run CI next to `staging`; do not delete the budget.
- `<ID>: step N within: "fast" is not a duration (use e.g. "800ms" or "2s")` — the journey does not load (a run reports it as VOID). Use `800ms`, `2s`.
- `no response from the service (… Client.Timeout exceeded …) — is it running at <url>?` — the request took longer than the per-request limit (30 seconds unless `--timeout` or `UJ_TIMEOUT` says otherwise). The journey is **VOID**, not FAIL. Either the service is overloaded (stop the load and check it), or the call is slow by design: step 7.
- `--parallel 8` takes as long as a plain run — your journeys share one `conflicts: global:<name>` and are serialised, or there are fewer journeys than slots. See step 2.
- Many VOIDs only under `--parallel` — setup itself is failing under concurrency (signup rate limits, a shared admin account). Run `uj doctor` (SOP 05); slow down with a lower `--parallel`.
- `uj load` / `uj probe` errors about registration, organisations, admin login or containers — expected on your service. Use steps 1–7.

## Coming

- **Generic load from journeys** (`uj load journeys/` with N virtual customers, ramp, duration; p50/p95/p99 per step; a PASS/FAIL against budgets). *Today:* steps 2–4 for concurrency, step 6 for load.
- **`load`/`probe`/`catalog` for any service** (your setup instead of the built-in auth fixtures). *Today:* none; do not run them on your service.

## Next

SOP 17, everything else uj can do. Or SOP 12 to put budgets and the concurrency smoke into CI.
