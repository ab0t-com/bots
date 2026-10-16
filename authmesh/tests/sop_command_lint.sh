#!/usr/bin/env bash
# =============================================================================
# sop_command_lint.sh — every `authsetup …` command Ally shows must exist
# =============================================================================
#
# What it checks
#   Reads every `authsetup …` command shown in Ally's pages (fenced code blocks and
#   `inline code` in the SOPs, agent.md, the ally-mesh-client skill and the bundled
#   authsetup-cli skill) and checks, against a real binary's own help text:
#     1. the command exists            (the binary's "unknown command … try: …" list)
#     2. a sub-command exists          (skills / connection / snippet: listed in `<cmd> --help`)
#     3. every flag exists for it      (a global flag from `authsetup --help` KEY FLAGS, or
#                                       named in `authsetup <cmd> --help`, or the binary's flag
#                                       table says the flag is for that command)
#     4. a command the binary lacks is allowed only if GAPS.md names it (a **Coming** verb);
#        otherwise it is an offender — so Coming items and GAPS.md stay in sync
#     5. (opt-in, REQUIRE_TARGET=1) every runnable command in a code block that depends on the
#        environment carries --env or --base-url (local-only commands and --help are exempt)
#   A command is `authsetup` at the start of a code span / code line, or after $ $( && || | ; :
#   (optionally after VAR=value). "authsetup" mid-sentence, as in a quoted message ("so authsetup
#   sent nothing there"), is prose and is skipped. Placeholders are skipped on purpose:
#   `authsetup <command> --help`, `authsetup …`, `authsetup [global flags] <command>`, and version
#   strings such as `authsetup 0.5.24`. It checks that commands and flags EXIST; it does not check
#   quoted message wording (that is a human review against the release's migration kit).
#
# Usage
#   tests/sop_command_lint.sh                         # uses `authsetup` on PATH, default files
#   tests/sop_command_lint.sh /path/to/authsetup      # a specific binary
#   tests/sop_command_lint.sh /path/to/authsetup file.md other.md   # specific files only
#   ALL_SKILLS=1 tests/sop_command_lint.sh ./authsetup               # also every companion skill
#   REQUIRE_TARGET=1 tests/sop_command_lint.sh ./authsetup           # also demand --env on code-block commands
#   VERBOSE=1 …                                       # print every command checked
#
# Requirements: bash 4+, awk, grep, sed. Read-only. It runs only `<binary> version`,
#   `<binary> --help`, `<binary> <cmd> --help` and `<binary> <unknown-command>` (all local; no
#   server is contacted, no credentials are read).
#
# Output / exit
#   Offenders as `file:line: authsetup <command…>  →  <reason>`, then a summary.
#   exit 0 = no offenders · exit 1 = offenders found · exit 2 = bad binary / usage.
# =============================================================================
set -u

BIN="${1:-authsetup}"
[ "$#" -gt 0 ] && shift

here="$(cd "$(dirname "$0")" && pwd)"
BOT="$(cd "$here/.." && pwd)"

if ! command -v "$BIN" >/dev/null 2>&1 && [ ! -x "$BIN" ]; then
  echo "error: authsetup binary not found: $BIN (pass its path as the first argument)" >&2
  exit 2
fi
VERSION_OUT="$("$BIN" version 2>&1 | head -1)"
case "$VERSION_OUT" in
  authsetup\ *) ;;
  *) echo "error: $BIN does not look like authsetup (version said: $VERSION_OUT)" >&2; exit 2 ;;
esac

# ----- files ------------------------------------------------------------------
files=()
if [ "$#" -gt 0 ]; then
  files=("$@")
else
  for f in "$BOT"/*.md "$BOT"/skills/ally-mesh-client/SKILL.md; do [ -f "$f" ] && files+=("$f"); done
  while IFS= read -r f; do files+=("$f"); done < <(find "$BOT/skills/authsetup-cli" -name '*.md' 2>/dev/null | sort)
  if [ "${ALL_SKILLS:-0}" = "1" ]; then
    while IFS= read -r f; do
      case "$f" in */ally-mesh-client/*|*/authsetup-cli/*) continue ;; esac
      files+=("$f")
    done < <(find "$BOT/skills" -name '*.md' 2>/dev/null | sort)
  fi
fi

# ----- what the binary says it has ----------------------------------------------
TOP_HELP="$("$BIN" --help 2>&1)"

# valid commands: the binary's own "unknown command … — try: a, b, c (or `authsetup help`)" list
probe="$("$BIN" __sop_lint_no_such_command__ 2>&1)"
cmd_list="$(printf '%s\n' "$probe" | sed -n 's/.*try: \(.*\) (or .*/\1/p' | tr -d ',')"
if [ -z "$cmd_list" ]; then   # fallback: the COMMANDS section of --help
  cmd_list="$(printf '%s\n' "$TOP_HELP" | awk '/^COMMANDS/{f=1;next} /^[A-Z]/{f=0} f && /^  [a-z]/{print $1}')"
fi
declare -A VALID_CMD=()
for c in $cmd_list help; do VALID_CMD["$c"]=1; done

