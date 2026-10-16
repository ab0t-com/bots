#!/usr/bin/env sh
# =============================================================================
# Install Meta (the bot that builds and keeps the ab0t mesh bots) for Claude Code
# =============================================================================
#
#   curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/meta/install.sh | sh
#
# What it does (and nothing else):
#   1. Downloads the bots repository tarball over HTTPS and extracts ONLY this bot's
#      folder to $AB0T_BOTS_HOME/meta (default ~/.ab0t/bots/meta).
#      If you run it from a checkout (./install.sh), it uses the folder you are in instead.
#   2. Symlinks the agent into ~/.claude/agents/meta.md.
#   3. Symlinks the routing skill and the method skills into ~/.claude/skills/<name>.
#      Existing skill folders you already have are left untouched. With FORCE=1 they are
#      replaced by the link and your folder is moved (never deleted) to
#      $AB0T_BOTS_HOME/.skill-backups/<name>.<timestamp>.
#   4. Prints what to do next. Nothing talks to any ab0t service; no credentials are read.
#
# Knobs:  REPO=ab0t-com/bots  REF=main  AB0T_BOTS_HOME=~/.ab0t/bots  CLAUDE_HOME=~/.claude  FORCE=1
# Re-running is safe: it refreshes the folder and re-points the links.
# Uninstall: remove ~/.claude/agents/meta.md, the symlinks it printed, and the bot folder.
# =============================================================================
set -eu

BOT="meta"
AGENT="meta"
ROUTING_SKILL="meta-bot-builder"
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

# ----- 3. skills -------------------------------------------------------------
link_skill() {
  name="$1"; src="$BOT_DIR/skills/$name"; dst="$CLAUDE_HOME/skills/$name"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    if [ "$FORCE" != "1" ]; then
      say "· skill   $name already present (not a symlink) — left as is; FORCE=1 to replace"
      return
    fi
    bak="$BOTS_HOME/.skill-backups/$name.$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BOTS_HOME/.skill-backups"; mv "$dst" "$bak"
    say "· skill   your $name moved aside to $bak"
  fi
  rm -f "$dst"; ln -sfn "$src" "$dst"
  say "✓ skill   $dst"
}
link_skill "$ROUTING_SKILL"
for d in "$BOT_DIR"/skills/*/; do
  n="$(basename "$d")"; [ "$n" = "$ROUTING_SKILL" ] && continue
  link_skill "$n"
done

# ----- 4. next ---------------------------------------------------------------
say ""
say "Done. Start a new Claude Code session and say:  @agent-$AGENT build a bot for <service>"
say "Meta hands product questions to the other bots; install them too:"
say "  curl -fsSL https://raw.githubusercontent.com/$REPO/$REF/install.sh | sh -s -- authmesh billing-quota authz uj"
say "Read first: $BOT_DIR/00_index.md"
