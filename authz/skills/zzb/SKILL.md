---
name: zzb
description: Drive the zzb CLI to manage ab0t authorization (Zanzibar/ReBAC) against auth.service.ab0t.com. Use when installing/updating the CLI, authenticating an org, writing or deleting relationship tuples, running permission checks (check/expand/list-objects/list-users), publishing authorization models, running assertions, reading the change feed, or scripting any of this in CI or an agent. Covers config precedence (flags → env → ~/.zzb/config.json), the object#relation@subject tuple notation, atomic transact, cursor-paginated read, and --json for machine output. For sized, end-to-end customer setups use zzb-authorization-recipes.
---

# zzb — driving the ab0t authorization CLI

## Install / update zzb

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/ab0t-zzb/main/install.sh | sh
zzb --version        # confirm
```

HTTPS-only, sha256-verified, idempotent. Update in place with `zzb update`
(checksum-verified, atomic; keeps the prior binary as `zzb.previous`) or
re-run the one-liner. Windows: `irm …/install.ps1 | iex`. Mirror:
`ZZB_INSTALL_BASE=… curl -fsSL …/install.sh | sh`.

---

## What this is

`zzb` is a thin HTTPS client for the **ab0t auth service**'s
authorization API. The engine (Check/Expand/tuples) runs in the service; the CLI
just calls it. THE ONE RULE: everything is a relationship tuple
`object#relation@subject`, and a **store** is an organization
(`store_id == org_id`).

Environments: prod `https://auth.service.ab0t.com` · dev `https://auth.dev.ab0t.com`
· local `http://localhost:8001`.

## Authenticate

Config resolves **flags → env → `~/.zzb/config.json`**.

Interactive (writes the config file):
```sh
zzb auth login --url https://auth.service.ab0t.com \
  --org <your-org-slug> --email you@example.com --password ****
zzb whoami        # decode the token: subject, org, expiry (no network call)
```
> Slugs are normalized server-side on `org create`; log in with the slug printed
> in `org create`'s "Next:" hint, not the raw one you typed.

Non-interactive (CI / agents — no login prompt). First **obtain** an org-scoped
token + store, then export the three env vars:
```sh
# one-time: create an identity + org, then log in SCOPED to the org.
zzb auth register --url https://auth.service.ab0t.com --email you@example.com --password **** --name You
zzb org create --name "My Org" --slug my-org        # note the slug it prints in "Next:"
zzb auth login  --url https://auth.service.ab0t.com --org <slug-from-that-hint> --email you@example.com --password ****
# the org-scoped token + store are now saved to ~/.zzb/config.json — read them for CI:
export ZZB_URL=https://auth.service.ab0t.com
export ZZB_TOKEN="$(jq -r .token ~/.zzb/config.json)"
export ZZB_STORE="$(jq -r .store ~/.zzb/config.json)"
```
> **Token lifetime:** org-scoped tokens are short-lived (~15 min). `whoami` shows
> the expiry; for a long automation run, re-run `auth login` (or re-mint the token)
> when it nears expiry, or a call will start returning 401.

## Prerequisite: declare a type before you write tuples for it

> You must publish a model (or register a namespace) that declares an object type
> **before** you can write relationship tuples of that type. Writing a tuple for an
> undeclared type fails with a `404` whose message names the cause and the fix:
> *"Object type is not declared in this store's authorization model. Publish a model
> that defines it first (e.g. `model create --file model.json`)."* So the order is
> always **`model create` → `relationship write`**.

## Start from zero: `zzb init`

New to a store? `zzb init` is a guided scaffold that takes you from zero to a
**working, tested model in one command**. Pick a starter TEMPLATE (`docs`, `drive`,
`notion`, `github`, `bank`) → it writes `model.json` + `assertions.json` (+ a `seed.json`
of the tuples the assertions expect) into the cwd; with `--publish` it also creates the
model, seeds the tuples, and runs the assertions against your active store.

