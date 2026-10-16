# billing-quota/ — Penny, the ab0t mesh billing, payment and quota client assistant

A complete, client-facing system for metering usage, enforcing tier limits and charging customers on
the ab0t mesh, built the same way as Ally (`../authmesh/`):

- `00_index.md` — start here; the journey and one line per SOP.
- `01_…` to `18_sop_system_*.md` — plain-language SOPs, one per job.
- `agent.md` — **Penny**, a Claude Code agent that follows the SOPs for the user.
- `skills/penny-billing-quota/SKILL.md` — the skill Penny loads; it routes to the SOPs.
- `skills/*` — companion skills (the quota library in depth, the billing and payment APIs, keys and
  tenancy), each a short guide that links back to the SOPs.
- `GAPS.md` — every **Coming** item across the SOPs; the spec list for the quota library, billing and
  payment client experience.

Penny hands everything `authsetup` (install, environments, `connect`, rotation, its errors) to Ally's
SOPs. Install both.

## Install Penny

```sh
curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/billing-quota/install.sh | sh
```
It downloads this folder to `~/.ab0t/bots/billing-quota`, symlinks `~/.claude/agents/penny.md` and
`~/.claude/skills/<each skill>` (the routing skill `penny-billing-quota` plus the companion skills
under `skills/`), leaves any skill folder you already have alone (`FORCE=1` replaces it after moving
yours to `~/.ab0t/bots/.skill-backups/`), and prints what to do next. It talks to no ab0t service and
reads no credentials. From a checkout, `./install.sh` uses the folder you are in. Re-running is safe.
Two companion skills (`mesh-tenancy-authority`, `billing-payment-consumer-setup`) also ship with
Ally; whichever bot you install last provides them.

Also install Ally (`../authmesh/install.sh`), since Penny hands all `authsetup` work to her, and the
library you use:
```sh
go install github.com/ab0t-com/ab0t-quota-go/cmd/quotactl@v0.1.9                      # Go: the quotactl CLI
go get github.com/ab0t-com/ab0t-quota-go@v0.1.9                                        # Go: the library, in your module
pip install "ab0t-quota[all] @ git+https://github.com/ab0t-com/ab0t-quota.git@v0.6.7"   # Python
```
Then start a new Claude Code session and say `@agent-penny`, or "add a free and pro tier to my
service", "my customer paid but is still on free", "connect to billing".

## What Penny will and will not do

- Explains in plain words first; previews every change (diff, `--dry-run`, read-back) and waits for
  your yes; asks before `quotactl capabilities|doctor` because they connect and may create tables.
- Never prints a key; never deletes `~/.authmesh/<service>/`; never tests money on prod; never flips
  enforcement without the acceptance list.
- Writes dollars, decimal strings and idempotency keys; takes `org_id` from the validated token only.
- Says "org", never "realm"; calls the cross-customer capability "the provider's platform-scope tier"
  and never recommends the legacy names the servers still print.

## Keeping it honest

Every command, flag, field and message in the SOPs was checked against the source of `ab0t-quota-go`
v0.1.9, `ab0t-quota` v0.6.7 and the billing and payment services, and the Go snippets compile
against v0.1.9. Where the tool does not do something yet, the SOP says **Coming** and gives today's
workaround; `GAPS.md` collects them. When a gap ships, the SOP is updated and the row removed.

Questions or a message the SOPs do not cover: `platform-team@ab0t.com`.
