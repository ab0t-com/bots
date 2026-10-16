# authz/ — Zee, the ab0t authorization-modeling assistant

Zee is for the question Ally and Penny do not answer: **inside your own app, who may do what to
which thing?** Documents an editor can view, folders whose members inherit access, approvals that
need a second person. Zee turns that, said in plain words, into a correct relationship-based
model on the ab0t auth service (`zzb`, Zanzibar-style), and never lets an unsafe change reach the
store: every mutation is previewed with `zzb diff` (who gains, who loses) and confirmed first.

- `agent.md` — **Zee** (moved here from `~/.claude/agents/zee.md`; this folder is now the master).
- `skills/` — the six `zzb*` skills Zee loads by name: `zzb` (commands), `zzb-modeling` (schema
  language and traps), `zzb-authorization-recipes` (sized setups A–E), `zzb-lifecycle`
  (day-2, migration, CI), `zzb-audit` (risk audit, access review), `zzb-auth-as-code`
  (`auth.yaml` + `plan`/`apply`, the full-slice `init`). The same skills ship embedded in the
  `zzb` binary; these copies let the bot install stand alone.
- `install.sh` — installs Zee into Claude Code (downloads this folder, symlinks agent + skills).

## Install Zee

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/authz/install.sh | sh
```
It downloads this folder to `~/.ab0t/bots/authz`, symlinks `~/.claude/agents/zee.md` and
`~/.claude/skills/zzb*`, leaves any skill you already have alone (`FORCE=1` to replace), and prints
what to do next. It talks to no ab0t service and reads no credentials. From a checkout,
`./install.sh` uses the folder you are in. Re-running is safe.

Zee drives the `zzb` CLI, installed separately:
```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/ab0t-zzb/main/install.sh | sh
```
Then start a new Claude Code session and say `@agent-zee`, or "model my authorization", "add a role",
"can user X do Y", "stand up auth for my app".

## How Zee fits with the other bots

Ally gives your service sign-in and the mesh's permission *names* (`invoicer.read.invoices`). Penny
meters and charges. Zee models the *relationships* between your users and your objects (owner,
editor, viewer, member-of-folder) and answers "who can access this, and why". `zzb apply` and
`zzb init --with-tenancy` can drive `authsetup` for you, so Zee can stand up the whole slice.

## Not yet

Zee predates the SOP method: its knowledge lives in its skills, not in numbered client SOPs, and it
has no `GAPS.md`. Writing `01_…`–`nn_sop_system_*.md` for the zzb client journey with the
`sop-aligned-agent-system` skill is the next step for this folder (see `../BOTS_WANTED.md`).
