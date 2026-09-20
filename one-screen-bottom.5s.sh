#!/usr/bin/env bash
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
#
# Hidden. Starts a bottom strip when there is no display stacked below.
# Stacked dual monitors: overlay hides; your lower-display SwiftBar stays.
# While the strip is up, SwiftBar itself is quit so extras leave the top menu bar.
# Closed (×) or urgent memory pressure: do not start.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/bin/bottom-overlay.swift"
BIN="$DIR/bin/bottom-overlay"
PLUGINS="${SWIFTBAR_PLUGINS_PATH:-$DIR}"
MARKER="swiftbar-one-screen-bottom"

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

# shellcheck source=lib/bar-state.sh
if [[ -f "$DIR/lib/bar-state.sh" ]]; then
  . "$DIR/lib/bar-state.sh"
else
  exit 0
fi

if ! bar_should_autostart "$DIR"; then
  exit 0
fi

if [[ ! -f "$SRC" ]]; then
  exit 0
fi

mkdir -p "$DIR/bin"

if [[ ! -x "$BIN" || "$SRC" -nt "$BIN" ]]; then
  if ! /usr/bin/swiftc -O -o "$BIN" "$SRC" 2>/tmp/swiftbar-bottom-overlay.log; then
    echo "bottom ⚠️"
    echo "---"
    echo "swiftc failed | bash=/usr/bin/open param1=/tmp/swiftbar-bottom-overlay.log"
    exit 0
  fi
  chmod +x "$BIN"
fi

if ! bar_is_up; then
  nohup "$BIN" --plugins-dir "$PLUGINS" --marker "$MARKER" \
    >/tmp/swiftbar-bottom-overlay.out 2>&1 &
  disown || true
fi
