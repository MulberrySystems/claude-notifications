#!/bin/bash
# Record a short demo of the notification and the click-to-focus, then convert it to docs/demo.gif.
# Usage: scripts/record-demo.sh [seconds]      (default 12)
# Needs: macOS, ffmpeg (brew install ffmpeg), the hooks installed (./install.sh), and Screen
# Recording permission for the terminal app you run this from (macOS asks the first time).
# While it records: a sample notification appears after ~2 s; click it so VS Code jumps to the
# terminal. Switch to another window first so the focus change is visible.
set -euo pipefail
SECS="${1:-12}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/docs/demo.gif"
MOV="$HERE/docs/demo.mov"
command -v ffmpeg >/dev/null || { echo "ffmpeg missing: brew install ffmpeg"; exit 1; }
HOOK="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-ping.py"
[ -f "$HOOK" ] || { echo "hooks not installed: run ./install.sh first"; exit 1; }

echo "Recording $SECS s to $MOV ... click the notification when it appears."
screencapture -v -V "$SECS" -x "$MOV" &
REC=$!
sleep 2
printf '{"session_id":"demo0000-0000-0000-0000-000000000000","cwd":"%s","transcript_path":""}' "$HERE" \
  | python3 -I "$HOOK" stop || true
wait "$REC"

echo "Converting to $OUT"
ffmpeg -y -loglevel error -i "$MOV" \
  -vf "fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
  -loop 0 "$OUT"
ls -lh "$OUT"
echo "Done. Trim or re-record as needed; docs/demo.mov is ignored by git."