# global flags: the KEY FLAGS section (they go before the command and apply to every command)
declare -A GLOBAL_FLAG=([help]=1 [h]=1 [version]=1)
while read -r fl; do [ -n "$fl" ] && GLOBAL_FLAG["$fl"]=1; done < <(
  printf '%s\n' "$TOP_HELP" | awk '/^KEY FLAGS/{f=1;next} /^[A-Z]/{f=0} f && /^  --[a-z]/{sub(/^--/,"",$1); print $1}')

# flag table (ALL FLAGS): which flags take a value, and the description naming their commands
declare -A FLAG_TAKES_VALUE=() FLAG_DESC=()
while IFS=$'\t' read -r name kind desc; do
  [ -z "$name" ] && continue
  FLAG_TAKES_VALUE["$name"]="$kind"
  FLAG_DESC["$name"]="$desc"
done < <(printf '%s\n' "$TOP_HELP" | awk '
  /^ALL FLAGS/{f=1;next}
  f && /^  -[a-z]/ { if (name!="") print name "\t" kind "\t" desc
                    name=$1; sub(/^-+/,"",name); kind=(NF>=2)?"1":"0"; desc=""; next }
  f && /^    / { d=$0; gsub(/^[[:space:]]+/,"",d); desc=desc " " d; next }
  END { if (name!="") print name "\t" kind "\t" desc }')

declare -A CMD_HELP=()
cmd_help() {  # cached `<bin> <cmd> --help`
  local c="$1"
  if [ -z "${CMD_HELP[$c]+x}" ]; then CMD_HELP["$c"]="$("$BIN" "$c" --help 2>&1)"; fi
  printf '%s' "${CMD_HELP[$c]}"
}

flag_ok() {  # flag_ok <cmd> <flag-name>
  local c="$1" fl="$2"
  [ -n "${GLOBAL_FLAG[$fl]+x}" ] && return 0
  [ -z "$c" ] && return 1
  cmd_help "$c" | grep -qE -- "(^|[^a-z-])--?${fl}([^a-z0-9-]|$)" && return 0
  if [ -n "${FLAG_DESC[$fl]+x}" ]; then
    printf '%s' "${FLAG_DESC[$fl]}" | grep -qE "(^|[^a-z-])${c}([^a-z-]|$)" && return 0
  fi
  return 1
}

# ----- extract commands: "file<TAB>line<TAB>args after 'authsetup'" ---------------
extract() {
  awk -v FILE="$1" '
    # A command starts a span/line, or follows $ $( && || | ; : (optionally after VAR=value
    # assignments). "authsetup" in the middle of a sentence (a quoted message such as
    # "so authsetup sent nothing there") is prose, not a command.
    function command_context(pre) {
      sub(/[[:space:]]+$/, "", pre)
      while (match(pre, /(^|[[:space:]])[A-Z_][A-Z0-9_]*=[^[:space:]]*$/)) {
        pre = substr(pre, 1, RSTART); sub(/[[:space:]]+$/, "", pre)
      }
      return (pre == "" || pre ~ /(\$|\$\(|&&|\|\||\||;|:)$/)
    }
    function emit(ln, kind, seg,   s, i, rest, cut, m, pre) {
      gsub(/"[^"]*"/, "Q", seg); gsub(/\047[^\047]*\047/, "Q", seg)    # quoted strings → one token
      s = " " seg
      while (match(s, /[^A-Za-z0-9_.\/-]authsetup( |$)/)) {
        pre = substr(s, 1, RSTART)
        rest = substr(s, RSTART + RLENGTH)
        if (!command_context(pre)) { s = " " rest; if (length(s) <= 1) break; continue }
        cut = length(rest) + 1
        if ((m = index(rest, "#"))  && m < cut) cut = m
        if ((m = index(rest, "|"))  && m < cut) cut = m
        if ((m = index(rest, "&&")) && m < cut) cut = m
        if ((m = index(rest, ";"))  && m < cut) cut = m
        if ((m = index(rest, ")"))  && m < cut) cut = m
        if ((m = index(rest, " >")) && m < cut) cut = m
        if ((m = index(rest, "→"))  && m < cut) cut = m
        print FILE "\t" ln "\t" kind "\t" substr(rest, 1, cut - 1)
        s = substr(rest, 1)
        s = " " s
        if (length(s) <= 1) break
      }
    }
    /^[[:space:]]*```/ { fence = !fence; next }
    {
      if (fence) {
        start = FNR; line = $0
        while (line ~ /\\[[:space:]]*$/ && (getline nxt) > 0) { sub(/\\[[:space:]]*$/, " ", line); line = line nxt }
        emit(start, "block", line)
      } else {
        n = split($0, parts, "`")
        for (i = 2; i <= n; i += 2) emit(FNR, "inline", parts[i])
      }
    }' "$1"
}

# ----- Coming verbs: a command the binary lacks is allowed only if GAPS.md lists it ----
declare -A COMING=()
if [ -f "$BOT/GAPS.md" ]; then
  while IFS=$'\t' read -r _ _ _ args; do
    c="${args%% *}"; c="${c## }"
    [ -n "$c" ] && [ -z "${VALID_CMD[$c]+x}" ] && COMING["$c"]=1
  done < <(extract "$BOT/GAPS.md")
