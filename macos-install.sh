#!/usr/bin/env bash
# Download into ~/.config/swiftbar as apply.sh, then: ./apply.sh --apply
set -euo pipefail

if [[ -n "${SWIFTBAR:-}" ]]; then
  exit 0
fi

MARKER="swiftbar-one-screen-bottom"
DEFAULT_MAC_PLUGINS="/Users/andrew/.config/swiftbar"
BASE="https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main"

if [[ "$(uname -s)" != "Darwin" ]]; then
  cat >&2 <<EOF
This installer only runs on the Mac.

  cd ${DEFAULT_MAC_PLUGINS}
  curl -fsSL ${BASE}/macos-install.sh -o apply.sh
  chmod +x apply.sh
  ./apply.sh --apply
EOF
  exit 1
fi

DEST_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      shift
      ;;
    --help|-h)
      echo "Install a bottom SwiftBar strip on one display."
      exit 0
      ;;
    -*)
      echo "unknown option: $1" >&2
      exit 2
      ;;
    *)
      DEST_ARG="$1"
      shift
      ;;
  esac
done

if [[ -n "$DEST_ARG" ]]; then
  DEST="$DEST_ARG"
elif DEST="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null)"; then
  DEST="${DEST%\"}"
  DEST="${DEST#\"}"
else
  DEST="${SWIFTBAR_PLUGINS_PATH:-$HOME/.config/swiftbar}"
fi

mkdir -p "$DEST/bin"
curl -fsSL "$BASE/one-screen-bottom.5s.sh" -o "$DEST/one-screen-bottom.5s.sh"
curl -fsSL "$BASE/bin/bottom-overlay.swift" -o "$DEST/bin/bottom-overlay.swift"
chmod 755 "$DEST/one-screen-bottom.5s.sh"
chmod 644 "$DEST/bin/bottom-overlay.swift"

BIN="$DEST/bin/bottom-overlay"
SRC="$DEST/bin/bottom-overlay.swift"
if ! /usr/bin/swiftc -O -o "$BIN" "$SRC" 2>/tmp/swiftbar-bottom-overlay.log; then
  echo "swiftc failed; see /tmp/swiftbar-bottom-overlay.log" >&2
  exit 1
fi
chmod +x "$BIN"

if pgrep -fq "$MARKER" >/dev/null 2>&1; then
  pkill -f "$MARKER" >/dev/null 2>&1 || true
  sleep 0.3
fi

nohup "$BIN" --plugins-dir "$DEST" --marker "$MARKER" \
  >/tmp/swiftbar-bottom-overlay.out 2>&1 &
disown || true

if [[ -f "$0" && "$0" != *bash && -r "$0" ]]; then
  src_dir="$(cd "$(dirname "$0")" && pwd)"
  dest_dir="$(cd "$DEST" && pwd)"
  if [[ "$src_dir" != "$dest_dir" || "$(basename "$0")" != "apply.sh" ]]; then
    install -m 755 "$0" "$DEST/apply.sh"
  fi
fi

open "swiftbar://refreshallplugins" >/dev/null 2>&1 || true
echo "Installed into $DEST"
echo "One display: bottom strip. Two displays: strip hides."
