# 14 · Keep journeys true as the product changes

**What this is for.** Journeys are only worth having while they say what the product really does. This SOP covers the everyday upkeep: the API changed, a journey needs a new name or shape, a known bug is pinned red, a journey flickers, an endpoint is retired, and uj itself gets a new version. One rule runs through all of it: **a red journey is fixed by fixing the product, or by correcting an expectation that was wrong, with a reason. Never by weakening it until it goes green.** The running example is Acme's `invoicer` (Acme's API; yours will differ).

**Before you start.** SOPs 08 (assertions), 11 (reading a FAIL), 12 (CI) and 13 (where pins live). Your journeys in git, so every change is reviewed. The project's `.uj/decisions.md` and `.uj/findings.md` (created by `uj init`): the append-only logs of why things changed and which bugs are pinned.

## Steps

**1. Change journeys in the same pull request as the API.** Acme renames the invoice field `amount` to `total`. Find every use, fragments included:
```sh
grep -rn 'amount' journeys/
```
Update request bodies (`body: { …, total: 1200 }`) and expectations (`expect: { body: { total: 1200 } }`) together. If the old field must stay for old clients for a while, assert both in one step, and that is a product decision for Maya, not a test detail.

**2. Check the edit offline.**
```sh
uj lint journeys/
uj validate journeys/
uj explain journeys/sessions/MONTH_END_BILLING.yaml
```
`lint` catches a renamed capture still used under its old name (JL001) and a `{rand}` inside an expectation (JL010). `explain` answers the question nobody else will ask: does the story still read true?

**3. Run it on dev, then read history in the right way.**
```sh
uj run journeys/sessions/MONTH_END_BILLING.yaml
uj history MONTH_END_BILLING
```
Each history record carries a fingerprint of the journey's expanded steps, fragments included. Flaky detection only compares runs of the **same content against the same target**, so a FAIL before your edit and a PASS after it is not called flaky, and editing a fragment starts a fresh comparison for every journey that uses it.

**4. Rename, split or merge with care.**
- **Rename:** change the file name and `id` together. History, checkpoints and CI reports are keyed by `id`, so the new name starts a fresh history line; put the old id in `notes:` for whoever looks later.
- **Split** only when a journey tells two outcomes (two `success:` statements hiding in one). Never split a realistic session just to make it short; `--run-id`/`--resume` handle long ones (SOP 11).
- **Merge** two journeys that tell the same story with different data; keep the stronger expectations of both.
- Steps repeated in three or more journeys move into a fragment (SOP 09). Then run `uj explain` on one user of it to check nothing changed in the story.

**5. Keep pinned bugs red, then flip them when fixed.** A pin asserts the correct behaviour and fails until the bug is fixed (SOP 13 step 8). These "fixes" are forbidden, whoever asks:

| tempting change | why it is wrong |
|---|---|
| change `expect: { status: 409 }` to the `200` the server returns | the journey now protects the bug |
| delete the failing step, or replace an exact check with `expect: success` | the risk is now untested, silently |
| move it to `_archive/` | the bug disappears from every report |
| wrap a `run:` check in `… \|\| true` | it can no longer fail |

Log every pin in `.uj/findings.md`, one dated line (`2026-10-09 · SEND_TWICE_DOUBLE_EMAILS · a second send queues a second email · <issue link> · pinned red`). The log is append-only: when the fix ships and the pin passes on dev, add a new line with `fixed in <version>`, move the journey from `findings/` to its normal folder, remove the `known-bug` tag and the "KNOWN BUG" note, and keep it. It is now the regression guard for that bug.

**6. Correct an expectation that was wrong, with a reason.** Sometimes the journey is wrong: a misread path, an id taken from the wrong step, a rule nobody agreed. Fix it, and write in the pull request what the product does, why that is right, and who agreed (Maya for behaviour). Add the same as a dated line to `.uj/decisions.md` (`date · decision · why · who`), so the reason outlives the pull request. Reviewers compare the old and new `expect:` blocks; an expectation that got looser needs that sentence.

**7. Triage a flaky journey; do not retry it.**
```sh
uj history --flaky
uj history SEND_FROM_THE_WEB_APP
```
The last twelve verdicts read oldest→newest (`·` pass, `X` fail, `-` skip, `!` void, `?` inconclusive). VOIDs are an environment that broke, not flakiness. The usual causes of a real flake, and the fix:

