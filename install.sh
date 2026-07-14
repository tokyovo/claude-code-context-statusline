#!/bin/bash
#
# Installer for claude-code-context-statusline.
#
#   curl -fsSL https://raw.githubusercontent.com/tokyovo/claude-code-context-statusline/main/install.sh | bash
#
# Copies statusline.sh to ~/.claude/ and points settings.json at it.
# Any existing settings are preserved — only the "statusLine" key is touched,
# and a timestamped backup is taken first.

set -euo pipefail

RAW="https://raw.githubusercontent.com/tokyovo/claude-code-context-statusline/main/statusline.sh"
DEST="$HOME/.claude/statusline.sh"
SETTINGS="$HOME/.claude/settings.json"

echo "→ claude-code-context-statusline"

# --- prerequisites ------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "✗ jq is required but not installed."
  echo "  macOS:  brew install jq"
  echo "  Debian: sudo apt install jq"
  exit 1
fi

# --- fetch the script ---------------------------------------------------------
mkdir -p "$HOME/.claude"

if [ -f "./statusline.sh" ]; then
  cp ./statusline.sh "$DEST"           # running from a clone
else
  curl -fsSL "$RAW" -o "$DEST"          # running via curl | bash
fi
chmod +x "$DEST"
echo "✓ installed $DEST"

# --- wire it into settings.json -----------------------------------------------
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

if ! jq empty "$SETTINGS" 2>/dev/null; then
  echo "✗ $SETTINGS is not valid JSON. Fix it and re-run."
  exit 1
fi

BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"

if jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
  echo "! you already have a statusLine configured — replacing it"
  echo "  (previous settings backed up to $BACKUP)"
fi

TMP=$(mktemp)
jq '.statusLine = {"type":"command","command":"~/.claude/statusline.sh","padding":0}' \
  "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

echo "✓ configured $SETTINGS"

# --- show what it looks like ---------------------------------------------------
echo
echo "Preview:"
echo
echo '{"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"Opus 4.8"},"context_window":{"used_percentage":38}}' \
  | bash "$DEST"
echo
echo
echo "Restart Claude Code to see it. Uninstall any time with:"
echo "  jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/s && mv /tmp/s ~/.claude/settings.json"
