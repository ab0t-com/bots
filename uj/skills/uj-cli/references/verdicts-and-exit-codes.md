# Verdicts & exit codes — the honest-verdict protocol

The whole point of uj is that a verdict never lies. Read this before you branch on a result.

## The five verdicts

| Verdict | Meaning | What an agent should do |
|---|---|---|
| `PASS` | every assertion held | done — the behaviour is correct |
| `FAIL` | the service answered, and an assertion failed | a real defect — or a wrong expectation in the journey; read the step's reason + response before filing |
| `SKIP` | a required capability is absent (e.g. enterprise endpoint not mounted) | not a failure — note it, move on |
| `VOID` | the journey could not be judged: environment setup failed, no HTTP response (service down / wrong URL), or a step used a `{var}` nothing provided | **fix the environment (or the var name), do NOT file a code bug** |
| `INCONCLUSIVE` | the journey executed but asserted nothing | add assertions — a green that proves nothing |

The critical distinctions:
- **VOID ≠ FAIL.** A failed *setup* (couldn't mint a tenant, service unreachable) is VOID. Treating
  it as a code failure sends you chasing a bug that isn't there. When you see VOID, run `uj doctor`:
  it checks the target, the service health, and the environment's setup steps.
- **INCONCLUSIVE ≠ PASS.** A journey whose steps executed no assertion at all (`no steps executed an
  assertion`) is INCONCLUSIVE. Do not report it as passing. A step that checks only the status is an
  assertion, so it can PASS; that is why lint flags status-only success checks as JL004.
- **Exit 0 ≠ PASS.** The shell exit code is a coarse signal. The *verdict* is the truth.

## The verdict line

Every run emits, per journey, a structured line:

```
### UJ-VERDICT v1 {"id":"ONBOARD","result":"pass","passed":3,"failed":0,"skipped":0}
```

A resumed run adds `"resumed":true` — an auditor must see the run wasn't clean-from-zero:

```
### UJ-VERDICT v1 {"id":"ONBOARD","result":"pass","passed":3,"failed":0,"skipped":0,"resumed":true}
```

Parse this line (or the `--json` output) rather than the human summary. Casing note: the verdict
line uses lowercase (`"result":"pass"`); `uj run --json` uses uppercase (`"result":"PASS"`). Both are
stable contracts — compare case-insensitively.

## Exit codes

**`uj run`** — suite-level:

| code | meaning |
|---|---|
| 0 | every journey PASSed (SKIP/INCONCLUSIVE allowed unless `--strict`) |
| 1 | at least one journey FAILed (a real FAIL outranks VOID) — or, with `--strict`, an INCONCLUSIVE/SKIP |
| 2 | at least one journey was VOID (environment broke; nothing judged) — or a usage error (bad flag, no target, no journeys) |

So a CI job can tell "the product is broken" (1) from "the environment is broken" (2) without
parsing JSON. Use `--strict` in CI so "asserted nothing" never shows green.

**`uj verdict <file|->`** — per-verdict, richer, for scoring a captured log:
| code | verdict |
|---|---|
| 0 | PASS |
| 1 | FAIL |
| 2 | VOID |
| 3 | SKIP |
| 4 | INCONCLUSIVE |

Use `verdict` when you have captured a test's stdout and want an honest score:

```bash
./some_legacy_test.sh | uj verdict -      # scores the captured output, never exit-0=pass
```

## Why this exists

A test suite is only useful if green means "it works". The most common way it stops meaning that
is a test that passes whether or not the thing it names is true: a check over an empty list, a setup
that silently failed, a script whose exit code was `0` because nothing ran. The verdict vocabulary
and the VOID/INCONCLUSIVE distinctions are the machine-checkable defence: a run that couldn't
evaluate, or evaluated nothing, says so loudly rather than showing green.
