# 15 · Migrations and upgrades

**What this is for.** Four kinds of "newer version": the `authsetup` binary itself (and the scripts or agents that drive it), moving off the old bash setup kit onto `authsetup`, upgrading the SDK inside your service (`auth-sdk-go` for Go via **migrationbot**, `ab0t_auth` for Python), and your `permissions.json` as the schema grows.

**Before you start.** A quiet moment; none of these should be done mid-incident. For SDK upgrades, a clean working tree in your service repo and a passing build. For an `authsetup` upgrade, know where your CI scripts that call `authsetup` live.

**How every upgrade is shipped.** A release that changes behaviour comes with a **migration kit**, one folder per hop, named `migrations/vFROM-to-vTO/`, in the tool's or library's public repository. Each kit has the same three files:
- `MIGRATION.md`: what changed, why, before → after, whether it can break you, what to do;
- `migrate-check.sh`: a **read-only** checker. `./migrate-check.sh /path/to/your/repo` prints every place that relies on the old behaviour, with the fix, and exits non-zero while any remain (gate CI on it). It never edits your files;
- `CLIENT_NOTICE.md`: a short notice to paste to your team.
Crossing several versions? Run each kit's checker in order.

## Steps

### A. Keep `authsetup` current
```sh
authsetup version
authsetup update --check          # is there a newer release? downloads nothing
authsetup update                  # download, verify sha256, swap in place; old binary kept as <path>.previous
authsetup version
```
`update` talks only to the public release repository on GitHub, never to the auth service, and needs no config or credentials. `authsetup --env dev doctor` also tells you when a newer version exists. Roll back with the printed one-liner: `mv -f /usr/local/bin/authsetup.previous /usr/local/bin/authsetup`. Your `config/` and `~/.authmesh/` are untouched by an update; the tool reads older credential files as they are. Ally's pages are checked against the version in their `VERSION` file (0.5.25); after an update, refresh Ally with `authsetup bot install` (from 0.5.25 `update` prints that line for you when your Ally is older).

**Then check what drives `authsetup`.** People rarely need to change anything; scripts, CI jobs and agents that *read authsetup's words* might. The kits for `authsetup` live in `github.com/ab0t-com/clientsetup`, folder `migrations/`:
```sh
git clone --depth 1 https://github.com/ab0t-com/clientsetup /tmp/clientsetup
bash /tmp/clientsetup/migrations/v0.5.23-to-v0.5.24/migrate-check.sh /path/to/your/repo
```
`No v0.5.24 migration findings.` (exit `0`) means nothing to do. Otherwise each finding names the rule (`R2`, `R5`, `R10` …), the line, and the fix; `MIGRATION.md` in the same folder explains the rule.

**What 0.5.24 changed, for you** (rows R1–R19 of that kit, in short):
- Your permission schema is registered **only by your service org**; steps 04 and 08 no longer re-register it from the other orgs (that was refused with a `403` and could stop step 04). Stuck at 04/08 with a schema `403` on 0.5.23? Upgrade and run again.
- The schema **name is checked before anything is created**, in a preview too. A taken name now makes a first `--dry-run run` / `up --dry-run` exit `1`: the apply would have failed anyway.
- Ownership refusals are explained in plain words: **is taken**, **no owner recorded**, or the server did not say which. They no longer contain `HTTP 403` or `owned by another organization`; a script that grepped those stops matching. Use the exit code (`1`); to tell the cases apart, match `is taken` / `no owner recorded`.
- **NEXT lines keep your target** (`--env`, or `--base-url` when you used a URL; plus `--config-dir` and `--as`).
- Step 06 **removes its throwaway test user**. Users left by older versions are named `setup-go-test-…`; remove them from your users org by hand.
- Run summaries say what happened: `~ re-sent:` is not a change; `N changed · M re-sent`; `✗ run failed at step NN (…)` with the exact resume command; a preview's count equals its `would:` lines. Do not parse these lines; use exit codes `0`/`1`/`4`.
- `providers --json` and `update --json` print exactly **one** JSON document; drop any `tail`/`sed` workaround. `validate --json` gains a `warnings` array.
- Off production, `connect` leaves `<SVC>_SERVICE_URL=` empty instead of guessing the production address.
- **Security:** credentials go only to the auth URL you gave (same scheme, host and port). A server that advertises or redirects to another origin now fails the step (exit `1`) with a message naming both origins (SOP 16, SOP 17).
- `doctor` no longer signs in by default; `doctor --strict` does, once.
- Rollback: reinstall the 0.5.23 binary; no data migration is involved.

