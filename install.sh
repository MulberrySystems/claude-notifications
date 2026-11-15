#!/bin/bash
# Set up Claude Code macOS notifications with click-to-focus of the VS Code terminal.
#
# Installs: terminal-notifier (brew), ~/.claude/hooks/claude-ping.py and focus-terminal.py,
# the claude-terminal-focus VS Code extension, and the Notification/Stop hooks in
# ~/.claude/settings.json (other settings are kept).
# Usage: ./install.sh            from this folder, on the Mac to set up. Undo with ./uninstall.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

[ "$(uname)" = Darwin ] || { echo "macOS only"; exit 1; }
command -v brew >/dev/null || { echo "Homebrew missing: https://brew.sh"; exit 1; }
CODE="$(command -v code || true)"
[ -n "$CODE" ] || CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
[ -x "$CODE" ] || { echo "VS Code 'code' CLI missing: in VS Code run 'Shell Command: Install code command in PATH'"; exit 1; }

echo "1/5 terminal-notifier"
command -v terminal-notifier >/dev/null || brew install terminal-notifier

echo "2/5 hooks -> $CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/hooks"
cp "$HERE/hooks/claude-ping.py" "$HERE/hooks/focus-terminal.py" "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/"*.py

echo "3/5 VS Code extension"
TMP="$(mktemp -d)"
VERSION="$(python3 -c "import json;print(json.load(open('$HERE/vscode-extension/extension/package.json'))['version'])")"
( cd "$HERE/vscode-extension" && python3 - "$TMP/claude-terminal-focus-$VERSION.vsix" <<'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED)
for n in ["[Content_Types].xml", "extension.vsixmanifest", "extension/package.json", "extension/extension.js"]:
    z.write(n, n)
z.close()
PY
)
"$CODE" --install-extension "$TMP/claude-terminal-focus-$VERSION.vsix" --force 2>&1 | grep -v -i "deprecation" || true
rm -rf "$TMP"

echo "4/5 hooks in $CLAUDE_DIR/settings.json"
python3 - "$CLAUDE_DIR/settings.json" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    s = json.load(open(path))
except (OSError, ValueError):
    s = {}
hooks = s.setdefault("hooks", {})
def entry(mode, matcher=None):
    e = {"hooks": [{"type": "command", "command": f'python3 -I "$HOME/.claude/hooks/claude-ping.py" {mode}',
                    "timeout": 30, "async": True}]}
    if matcher:
        e["matcher"] = matcher
    return e
for event, mode, matcher in (("Notification", "notification", "permission_prompt|elicitation_dialog|idle_prompt|elicitation_url_dialog"),
                             ("Stop", "stop", None)):
    lst = [x for x in hooks.get(event, []) if "claude-ping.py" not in json.dumps(x)]
    lst.append(entry(mode, matcher))
    hooks[event] = lst
json.dump(s, open(path, "w"), indent=2)
open(path, "a").write("\n")
PY

echo "5/5 notification permission"
if ! terminal-notifier -title "Claude Code" -message "Notifications set up" -sound Glass >/dev/null 2>&1; then
  APP="$(ls -d "$(brew --prefix)"/Cellar/terminal-notifier/*/terminal-notifier.app | tail -1)"
  open "$APP" || true
  cat <<MSG

macOS has not allowed notifications for terminal-notifier yet.
Open System Settings > Notifications > terminal-notifier and turn on Allow Notifications,
then run:  terminal-notifier -title test -message ok
MSG
fi

cat <<MSG

Done. In every open VS Code window run "Developer: Reload Window" so the extension loads.
Review the hooks with /hooks in Claude Code. Debug log: $CLAUDE_DIR/terminal-focus.log
MSG
