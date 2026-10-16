# Pointing uj at YOUR service — the operational truths

Design thinking gets you a good journey; these are the operational facts that matter once you RUN
it against a real service (uj 0.1.1).

## Setup is yours to describe — or leave empty

uj has no built-in idea of your service. The target comes from `harness.toml` (or `--base`); what
runs before each journey comes from `environment.json` in the project. With no environment file, or
`"setup": []`, each journey starts anonymous — right when the journey signs up / logs in itself.

- If setup fails, `run` returns **VOID** with the failing step and its reason. VOID means "the
  environment couldn't be set up" — fix the config, don't chase a bug in your service.
- Run `uj doctor` first: it checks the target, reachability, and runs the setup once, listing the
  `{vars}` every journey will get, and names the remedy before you get a confusing run.
- Credentials never go in the file: `{env:NAME}` reads an environment variable at run time.

## `environment.json` `export:` accepts BOTH `{braces}` and bare names

`export` renames a captured var to a canonical journey name. The source resolves either way; here
`session_token` and `org_id` are names an earlier setup step captured:

```json
"export": { "token": "{session_token}", "org": "org_id" }
```

The first entry uses the `{braced}` interpolation form, the second a bare capture name; both work.
If you don't need renaming, omit `export` — captured names are already usable as `{name}`.

## `capture:` works on `run:` steps too — from the command's JSON stdout

A `run:` (shell escape-hatch) step can `capture:` by emitting JSON on stdout:

```yaml
- intent: mint a token via a CLI and hand it downstream
  run: "mytool issue-token --json"     # prints {"token":"..."}
  capture: { "secret:token": "$.token" }
  expect: { exit: 0 }
```

The same JSONPath-lite and append-only rules as HTTP steps apply; if the path isn't in the output
the step FAILS loudly (no silent drop).

## `capability:` — built-in `enterprise` plus whatever the environment declares

`capability: [enterprise]` is probed automatically. For your OWN capabilities, declare them present
in `environment.json`:

```json
"capabilities": ["premium_tier", "beta_exports"]
```

A journey gating on `capability: [premium_tier]` then runs; anything neither probed nor declared
SKIPs honestly.

## Read the per-finding lint lines; a parse failure BLOCKS

`uj lint`'s per-finding lines are authoritative. A journey that does not parse (`JL000`) makes lint
**FAIL and exit 1**, as does a credential in `.uj/` memory (`JL011`); the other journey rules are
advisory. Read the findings above the summary: the summary is a roll-up, the findings are the
detail.

## Under-sold capability: `expect.body` keys can be dotted paths

`expect.body` is not top-level-only — a dotted key asserts a NESTED field:

```yaml
expect:
  body: { "revoked_by.id": "admin-42" }   # asserts response.revoked_by.id == "admin-42"
```

Use it to assert nested response values without reaching for `schema`.

## `uj new journey` writes into the project's `journeys/`

It finds the project by walking up from where you stand (the folder with `harness.toml`) and writes
`journeys/<ID>.yaml` there, whichever sub-folder you run it from; it prints the full path and the
next commands. Nothing is overwritten: if the file exists it stops with
`uj new: <project>/journeys/<NAME>.yaml already exists — pick another name (nothing overwritten)`.
