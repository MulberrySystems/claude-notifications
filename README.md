# Claude Code notifications with click-to-focus

[![CI](https://github.com/MulberrySystems/claude-notifications/actions/workflows/ci.yml/badge.svg)](https://github.com/MulberrySystems/claude-notifications/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-lightgrey)

A macOS notification when a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) session
needs your input or finishes a turn. **Click it and VS Code jumps to the exact terminal that runs
that session**, even with several windows and a dozen tabs open.

<p align="center"><img src="docs/examples/banner-meme-man.png" width="560" alt="macOS banner: ✻ Git user identity, Prompt finished in claude-notifications, with a Meme Man image on the right"></p>

- Titled with the terminal tab title, so you know which session it is before you look.
- Carries an image you choose per repository, with a global default, so you can tell projects
  apart at a glance. See [Notification images](#notification-images).
- Silent while you are already looking at that terminal in a focused VS Code window.
- Silent when a turn only pauses to wait for a subagent or workflow; you hear from it once the
  main agent is really done.
- Two small Python hooks, one 110-line VS Code extension, no dependencies beyond
  [terminal-notifier](https://github.com/julienXX/terminal-notifier).

## Requirements

- macOS (uses terminal-notifier and the `code` CLI; the hooks are not portable to Linux or Windows)
- [Homebrew](https://brew.sh)
- VS Code with the `code` command on your PATH (`Shell Command: Install 'code' command in PATH`)
- Claude Code running inside a VS Code integrated terminal

## Install

```bash
git clone https://github.com/MulberrySystems/claude-notifications.git
cd claude-notifications
./install.sh
```

The script installs terminal-notifier, copies the hooks to `~/.claude/hooks/`, builds and installs
the VS Code extension, and adds `Notification` and `Stop` hooks to `~/.claude/settings.json`
without touching your other settings.

Then, once:

1. Allow notifications for **terminal-notifier** in System Settings > Notifications. The script
   opens the app so it appears in the list.
2. Run `Developer: Reload Window` in every open VS Code window so the extension loads.

To check, run `/hooks` in Claude Code and start a turn; you should get a notification when it ends.

## Notification images

Every notification can carry an image on the right of the banner, chosen per repository, so you
can tell projects apart at a glance. Two banners from the same machine:

| Example 1: this repo's own image | Example 2: the global default |
|:---:|:---:|
| <img src="docs/examples/banner-meme-man.png" width="380" alt="banner with Meme Man"> | <img src="docs/examples/banner-pixel-creature.png" width="380" alt="banner with a pixel creature"> |

Example 2 uses [`docs/examples/pixel-creature.png`](docs/examples/pixel-creature.png) installed
as `~/.claude/notification.png`, so every project on the machine gets the creature unless it
brings its own. Example 1 is this repo overriding that with its own `.claude/notification.png`.

**Per repository.** Put the image at `.claude/notification.png` (or `.jpg`, `.jpeg`, `.gif`) in
the repo. Sessions started anywhere inside that repo use it:

```bash
mkdir -p .claude
cp /path/to/your-image.png .claude/notification.png
```

**Default for everything else.** Put one at `~/.claude/notification.png`. Any session whose
project has no image of its own falls back to it:

```bash
cp /path/to/your-image.png ~/.claude/notification.png
```

**How the lookup works.** The hook walks from the session folder upwards and takes the first
`.claude/notification.*` it finds, so a repo inside a bigger workspace can have its own image
while the workspace sets one for the rest, and the home folder's `.claude` is the last stop.
No file anywhere means a banner without an image. Changes take effect on the next notification;
nothing needs restarting. Square images around 256 to 512 px look best; WebP is not accepted by
macOS, convert it first with `sips -s format png in.webp --out notification.png`.

The icon on the left is a different matter: macOS always takes it from the sending app bundle,
and it cannot be set per notification.

## Uninstall

```bash
./uninstall.sh
```

Removes the hooks, their `settings.json` entries, the extension and its state files. It leaves
Homebrew's terminal-notifier in place.

## How it works

```
Claude Code ──hook──▶ claude-ping.py ──▶ terminal-notifier ──click──▶ focus-terminal.py
                           ▲                                               │
                           │ reads                                         │ code <root>
                           │                                               ▼
                 ~/.claude/vscode-windows.json ◀──writes── VS Code extension ──▶ terminal.show()
```

- **`hooks/claude-ping.py`** runs on the `Notification` and `Stop` hook events. It builds the
  title from the session name (`claude agents --json`) or Claude's generated title in the
  transcript, checks whether you are already viewing that terminal, and calls terminal-notifier
  with `focus-terminal.py` as the click action.
- **`hooks/focus-terminal.py`** runs on click. It looks up the owning window in
  `~/.claude/vscode-windows.json`, raises it with `code <root>` (the `.code-workspace` file or the
  first folder, so VS Code reuses the window instead of opening a new one) and asks the extension
  to show the terminal.
- **`vscode-extension/`** is the companion extension (`mulberrysystems.claude-terminal-focus`).
  Every window records its root, folders, terminals, focus state and active terminal in
  `vscode-windows.json`. On a focus request it shows the terminal whose tab title matches,
  ignoring Claude Code's leading spinner glyph. It is installed from a locally built VSIX and is
  not on the Marketplace.

Sessions normally run inside the Claude daemon rather than directly in the shell, so the terminal
is matched by tab title; shell pids are tried first as a fast path.

## Troubleshooting

Debug log: `~/.claude/terminal-focus.log` (written by the extension and the click script).

- **No notification at all.** Run `terminal-notifier -title test -message ok`. If nothing shows,
  notifications for terminal-notifier are off in System Settings. Note that
  `brew upgrade terminal-notifier` resets that permission.
- **Notification shows but the click opens a new window.** The extension is not loaded in the
  window that owns the session. Reload the window; a freshly installed or updated extension is
  not picked up by windows that were already open.
- **Click raises the window but not the terminal.** Check the log for `names here:`; the tab
  title in VS Code differs from what the hook computed. Open an issue with those lines.
- **Notification shows while I am looking at the terminal.** VS Code does not expose whether the
  terminal panel is visible, so a focused window whose active terminal is the session's counts as
  "viewing" even with the panel collapsed; the reverse (a different terminal tab active) counts as
  not viewing.
- **The icon is a generic terminal.** macOS takes the icon from the sending app bundle; it cannot
  be changed from here. The image on the right can, see [Notification images](#notification-images).
- **My image does not show.** Check the file name and that it sits in `.claude/` of the project or
  of a parent folder. terminal-notifier reports an unreadable file on stderr; run the hook by hand
  to see it.

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). This project follows
the [Contributor Covenant](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE) © Mulberry Systems
