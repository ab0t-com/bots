# 18 · Troubleshooting: every message, what it means, what to do

**What this is for.** The messages uj prints, in its own words, with what each means and the fix. Find your message by its fixed words; parts in `<angle brackets>` vary (a path, a name, a number). Examples use Acme's `invoicer` (Acme's API; yours will differ).

**Before you start.** Four looks answer most questions; only `doctor` and `run` touch the service:
```sh
uj --version                 # which uj (uj 0.1.1-public)
uj where                     # offline: project, target and its source, setup, last run, risk gaps, memory
uj doctor --target dev       # target, environment file, reachability, setup — each with its fix
uj run <journey> --json      # the failing step, its reason and the response body
```
`uj doctor` does run your setup steps (a signup, a login) against the target, like a journey would; `uj doctor --no-setup` checks everything else and creates nothing. Point it at `dev` or `staging`, never production.

## Install and update

| you see | it means | do |
|---|---|---|
| `[!] <dir> is not in your $PATH. Add it:` | installed, but your shell cannot find it | add the printed `export PATH=…` line to your profile, open a new shell |
| `[ok] uj 0.1.1-public already installed at <path> — nothing to do.` | already current | nothing |
| `[x] could not fetch checksums.txt — refusing to install without verification` | network or mirror problem | retry; behind a proxy use `UJ_INSTALL_BASE=<mirror>` on `sh` (SOP 03) |
| `[x] checksum mismatch — expected <a>, got <b>. Aborting (no install performed).` | the download was altered or truncated | retry; if it repeats, stop and report it |
| `[x] download failed — the binary may not be published for <platform> yet` | no build for your OS/CPU | SOP 03, platforms |
| `[x] no sha256 tool found (need one of: sha256sum, shasum, openssl)` | the installer cannot verify | install one of them |
| `[x] <dir> is not writable and sudo is unavailable` | no permission for the default folder | `curl -fsSL …/install.sh \| INSTALL_DIR=$HOME/bin sh` |
| `[!] Installed binary did not respond to --version. Roll back with:` | the new binary does not start | run the printed `mv -f` line |
| `uj update: refusing a non-HTTPS source "<url>" (TLS is mandatory)` | `UJ_INSTALL_BASE` is `http://` | use `https://` |
| `uj update: checksum mismatch — expected <a>, got <b>. Aborting (nothing changed).` · `uj update: cannot write to <dir>: <error>` | bad download · folder not writable | retry · re-run the installer with the right `INSTALL_DIR` |
| `uj update: install failed, restored previous binary: <error>` · `uj update: no published source is configured in this build.` | the swap failed (still on the old version) · no update source | retry · `UJ_INSTALL_BASE=<url> uj update`, or the installer |
| `uj: unknown command "<x>"` then `did you mean "<y>"? (try: uj help <y>)` | a typo | use the suggestion; `uj help` lists all |

A `curl … | sh` pipe cannot report a failed download: if `uj --version` does not print `uj 0.1.1-public`, the install did not happen.

## Project, target and your project list

