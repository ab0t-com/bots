#!/usr/bin/env sh
# =============================================================================
# Install one or more ab0t bots for Claude Code
# =============================================================================
#
#   curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/install.sh | sh -s -- authmesh billing-quota
#   curl -fsSL https://raw.githubusercontent.com/ab0t-com/bots/main/install.sh | sh -s -- all
#   ./install.sh authz                     # from a checkout
#
# It does one thing: for each named bot, run that bot's own install.sh (which downloads
# the bot folder, symlinks the agent and skills into ~/.claude, and prints next steps).
# With no arguments it lists the bots and exits. Nothing talks to any ab0t service.
#
# Knobs (passed through): REPO=ab0t-com/bots  REF=main  AB0T_BOTS_HOME=~/.ab0t/bots  CLAUDE_HOME=~/.claude  FORCE=1
# =============================================================================
set -eu

REPO="${REPO:-ab0t-com/bots}"
REF="${REF:-main}"
KNOWN="authmesh billing-quota authz uj meta"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [ "$#" -eq 0 ]; then
  say "ab0t bots — pick one or more:"
  say "  authmesh       Ally   put my service on the mesh (sign-in, permissions, login page, keys)"
  say "  billing-quota  Penny  meter it, limit it, charge for it"
  say "  authz          Zee    who may do what inside my app"
  say "  uj             Quinn  test my product the way users use it (user journeys, end-to-end, CI)"
  say "  meta           Meta   build a bot like these for my own service"
  say ""
  say "  sh install.sh authmesh billing-quota      # or: all"
  exit 0
fi

bots="$*"
[ "$bots" = "all" ] && bots="$KNOWN"

here="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
for b in $bots; do
  case " $KNOWN " in *" $b "*) ;; *) die "unknown bot '$b' (known: $KNOWN)";; esac
  say "=== $b"
  if [ -n "$here" ] && [ -x "$here/$b/install.sh" ]; then
    sh "$here/$b/install.sh"
  else
    command -v curl >/dev/null 2>&1 || die "curl is required"
    curl -fsSL "https://raw.githubusercontent.com/$REPO/$REF/$b/install.sh" | REPO="$REPO" REF="$REF" sh
  fi
  say ""
done
say "Installed: $bots. Start a new Claude Code session and say @agent-<name>."
