# Contributing

Thanks for taking the time. This is a small tool, so the process is light.

## Before you start

- For a bug, open an issue with the template. Include the output of the debug log
  (`~/.claude/terminal-focus.log`) when the click does not focus the right terminal.
- For a feature or a behaviour change, open an issue first so we can agree on the approach before
  you spend time on a pull request.

## Making changes

1. Fork and branch from `main`.
2. Run `./install.sh` to install your working copy, then `Developer: Reload Window` in VS Code.
3. Exercise the change: trigger a permission prompt and a finished turn in Claude Code, click both
   notifications, and check the behaviour when the terminal is already focused.
4. Keep the pieces small. The hooks are plain Python 3 with no dependencies and the extension is
   plain JavaScript; please keep it that way.
5. CI runs `python3 -m py_compile`, `node --check`, `bash -n` and shellcheck. Run them locally if
   you can.

## Pull requests

- One change per pull request, with a short description of what and why.
- Update the README when behaviour or installation changes, and add a line to `CHANGELOG.md`
  under "Unreleased".
- Bump the version in `vscode-extension/extension/package.json` and
  `vscode-extension/extension.vsixmanifest` together when the extension changes.

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