### B. Move from the old bash kit (`./setup`, `scripts/01-…09-…sh`)
The bash scripts no longer ship; `authsetup` reads the **same `config/` files** and writes compatible credential files, so your config migrates as-is. What moves is where credentials live: from the repo's `./credentials/` to `~/.authmesh/invoicer/`.

1. From the directory that holds your old `./credentials/`:
   ```sh
   authsetup --env prod --config-dir ./config --dry-run migrate
   authsetup --env prod --config-dir ./config migrate
   ```
   It verifies the old admin and org **against the server** before trusting anything, then imports `credentials/invoicer.json` to `~/.authmesh/invoicer/invoicer.prod.json`. Use `--env dev` for a dev checkout (it reads the old `invoicer-dev.json`). Re-running is a no-op (`already migrated`).
2. Confirm and adopt:
   ```sh
   authsetup --env prod info
   authsetup --env prod --config-dir ./config --dry-run run    # a healthy setup shows no planned changes
   authsetup --env prod --config-dir ./config run 05 06
   ```
   Any planned change on that dry-run is **real drift** the old kit's "already exists, skipping" had hidden; read each one before applying. A `~ re-sent` line is not drift.
3. Consumer keys the bash kit minted (`credentials/<provider>-consumer.json`) are not imported by `migrate`. Copy each into `~/.authmesh/invoicer/` as `<provider>-consumer.prod.json` **before** `run 07`, or it will mint a new one.
4. Once confident, move the repo-local `./credentials/` out of the repository (into an archive folder outside it); it is the only credentials folder you ever retire.

Things that behave differently on purpose: validation now gates every command (the bash validator did not); step 04 honours your configured default role instead of hard-coding `member` (set `end_users.default_role: "member"` explicitly if you relied on that); hyphenated `registration.service` is now an error; failures stop the run instead of printing and continuing. Once you use `--env`, the per-environment file names (`<name>.<env>.json`) are not readable by the bash kit; going back is the one-way step.

### C. Upgrade `auth-sdk-go` in a Go service (migrationbot)
Kits live in the SDK repository (`github.com/ab0t-com/auth-sdk-go`, folder `migrations/vFROM-to-vTO/`), with an optional agent, **migrationbot**, that runs the loop for you.

1. Find your version: `grep auth-sdk-go go.mod` → FROM. The highest tag is TO.
2. Install the agent once: copy `migrations/agent/migrationbot.md` from the SDK repo to `~/.claude/agents/migrationbot.md`.
3. Hand off: `@agent-migrationbot migrate this service from <FROM> to <TO> using <kit path>`. It chains kits when several versions are between you, applies the mechanical edits, runs `go get github.com/ab0t-com/auth-sdk-go@<TO>`, re-checks, and stops only when `go build ./... && go vet ./... && go test ./...` are green. It writes an append-only `MIGRATIONBOT_WORKLOG.md` and **does not commit**; you review.
4. By hand instead: `bash <kit>/migrate-check.sh .`, fix each printed site per `MIGRATION.md`, bump, rebuild. The authoritative stop condition is the clean build; older kits' checkers may keep flagging identically named fields on your own types, which you triage.
5. Anything the kit marks **SECURITY** (for example `Authorize` now making a real scoped decision) gets a human look: a test that used to pass with `true` may now correctly be `false`. Fix the assertion, never the behaviour.

The two most recent hops need no source change, but read them:
- **v0.11.2 → v0.12.0** (behavioural): validation answers are **cached by default** (API key 60 s, user token 15 s, permission decision 15 s), so a revocation can take that long to reach your process. Opt out with `auth.WithValidationCache(0)`; bypass for one sensitive call with `auth.WithFreshValidation(ctx)`. Tests that flip a fake auth server's answer mid-test should build the client with the fake's `NewClient()`. New: `VerifyAccessTokenLocal` (no network call; cannot see logout).
- **v0.12.0 → v0.12.1** (bug fix + additive): the `authmw` middleware answers **401, not 503**, when the auth service rejects a token (and `FailOpen` no longer lets such a request through). New, opt-in: `WithExpectedJWTAudience` (checks your audience on user tokens only, so mesh service keys still pass; SOP 06), `RequireIdentity`, `IncludePermissions`, `JSONDenial`. Clients that retried on 503 now correctly re-authenticate.

