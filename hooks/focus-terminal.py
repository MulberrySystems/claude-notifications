#!/usr/bin/env python3
"""Run by terminal-notifier when a Claude Code notification is clicked.
Usage: focus-terminal.py <pids,csv> <root> <cwd> <terminal title>
The window is found in ~/.claude/vscode-windows.json (written by the claude-terminal-focus
extension): first by a terminal shell pid among <pids>, then by <root> (CLAUDE_VSCODE_ROOT from
the terminal env), then by the folder that contains <cwd>. `code <root>` raises the window that
already has it open, then the extension URI focuses the terminal owning one of the pids. The
request file is the extension's fallback."""
import json, os, subprocess, sys, time, urllib.parse

CODE = next((p for p in ("/usr/local/bin/code", "/opt/homebrew/bin/code", "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code") if os.path.exists(p)), "code")
REQUEST = os.path.expanduser("~/.claude/terminal-focus-request.json")
WINDOWS = os.path.expanduser("~/.claude/vscode-windows.json")

arg = lambda i: sys.argv[i] if len(sys.argv) > i else ""
pids = [int(p) for p in arg(1).split(",") if p.strip().isdigit()]
root_arg, cwd, name = arg(2), arg(3), arg(4)
try:
    json.dump({"pids": pids, "name": name, "ts": int(time.time() * 1000)}, open(REQUEST, "w"))
except OSError:
    pass
try:
    windows = list(json.load(open(WINDOWS)).values())
except (OSError, ValueError):
    windows = []
root = ""
# 1. the window whose terminal shell is an ancestor of the hook
for w in windows:
    if w.get("root") and set(w.get("pids") or []) & set(pids):
        root = w["root"]
        break
# 2. CLAUDE_VSCODE_ROOT from the terminal env, if it is a known window
if not root and root_arg and any(w.get("root") == root_arg for w in windows):
    root = root_arg
# 3. the window whose folder contains the session cwd (longest match)
if not root and cwd:
    best = ""
    for w in windows:
        for f in w.get("folders") or []:
            if (cwd == f or cwd.startswith(f.rstrip("/") + "/")) and len(f) > len(best) and w.get("root"):
                best, root = f, w["root"]
if root and os.path.exists(root):
    subprocess.run([CODE, root], capture_output=True, timeout=15)
    time.sleep(0.5)
q = urllib.parse.urlencode({"pids": ",".join(map(str, pids)), "name": name})
subprocess.run([CODE, "--open-url", f"vscode://mulberrysystems.claude-terminal-focus/focus?{q}"], capture_output=True, timeout=15)
