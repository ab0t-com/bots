# 03 · Install, sign in, pick an environment

**What this is for.** Getting `authsetup` onto your machine at the right version, knowing which account it will act as, and making sure every command points at the environment you mean. Read this once; everything after it assumes you did.

**Before you start.** A terminal on Linux or macOS (amd64 or arm64). Nothing else: no account, no ticket, no checkout of any ab0t repository.

## Steps

**1. Install the tool, and check the version.**
```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/clientsetup/main/install.sh | sh
authsetup version
```
The installer checks the published sha256 before it writes anything, installs to `/usr/local/bin/authsetup` (to install elsewhere, set the variable for `sh`: `curl -fsSL …/install.sh | PREFIX=$HOME/.local sh`), and keeps the previous binary as `authsetup.previous` so you can roll back. It is safe to re-run.

These SOPs are checked against **`authsetup 0.5.25`** (the `VERSION` file next to them). If `authsetup version` prints something older, update first: `authsetup update --check`, then `authsetup update` (SOP 15). Older binaries print different messages from the ones SOP 16 quotes, and before 0.5.24 a NEXT line could drop your environment.

**2. Know which environment you are talking to.**
```sh
authsetup --env dev env
```
Three are built in:

| name | auth service | who uses it |
|---|---|---|
| `prod` | `https://auth.service.ab0t.com` | your live customers |
| `dev` | `https://auth.dev.ab0t.com` | you, while building |
| `local` | `http://localhost:8001` | a stack on your own machine |

**`prod` is the default.** If you type a command with no `--env`, it goes to production. Every SOP in this folder therefore writes `--env` on every command, and so should you. Working against an auth service by URL instead? Use `--base-url <url>` on every command; a URL you give and an `--env` you give must agree, or the command stops.

**3. Make `dev` your default while you build.**
```sh
authsetup use-env dev
authsetup use-env          # prints the current default
```
This writes one label to `~/.authmesh/active-env`. A per-command `--env` still wins, and `AUTHSETUP_ENV=dev` in your shell works too. The order is: `--env` > `AUTHSETUP_ENV` > the sticky default > a label derived from a URL > prod.

`authsetup up` (SOP 05) is stricter: it never falls back to prod. If none of the above chose an environment it asks you once in a terminal (default `dev`) and offers to remember the answer with `use-env`; in a script it stops with `up needs a chosen environment and never guesses production — pass --env dev (or --env prod), or run `authsetup use-env dev` once`.

**4. Copy NEXT lines with their target.** Every command ends with a `NEXT —` block: the command to run next and why. From 0.5.24 those lines repeat how you chose the target (`--env dev`, or `--base-url <url>`), plus `--config-dir` and `--as` when you gave them. When nothing chose the target, the flag is left out on purpose; add your `--env` before you run the line.

**5. See who the tool acts as.**
`authsetup` acts as whichever identity owns the credentials it finds, never as "you" the person. Those credentials live in `~/.authmesh/<name>/`, one folder per identity, one file per environment; for your own service that is the admin account step 01 created (`invoicer-admin@acme.example`, file `~/.authmesh/invoicer/invoicer.<env>.json`).
```sh
authsetup accounts                 # every identity on this machine
authsetup --env dev info           # one identity in detail: orgs it owns, accounts it holds, where files are
```
If you own several services, pick one with `--as invoicer`. If `info` shows `self: authmesh-consumer`, you have no credentials yet; that is normal before your first run. During a run, each switch prints `· acting as invoicer-admin@acme.example in your service org invoicer (<id>)` (or `your end-users org …`, `your consumers org …`), so you can see who did what where.

**6. Give your AI assistant the same knowledge.**
```sh
authsetup bot install          # Ally herself: the agent, these SOPs and her skills (offline, matches your authsetup)
authsetup skills install       # the bundled client skills on their own (authsetup-cli and the rest)
authsetup skills list
```
`bot install` (from 0.5.25) puts Ally in `~/.ab0t/bots/authmesh/` and links her agent and skills into `~/.claude/`, the same layout as the bots installer; `--project` does it for one repository (`./.claude/`). `skills install` copies the bundled skills into `~/.claude/skills/`. Restart the assistant afterwards so it loads them. `authsetup bot status` tells you later whether Ally still matches your `authsetup`.

**7. Check your situation any time.**
```sh
authsetup --env dev doctor
```
Read-only. It checks the binary version, whether the auth service is reachable, whether your config is valid, where your credentials are, whether your service key actually holds the permissions you declared, whether your saved admin credentials are present, and your connections. Safe against prod too. By default it does **not** sign in as your admin (a sign-in with a stale password counts toward that account's lockout); `authsetup --env dev doctor --strict` signs in once to prove the credentials still work, and also fails when the service key holds fewer permissions than you declared.

## What you'll see

Every command prints the environment it resolved on its first line, like `· env: dev  (auth: https://auth.dev.ab0t.com)` (with `(active)` when it came from `use-env`). If that line says `prod` and you did not mean it, stop. Local-only commands say so: `validate` prints `… — not contacted: validate is local-only`.

The first time you change anything on prod from a given credentials folder, you get a loud banner and must type `prod` to continue. After that one confirmation it stops asking for that folder. In automation set `AUTHSETUP_CONFIRM_PROD=1` instead of typing.

`doctor` prints an `admin sign-in` row: ``✓ saved credentials present (sign-in not tried) — run `authsetup --env dev doctor --strict` to verify the admin can sign in``.

## If it goes wrong

- `refusing to mutate PRODUCTION (…) without an explicit target — pass --env dev (or --env <name>), …` — you ran a changing command with no `--env`. Add `--env dev`, or `--env prod` if you truly mean it.
- `refusing to mutate PRODUCTION (…) on a non-interactive terminal without confirmation` — a script, a pipe or `</dev/null` aimed at prod. From 0.5.24 `/dev/null` counts as "not a terminal", so CI sees this at once. Set `AUTHSETUP_CONFIRM_PROD=1` only if prod is intended.
- `unknown environment "staging" (…) — define it in environments.json or use one of: …` — only `prod`, `dev`, `local` are built in. Add your own URL to `~/.authmesh/environments.json` (`{"environments":{"staging":{"auth_service_url":"https://…"}}}`), or a repo-local `config/environments.json`. URLs only; anything that looks like a secret in that file is ignored.
- `environment "dev" resolves to … but an explicit URL … was also given — they must agree (drop one)` — you passed `--env` and `--base-url` (or `AUTH_SERVICE_URL`) pointing at different servers. Pass one or the other.
- `active-env "x" … is not a known environment — ignoring` — your sticky default names an environment that no longer exists; run `authsetup use-env dev` to reset it.
- `unknown flag --jsn — did you mean --json?` (exit `2`) — a typo; the line tells you the right flag and which `--help` to read.
- Wrong or old binary: `authsetup update --check`, then `authsetup update`. Roll back with `mv -f /usr/local/bin/authsetup.previous /usr/local/bin/authsetup` (the update prints the exact path).

## Coming

- **`authsetup login`** — sign in once as a person and have the tool act as you, instead of as whichever credentials folder it finds. *Today:* identity is the credentials folder; use `accounts`, `info` and `--as <name>` to see and choose. This waits on a device sign-in flow in the auth service.

## Next

SOP 04, describe your service.
