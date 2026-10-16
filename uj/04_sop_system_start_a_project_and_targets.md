# 04 · Start a test project and point it at your environments

**What this is for.** Turning a repo into a uj project: one folder that says which service to test (its targets), what runs before every test, where the tests live, what the team knows about the product and its risks, and how a teammate runs it all with no flags. For Acme that is the `invoicer` repo, tested on `dev` (Dev's laptop) and `staging`.

**Before you start.** SOP 03 (`uj --version` works). The service's URL for each environment. For Acme's API (yours will differ): `dev` = `http://localhost:8080`, `staging` = `https://invoicer.staging.acme.example`. An OpenAPI spec if you have one (a URL or a file); it saves you writing setup by hand. Never use production as a target: journeys create real users and records.

## Steps

**1. Scaffold the project.** Anywhere inside the repo:
```sh
cd invoicer
uj init --openapi ./openapi.json --base http://localhost:8080
```
With no folder argument, `uj init` puts the project at the **root of the git repo**, wherever you stand, and says so on its first line. Not in a git repo: the current folder. `uj init some/dir` uses that folder instead. With a spec, uj drafts the setup (sign up, log in, keep the token); a spec URL also sets the target from its address, a spec file does not, so pass `--base` with a file. No spec: `uj init --base http://localhost:8080`. `init` never overwrites: a second run prints `skip (exists)` for every file it finds.

**2. One project per repo, unless you mean it.** If the repo already has a uj project somewhere, `uj init` refuses and names it (exit `2`); work there. `--here` starts a separate project in the current folder, for a monorepo that really wants one per service (step 11).

**3. Read what it made.**

| file | what it is | who edits it |
|---|---|---|
| `harness.toml` | the project's name and id, and the targets: which service to test | whoever owns the environments (Dev) |
| `environment.json` | setup that runs before every journey (SOP 05) | Dev; `uj doctor` checks it |
| `journeys/` | the tests, one journey per file, sub-folders allowed | Maya writes intents, Dev fills mechanics |
| `journeys/_EXAMPLE.yaml` | an annotated reference; `_` files are never run | read it, keep or delete |
| `.uj/` | the project's memory: `product.context`, `risks.context`, `conventions.context`, `decisions.md`, `findings.md`, three `*.context.example` recipes and a `README.md` | the team and Quinn; never secrets |
| `HARNESS.md` | "how to run these" for teammates; lists `.uj/` and starts with `uj where` | anyone |
| `scenarios.d/` | optional load-test scenarios (SOP 16) | leave it |
| `.gitignore` | gains `runs/` and `.env` (local secrets, SOP 05) | uj |

**4. Keep the `[project]` block.** `harness.toml` starts with:
```toml
[project]
name = "invoicer"
id   = "uj_<12 hex>"
```
`uj init` takes the name from the folder (a repo called `acme-invoicer` gives `name = "acme-invoicer"`). Change the name freely; never change the id.
The id stays the same across renames, moves and clones; your project list (step 10) is keyed by it. Never copy it into another project; each project needs its own.

**5. Check the drafted setup.** `init --openapi` prints what it recognised, for Acme `(openapi: detected signup=POST /signup, login=POST /login)`, and a `CONFIRM:` line for anything it guessed. Open `environment.json`: two steps, sign up then log in, with the token captured as `secret:token`. SOP 05 decides whether to keep it.

**6. Add staging and name a default.** `uj init` wrote one target, `[target.local]`. Rename it to `[target.dev]` (or keep `local`; the name is only a label you pass to `--target`) and add staging, so `harness.toml` reads:
```toml
[project]
name = "invoicer"
id   = "uj_<12 hex>"
default_target = "dev"

[target.dev]
base = "http://localhost:8080"

[target.staging]
base = "https://invoicer.staging.acme.example"
```
`default_target` goes in `[project]` (the scaffold has a commented line there; a first line above `[project]` works too). With one target you need no default. With several and no default, uj uses `local` if it exists, otherwise it stops and asks.

**7. Mark production so uj refuses it.** You never test production, but a URL can still get pasted in. Write it down once, marked:
```toml
[target.prod]
base = "https://invoicer.acme.example"
production = true
```
`uj run` then refuses any run whose URL matches it, `--base` included, and exits `2`; `uj doctor` fails its target check. `--allow-production` overrides; the only sensible use is a read-only reachability check, `uj doctor --target prod --no-setup --allow-production`. Mark every production URL you know of. Never make it the `default_target`.

**8. Choose the target for a run.** Plain `uj run` uses the default. To pick another:
```sh
uj doctor --target staging                       # check staging first (SOP 05)
uj run --target staging
uj run --base http://localhost:9090              # a one-off URL, e.g. a second local copy
UJ_BASE=http://localhost:9090 uj run             # the same, from an environment variable
```
First match wins: `--base` › `--target NAME` › `$UJ_BASE` › `harness.toml`. Every run starts by naming the target and where it came from.

**9. Orient, offline.** `uj where` prints the project, the target and where it came from, the setup, the journey count, the last run, the risk gaps and the `.uj/` files, without contacting the service. Start every session with it (Quinn does).

**10. Find projects later, and act on them from anywhere.** `uj init`, `uj run`, `uj doctor` and `uj where` remember each project on this machine (SOP 03):
```sh
uj projects                          # name, folder, last run
uj where  --project invoicer         # by name or by id
uj run    --project invoicer         # its journeys/, its default target
uj doctor --project invoicer
```

**11. Several projects in one repo (monorepo).** Give each service its own project with `--here`:
```sh
cd services/invoicer && uj init --here --base http://localhost:8080
cd ../payouts        && uj init --here --base http://localhost:8081
```
Each folder gets its own `harness.toml` (with its own id), `environment.json`, `.uj/`, `.gitignore` and `runs/`. A path decides the project, so `uj run services/invoicer/journeys/` works from the repo root. A `.uj/` at the repo root holds memory every project shares; a project's own file of the same name wins (SOP 13). One run tests one target; a journey that crosses services is SOP 10.

**12. Commit the project.**
```sh
git add harness.toml environment.json journeys/ .uj/ HARNESS.md scenarios.d/ .gitignore
git commit -m "Add uj journey tests for invoicer"
```
`runs/` and `.env` stay out (local history, local secrets). Passwords never go in these files, `.uj/` included; reference them as `{env:NAME}` (SOP 05). Point teammates at `HARNESS.md`.

## What you'll see

`uj init --openapi ./openapi.json --base http://localhost:8080` from a sub-folder of Acme's repo:
```
  (project goes at the git root: <repo> — use --here for this folder instead)
  (openapi: detected signup=POST /signup, login=POST /login)
  create harness.toml
  create environment.json
  create journeys/_EXAMPLE.yaml
  create scenarios.d/example.json
  create HARNESS.md
  create .uj/product.context
  …                                   (the other .uj/ files)
  update .gitignore (+runs/)
  update .gitignore (+.env)

init: 14 created, 0 skipped in <repo>
```
then a `NEXT —` block starting `1. target is http://localhost:8080 (harness.toml) — change it there if needed`. Without a URL, line 1 reads `1. set your service URL in harness.toml   ([target.local] base = "http://…")`. Exit `0`.

`uj projects`: one line per project, such as `invoicer  <folder>  last run 2026-10-09: 4 pass · 0 fail · 0 void` or `never run here`. A run names its target first: `(target: <url> — from target "dev" (<path>/harness.toml))`.

## If it goes wrong

| you see | it means | do |
|---|---|---|
| ``uj init: this repo already has a uj project at <dir> — work there (`uj where`), or pass --here to start a separate project in this folder`` | one project per repo | `cd` there; `--here` only for a deliberate second project |
| `(project goes at the git root: <dir> — use --here for this folder instead)` | information, not an error | fine; or `--here` |
| `` uj run: no target service — pass --base <url> (e.g. --base http://localhost:3000), or run `uj init` and set [target.local] base in harness.toml so `uj run` needs no flags `` | no project and no URL | step 1, or `--base` |
| `usage: uj run <journey.yaml|dir> [--base URL]   (no journeys/ dir here — `uj init` scaffolds one)` | `uj run` with no path, outside any project | `cd` into the project (or `uj run --project <name>`), or `uj init` |
| `<path> has several targets (dev, staging) and no default — pass --target NAME, or set default_target = "NAME" under [project]` | no default, or it sits under a `[target.…]` section | add `default_target = "dev"` in `[project]` |
| `uj run: target "prod" is marked production = true in harness.toml — journeys create real data; refusing. Pass --allow-production only if you really mean it` | the URL you chose is a production target (step 7) | use `--target staging`; check `uj where` and `UJ_BASE` |
| `--target staging is not defined in <path> (targets: dev) — add a [target.staging] section with base = "<url>"` | typo or missing section | add it |
| `` uj: no project "invoicer" in your project list — `uj projects` lists them; `uj projects --scan <dir>` finds more `` | `--project` name unknown on this machine | `uj projects --scan ~/code` |
| `(openapi: no signup/login/tenant endpoints detected — wrote an EMPTY setup (fine if journeys create their own state))` | no recognisable auth paths | fine if journeys sign up themselves; else SOP 05 |
| `uj where` shows `no [project] id in harness.toml — add one so history survives a move:` | a project made before ids existed | paste the printed `[project]` lines |

## Coming

- **A setup file per target** (staging uses its own `environment.staging.json` automatically). *Today:* pass `--env environment.staging.json` with `--target staging` (SOP 05).
- **`uj target add` / `uj target list`.** *Today:* edit `harness.toml`; `uj where` shows what resolves.
- **One command for every project in a monorepo.** *Today:* `uj run --project <name>` per project, or a shell loop, `for p in services/*/; do (cd "$p" && uj run); done`.
- **One journey across several services.** *Today:* one target per run; SOP 10.

## Next

SOP 05, describe what runs before every journey. Then SOP 06 to fill `.uj/risks.context`.
