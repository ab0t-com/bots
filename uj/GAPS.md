# GAPS — every **Coming** item in the SOPs, in one table

Each row is something the SOPs describe as part of the ideal flow that uj (0.1.1) does not do yet, with the path to take today. This is the spec list. When a row ships, update the SOPs named in the row and delete the row. Rows 1 and 2 are the two largest gaps: load testing driven by your own journeys, and journeys that span several services. Everything else is a convenience or a sharper check; none of it blocks a team from testing honestly today.

| # | item | SOP | why users want it | today |
|---|---|---|---|---|
| 1 | **Generic load from journeys** (`uj load journeys/`: N virtual customers, ramp, duration, p50/p95/p99 per step, PASS/FAIL against budgets) | 06, 16 | after "does it work" the next question is "does it hold up", with real sessions | `within:` budgets, `--parallel` concurrency smoke, the same file passed N times, an external load tool scripted from the journey |
| 2 | **First-class multi-service journeys** (a named target per step) | 04, 10, 17 | one customer story crosses invoicer, the mailer and the web app | one target per run; other services through `run:` steps with `{env:NAME}` or captured URLs; one pack per service plus a small cross-service pack |
| 3 | **`load` / `probe` / `catalog` usable on any service** (your setup instead of the built-in fixtures) | 16 | the verbs are listed in `uj help` and look usable | none; do not run them on your service |
| 4 | **`uj uninstall`** | 03 | clean removal without knowing where the installer put things | delete the binary and `uj.previous`, and the state folder |
| 5 | **`uj update` to a chosen version** | 03 | pin or downgrade without re-running the installer | the installer with `REF=v<version>` |
| 6 | **Package-manager installs** (Homebrew, winget, apt) | 03 | org policy often forbids `curl \| sh` | the installers, or a `release/` binary checked against `release/checksums.txt` |
| 7 | **Windows on ARM and other platforms** | 03 | the PowerShell installer detects arm64 but no build is published | linux amd64/arm64, macOS amd64/arm64, windows amd64 |
| 8 | **A setup file bound to each target** (staging → `environment.staging.json`) | 04, 05 | no `--env` to remember on every staging command | `--env FILE` with `--target NAME` |
| 9 | **`uj target add` / `uj target list`** | 04 | edit targets without hand-editing TOML (and the `default_target` placement trap) | edit `harness.toml`; `uj where` shows what resolves |
| 10 | **One command for every project in a monorepo** (each with its own target) | 04, 13 | one CI step for many services | `uj run --project <name>` per project, a shell loop, or separate CI jobs |
| 11 | **Setup teardown** (remove the users setup created) | 05 | every journey and every `uj doctor` leaves a user on the target | a resettable dev/staging; clean up records in each journey's `finally:` |
| 12 | **`uj new` scaffolding the rule-of-three trio** (functional, regression, security) | 06 | auth and data changes need all three | write them by hand, or three checkpoints in one session |
| 13 | **A dry run** printing each resolved request without sending it | 07 | see exactly what will hit the service | `uj explain` + `uj lint` |
| 14 | **Drafting journey steps from an OpenAPI operation** | 07 | faster mechanics for engineers | `uj init --openapi` drafts setup only |
| 15 | **Number comparisons and ranges in `expect`** | 08 | amounts, counts, totals | exact values; `type: number` in `schema` |
| 16 | **Regex matches and list length in `expect`** | 08 | ids, formats, "exactly 2 items" | `contains` for substrings and members; `items[N].id` |
| 17 | **`$ref`, `enum` and `format` in `expect.schema`** | 08, 15, 19 | allowed status values, date formats, shared schemas | inline fields; exact values in `body:` |
| 18 | **"Eventually" checks / a wait-retry step** (`until:`) | 08, 10 | async sends, webhooks, background jobs | a polling loop with a deadline in a `run:` step |
| 19 | **Fragment parameters** (`use: create_draft_invoice` with values) | 09 | reuse one activity with different data | set the values in `vars:` and write the fragment against `{name}` |
| 20 | **`needs:` / `provides:` enforced at lint time** | 09 | catch a fragment used where its inputs do not exist | documentation in `uj fragments`; JL001 catches unknown `{var}` after expansion |
| 21 | **The same fragment twice in one journey** | 09 | sessions repeat activities (two invoices) | captures are append-only; inline the second copy with new capture names |
| 22 | **Data-driven steps** (one step, a table of inputs) | 09 | edge-input lists without one step per input | one step per input, or a `run:` loop |
| 23 | **Generated payloads** (huge, random, fuzzed bodies) | 09 | size and fuzz edge cases | a `run:` step that builds the body and calls `{base}` |
| 24 | **Time travel** (due dates, expired tokens) | 09 | date-based rules and real expiry | a forged token for "expired"; date rules need a test hook in your API |
| 25 | **A built-in browser driver** | 10 | UI steps without writing a driver | bring one via `UJ_BROWSER_CMD` or `UJ_BROWSER_URL` |
| 26 | **Auth headers and settings for the `http` browser driver** | 10 | browser services behind auth | only the three `UJ_BROWSER_*` variables are read; use an unauthenticated dev endpoint |
| 27 | **A way for a `run:` step to report VOID** (the other service is down) | 10 | honest verdicts when a dependency, not the product, broke | an unset `{env:NAME}` is VOID; a down service is a FAIL whose last output line says why |
| 28 | **A built-in webhook receiver** | 10 | assert on outbound callbacks directly | poll the receiving service |
| 29 | **Resume across a whole folder** | 11 | retry a whole red suite from where each stopped | `--run-id` / `--resume` take one journey file |
| 30 | **An HTML run report** | 11 | a shareable result page | text, `--json`, JUnit/CTRF in the CI viewer |
| 31 | **History kept outside the runner** (a shared flake record) | 12 | a flaky gate that works on fresh CI runners | cache or upload `runs/` between CI runs |
| 32 | **An exclude filter** (`--not-tag known-bug`) | 12, 13 | keep pins out of the gate without moving files | `journeys/findings/` (skipped by `uj run journeys/`) + a non-blocking job |
| 33 | **A ready-made CI action** | 12 | one-line CI setup | the shell script and workflow in SOP 12 |
| 34 | **One gap report across projects and repos** | 13 | one view of the product's untested risks | the per-project `uj coverage --json` loop in SOP 13, or merge per repo in a dashboard |
| 35 | **A rename that keeps history** (`uj mv OLD NEW`) | 13, 14 | rename without losing the flake record | a new id starts a new history line; note the old id in `notes:` |
| 36 | **An expected-failure marker** for pinned bugs (alerts on an unexpected pass) | 14 | keep pins red in reports without breaking the gate | `findings/` + a non-blocking job + `.uj/findings.md`; watch for green |
| 37 | **A check that flags weakened expectations in a diff** | 14, 19 | stop "make it green" edits | reviewers compare `expect:` blocks |
| 38 | **Find every use of a field across journeys and fragments** | 14 | safe API renames | `grep -rn` |
| 39 | **Field-level breaking-change diff in `contract --parity`** (renamed, removed, retyped fields; endpoints in one spec only) | 15 | parity compares only whether bodies are documented | `diff` of `jq -S .` and of the endpoint list |
| 40 | **The list of endpoints a HAR did not exercise** | 15 | `--har` prints only `N/M endpoints exercised` | compare HAR URLs with the endpoint list by hand |
| 41 | **Endpoint coverage from journeys** (not only from a HAR) | 15 | teams already have journeys; recording a HAR is extra work | `uj coverage` for risks + a HAR from devtools or a proxy |
| 42 | **Status-aware HAR conformance** | 15 | recorded `401`/`404` bodies are checked against the 2xx schema | record successful calls only |
| 43 | **A built-in comparison report for two targets** | 17 | rewrite and migration parity is a common job | `run --json` per target + `jq` + `diff` |
| 44 | **A read-only smoke mode for production** | 17 | a post-deploy check in prod; journeys create data | `uj doctor --no-setup --allow-production` on the production target checks it answers; smoke staging, monitor prod |
| 45 | **`uj explain-error <message>`** | 18 | people and agents search by message | SOP 18 |
