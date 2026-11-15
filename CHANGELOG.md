# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow the VS Code
extension version in `vscode-extension/extension/package.json`.

## [Unreleased]

### Added
- Per-project notification image: the nearest `.claude/notification.{png,jpg,jpeg,gif}` from the
  session folder upwards is attached to the banner, with `~/.claude/notification.png` as default.

## [0.2.0] - 2026-11-15

First public release.

### Added
- `Notification` and `Stop` hooks that post a macOS notification titled with the Claude Code
  terminal tab title, via terminal-notifier.
- Click-to-focus: clicking the notification raises the VS Code window that owns the session and
  shows its terminal, through a small companion extension.
- No notification while a focused VS Code window already has that session's terminal active.
- No notification for a `Stop` that only hands the turn to a running subagent or workflow.
- `install.sh` and `uninstall.sh`.

[Unreleased]: https://github.com/MulberrySystems/claude-notifications/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/MulberrySystems/claude-notifications/releases/tag/v0.2.0
