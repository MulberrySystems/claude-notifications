#!/bin/bash
# Undo install.sh: remove the hooks, their settings.json entries, the VS Code extension and the
# state files it keeps. Homebrew's terminal-notifier is left in place (brew uninstall terminal-notifier).
set -euo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CODE="$(command -v code || true)"
[ -n "$CODE" ] || CODE="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

echo "1/3 hooks"
rm -f "$CLAUDE_DIR/hooks/claude-ping.py" "$CLAUDE_DIR/hooks/focus-terminal.py"
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  python3 - "$CLAUDE_DIR/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
s = json.load(open(path))
hooks = s.get("hooks", {})
for event in ("Notification", "Stop"):
    lst = [x for x in hooks.get(event, []) if "claude-ping.py" not in json.dumps(x)]
    if lst:
        hooks[event] = lst
    else:
        hooks.pop(event, None)
if not hooks:
    s.pop("hooks", None)
json.dump(s, open(path, "w"), indent=2)
open(path, "a").write("\n")
PY
fi

echo "2/3 VS Code extension"
if [ -x "$CODE" ]; then
  "$CODE" --uninstall-extension mulberrysystems.claude-terminal-focus 2>&1 | grep -v -i "deprecation" || true
fi

echo "3/3 state files"
rm -f "$CLAUDE_DIR/vscode-windows.json" "$CLAUDE_DIR/terminal-focus-request.json" "$CLAUDE_DIR/terminal-focus.log"

echo "Done. Reload open VS Code windows (Developer: Reload Window) to unload the extension."
