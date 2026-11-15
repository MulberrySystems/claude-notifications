#!/usr/bin/env python3
"""Claude Code hook: macOS notification via terminal-notifier; a click focuses the VS Code terminal.

Usage: claude-ping.py notification|stop   (hook JSON on stdin)
Title = the VS Code terminal tab title ("* <session name or generated title>"). A click runs
focus-terminal.py with the ancestor pids, CLAUDE_VSCODE_ROOT, the cwd and the title; it raises the
owning window and the claude-terminal-focus VS Code extension shows the terminal whose tab title
matches (sessions run in the Claude daemon, so pids only match when claude runs directly in the
shell).
Nothing is shown while a focused VS Code window has this session's terminal active (state from
~/.claude/vscode-windows.json, kept by the extension).
- notification: "Claude needs your attention in <folder> (<sid>)!" with the Glass sound.
- stop: nothing while a subagent or workflow of the session is still running (the main agent only
  paused to wait for it); otherwise "Prompt finished in <folder> (<sid>)" with the Glass sound.
Never raises.
"""
import json, os, re, subprocess, sys

FOCUS = os.path.expanduser("~/.claude/hooks/focus-terminal.py")
NOTIFIER = next((p for p in ("/opt/homebrew/bin/terminal-notifier", "/usr/local/bin/terminal-notifier") if os.path.exists(p)), "terminal-notifier")


def ancestors():
    """Pids from this process up to launchd: one of them is the terminal's shell."""
    pids, pid = [], os.getpid()
    for _ in range(15):
        pids.append(pid)
        try:
            out = subprocess.run(["ps", "-o", "ppid=", "-p", str(pid)], capture_output=True, text=True, timeout=5).stdout.strip()
        except Exception:
            break
        if not out.isdigit() or int(out) <= 1:
            break
        pid = int(out)
    return pids


WINDOWS = os.path.expanduser("~/.claude/vscode-windows.json")
GLYPH = re.compile(r"^[^\w]+", re.U)


def viewing(title):
    """True when a focused VS Code window has this session's terminal active."""
    norm = lambda s: re.sub(r"\s+", " ", GLYPH.sub("", s or "")).strip().lower()
    try:
        for pid, w in json.load(open(WINDOWS)).items():
            if not w.get("focused") or not w.get("active"):
                continue
            try:
                os.kill(int(pid), 0)
            except (OSError, ValueError):
                continue
            if norm(w["active"].get("name")) == norm(title):
                return True
    except (OSError, ValueError):
        pass
    return False


def notify(title, text, sound, cwd):
    """macOS notification; a click focuses the VS Code terminal of this session."""
    if viewing(title):
        return
    q = lambda a: "'" + a.replace("'", "'\\''") + "'"
    root = os.environ.get("CLAUDE_VSCODE_ROOT", "")
    execute = " ".join(["/usr/bin/python3", "-I", q(FOCUS), q(",".join(map(str, ancestors()))), q(root), q(cwd or ""), q(title)])
    try:
        subprocess.run([NOTIFIER, "-title", title, "-message", text, "-sound", sound,
                        "-execute", execute, "-group", f"claude-code-{os.getpid()}"],
                       capture_output=True, timeout=10)
    except Exception:
        pass


def display_title(name, sid, cwd, path):
    """The terminal tab title: the session name if the user chose one, else Claude's generated
    title. An auto name is <folder>-<short hex> (e.g. myapp-d1) or the bare session id prefix."""
    folder = os.path.basename((cwd or "").rstrip("/"))
    auto = name == sid[:8] or (bool(folder) and bool(re.fullmatch(re.escape(folder) + r"-[0-9a-f]{2,4}", name or "")))
    title = ""
    if auto:
        try:
            for line in open(path, encoding="utf-8", errors="replace"):
                if line.startswith('{"type":"ai-title"'):
                    try:
                        title = json.loads(line).get("aiTitle") or title
                    except ValueError:
                        pass
        except OSError:
            pass
    return "\u273b " + (title or name or sid[:8])


def session_name(sid):
    try:
        out = subprocess.run(["claude", "agents", "--json", "--all"], capture_output=True, text=True, timeout=15).stdout
        for s in json.loads(out):
            if s.get("sessionId") == sid and s.get("name"):
                return s["name"]
    except Exception:
        pass
    return sid[:8]


def agents_running(d):
    """True while a subagent or workflow of this session is still running: the main agent only
    paused to wait for it and resumes when it finishes, so this Stop is not the end of the prompt."""
    return any(t.get("status") == "running" and ("agent" in str(t.get("type")) or "workflow" in str(t.get("type")))
               for t in d.get("background_tasks") or [])


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "stop"
    try:
        d = json.load(sys.stdin)
    except ValueError:
        return
    sid = d.get("session_id", "")
    cwd = d.get("cwd") or ""
    folder = os.path.basename(cwd.rstrip("/"))
    where = f"{folder} ({sid[:8]})"
    name = session_name(sid)
    title = display_title(name, sid, cwd, d.get("transcript_path", ""))
    if mode == "notification":
        notify(title, f"Claude needs your attention in {where}!", "Glass", cwd)
        return
    if agents_running(d):
        return
    notify(title, f"Prompt finished in {where}", "Glass", cwd)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