| cause | fix |
|---|---|
| two journeys change the same shared thing under `--parallel` | `conflicts: global:<name>` on both (SOP 12) |
| waiting for async work with a fixed sleep | poll with a deadline in a `run:` step (SOP 10) |
| a `within:` budget near the real latency | budget for staging, not your laptop |
| data left by an earlier run (same email, same name) | unique values in `vars:` with `{rand}` |
| depends on journey order | make it create what it needs; setup gives each journey a fresh user |

History grows with every run. Once a flake is triaged, trim it: `uj history --prune 50` keeps the newest 50 records per journey. Prune after triage, never during it: the old records are the evidence that a journey flips.

**8. Retire an endpoint in two moves.** While `POST /invoices/{id}/send` is deprecated in favour of a new path, keep the old journey and add one for the new path. When the old path is removed, change the old journey to assert the removal (`expect: not-found`, or the status your API promises for removed routes), ship it with the removal, and archive it a release later.

**9. Upgrade uj on purpose.** Read the release notes first (`CHANGELOG.md` in the uj repository), then:
```sh
uj update --check
uj update
uj --version
uj validate journeys/
uj lint journeys/
```
New versions can add lint rules or change behaviour, so validate, lint and run on dev before CI. Recent changes that surface old mistakes: a misspelled key (`expct:`) is now refused instead of ignored, so a step that silently accepted any 2xx now stops the file loading; a `within:` uj cannot read is refused; `denied` fails on a `5xx`; `null` fails a schema `type` unless the property says `nullable: true`; certificates are verified. Each of these can turn an old green into a red or a VOID. Fix the file, then judge the new red like any other (SOP 08 step 15): it may be a bug that was hiding all along. Note the upgrade in `.uj/decisions.md`. CI installs a pinned `REF=` (SOP 12); bump it in its own pull request. To roll back, `uj update` prints the exact `mv -f` line.

## What you'll see

`uj update --check` prints `current:   <version>` and `published: <version>`, then `uj is up to date.` or ``a different release is available (<version>) — run `uj update` to install it.``. `uj update` prints `downloading <asset> …`, `checksum verified.`, `updated: uj <old> → <new>` and `(previous binary kept at <path> — roll back with: mv -f "<previous>" "<binary>")`. After an edit, `uj validate journeys/` ends `validate: N ok, 0 invalid`, and `uj lint` ends `OK — no critical/high findings`. `uj history --prune 50` prints `history: kept K of T record(s) (newest 50 per journey)`.

## If it goes wrong

- `references {invoce_id} which is not a fixture/journey var or a prior capture (typo? or an environment export)` (JL001) — a capture was renamed or misspelled; fix every use.
- `no field at "total" in the response (wanted "1200") — check the path; …` — the API does not return that field (yet), or the path is wrong.
- `response contract violated: …` — a `schema:` expectation caught a dropped or retyped field; decide with Maya whether the API or the journey is right (SOP 15).
- ``<file>: unknown key "expct" — not a uj field (typo?); see `uj schema journey` or `uj schema environment` `` right after an upgrade — the typo was always there and was being ignored; fix it, run the journey, and treat a new red as a finding.
- `uj new: journeys/<NAME>.yaml already exists — pick another name (nothing overwritten)` — choose another title or edit the existing file.
- `uj update: checksum mismatch — expected …, got …. Aborting (nothing changed).` — a bad download or mirror; retry, or re-run the installer.
- `uj update: cannot write to <dir>: …` — the install folder is not yours; re-run the installer as it suggests, or with `INSTALL_DIR=$HOME/.local/bin`.
- `uj update: refusing a non-HTTPS source "…" (TLS is mandatory)` — fix `UJ_INSTALL_BASE`.
- A pin goes green and nobody fixed the bug — look at the file's git history for a weakened expectation before you celebrate.

## Coming

- **A rename that keeps history** (`uj mv OLD NEW`). *Today:* a new id starts a new history line; note the old id in `notes:`.
- **An expected-failure marker** that keeps a pin red in reports but alerts when it unexpectedly passes. *Today:* `findings/` plus a non-blocking job; watch for green.
- **A check that flags weakened expectations in a diff.** *Today:* reviewers compare `expect:` blocks (step 6).
- **A uj command to find every use of a field** across journeys and fragments. *Today:* `grep -rn`.

## Next

SOP 15, API contract and drift. Or back to SOP 09 to write the edge cases the change exposed.