The whole entrypoint is `migrations/init.md` in the SDK repo, written to be pasted into your assistant.

### D. Upgrade `ab0t_auth` in a Python service
```
pip install --upgrade "git+https://github.com/ab0t-com/auth_wrapper.git@v0.1.4"    # the tag you upgrade to
```
Kits live in that repository too (`migrations/vFROM-to-vTO/`; they are not part of the installed package, so fetch them from the repository at the release you upgrade to). **0.1.3 → 0.1.4** has no source change but changes cache defaults to match the Go SDK: permission decisions 15 s allowed / 5 s denied (was 30 s), API keys now cached 60 s / 10 s (were checked on every request), unknown-`kid` key refetch at most once a minute. A revoked key can therefore keep working on your service for up to 60 s. For sensitive routes pass `fresh=True` to the dependency; every TTL is configurable (`AB0T_AUTH_*_CACHE_*`, `0` disables). Run the kit's `migrate-check.sh /path/to/your/service`, then your test suite.

### E. Your `permissions.json` as the schema grows
New fields are additive and ignored by older binaries. To adopt the scope model (SOP 01, in `authsetup` since 0.5.21): add `"scope": "platform"` to the few cross-customer permissions, `authsetup --config-dir ./config validate` (it now checks reach words and defaults), then `authsetup --env dev --config-dir ./config up`. Nothing else changes; a file without `scope` keeps working exactly as before.

## What you'll see

`update`: `already on the latest` or the new version printed by `authsetup version`. A kit checker: `No v0.5.24 migration findings.` (exit `0`) or `[R5] …` blocks with `file:line` and `Candidates above — see MIGRATION.md.` (exit `1`). `migrate`: `migrated invoicer → ~/.authmesh/invoicer (org invoicer, verified on server)` then a NEXT block pointing at `run`. migrationbot: a worklog whose last entry shows `No migration findings` and the green build.

## If it goes wrong

- `update`: a bad release → `mv -f <path>.previous <path>`. Network errors are GitHub reachability only. `update --json` failures are a JSON document (`{"action":"error",…}`) from 0.5.24.
- A kit checker flags a line you know is fine (it prefers false alarms to misses): confirm by reading the line; the rule's `MIGRATION.md` row says what it looks for.
- A CI step that grepped `HTTP 403`, `owned by another organization`, `✓ PUT login-config`, `step(s) not reached` or `would: deferred` stopped matching after the upgrade: switch it to the exit code (R2, R5, R10).
- `migrate`: `no bash-kit credentials at ./credentials/invoicer.json — nothing to migrate`: run it from the old checkout, or you never used the bash kit and do not need it.
- `migrate`: `the bash-kit admin … no longer authenticates against <url> — refusing to migrate stale credentials`: recover the admin (password reset) or set up fresh; it will not import something the server rejects.
- `migrate`: `credentials dir is inside a git repository and NOT gitignored`: pass `--write-gitignore` or let the default `~/.authmesh/` stand.
- After migrating, `run 01` says `a service org with slug "invoicer" already exists`: the import did not land in the creds dir `run` is using; check `--creds-dir` / `AUTHSETUP_CREDS_DIR` and `authsetup info`.
- migrationbot stops with a `file:line` it cannot resolve: that is by design; fix that one site yourself and resume.

## Coming

- **`authsetup migrate` importing consumer keys too.** *Today:* copy them by hand (step B.3).
- **`authsetup migrate-config`** to add new schema fields (such as `scope`) with a diff. *Today:* edit by hand; `validate` checks it.
- **`update` notifying you inside `run`** when you are behind. *Today:* `doctor` and `update --check`.
- **A machine-readable run result** so scripts never read prose. *Today:* exit codes.

## Next

SOP 16, troubleshooting and recovery.