```sh
zzb init --list                       # the full 10-template gallery, one line each
zzb init                              # interactive: pick a template, then optionally publish
zzb init --template docs              # promptless scaffold (writes the three files)
zzb init --template github --publish  # scaffold + model create + seed + assert run (CI-friendly)
```
A 10-template GALLERY (`init --list`): `docs`, `drive`, `notion`, `github`, `bank`, `slack`
(nested teams + public wildcard), `saas-multitenant` (org roles → workspace → resource),
`marketplace` (two-sided buyer/seller + escalation), `warehouse` (ABAC classification × purpose
intersection), `classified` (ordered levels + compartment + NOFORN). On a non-TTY without
`--template` it prints the template list + the flag form and exits (it never hangs on a prompt).
Each template is embedded in the binary and its assertions PASS against its own model once
published. Templates map to `zzb-authorization-recipes`.

## The command surface (with real output)

> **Every verb has rich `--help`** — purpose, flags, copy-pasteable examples, and a NEXT
> block (what to run next + why): `zzb check --help`, `zzb model create --help`,
> `zzb init --help`, …. A typo suggests the closest command (`unknown command 'chek'
> — did you mean 'check'?`).

```
$ zzb model create --file model.json
✓ published authorization model 01M1FYVR1D0BSYQS19W0D8P3C7

$ zzb relationship write document:q3-report owner user:alice
+ document:q3-report#owner@user:alice  (token: eyJvcCI6…)

$ zzb transact --write document:q3-report#viewer@user:bob \
                       --write document:q3-report#editor@user:carol
✓ committed atomically: 2 written, 0 deleted  (token: eyJvcCI6…)

$ zzb check user:bob viewer document:q3-report
ALLOW  user:bob can viewer document:q3-report
  reason: Direct viewer relationship
  time:   6.54ms

$ zzb read --object document:q3-report
document:q3-report#editor@user:carol
document:q3-report#owner@user:alice
document:q3-report#viewer@user:bob

$ zzb list-users document:q3-report viewer
1 subject(s) can viewer document:q3-report:
  - user:bob
```

| Task | Command |
|---|---|
| scaffold a starter model | `init [--template docs\|drive\|notion\|github\|bank] [--publish]` — model.json + assertions.json, optionally created + tested |
| write / delete a tuple | `relationship write o r s` · `relationship delete o r s` |
| atomic batch | `transact --write o#r@s [--write …] [--delete o#r@s …]` |
| can X do Y on Z? | `check <subject> <permission> <object>` |
| whole userset tree | `expand <permission> <object> [--max-depth N]` |
| what can X access? | `list-objects <subject> <permission> <object_type>` |
| who can access Z? | `list-users <object> <permission>` |
| what-if a change | `diff --write o#r@s [--delete o#r@s] (--checks f.json \| --sample)` — preview who gains/loses BEFORE applying; exits `3` if any check flips (`--no-fail` to override). Temporarily stages+reverts the change on the live store, so needs `zanzibar.admin`. `--model/--to` model-version diff is not available yet (needs a server addition). |
| query tuples | `read --object o` / `read --user u` (`--page-size`, `--cursor`) |
| versioned schema | `model create --file m.json` · `model list` · `model get <id>` |
| test the model | `assert put <id> --file a.json` · `assert run <id>` |
| lint for risks | `audit [--max-severity high] [--object o]… [--user u]…` — ranked findings; exits `3` at/above the gate |
| durable watch | `changes [--cursor tok] [--limit N]` |
| bulk checks | `check bulk --file checks.json [--concurrency N]` |

## Tuple syntax differs across verbs (read this once)

The same tuple is spelled three different ways depending on the verb — a common
papercut. Don't guess:

| Verb | Argument shape | Example |
|---|---|---|
| `relationship write` / `relationship delete` | THREE positionals: `<object> <relation> <subject>` | `relationship write document:x owner user:alice` |
| `transact` | combined `--write`/`--delete o#r@s` flags | `transact --write document:x#owner@user:alice` |
| `check` | `<subject> <permission> <object>` (subject FIRST) | `check user:alice can_edit document:x` |

So `write`/`delete` are space-separated `o r s`, `transact` is the packed
`o#r@s`, and `check` flips the order to `s p o`.

## Scripting / agents

