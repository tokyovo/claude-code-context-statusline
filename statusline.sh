#!/bin/bash
#
# A Claude Code status line that always shows how much of your context window you've used.
#
#   ~/code/my-project (main)
#   [Opus 4.8] ▓▓▓░░░░░░░ 38%
#
# Claude Code pipes a JSON blob to this script on stdin before each turn, and renders
# whatever it prints. The context numbers come pre-calculated in `.context_window` —
# no transcript parsing needed.
#
# Docs: https://docs.claude.com/en/docs/claude-code/statusline

set -uo pipefail

input=$(cat)

# --- config -------------------------------------------------------------------
WIDTH=${STATUSLINE_BAR_WIDTH:-10}   # characters in the bar
WARN=${STATUSLINE_WARN_AT:-70}      # % at which the bar turns amber
CRIT=${STATUSLINE_CRIT_AT:-85}      # % at which it turns red
SHOW_COST=${STATUSLINE_SHOW_COST:-0}  # set to 1 to append the session cost
# ------------------------------------------------------------------------------

DIR=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
MODEL=$(jq -r '.model.display_name // "?"' <<<"$input")
PCT=$(jq -r '.context_window.used_percentage // 0' <<<"$input" | cut -d. -f1)

# Guard against a missing/garbage percentage.
[[ "$PCT" =~ ^[0-9]+$ ]] || PCT=0

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

LINE2="${DIM}[${MODEL}]${RESET} ${C}${BAR}${RESET} ${PCT}%"

if [ "$SHOW_COST" = "1" ]; then
  COST=$(jq -r '.cost.total_cost_usd // 0' <<<"$input")
  LINE2+=$(printf "  %s\$%.2f%s" "$DIM" "$COST" "$RESET")
fi

printf "%s\n%s" \
  "${DIM}${SHORT_DIR}${BRANCH:+ (${BRANCH})}${RESET}" \
  "$LINE2"
