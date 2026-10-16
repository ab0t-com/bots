# 05 · Verify and ship a bot

**What this is for.** The checks a bot passes before anyone installs it, the install test, the release from its repository, and how to roll one back. Nothing here talks to an ab0t service.

**Before you start.** The bot folder complete per SOP 01. A checkout of the repository that holds it (your own, or `github.com/ab0t-com/bots`). A yes from whoever decides releases for that repository; a release is a person's decision, never automatic.

## Steps

**1. Structure.** From the root of the checkout (the folder that contains `<bot>/`):
```sh
B=<bot>
ls $B/00_index.md $B/agent.md $B/README.md $B/install.sh $B/GAPS.md $B/skills/*/SKILL.md
for f in $B/0[3-9]_*.md $B/1[0-9]_*.md; do for h in "What this is for" "Before you start" "## Steps" "## What you'll see" "## If it goes wrong" "## Coming" "## Next"; do grep -q "$h" "$f" || echo "$f: missing [$h]"; done; done
```
Troubleshooting tables and rules pages may lack Steps by design; everything else must have all seven.

**2. Honesty.** Every Coming has a Today; every GAPS row names an SOP that mentions it:
```sh
grep -n "^- \*\*" $B/*_sop_system_*.md | grep -A0 "Coming" >/dev/null; grep -L "Today" $B/*_sop_system_*.md | xargs -r grep -l "## Coming" || true
```
(Read the Coming sections by eye as well; a workaround of "none" is allowed when it is true.)

**3. Vocabulary and secrets.**
```sh
grep -rn -i "realm" $B | grep -v 'never "realm"'
grep -rn "cross_tenant\|cross_org" $B | grep -v "17_\|16_\|GAPS\|legacy\|details.required\|never"   # only quoted server strings and Coming rows may remain
grep -rnoE "ab0t_sk_(live|test)_[A-Za-z0-9]{20,}|sk_(live|test)_[A-Za-z0-9]{20,}|whsec_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{40,}" $B | grep -v xxxx
```
All three should print nothing (or only rule lines).

**4. Routing.** Every file the agent and the skill point at exists:
```sh
grep -o '[0-9][0-9]_sop_system_[a-z0-9_]*\.md' $B/agent.md $B/skills/*/SKILL.md $B/00_index.md | cut -d: -f2 | sort -u | while read f; do [ -f "$B/$f" ] || echo "missing: $f"; done
```

**4a. Commands exist.** If the bot ships a command lint (Ally: `authmesh/tests/sop_command_lint.sh <path-to-authsetup>`, documented in `authmesh/tests/README.md`), run it against the release the bot claims in its `VERSION`; it must print `0 offender(s)`. A bot for a CLI without one should get one: every command and flag shown, checked against the binary's own `--help`, with unbuilt verbs allowed only when `GAPS.md` lists them.

**4b. Manifest.** `bot.json` parses, every `sops` entry exists, every hand-off names a catalogued bot:
```sh
python3 -c "import json;json.load(open('$B/bot.json'))" && for f in $(python3 -c "import json;print(' '.join(json.load(open('$B/bot.json'))['sops']))"); do [ -f "$B/$f" ] || echo "manifest names missing file: $f"; done
```

**5. Installer.** `sh -n $B/install.sh && test -x $B/install.sh`. Then a real local install from the checkout into a scratch home, so nothing of yours is touched:
```sh
CLAUDE_HOME=/tmp/claude-test AB0T_BOTS_HOME=/tmp/bots-test sh $B/install.sh
ls -l /tmp/claude-test/agents /tmp/claude-test/skills | head
rm -rf /tmp/claude-test /tmp/bots-test
```

**6. Read it as the client.** Open `00_index.md`, then `02`, then one procedure SOP, as someone who has never seen the tool. Every command runnable as written? Every "What you'll see" something you have seen in source? Any sentence that needs your team's internals (private paths, issue numbers, internal names) to parse? Fix before shipping. Keep work logs and notes that are not for clients out of the folder you publish.

**7. Release.** Commit with a message naming the bot and the SOP numbers changed, and push to the branch your installer downloads (`REF`, default `main`). The install line is live the moment that branch has the file:
`https://raw.githubusercontent.com/<owner>/<repo>/main/<bot>/install.sh`. Test it from a clean shell into the scratch homes above, outside your checkout (piped into `sh`, the installer uses the current folder instead of downloading if that folder looks like the bot):
```sh
cd /tmp && curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/<bot>/install.sh | CLAUDE_HOME=/tmp/claude-test AB0T_BOTS_HOME=/tmp/bots-test sh
```
To try a branch before merging, add `REF=<branch>` (and `REPO=<owner>/<repo>` for a fork) beside the other two; the installers take a branch name, not a tag.

**8. Announce** in the catalogue. A bot in `github.com/ab0t-com/bots`: its `BOTS_WANTED.md` row → shipped, its `index.md` entry with the install line. A bot in your own repository: SOP 06 step 6.

## What you'll see

Steps 1–5 silent (no output) except the installer's `✓` lines. Step 5's scratch listing shows `agents/<name>.md -> …/agent.md` and one symlink per skill.

## If it goes wrong

- `missing [## Coming]`: a procedure SOP without an honesty ledger; add it even if it says "nothing we know of".
- A `realm` or legacy-name hit outside the allowed lines: rewrite the sentence; quote server output only inside backticks, with the sentence saying it is legacy.
- `missing: 12_sop_system_….md`: a routing table outran the files (renumber slipped). Fix from `00_index.md`.
- The installer links a skill the user already had as a real folder: by design it leaves it; tell them `FORCE=1`.
- A bad release: `git revert` the commit on the branch the installer downloads; installs keep `~/.ab0t/bots/<bot>.previous`, and `mv` restores it locally.
- Step 7's download says the tarball has no `<bot>` folder: the bot folder is not at the top level of the repository, or `REPO`/`REF` is wrong (SOP 06 step 4).

## Coming

- **`meta check <bot>`** doing steps 1–5 in one command with a pass/fail table. *Today:* the shell lines above.
- **A release workflow** (changelog, tags, installs pinned to a tag). *Today:* commit to the branch the installer downloads; the commit message is the changelog.
- **Install analytics-free telemetry of versions** (which bot version a client has). *Today:* none; `ls ~/.ab0t/bots`.

## Next

SOP 03 to keep it honest over time; SOP 06 if the bot is a customer's; SOP 08 to check its hand-offs and manifest.
