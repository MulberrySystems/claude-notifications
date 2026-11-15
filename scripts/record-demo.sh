#!/bin/bash
# Record a short demo of the notification and the click-to-focus, then convert it to docs/demo.gif.
# Usage: scripts/record-demo.sh [seconds]      (default 12)
# Env:   SCREEN=<n>   avfoundation index of the display to record (default: the first "Capture
#                     screen" device; run `ffmpeg -f avfoundation -list_devices true -i ""` to see them)
# Needs: macOS, ffmpeg (brew install ffmpeg), the hooks installed (./install.sh), and Screen
# Recording permission for the terminal app you run this from (macOS asks the first time).
# While it records: a sample notification appears after ~2 s; click it so VS Code jumps to the
# terminal. Record from a clean VS Code window whose contents you are happy to publish, and switch
# to another window first so the focus change is visible.
set -euo pipefail
SECS="${1:-12}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/docs/demo.gif"
MOV="$HERE/docs/demo.mp4"
command -v ffmpeg >/dev/null || { echo "ffmpeg missing: brew install ffmpeg"; exit 1; }
HOOK="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/claude-ping.py"
[ -f "$HOOK" ] || { echo "hooks not installed: run ./install.sh first"; exit 1; }
if [ -z "${SCREEN:-}" ]; then
  SCREEN="$(ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 | grep -i 'capture screen' | head -1 | grep -o '\[[0-9]*\]' | tr -d '[]' || true)"
  [ -n "$SCREEN" ] || { echo "no screen capture device found; set SCREEN=<index>"; exit 1; }
fi

echo "Recording display $SCREEN for $SECS s to $MOV ... click the notification when it appears."
mkdir -p "$HERE/docs"
ffmpeg -y -hide_banner -loglevel error -f avfoundation -framerate 30 -capture_cursor 1 -i "${SCREEN}:none" \
  -t "$SECS" -pix_fmt yuv420p "$MOV" &
REC=$!
sleep 2
printf '{"session_id":"demo0000-0000-0000-0000-000000000000","cwd":"%s","transcript_path":""}' "$HERE" \
  | python3 -I "$HOOK" stop || true
wait "$REC" || true
[ -s "$MOV" ] || { echo "No recording was written. Grant Screen Recording to your terminal app in System Settings > Privacy & Security and run again."; exit 1; }

echo "Converting to $OUT"
ffmpeg -y -loglevel error -i "$MOV" \
  -vf "fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
  -loop 0 "$OUT"
ls -lh "$OUT"
echo "Done. Re-record if needed; docs/demo.mp4 is ignored by git."