| you see | it means | do |
|---|---|---|
| `(project goes at the git root: <dir> — use --here for this folder instead)` | `uj init` with no folder uses the repo root | fine; `--here` for a deliberate second project |
| ``uj init: this repo already has a uj project at <dir> — work there (`uj where`), or pass --here to start a separate project in this folder`` | one project per repo; exit `2` | `cd` there, or `--here` (SOP 04) |
| ``uj run: no target service — pass --base <url> (e.g. --base http://localhost:3000), or run `uj init` and set [target.local] base in harness.toml so `uj run` needs no flags`` | no `harness.toml` walking up, no `--base`, no `$UJ_BASE` | `cd` into the project, or `uj init` |
| ``uj run: no target service — set `base = "<your-service-url>"` under [target.local] in <path>/harness.toml (then `uj run` needs no flags), or pass --base <url>`` | `harness.toml` has no target | add `[target.dev]` with `base = "http://localhost:8080"` |
| ``--target <name>: no harness.toml found (walked up from here) — run `uj init` or pass --base <url>`` | `--target` outside a project | `cd` into it, or `--project` |
| `--target <name> is not defined in <path> (targets: <list>) — add a [target.<name>] section with base = "<url>"` | typo or missing target | use a listed name or add it |
| `<path> has several targets (<list>) and no default — pass --target NAME, or set default_target = "NAME" under [project]` | no default, or it sits under a `[target.…]` section | `default_target = "dev"` in `[project]` |
| `(target: <url> — from <source>)` · `(environment: none — journeys start with no pre-made user/token …)` | the two header lines of every run | read them: the wrong URL here explains everything after |
| `uj run: target "<name>" is marked production = true in harness.toml — journeys create real data; refusing. Pass --allow-production only if you really mean it` | the URL (from `--target`, `--base`, `$UJ_BASE` or the default) is a marked production target; exit `2` | use `dev` or `staging`; `uj where`, `unset UJ_BASE` (SOP 04 step 7) |
| `✗ target` · `target "<name>" is marked production = true` · `fix: doctor runs setup, which creates data — use a dev/staging target, or --no-setup --allow-production for a read-only reachability check` | `uj doctor` on a production target; exit `1` | another target; or `uj doctor --target <name> --no-setup --allow-production` to check it answers |
| ``uj: no project "<x>" in your project list — `uj projects` lists them; `uj projects --scan <dir>` finds more`` | `--project` name or id unknown here; exit `2` | `uj projects --scan ~/code` |
| `no uj project here (no harness.toml in this folder or above).` | `uj where` outside a project; it then lists `your projects (most recent first):` | `cd` into one, or `uj where --project <name>` |
| `no [project] id in harness.toml — add one so history survives a move:` | a project made before ids | paste the printed `[project]` lines into `harness.toml` |
| `(MISSING — moved or deleted?)` | a remembered folder is gone | `uj projects --scan <new parent>` finds it by its id |
| `uj projects: the project list is off (UJ_NO_INDEX is set)` | the list is switched off; exit `2` | `unset UJ_NO_INDEX`, or ignore it |
| `STALE (updated <n> days ago — review before relying on it)` | a `.uj/*.context` file is over 90 days old | review it, update `# Last updated:` |
| `uj run: no journeys found` · `uj new: <path>/journeys/<NAME>.yaml already exists — pick another name (nothing overwritten)` | nothing runnable (`_` files, `fragments/`, `findings/` skipped) · name taken | `uj new journey "<name>"` · another title |
| ``usage: uj run <journey.yaml\|dir> [--base URL]   (no journeys/ dir here — `uj init` scaffolds one)`` | no path and no `journeys/` here or in the project | pass a path, `cd` into the project, or `--project` |
| ``no projects remembered yet — they appear when you `uj init`, `uj run` or `uj doctor` in them,`` | an empty project list | `uj projects --scan ~/code` |
| ``risks     no risk register — add one in .uj/risks.context so `uj coverage` can show gaps`` · ``memory    no .uj/ — `uj init` creates it (product, risks, conventions, decisions, findings)`` | `uj where` in a project without them | SOP 06 step 3 · re-run `uj init` in the project folder (`--here` for a sub-project); it only adds what is missing |
| `1. set your service URL in harness.toml   ([target.local] base = "http://…")` · `(openapi: no signup/login/tenant endpoints detected — wrote an EMPTY setup (fine if journeys create their own state))` | `init` found no URL · no auth paths in the spec | set `base` · fine if journeys sign up themselves; else SOP 05 |

## Setup (environment.json, `uj doctor`)

| you see | it means | do |
|---|---|---|
| ``uj run: environment <path> does not exist (fix --env, or `uj init`)`` | `--env` points nowhere | fix the path |
| `✗ reachable` · `no HTTP response from <url>` · `fix: start the service, or fix the target (--base / harness.toml)` | nothing answers, or its certificate did not verify | start `invoicer`; check the URL and certificate (a self-signed dev certificate: `UJ_INSECURE_TLS=1`, dev only; `uj doctor` and `uj run` both honour it) |
| `✓ reachable — <url> responds (HTTP <code>)` · `✓ setup — no setup steps — each journey starts anonymous and signs up / logs in itself` | no `/health`, but the base URL answers · `setup: []` | fine · fine if intended |
| ``✓ setup — skipped (--no-setup) — no data created; `uj validate environment.json` checks the file offline`` | `uj doctor --no-setup`: setup was not run | `uj validate environment.json`; a plain `uj doctor` on dev proves the setup works |
| `(read <n> variable(s) from .env)` | `uj run` filled `<n>` unset variables from `<project>/.env`; set ones were left alone | fine; a value that seems ignored is set in your shell, which wins |
| `✗ setup` · `environment setup failed: environment step <n> (<intent>): <reason> [status <s>]` (no `[status …]` when nothing answered) | a setup step failed; in a run the same reason makes every journey VOID | fix that step (SOP 05) |
| `environment variable <NAME> is not set (referenced as {env:…}) — export it, or set it in your CI secrets` | an `{env:NAME}` is empty, in setup, a journey or a `run:` step; VOID | `export ACME_QA_PASSWORD=…` or a line in `.env` locally (SOP 05); a CI secret in CI |
| ``doctor: FAIL — fix the above before `uj run` (a journey would VOID here)`` | at least one `✗`; exit `1` | fix each `✗` in order |

## Journey and environment files (`validate`; `lint` as JL000; VOID in a run)

| you see | it means | do |
|---|---|---|
| ``<file>: unknown key "<x>" — not a uj field (typo?); see `uj schema journey` or `uj schema environment` `` | a misspelled key; `_`-prefixed top-level keys are comments | fix the spelling (also in `environment.json`) |
| `<id>: step <n> within: "<x>" is not a duration (use e.g. "800ms" or "2s")` | an unreadable budget | `800ms`, `2s` |
| `<id>: step <n> missing intent (every step must state what it means)` · `<id>: step <n> needs a method (HTTP), a run: command, or a browser: action` | a step without intent · without mechanics | add `intent:` · add `method:` + `path:` |
| `<file>: unknown expect alias "<x>" (use success\|denied\|not-found\|created or an object)` | `expect: fine` and similar | an alias or an object (SOP 08) |
| `fragment "<name>" not found (searched fragments/ trees from <dir> upward)` · `fragment cycle: …` · `fragment nesting too deep (>10): …` | `use:` has no file · a loop | `uj fragments journeys/`; flatten |
| `<file>: yaml: line <n>: <detail>` | YAML syntax (indentation, a `[0]` inside `{ … }`) | fix the line; quote the path |
| `journey file could not be loaded: <error> — fix it (uj validate <file>)` | any of the above, met by `uj run`; VOID | `uj validate <file>` |
| `uj validate: no .json/.yaml files found` · `cannot infer kind for <file> — pass --kind` · `unknown kind "<x>" (journey\|environment\|scenario)` | wrong path · unusual file name · `uj schema` or `--kind` typo | check it · `--kind journey` |

## Run: step reasons and verdicts

| you see | verdict | it means · do |
|---|---|---|
| ``unresolved {<name>} — not provided by environment.json setup, the journey's vars:, or an earlier capture: (check the name, or `uj doctor` to see what setup provides)`` | VOID | typo, or setup did not capture it · `uj doctor` lists what setup provides |
| `no response from the service (<error>) — is it running at <url>?` | VOID | down, wrong URL, slower than the request timeout (30 s; `--timeout 90s` or `UJ_TIMEOUT=90s`, SOP 16), or a certificate that did not verify (`UJ_INSECURE_TLS=1` for a self-signed dev target only) · `uj doctor` |
| `status <got>, wanted <want>` | FAIL | wrong status (`2xx` = any success expected) · a bug or a wrong expectation: read the response |
| `expected the request to be REFUSED, but got <code>` | FAIL | an abuse step got through · likely a security bug; keep it red |
| `expected a refusal (4xx), but the service errored with <code> — a crash is not a refusal` | FAIL | the abuse attempt crashed the service · a bug; keep it red |
| `response missing expected field: <f>` · `no field at "<k>" in the response (wanted "<v>") — check the path; …` | FAIL | field absent or path wrong · `items[0].id`, or `{contains: …}` |
| `field "<k>" = "<got>", wanted "<want>"` · `… wanted to CONTAIN …` · `… wanted to NOT contain …` | FAIL | value differs · bug, or an expectation that changed |
| `field must be ABSENT but was present: <f>` · `response must NOT contain "<x>" (but it does)` | FAIL | something leaked · treat as a bug |
| `response missing expected header: <name>` · `header "<n>" = "<got>", wanted to contain "<x>"` | FAIL | header missing/different |
| `response contract violated: <path>: <detail>` · `response is not JSON, cannot check schema` | FAIL | shape changed; a `null` needs `nullable: true` (SOP 15) |
| `took <d>, wanted within <d>` | FAIL | slower than its budget (SOP 16) |
| `capture failed: no value at <path>` · `capture refused (append-only): <name>` | FAIL | path wrong · a name captured twice: rename one |
| `run failed to start: <error>` · `run exit <n>, wanted <m> — <first line>` · `run capture failed: no value at <path> (the command must emit JSON on stdout to capture from it)` | FAIL | a `run:` step (SOP 10) |
| `no browser driver configured (set UJ_BROWSER_CMD or UJ_BROWSER_URL, or gate the journey on capability: [browser] so it SKIPs)` | FAIL | SOP 10 |
| `capability absent: <cap>` · `no steps executed an assertion` | SKIP · INCONCLUSIVE | expected where it is missing · add expectations |
| `skipped — a prior step failed` · `skipped — nothing to clean up (<what> was never captured)` · `already gone (404) — fine for cleanup` | — | normal after a failure; cleanup succeeded |

## Run: flags, selection and exports

| you see | it means | do |
|---|---|---|
| `uj run: no journeys match persona="<p>" tag="<t>" — check the spelling (a selection that runs nothing is not a pass)` | the filter matched nothing; exit `2` | fix the tag or persona |
| `(--failed: <n> journey(s) not PASS last time)` · `uj run --failed: nothing failed last time — nothing to re-run` | `--failed` picked the journeys whose last result was not PASS · none did (or no history yet); exit `0` | read the results · nothing to retry; on a fresh CI runner restore `runs/` first |
| `invalid value "<x>" for flag -timeout: parse error` | `--timeout` needs a duration; exit `2` | `--timeout 90s` |
| `uj: ignoring UJ_TIMEOUT="<x>" — not a duration (use e.g. 90s); the request timeout stays 30s` | `UJ_TIMEOUT` is not a duration; the run continues with 30 s | `UJ_TIMEOUT=90s` |
| `uj run: --run-id/--resume target a single journey (got <n>); pass one journey file` | resume works per journey | pass one file |
| `no checkpoint for run-id <id>: <error>` (VOID) · `run-id <id> already finished (<verdict>)` (SKIP) | nothing to resume | start with `--run-id` first; pick a new id |
| `bad --shard "<x>", want i/n (e.g. 1/4)` · `bad --shard "<x>", want i/n with 1<=i<=n` | shard syntax | `--shard 1/4` |
| `uj run --changed: not a git repo (or git unavailable): <error>` · `git diff against "<ref>" failed (bad ref?): <error>` | `--changed` needs git and a real ref | fetch the base branch in CI |
| `no changed journeys — nothing to run (this is a clean pass in CI)` | nothing changed; a fragment, `environment*.json` or `harness.toml` change would have selected every journey | exit `0`, correct |
| `junit export failed: <error>` · `ctrf export failed: <error>` · `(warning: checkpoint save failed: <error>)` | a file could not be written; a failed export makes the run exit `2` | check the path is writable (uj creates missing folders) |

## Lint, coverage, history and the rest

| you see | it means | do |
|---|---|---|
| ``uj lint: no paths given and no journeys/ dir here — pass a file or folder (e.g. uj lint journeys/), or `uj init` to start a project`` | outside a project | pass a path |
| `FAIL — <n> file(s) do not parse (cannot be tested); fix the syntax first` · `FAIL — critical/high findings present (fix before commit)` | JL000; exit `1` · old `.sh` scripts broke a UJ rule | see "Journey files" · SOP 17 step 2 |
| `JL011` · `looks like a credential written into project memory — remove it and reference {env:NAME} instead` | a secret in `.uj/` | delete it, rotate it, write `{env:NAME}` |
| `JL012` · `<n> place(s) still hold scaffold placeholders (<…> text or /TODO paths) — replace them with the real story and endpoints` | an unfinished `uj new` file | fill in the story and the paths (SOP 07) |
| `JL013` · `no refusal step — add one where an outsider or a wrong input must be REFUSED (abuse: + expect: denied); negative space is the most-skipped check` | a journey of 3+ steps never checks a refusal (info) | add an `abuse:` step with `expect: denied` (SOP 06 step 8) |
| `GAPS — <n> registered risk(s) with no journey (<file>):` | risks nothing tests yet, P0 first | write the next journey for the top one (SOP 06) |
| `<n> covers id(s) not in the risk register (typo, or add the risk):` | a `covers:` id the register lacks | fix the spelling, or add the row |
| `every registered risk (<n>) has at least one journey (<file>)` · `(no risk register — list your risks in .uj/risks.context and this report shows the gaps)` | all covered · no register yet | thin risks next · SOP 06 step 3 |
| `accepted, not covered on purpose: <ids>` | risks listed in `## Not covered on purpose` in `.uj/risks.context` | nothing; they are reported, never counted as gaps. Record why in `.uj/decisions.md` |
| `usage: uj coverage <dir> [--json]` | no path and no project here | pass a folder, or `cd` into the project |
| `no run history yet (run some journeys first; history is written unless --no-history)` · `FLAKY` rows · `<n> journeys · <n> FLAKY` | nothing recorded · PASS and FAIL on the same content and target; `--flaky` exits `1` | run from the project · fix it, never retry it away (SOP 14) |
| `history: kept <k> of <t> record(s) (newest <n> per journey)` | `uj history --prune <n>` trimmed `runs/history.jsonl` | fine; prune after flake triage, not during it |
| `uj contract: no spec — pass --spec <openapi.json file or URL>, or set a target in harness.toml (then <target>/openapi.json is used)` · `uj contract: yaml: line <n>: <detail>` | nothing to read · the spec is neither valid JSON nor valid YAML | `--spec openapi.json` or `--target staging` · fetch the spec again (SOP 15) |
| `FAIL — <p>% of endpoints document a 2xx response; --min-documented is <m>%` | completeness under the floor; exit `1` | document the listed endpoints (SOP 15 step 7) |
| `uj contract: open <file>: no such file or directory` · `uj contract --parity: <error>` · `uj contract --har: <error>` | a spec or HAR could not be read | fix the path or file |
| `✗ <METHOD> <path>  $: missing required field "<f>"` | a recorded response breaks the spec; exit `1` | SOP 15 |
| `reason:  no verdict line and no Success Rate — cannot conclude (exit 0 is NOT accepted as pass)` | `uj verdict` found nothing; exit `4` | print a verdict line (SOP 17 step 1) |
| `reason:  environment signal in output` · `reason:  capability/skip signal in output` | VOID (exit `2`) · SKIP (exit `3`) from phrases in the output | fix the environment, or print an explicit verdict |
| `uj explain: open <file>: no such file or directory` · `uj verdict: open <file>: no such file or directory` · `uj fragments: <dir> is not a directory` | wrong path | pass a file or folder, or `-` and pipe for `verdict` |
| `usage: uj new journey <TITLE> [--id ID]   (writes journeys/<ID>.yaml)` · `usage: uj verdict <file\|->   (scores a journey's captured stdout)` · `usage: uj validate <file> [--kind journey\|environment\|scenario]` · `usage: uj explain <journey\|dir> [more…]   (a dir renders every journey's story — the manager view)` | the command needs an argument | add it |

`load`/`probe` errors on your service are expected; SOP 16 explains why.

## What you'll see

Errors go to stderr; results to stdout. `uj run` exits `0` all passed, `1` a FAIL (outranks VOID), `2` a VOID, a selection that ran nothing, a failed export, a refused production target, or a usage error.

## If it goes wrong

Your message is not here? Collect `uj --version`, `uj where`, the `uj doctor` output and `uj run <journey> --json` (captured secrets are masked), and send them to `platform-team@ab0t.com` (or open an issue on the uj repository once it is public). Never paste `runs/**/secrets.json` or your environment variables.

## Coming

- **`uj explain-error <message>`** printing this page's row. *Today:* this page.

## Next

SOP 19, the rules for honest tests.