- Add `--json` to any command for machine-readable output.
- **Exit codes — read this before scripting `check`:** most commands exit `0` on
  success and non-zero on an API error. But `check` **also exits `2` on a DENY** — a
  DENY is a valid *verdict*, not an error (this mirrors `test`/`zed`). So under
  `set -e` a correct DENY will abort your script. Branch on the verdict, don't let it
  kill the run:
  ```sh
  if zzb check user:alice can_edit document:x >/dev/null; then echo allowed; else echo "denied-or-error"; fi
  # or capture and inspect: v=$(zzb --json check … | jq -r .allowed)
  # verifying a DENY under set -e: guard it →  zzb check … || true
  ```
- `zzb --json read --user user:alice | jq '.tuples[].key.object'`.
- **`--json` output shapes** (the wrappers you'll `jq` most):

  | Command | Extract | jq path |
  |---|---|---|
  | `check` | verdict | `.allowed` |
  | `model create` | new model id | `.authorization_model_id` |
  | `model list` | model ids (newest first) | `.authorization_models[].authorization_model_id` |
  | `model get <id>` | the schema | `.authorization_model.type_definitions[]` |
  | `read` | tuples (+ `expires_at` when time-bound) | `.tuples[].key`, `.tuples[].expires_at` |
  | `read` / `changes` | next page cursor | `.continuation_token` |
  | `list-users` | subjects | `.users[]` |
  | `list-objects` | objects | `.objects[]` |
  | `assert run` | overall + per-assertion | `.passed` (bool), `.results[]` |

  `assert run` also **exits non-zero when `.passed` is false** — safe to use directly as a
  CI gate (`zzb assert run "$MID"`); the `.passed` field is the machine-readable twin.
- Prefer the `ZZB_*` env vars over `auth login` in automation.

## More situations

- **Bulk-authorize a batch** in one fan-out: `check bulk --file checks.json
  --concurrency 16 --json`.
- **Debug a surprising DENY:** `expand <permission> <object> --max-depth 5` shows
  the whole userset tree so you can see which branch is (not) matching.
- **Reverse questions:** `list-objects user:alice can_view document` ("what can
  alice view?") and `list-users document:x can_view` ("who can view x?"). A public
  (`user:*`) object shows up for **every** subject in `list-objects` — that's correct
  (anyone can see it), so "what can this guest see?" includes public objects.
- **Point at another environment for one call:** `zzb --url
  https://auth.dev.ab0t.com --token "$TOK" --store "$ORG" check …`.
- **Two different "wildcard" things — don't confuse them:**
  - **Public / "anyone with the link"** on an *object*: write a `user:*` tuple and
    check it the normal way —
    `relationship write page:x public 'user:*'` then `check user:anyone can_view page:x`.
    This is the mechanism for public pages/links (modeled with `allows_wildcard`; see
    `zzb-modeling`).
  - **Org-wide admin grant** (a PERM#-style ceiling, not a tuple):
    `permission grant user:ops admin organization:<org>` then
    `check wildcard <user_id> <permission>`. NOTE `check wildcard` is **object-less** —
    it answers "does this user hold this permission anywhere?", and does **not** reflect
    the `organization:` target — so use the `user:*`-tuple path above for object/link
    access, not `check wildcard`.

## Gotchas

- **Relation-only `read` is rejected** — always pass `--object` and/or `--user`.
- **`transact` writes are create-only** — writing an existing tuple aborts the
  whole batch (HTTP 409) and persists nothing; delete-then-write to replace.
- **Tuple notation:** `object#relation@subject` splits on the FIRST `#` and FIRST
  `@`; a userset subject like `folder:x#viewer` keeps its own `#relation`.
- **Write 404 = undeclared type.** A `404` on a `relationship write`/`transact`
  means the object's `type` isn't in the active model; the message says so
  ("Object type is not declared … Publish a model that defines it first") — publish a
  model that declares it first (see the prerequisite above).
- **`check` a *permission* vs a *relation*:** you can check either a written
  relation (`viewer`) or a computed permission (`can_view`) — see
  `zzb-modeling` for the difference.

## Related skills

- **`zzb-modeling`** — the schema file + permission language (`+ & - ->`).
- **`zzb-authorization-recipes`** — whole setups by customer size.
- **`zzb-lifecycle`** — schema-as-code, migration, CLI vs SDK vs API.
- **`zzb-audit`** — audit a store for over-grants, public exposure, and dark resources.
- Lost? Read `skills/README.md` (the router).
