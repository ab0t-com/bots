# Machine-readable output shapes

Parse these instead of scraping human text. `--json` is available on `run`, `lint`, `coverage`,
`where`, `projects` and `history`; `help --json` dumps the command catalog. The shapes of `run`,
`lint` and `help` are below; for the others, run them once with `--json` and read the keys.

## `uj run … --json`

```json
{
  "tool": "uj",
  "kind": "journey-run",
  "base": "http://localhost:3000",
  "summary": { "passed": 1, "failed": 0, "other": 0, "void": 0 },
  "results": [
    {
      "id": "ONBOARD",
      "kind": "epic",
      "result": "PASS",
      "reason": "",
      "passed": 3, "failed": 0, "skipped": 0,
      "steps": [
        { "n": 1, "intent": "user logs in", "method": "POST", "status": 200, "ran": true, "pass": true, "reason": "",
          "resp_body": "{\"access_token\": \"***redacted***\", \"user_id\": \"u1\"}" },
        { "n": 2, "intent": "...", "method": "GET", "status": 200, "ran": true, "pass": true, "reason": "" }
      ]
    }
  ]
}
```

- `base` is the target the run hit. `summary.other` counts SKIP + VOID + INCONCLUSIVE; `summary.void`
  is the VOID subset — **inspect `results[].result` individually**; a non-zero `other` is not necessarily fine.
- `resp_body` (when present) is the response evidence with every `secret:` capture value masked as
  `***redacted***` — including in the response that first returned the secret.
- `result` is UPPERCASE here (`PASS`); the `### UJ-VERDICT v1` text line uses lowercase (`pass`).
- A step with `"ran": false` was skipped because a prior step failed (epic abort-on-first-fail).
- A failed step carries a human `reason` (e.g. `"status 500, wanted 200"`); the journey-level `reason`
  repeats the first failing step's, prefixed `step N:`.
- Setup failure, no HTTP response, or an unresolved `{var}` appears as `"result": "VOID"` with a `reason`.

Branch logic for an agent:
```
for r in results:
    if r.result == "PASS":          continue
    elif r.result == "FAIL":        # real defect — the failing step is the one with pass=false
    elif r.result == "VOID":        # environment problem — `uj doctor`; fix target/setup/var names, not the code
    elif r.result == "INCONCLUSIVE":# journey asserted nothing — strengthen it
    elif r.result == "SKIP":        # capability absent — expected
```

## `uj lint … --json`

```json
{
  "tool": "uj", "kind": "lint",
  "files": 3, "journey_files": 3, "bash_files": 0, "blocking": false, "parse_failures": 0,
  "counts": { "critical": 0, "high": 0, "medium": 1, "low": 2 },
  "findings": [ { "rule": "UJ012", "severity": "high", "file": "...", "line": 42, "message": "..." } ],
  "journey_findings": [ { "rule": "JL004", "severity": "warn", "file": "...", "loc": "step 2", "message": "..." } ]
}
```

- `findings` = legacy bash-UJ (.sh) rules (critical/high block); `journey_findings` = JL journey-file
  rules, advisory except `JL000` (the file does not parse; counted in `parse_failures`) and `JL011`
  (a credential in `.uj/` memory), which block.
- `blocking: true` (and exit 1) means a JL000, a JL011 or a critical/high UJ finding — fix before merge.

## `uj help --json`

```json
{ "tool": "uj", "kind": "help",
  "commands": [
    { "name": "run", "group": "run", "needs_service": true,
      "usage": "uj run [journey|dir] [--base URL | --target NAME] ...",
      "examples": ["uj run                                    # all of journeys/ against harness.toml's target", "..."],
      "related": "correctness ... For PERFORMANCE use `load`." }
  ] }
```

Use this to enumerate verbs, learn each one's flags/examples, and see which `needs_service`.
This is the authoritative, drift-guarded command list — prefer it over any hardcoded verb table.
