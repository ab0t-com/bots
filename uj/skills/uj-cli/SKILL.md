---
name: uj-cli
description: Drive the uj user-journey test-harness binary from the command line. Use when an agent needs to RUN journeys against a service, resume a failed multi-step epic, lint or validate journey files, read an honest PASS/FAIL/VOID verdict, or discover uj's own commands. Covers the verb set, targets (harness.toml / --base), the run/resume flags, --json machine output, exit codes, and the honest-verdict protocol (never treat exit 0 as pass). For WRITING journey files use uj-authoring.
---

# uj CLI (driving the binary)

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

`uj` is one Go binary that runs multi-step user journeys against an HTTP service and returns
ONE honest verdict per journey. This skill is how an agent operates it.

## First move: let the tool describe itself

`uj` is self-documenting. A bare `uj` prints a start page (where you are, the next step, every
command, an agent section). Before guessing, ask it:

```bash
uj help --json        # machine-readable catalog: every verb, its usage, examples, related, needs_service
uj help <command>     # detailed help + examples for one verb (e.g. uj help run)
uj <command> -h       # same help, from the subcommand
```

`help --json` is the authoritative command list — parse it instead of hardcoding verbs. Each entry
has `needs_service: true` when the verb hits a live HTTP target.

## The project (where things live)

A uj project is a folder with `harness.toml` at its root (create one with `uj init`):

| Path | What |
|---|---|
| `journeys/` | the tests, one journey per `.yaml` (sub-folders fine; `_`-prefixed files are references, not run) |
| `harness.toml` | the **target** service: `[target.local] base = "http://…"` (+ more targets) |
| `environment.json` | setup run before EVERY journey (may be empty) |
| `runs/` | local run history + resume checkpoints (git-ignored) |
| `.uj/` | the project's memory, committed: `product.context`, `risks.context` (the risk register), `conventions.context`, `decisions.md`, `findings.md` |

uj finds `harness.toml` by walking up from the journey path or the current directory, so commands
work from any sub-folder and always use the project's `environment.json` and `runs/`. `uj init`
puts the project at the **git root** (one per repo; `--here` for a monorepo sub-project) and writes a
stable `[project] id`.

**Lost?** `uj where` prints the project, target, setup, journeys, last run, risk gaps and memory in
one screen (offline). `uj projects` lists every uj project you have used, with its last result; a
`--project <name>` flag runs or checks one from anywhere. That list is per-user state (Linux
`~/.local/state/uj/`), holds no URLs or secrets, and is safe to delete (`UJ_NO_INDEX=1` turns it off).

## The verbs you'll actually use

| Verb | Needs service | What |
|---|---|---|
| `run <journey\|dir>` | yes | execute journeys → one honest verdict each (+ evidence) |
| `lint [paths]` | no | authoring-quality nudges before a run |
| `validate <file>` | no | is this file well-formed against the schema? |
| `explain <journey>` | no | render the journey as a plain-English story |
| `verdict <file\|->` | no | score captured stdout HONESTLY (never exit-0=pass) |
| `catalog` / `schema` / `new` / `init` | no | list scenarios / emit JSON schema / scaffold |

`load`/`probe`/`contract` are the performance + API-contract faces (see `uj help <verb>`).

## Running a journey

```bash
uj run                                              # all of journeys/ against harness.toml's target
uj run journeys/ONBOARD.yaml                        # one journey
uj run journeys/ --base http://localhost:3000 --json   # explicit target, machine-readable
uj run journeys/ --target staging                   # a [target.staging] from harness.toml
```

- **Target** (which service): `--base URL` > `--target NAME` > `$UJ_BASE` > harness.toml's default
  target (`default_target`, else the only target, else `local`). There is **no built-in URL** — with
  none of these, `run` stops (exit 2) and says how to set one. The first output line names the target.
- `--env FILE` — the setup run before every journey; default `<project>/environment.json`. No
  environment = journeys start anonymous (fine when a journey signs up / logs in itself).
