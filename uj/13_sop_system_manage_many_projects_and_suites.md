# 13 · Keep many services and suites organised

**What this is for.** Ten journeys fit in one folder. A hundred, across several services and repos, need a shape: one project per service, a memory each project carries with it, a way to find every project again months later, the risk gaps across all of them, tags to pick a slice, a shared library of normal activities, a place for known bugs, and reports anyone can read. The running example is Acme, now testing `invoicer` and its mailer service (Acme's services; yours will differ).

**Before you start.** SOPs 04 (projects, `--here`, `uj where`), 06 (the risk register), 09 (fragments, `covers:`), 11 (running) and 12 (CI). Everything here is offline except runs.

## Steps

**1. One project per service, with shared and own memory.** In a monorepo, one project per service (`uj init --here` in each folder, SOP 04), plus the small cross-service pack from SOP 10:
```
acme/
  .uj/                  shared memory: product.context, conventions.context
  fragments/shared/     activities every pack may use (health check)
  invoicer-tests/       harness.toml → invoicer; .uj/ (risks, decisions, findings); journeys/
  mailer-tests/         harness.toml → the mailer; its own .uj/ and journeys/
  e2e/                  harness.toml → invoicer; journeys that reach the mailer with run:
```
Memory is read nearest first: a project's own `.uj/<file>` wins; a file it does not have is taken from a `.uj/` higher up, as far as the repo root. So write what is true of the whole product once at the root (`product.context`, `conventions.context`) and remove those two from each project's `.uj/`; keep each service's own `risks.context`, `decisions.md` and `findings.md`. `uj where` lists every `.uj/` file it finds, nearest first. Separate repos: one project per repo, same layout inside.

**2. See every project you work on.**
```sh
uj projects
uj projects --scan ~/code          # add projects you have never used on this machine
```
One line each: name, folder, and `last run <date>: N pass · N fail · N void` or `never run here`. A folder that moved shows `(MISSING — moved or deleted?)`; a scan of the new location finds it again by its `[project]` id. The list is per user and per machine (SOP 03); it holds no URLs and no secrets.

**3. Act on any project from anywhere.**
```sh
uj where  --project mailer-tests
uj run    --project mailer-tests --target staging
uj doctor --project invoicer-tests
```
`--project` takes a name or an id. Two projects with the same name (two clones of `invoicer`): a name is ambiguous and uj stops with `uj: 2 projects are named "invoicer" — pass the id instead: …`, so pass the id from `harness.toml` (or `uj projects --json`) to be exact.

**4. Read the risk gaps across all projects.** `uj coverage` judges one project against its own register (with several paths it uses the first path's register), so ask each project and merge:
```sh
for p in invoicer-tests mailer-tests e2e; do
  (cd "$p" && uj coverage --json) |
    jq -r --arg p "$p" '.uncovered_risks[]? | "\(.priority)  \($p)  \(.id)  \(.risk)"'
done | sort
```
The top lines are the product's most important untested risks, whichever service they live in. `uj where --project <name>` shows the same count for one project at a glance.

**5. Shape `journeys/` so people can guess where a journey lives.** Acme's `invoicer-tests/journeys/`:
```
sessions/     realistic sessions (most journeys)       fragments/   reusable activities, by group
security/     isolation and abuse                      findings/    pinned known bugs (step 10)
edge/         odd inputs, ordering, deletes            _archive/    retired journeys (step 9)
```
Folders by persona (`freelancer/`, `accountant/`) work as well; pick one scheme and write it in the shared `.uj/conventions.context`.

**6. Name journeys once, well.** The `id` is what history, checkpoints, JUnit and `--json` use; keep it equal to the file name, in capitals, describing the outcome (`MONTH_END_BILLING`, `INVOICES_STAY_PRIVATE`). `uj new journey "A customer deletes an invoice"` names the file after the whole title; rename the file and the `id` together before the first run. Renaming later starts a fresh history line for the new id (SOP 14).

**7. Tag for slices, then run a slice.**
```sh
uj run invoicer-tests/journeys/ --tag security             # any journey tagged security
uj run invoicer-tests/journeys/ --tag security,edge        # tagged security OR edge
uj run invoicer-tests/journeys/ --persona freelancer       # persona text contains it, or a tag equals it
```
Matching ignores case. A filter that matches nothing stops with exit `2`. Keep a short agreed tag list (`smoke`, `security`, `edge`, `session`, `e2e`, plus personas) in `.uj/conventions.context`.

**8. Keep one fragment library per pack, plus a shared one.** `use: NAME` is looked up in the nearest `fragments/` folder, starting at the journey's own folder and walking up (up to eight levels). So `invoicer-tests/journeys/fragments/` serves invoicer, and `acme/fragments/shared/` serves every pack; a pack-local fragment with the same name wins. List what exists:
```sh
uj fragments invoicer-tests/journeys/        # one pack
uj fragments "$PWD"                          # the whole repo, from acme/
```
Folders under `fragments/` that start with `_` or `.` are never resolved: retire a fragment into `fragments/_old/`.

**9. Retire, never delete.** Move a journey you no longer run into `journeys/_archive/`. Files and folders starting with `_` are skipped by `uj run`, `lint`, `validate`, `explain` and `coverage`, and the file stays in git with its story. Add a dated line to that project's `.uj/decisions.md` saying why.

**10. Track known bugs as pinned journeys.** A pin asserts the **correct** behaviour and stays red until the bug is fixed. Give it `tags: [known-bug]` and a `notes:` line naming the bug, record it in `.uj/findings.md`, then choose one home:

| home | effect |
|---|---|
| in the normal folders | the CI gate stays red until it is fixed; the strongest signal |
| `journeys/findings/` | skipped by `uj run journeys/` and by `lint`/`validate`/`explain`/`coverage` on `journeys/`; run it on purpose with `uj run journeys/findings/` in a non-blocking CI job |

```yaml
id: SEND_TWICE_DOUBLE_EMAILS
tags: [known-bug]
notes: "KNOWN BUG — fails today: a second send returns 200 and queues a second email. Keep this RED until fixed; never loosen the expectation."
```
When one turns green, SOP 14 step 5.

**11. Hand the manager the stories and the gaps.** `uj explain` takes several paths and renders every journey from each, in order; then add step 4's gap list:
```sh
uj explain invoicer-tests/journeys/ mailer-tests/journeys/ e2e/journeys/ \
  invoicer-tests/journeys/findings/ > JOURNEYS_AS_STORIES.txt    # findings/ named on purpose: the known bugs
```

**12. Keep lint clean across every suite.** One command for all packs; one number for a dashboard:
```sh
uj lint invoicer-tests/journeys mailer-tests/journeys e2e/journeys
uj lint invoicer-tests/journeys mailer-tests/journeys e2e/journeys --json | jq '.journey_findings | length'
```
Fix JL004 (asserts only status), JL001 (unknown `{var}`), JL011 (a credential in `.uj/`) and JL012 (unfinished scaffold) first.

## What you'll see

`uj where` inside `e2e/` lists its own memory and the shared files by path:
```
memory
          .uj/README.md
          .uj/decisions.md
          .uj/findings.md
          .uj/risks.context  (updated 0 days ago)
          <repo>/.uj/conventions.context  (updated 0 days ago)
          <repo>/.uj/product.context  (updated 0 days ago)
```
Step 4's loop on Acme's three projects:
```
P0  invoicer-tests  amount-accuracy  the amount on a sent invoice differs from the amount typed
P0  mailer-tests  email-to-right-client  an invoice email goes to the wrong client
P1  invoicer-tests  invoice-email  the client never receives the invoice email
P2  mailer-tests  bounce-reported  a bounced email is not reported back
```
`uj fragments "$PWD"` from `acme/` groups `[auth]`, `[invoices]` and `[shared]` (`health_check  1 step(s)  #read`); a name listed twice means two packs each have their own copy. `uj lint` over three packs ends `lint: 7 journey file(s) + 0 bash-UJ file(s) · 0 critical/high finding(s), 1 authoring advisory — …` and `OK — no critical/high findings`.

## If it goes wrong

- `` uj: no project "mailer" in your project list — `uj projects` lists them; `uj projects --scan <dir>` finds more `` — the name is the folder's `[project] name` (`mailer-tests`); check `uj projects`.
- `--project invoicer` acts on the wrong clone — names collide; pass the id.
- A file in `.uj/` shows `STALE (updated N days ago — review before relying on it)` — older than 90 days; review it, then update `# Last updated:`.
- `fragment "health_check" not found (searched fragments/ trees from <dir> upward)` — the shared library is more than eight levels up, under a `_` folder, or misnamed.
- `uj run: no journeys match persona="accountant" tag="" — check the spelling (a selection that runs nothing is not a pass)` — exit `2`; check the tag list.
- Coverage shows a risk you know is tested — the journey sits in `findings/` or `_archive/`, lacks `covers:`, or lives in another project whose register does not list it.

## Coming

- **One command across all packs** (`uj run` over several projects, each with its own target). *Today:* `uj run --project <name>` per pack, a shell loop, or separate CI jobs.
- **One gap report across projects and repos.** *Today:* the loop in step 4, or `uj coverage --json` per repo merged by your dashboard.
- **An exclude filter** (`--not-tag known-bug`). *Today:* `findings/` or folder layout.
- **Rename-aware history.** *Today:* a renamed id starts a new history line; note the old id in `notes:`.

## Next

SOP 14, edit and maintain journeys. Or SOP 15 to add the API contract to the map.
