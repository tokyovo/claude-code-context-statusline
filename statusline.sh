#!/bin/bash
#
# A Claude Code status line that always shows how much of your context window you've used.
#
#   [Opus 4.8] ▓▓▓░░░░░░░ 38%                              ~/code/my-project (main)
#
# Claude Code pipes a JSON blob to this script on stdin before each turn, and renders
# whatever it prints. The context numbers come pre-calculated in `.context_window` —
# no transcript parsing needed. Terminal width arrives as $COLUMNS.
#
# Docs: https://docs.claude.com/en/docs/claude-code/statusline

set -uo pipefail

input=$(cat)

# --- config -------------------------------------------------------------------
WIDTH=${STATUSLINE_BAR_WIDTH:-10}     # characters in the bar
WARN=${STATUSLINE_WARN_AT:-70}        # % at which the bar turns amber
CRIT=${STATUSLINE_CRIT_AT:-85}        # % at which it turns red
SHOW_COST=${STATUSLINE_SHOW_COST:-0}  # 1 to append the session cost
# ------------------------------------------------------------------------------

DIR=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
MODEL=$(jq -r '.model.display_name // "?"' <<<"$input")
PCT=$(jq -r '.context_window.used_percentage // 0' <<<"$input" | cut -d. -f1)
USED=$(jq -r '.context_window.total_input_tokens // 0' <<<"$input" | cut -d. -f1)
MAX=$(jq -r '.context_window.context_window_size // 0' <<<"$input" | cut -d. -f1)

[[ "$PCT"  =~ ^[0-9]+$ ]] || PCT=0
[[ "$USED" =~ ^[0-9]+$ ]] || USED=0
[[ "$MAX"  =~ ^[0-9]+$ ]] || MAX=0

# 384102 -> 384k · 1000000 -> 1M · 200000 -> 200k
human() {
  local n=$1
  if   [ "$n" -ge 1000000 ]; then
    if [ $(( n % 1000000 )) -eq 0 ]; then printf '%dM' $(( n / 1000000 ))
    else printf '%d.%dM' $(( n / 1000000 )) $(( (n % 1000000) / 100000 )); fi
  elif [ "$n" -ge 1000 ]; then printf '%dk' $(( n / 1000 ))
  else printf '%d' "$n"
  fi
}

# Show ~/foo rather than /home/you/foo
TILDE='~'
SHORT_DIR="${DIR/#$HOME/$TILDE}"
BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)

# Colour the bar by how close auto-compact is.
if   [ "$PCT" -ge "$CRIT" ]; then C=$'\033[31m'   # red
elif [ "$PCT" -ge "$WARN" ]; then C=$'\033[33m'   # amber
else                             C=$'\033[32m'    # green
fi
DIM=$'\033[2m'
RESET=$'\033[0m'

FILLED=$(( PCT * WIDTH / 100 ))
[ "$FILLED" -gt "$WIDTH" ] && FILLED=$WIDTH
BAR=""
for ((i = 0; i < WIDTH; i++)); do
  if [ "$i" -lt "$FILLED" ]; then BAR+="▓"; else BAR+="░"; fi
done

# --- left: model, bar, percentage, tokens --------------------------------------
TOKENS=""
if [ "$MAX" -gt 0 ]; then
  TOKENS="$(human "$USED")/$(human "$MAX")"
fi

LEFT="${DIM}[${MODEL}]${RESET} ${C}${BAR}${RESET} ${PCT}%${TOKENS:+ ${DIM}${TOKENS}${RESET}}"
# Measured, not derived from the string, so multi-byte bar glyphs can't skew it.
LEFT_LEN=$(( ${#MODEL} + 2 + 1 + WIDTH + 1 + ${#PCT} + 1 ))
[ -n "$TOKENS" ] && LEFT_LEN=$(( LEFT_LEN + 1 + ${#TOKENS} ))

COST_STR=""
if [ "$SHOW_COST" = "1" ]; then
  COST=$(jq -r '.cost.total_cost_usd // 0' <<<"$input")
  COST_STR=$(printf '$%.2f' "$COST")
  LEFT+="  ${DIM}${COST_STR}${RESET}"
  LEFT_LEN=$(( LEFT_LEN + 2 + ${#COST_STR} ))
fi

# --- right: directory and branch, flushed to the right edge --------------------
RIGHT_PLAIN="${SHORT_DIR}${BRANCH:+ (${BRANCH})}"
RIGHT="${DIM}${RIGHT_PLAIN}${RESET}"

# Claude Code exports COLUMNS; tput is the fallback, then a sane default.
COLS=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
[[ "$COLS" =~ ^[0-9]+$ ]] || COLS=80

GAP=$(( COLS - LEFT_LEN - ${#RIGHT_PLAIN} - 1 ))

if [ "$GAP" -ge 2 ]; then
  printf '%s%*s%s' "$LEFT" "$GAP" "" "$RIGHT"
else
  # Too narrow to right-align — drop the path rather than wrap onto a second line.
  printf '%s' "$LEFT"
fi