- `--json` — emit machine-readable results (parse these, don't scrape the text); each step carries `ms`.
- `--failed` — only journeys whose last recorded result was not PASS (the retry loop after a fix).
- `--timeout 90s` (or `UJ_TIMEOUT`) — per-request timeout; default 30s.
- `--allow-production` — required to run against a `[target.X]` marked `production = true` (uj refuses it otherwise).
- `<project>/.env` (KEY=VALUE) fills `{env:NAME}` values that are not already set — never committed (`uj init`
  git-ignores it); the shell and CI always win.
- `uj doctor --no-setup` checks the target without running setup (creates no data). `uj history --prune N` keeps
  the newest N records per journey.

Every journey gets its OWN fresh setup run (isolation). A journey never shares state with another.

## Resumable epics (a long journey that failed midway)

```bash
uj run journeys/ONBOARD.yaml --run-id today     # checkpoint after each passed step
# ... step 9 fails (a dependency was briefly down) ...
uj run journeys/ONBOARD.yaml --resume today     # restore state, retry from step 9 — steps 1-8 NOT re-run
```

- `--run-id ID` enables checkpointing under `runs/<journey>/<ID>/`; `--resume ID` continues it.
- Resume restores the captured state (every `{var}`), so it does **not** re-provision or re-run
  completed steps. A resumed run records `"resumed":true` in its verdict.
- Checkpoints are evidence-safe: secret VALUES are masked in `checkpoint.json`; real secrets live
  only in a sealed `secrets.json` (perm 600), which a cleanly-finished run deletes.
- `--run-id`/`--resume` target a SINGLE journey (a run is one journey's state machine).

## Reading the result HONESTLY — the one rule

**Never infer "passed" from exit 0 or an HTTP 200.** Read the verdict.

- The verdict line: `### UJ-VERDICT v1 {"id":...,"result":"pass|fail|skip|void|inconclusive",...}`.
- `PASS` real pass · `FAIL` a real defect · `SKIP` capability absent · `VOID` the environment
  broke (couldn't even set up — NOT a code failure) · `INCONCLUSIVE` nothing was asserted.
- A journey that asserts nothing is **INCONCLUSIVE, not green**. A failed *setup* is **VOID**, not
  RED — re-check the environment, don't file a bug.

Exit codes for `uj run`: **0** all passed · **1** a journey FAILed · **2** a journey was VOID (the
environment broke — service down, setup failed, an unresolved `{var}`; nothing was judged) or a usage
error. A real FAIL outranks VOID. `--strict` also exits 1 on INCONCLUSIVE/SKIP. For one journey's
richer code use `uj verdict`: `0 pass · 1 fail · 2 void · 3 skip · 4 inconclusive`. Full detail:
[references/verdicts-and-exit-codes.md](references/verdicts-and-exit-codes.md).

## The typical agent loop

```bash
uj lint journeys/X.yaml            # 1. catch authoring mistakes (no service needed)
uj validate journeys/X.yaml        # 2. confirm it's well-formed
uj where                           # 0. where am I: project, target, gaps (offline)
uj doctor                          # 3. target reachable? setup works? which {vars} journeys get?
uj run journeys/X.yaml --json      # 4. execute (target from harness.toml or --base), parse the JSON
# 5. branch on result: pass → done · fail → real bug (or a wrong expectation) · void → fix the env · inconclusive → add assertions
```

## Machine-readable output

`--json` is on `run`, `lint`, `coverage`, `where`, `projects` and `history`; `help --json` dumps the
command catalog. Shapes: [references/json-output.md](references/json-output.md).

## Pitfalls (these bite agents specifically)

- **Don't scrape text — use `--json`.** Text is for humans; the JSON is the contract.
- **Flags work in any position** on `run`/`lint` (e.g. `run j.yaml --json`), but elsewhere put
  flags before positionals.
- **Only "no response" is VOID.** If the service answers at all, uj judges the answer: a `503` (or any
  `5xx`) where the step expected success is a **FAIL** with `status 503, wanted …` as the reason. When
  you know your environment was down (a deploy, a maintenance window), say so in your report and
  re-run once it is back; do not weaken the expectation.
- **There is no default target.** Set it once in `harness.toml` (or pass `--base`); the run's first
  line `(target: … — from …)` tells you which service you are about to hit.
- **Secrets stay hidden:** values captured as `secret:NAME` are masked as `***redacted***` in text,
  `--json`, exports and checkpoints — including the response that first returned them.
- **Don't run load/perf against a shared or production box.** `run` is one user; `load` hammers.