fi

# ----- check -------------------------------------------------------------------
offenders=0; checked=0; coming_seen=0
SUBCMD_CMDS=" skills connection snippet "
# commands that never read an environment (no server, no per-env credentials)
LOCAL_ONLY_CMDS=" validate init update skills version accounts env use-env help "

for f in "${files[@]}"; do
  [ -f "$f" ] || { echo "warning: no such file: $f" >&2; continue; }
  while IFS=$'\t' read -r file ln kind args; do
    # shellcheck disable=SC2206
    toks=($args)
    [ "${#toks[@]}" -eq 0 ] && continue
    cmd=""; sub=""; problems=(); skip_value=0; placeholder=0
    for t in "${toks[@]}"; do
      if [ "$skip_value" = "1" ]; then skip_value=0; continue; fi
      case "$t" in
        --*|-[a-z]*)
          name="${t#-}"; name="${name#-}"; hasval=0
          case "$name" in *=*) name="${name%%=*}"; hasval=1 ;; esac
          case "$name" in ""|*[!a-z0-9-]*) continue ;; esac     # `--` or prose like -->
          [ "$hasval" = "0" ] && [ "${FLAG_TAKES_VALUE[$name]:-0}" = "1" ] && skip_value=1
          problems+=("flag:$name")
          ;;
        *)
          if [ -z "$cmd" ]; then
            case "$t" in
              [!a-z]*|Q) placeholder=1; break ;;   # <command>, [flags], …, $VAR, 0.5.24, >= v0.5.1
            esac
            cmd="$t"
          elif [ -z "$sub" ] && [[ "$SUBCMD_CMDS" == *" $cmd "* ]]; then
            sub="$t"
          fi
          ;;
      esac
    done
    [ "$placeholder" = "1" ] && continue
    [ -z "$cmd" ] && [ "${#problems[@]}" -eq 0 ] && continue
    checked=$((checked + 1))
    [ "${VERBOSE:-0}" = "1" ] && echo "  check $file:$ln: authsetup $args"
    reasons=()
    if [ -n "$cmd" ] && [ -z "${VALID_CMD[$cmd]+x}" ]; then
      if [ -n "${COMING[$cmd]+x}" ]; then
        coming_seen=$((coming_seen + 1)); checked=$((checked - 1)); continue   # a Coming verb, listed in GAPS.md
      fi
      reasons+=("unknown command \"$cmd\" (not in this binary — if it is not built yet, mark it Coming and list it in GAPS.md)")
    else
      if [ -n "$sub" ]; then
        case "$sub" in \<*|\[*|…*|Q) ;; *)
          cmd_help "$cmd" | grep -qE "(^|[^a-z-])${sub}([^a-z-]|$)" || reasons+=("\"$cmd $sub\" is not in \`authsetup $cmd --help\`") ;;
        esac
      fi
      for p in "${problems[@]}"; do
        fl="${p#flag:}"
        flag_ok "$cmd" "$fl" || reasons+=("--$fl is not a flag of \`${cmd:-authsetup}\`")
      done
      # REQUIRE_TARGET=1: a runnable command (in a code block) that depends on the environment
      # must say which one. Inline mentions of a command by name are prose, not instructions.
      if [ "${REQUIRE_TARGET:-0}" = "1" ] && [ "$kind" = "block" ] && [ -n "$cmd" ] \
         && [[ "$LOCAL_ONLY_CMDS" != *" $cmd "* ]] && [[ " ${problems[*]} " != *" flag:help "* ]] \
         && [[ " ${problems[*]} " != *" flag:env "* ]] && [[ " ${problems[*]} " != *" flag:base-url "* ]]; then
        reasons+=("no --env / --base-url (this command depends on the environment — without one it targets prod)")
      fi
    fi
    if [ "${#reasons[@]}" -gt 0 ]; then
      offenders=$((offenders + 1))
      rel="${file#"$BOT"/}"
      printf '%s:%s: authsetup %s  →  %s\n' "$rel" "$ln" "$args" "$(IFS=';'; echo "${reasons[*]}" | sed 's/;/; /g')"
    fi
  done < <(extract "$f")
done

echo "sop_command_lint: $VERSION_OUT · ${#files[@]} file(s) · $checked command(s) checked · $coming_seen Coming (in GAPS.md) · $offenders offender(s)"
echo
echo "NEXT —"
if [ "$offenders" -eq 0 ]; then
  echo "  REQUIRE_TARGET=1 $0 $BIN      # also demand --env on every runnable command"
  echo "  WHY: every command and flag Ally shows exists in $VERSION_OUT; after the next release, run this against the new binary"
  echo "       and bump VERSION + bot.json verified_against once it is clean."
  exit 0
fi
echo "  fix each line above in the named file (rename the flag/command to what \`$BIN <cmd> --help\` shows,"
echo "  or mark an unbuilt verb Coming and add it to GAPS.md), then re-run: $0 $BIN"
echo "  WHY: a client who copies a command the binary does not have gets an error instead of help."
exit 1
