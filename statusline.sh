#!/bin/bash
#
# A Claude Code status line that always shows how much of your context window you've used.
#
#   [Opus 4.8] ▓▓▓░░░░░░░ 33% 334k/1M  ·  ~/code/my-project (main)
#
# Claude Code pipes a JSON blob to this script on stdin before each turn, and renders
# whatever it prints. The context numbers come pre-calculated in `.context_window` —
# no transcript parsing needed.
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

COST_STR=""
if [ "$SHOW_COST" = "1" ]; then
  COST=$(jq -r '.cost.total_cost_usd // 0' <<<"$input")
  COST_STR=$(printf '$%.2f' "$COST")
  LEFT+="  ${DIM}${COST_STR}${RESET}"
fi

# --- then: directory and branch -----------------------------------------------
# Deliberately NOT right-aligned. Claude Code clips the status line before the real
# terminal edge, so padding out to $COLUMNS gets the tail truncated ("…/personal (m…").
# Keeping everything left-packed means nothing is ever cut.
RIGHT_PLAIN="${SHORT_DIR}${BRANCH:+ (${BRANCH})}"

printf '%s%s' "$LEFT" "${RIGHT_PLAIN:+  ${DIM}·  ${RIGHT_PLAIN}${RESET}}"
