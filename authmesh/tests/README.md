# authmesh/tests — checks that keep Ally true to `authsetup`

## `sop_command_lint.sh` — every command and flag Ally shows exists

Ally's pages are full of `authsetup …` commands. A client (or an AI agent) copies them as written, so a
renamed flag or a command that is not built yet turns help into an error. This check reads every
`authsetup …` command in the SOPs, `agent.md`, `GAPS.md`, `README.md`, the `ally-mesh-client` skill and
the bundled `authsetup-cli` skill, and asks a real binary's own `--help` whether each command, sub-command
and flag exists. It is read-only, runs nothing but `--help`-style calls on the binary, and contacts no
server.

```sh
tests/sop_command_lint.sh                                  # authsetup on PATH
tests/sop_command_lint.sh /path/to/authsetup               # a specific binary (e.g. a new release)
REQUIRE_TARGET=1 tests/sop_command_lint.sh /path/to/authsetup   # also: runnable commands carry --env/--base-url
ALL_SKILLS=1 tests/sop_command_lint.sh /path/to/authsetup       # also scan every companion skill
tests/sop_command_lint.sh /path/to/authsetup some.md       # only the files you name
```

Exit `0` = no offenders, `1` = offenders (each printed as `file:line: authsetup … → reason`), `2` = the
binary is missing or is not `authsetup`.

**Rules it applies.**
- A command must be in the binary's own command list; a sub-command of `skills`, `connection` or
  `snippet` must appear in that command's `--help`.
- A flag must be a global flag (`authsetup --help`, KEY FLAGS), or be named in `authsetup <cmd> --help`,
  or be described for that command in the binary's flag table.
- A command the binary does not have is allowed only when `GAPS.md` names it: that is how **Coming** verbs
  (`authsetup login`, `authsetup rotate-key` …) stay honest. Mark an unbuilt verb Coming *and* add a
  `GAPS.md` row, or the lint fails.
- `REQUIRE_TARGET=1` additionally fails a command in a code block that depends on the environment but has
  no `--env` / `--base-url` (`validate`, `init`, `update`, `skills`, `version`, `accounts`, `env`,
  `use-env`, `help` and `--help` are exempt). Inline mentions of a command by name are not checked for this.
- Skipped on purpose: placeholders (`authsetup <command> --help`, `authsetup …`), version strings
  (`authsetup 0.5.24`), and "authsetup" in the middle of a sentence inside a quoted message.

**What it does not check.** The wording of quoted messages. Those come from the release's migration kit
(`migrations/vFROM-to-vTO/MIGRATION.md` in `github.com/ab0t-com/clientsetup`) and the source; re-read them
by hand when a release rewords output.

**Results recorded for this folder (2026-10-16).**
| binary | result |
|---|---|
| `authsetup 0.5.24` | Ally's pages: 229 commands checked, 24 Coming verbs (all in `GAPS.md`), **0 offenders**. `ALL_SKILLS=1` (every skill under `skills/`): 385 commands, 0 offenders, also with `REQUIRE_TARGET=1` |
| `authsetup 0.5.23` | 0 offenders (0.5.24 changed messages and behaviour, not the command surface) |
| `authsetup 0.5.17` | 70 offenders (no `up`, `settings`, `login-url`, `connection`, `grant-platform` …): the check does go red on a stale binary |
| a file with `up --jsonx`, `frobnicate`, `skills frob`, `doctor --verify`, `connect --tierx` | 5 offenders, one per mistake; `status --verify`, an env-prefixed `up --yes`, a Coming verb and a quoted message pass |

**When to run it.** After every `authsetup` release (against the new binary), after editing any SOP, and
before publishing the bots repo. When it is clean against a new release, bump `VERSION` and
`bot.json` → `verified_against`.
