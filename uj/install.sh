#!/usr/bin/env sh
# =============================================================================
# Install Quinn (the uj test assistant: user journeys, end-to-end and API tests) for Claude Code
# =============================================================================
#
#   curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/uj/install.sh | sh
#
# What it does (and nothing else):
#   1. Downloads the bots repository tarball over HTTPS and extracts ONLY this bot's
#      folder to $AB0T_BOTS_HOME/uj (default ~/.ab0t/bots/uj).
#      If you run it from a checkout (./install.sh), it uses the folder you are in instead.
#   2. Symlinks the agent into ~/.claude/agents/quinn.md.
#   3. Symlinks the routing skill and its companion skills into ~/.claude/skills/<name>.
#      Existing skill folders you already have are left untouched. FORCE=1 replaces them, after
#      moving yours to $AB0T_BOTS_HOME/.skill-backups/<name>.<timestamp> (never deleted).
#   4. Prints what to do next. It does not install the uj tool itself (SOP 03 does), talks to no
#      service, and reads no credentials.
#
# Knobs:  REPO=ab0t-com/bots  REF=main  AB0T_BOTS_HOME=~/.ab0t/bots  CLAUDE_HOME=~/.claude  FORCE=1
# Re-running is safe: it refreshes the folder and re-points the links.
# Uninstall: remove ~/.claude/agents/quinn.md, the symlinks it printed, and the bot folder.
# =============================================================================
set -eu

BOT="uj"
AGENT="quinn"
ROUTING_SKILL="quinn-uj"
REPO="${REPO:-ab0t-com/bots}"
REF="${REF:-main}"
BOTS_HOME="${AB0T_BOTS_HOME:-$HOME/.ab0t/bots}"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
FORCE="${FORCE:-0}"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# ----- 1. get the bot folder -------------------------------------------------
here="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
if [ -n "$here" ] && [ -f "$here/agent.md" ] && [ -d "$here/skills/$ROUTING_SKILL" ]; then
  BOT_DIR="$here"
  say "→ using the checkout at $BOT_DIR"
else
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v tar  >/dev/null 2>&1 || die "tar is required"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  url="https://github.com/$REPO/archive/refs/heads/$REF.tar.gz"
  say "→ downloading $url"
  curl -fsSL "$url" -o "$tmp/bots.tar.gz"
  top="$(tar -tzf "$tmp/bots.tar.gz" | head -1 | cut -d/ -f1)"
  tar -xzf "$tmp/bots.tar.gz" -C "$tmp" "$top/$BOT" || die "the tarball has no '$BOT' folder (REPO/REF right?)"
  mkdir -p "$BOTS_HOME"
  rm -rf "$BOTS_HOME/$BOT.new"; mv "$tmp/$top/$BOT" "$BOTS_HOME/$BOT.new"
  rm -rf "$BOTS_HOME/$BOT.previous"
  [ -d "$BOTS_HOME/$BOT" ] && mv "$BOTS_HOME/$BOT" "$BOTS_HOME/$BOT.previous"
  mv "$BOTS_HOME/$BOT.new" "$BOTS_HOME/$BOT"
  BOT_DIR="$BOTS_HOME/$BOT"
  say "✓ installed to $BOT_DIR (previous copy kept as $BOT.previous)"
fi

# ----- 2. agent --------------------------------------------------------------
mkdir -p "$CLAUDE_HOME/agents" "$CLAUDE_HOME/skills"
ln -sfn "$BOT_DIR/agent.md" "$CLAUDE_HOME/agents/$AGENT.md"
say "✓ agent   $CLAUDE_HOME/agents/$AGENT.md → $BOT_DIR/agent.md"

# ----- 3. skills (routing skill first, then companions) ----------------------
link_skill() {
  name="$1"; src="$BOT_DIR/skills/$name"; dst="$CLAUDE_HOME/skills/$name"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    if [ "$FORCE" != "1" ]; then
      say "· skill   $name already present (not a symlink) — left as is; FORCE=1 to replace (your copy is kept)"
      return
    fi
    # FORCE=1 never deletes your own skill folder: it is moved aside first.
    bak="$BOTS_HOME/.skill-backups/$name.$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BOTS_HOME/.skill-backups"
    mv "$dst" "$bak"
    say "· skill   $name: your existing folder was moved to $bak"
  fi
  ln -sfn "$src" "$dst"
  say "✓ skill   $dst"
}
link_skill "$ROUTING_SKILL"
for d in "$BOT_DIR"/skills/*/; do
  n="$(basename "$d")"; [ "$n" = "$ROUTING_SKILL" ] && continue
  link_skill "$n"
done

# ----- 4. next ---------------------------------------------------------------
say ""
say "Done. Start a new Claude Code session and say:  @agent-$AGENT  (or: \"write a user journey for my sign-up flow\")"
say "Quinn drives the uj tool. If it is not installed yet, Quinn's SOP 03 does it with you, or:"
say "  curl -fsSL https://raw.githubusercontent.com/ab0t-com/uj/main/install.sh | sh   then: uj --version"
say "  (the public uj repository is coming soon; if that address is not live yet, check back shortly)"
say "Read first: $BOT_DIR/00_index.md"
