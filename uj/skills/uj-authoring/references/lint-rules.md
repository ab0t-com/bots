# Lint rules — and how to satisfy each

`uj lint [paths]` runs two rule families. `uj lint --rules` prints them; `--json` splits them
into `findings` (UJ, legacy `.sh` files) and `journey_findings` (JL, `.json`/`.yaml` journeys).

## JL — journey-authoring rules (the ones you fix while writing a journey)

Two rules **block** (`uj lint` exits `1`): **JL000** (the file does not parse) and **JL011** (a
credential in `.uj/` memory). Every other JL rule is advisory (warn/info): lint still exits `0`, but
each one names a real defect, so fix them rather than ignore them.

| Rule | Sev | Fires when | How to satisfy |
|---|---|---|---|
| **JL000** | **blocks** | the journey file does not parse (bad YAML, an unknown key, an unreadable `within:`), so it cannot be tested | fix the syntax; `uj validate <file>` names the problem |
| **JL001** | warn | a step references `{var}` that is not a fixture/journey var or a prior capture | fix the typo, or declare the var in `vars:` / capture it earlier |
| **JL002** | info | a `capture` is never used by a later step (path, body, bearer, run, or `expect` values) | use it (assert or interpolate it) or delete the capture |
| **JL003** | info | the journey creates resources (POST) but has no `finally:` | add a `finally:` teardown (per-run tenant isolation may still cover it) |
| **JL004** | warn | a successful GET/POST/PUT/PATCH asserts ONLY status (no fields/body/schema/absent/notcontains/headers). Exempt: `deny`/`denied`, an expected status ≥ 300 (e.g. 404, 422), `abuse:` and `misstep:` steps | add `fields`, `body`, or a `schema` — a client consumes this response |
| **JL006** | warn | a capture NAME looks like a secret (token/password/…) but isn't marked | prefix the capture key `secret:` so its value is redacted in evidence |
| **JL007** | info | an `epic` has no `conflicts:` | only matters for `uj run --parallel`: `conflicts: tenant` if it touches only its own fresh data, `global:<name>` if it changes shared state |
| **JL008** | info | no `success:` statement | add a one-line, plain-English `success:` — what "worked" means |
| **JL009** | warn | `outcome:` starts with a task verb (create/get/delete…) | rewrite as the change in the person's world — ask "so that… what?" |
| **JL010** | warn | `{rand}` appears inside `expect` (body values, headers, notcontains) — it is a NEW value there, so it can never match | set it once in `vars:` and use that name in the request and the expectation |
| **JL011** | **blocks** | a `.uj/` memory file looks like it contains a credential | remove it (and rotate it); reference `{env:NAME}` |
| **JL012** | warn | scaffold placeholders left in (`<…>` text, `/TODO` paths) | replace them with the real story and endpoints |
| **JL013** | info | a journey of 3+ steps never checks that something is REFUSED (`abuse:`, `deny`/`denied`, an expected 4xx) | add a step where an outsider or a wrong input must be refused |

(JL005 is reserved and unused.)

**JL004 is the important advisory one.** A status-only assertion is the "gate that cannot fail"
defect class: a 200 with a garbage or wrong body still passes. Asserting `fields`/`body`/`schema`
turns the step into a real contract check. Aim for zero JL004 findings in journeys that matter.

## UJ — legacy bash user-journey rules (UJ001–UJ017)

These lint older `.sh` user-journey scripts (curl-based). Critical/high findings block (`uj lint`
exits `1`). They check, for example, that a script has an intent header, isolates its data, does not
treat `exit 0` as a pass, and prints a structured verdict line. For new work, prefer the journey
(YAML/JSON) format and the JL rules; the UJ rules exist for existing `.sh` scripts (SOP 17).

## Reading a lint run

```bash
uj lint journeys/                 # human output; findings + an OK/FAIL line
uj lint journeys/ --json          # machine-readable: findings[] (UJ) + journey_findings[] (JL); blocking, parse_failures
uj lint --rules                   # list every rule
```

`"blocking": true` (and exit `1`) means a JL000, a JL011, or a critical/high UJ finding: fix before
merge. The advisory JL findings never block, but a journey full of JL004s proves little; treat them
as must-fix for anything load-bearing.
