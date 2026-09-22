#!/usr/bin/env bash
# Visible in SwiftBar only when the bottom overlay is not running.
# Click to reopen after ×. Stays silent if closed and memory is tight.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/bin/bottom-overlay.swift"
BIN="$DIR/bin/bottom-overlay"
PLUGINS="${SWIFTBAR_PLUGINS_PATH:-$DIR}"
MARKER="swiftbar-one-screen-bottom"

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

if [[ -f "$DIR/lib/bar-state.sh" ]]; then
  . "$DIR/lib/bar-state.sh"
else
  exit 0
fi
if [[ -f "$DIR/lib/overlay-app.sh" ]]; then
  . "$DIR/lib/overlay-app.sh"
fi

open_bar() {
  bar_mark_open "$DIR"
  mkdir -p "$DIR/bin"
  if [[ -f "$SRC" ]] && [[ ! -x "$BIN" || "$SRC" -nt "$BIN" ]]; then
    sdk="$(xcrun --show-sdk-path 2>/dev/null || true)"
    if [[ -n "$sdk" ]]; then
      xcrun swiftc -sdk "$sdk" -framework Cocoa -framework ApplicationServices -O -o "$BIN" "$SRC" \
        2>/tmp/swiftbar-bottom-overlay.log || exit 0
    else
      /usr/bin/swiftc -framework Cocoa -framework ApplicationServices -O -o "$BIN" "$SRC" \
        2>/tmp/swiftbar-bottom-overlay.log || exit 0
    fi
    chmod +x "$BIN"
  fi
  RUN="$BIN"
  if type overlay_app_wrap >/dev/null 2>&1; then
    RUN="$(overlay_app_wrap "$DIR" "$BIN")"
  fi
  if [[ -x "$RUN" ]] && ! bar_is_up; then
    nohup "$RUN" --plugins-dir "$PLUGINS" --marker "$MARKER" \
      >/tmp/swiftbar-bottom-overlay.out 2>&1 &
    disown || true
  fi
}

if [[ "${1:-}" == "--open" ]]; then
  open_bar
  exit 0
fi

if ! bar_should_show_launcher "$DIR"; then
  exit 0
fi

echo "⬇"
echo "---"
echo "Show bottom bar | bash=${DIR}/one-screen-bottom-launch.5s.sh param1=--open terminal=false refresh=true"
