#!/usr/bin/env bash
# Install the one-screen bottom strip into SwiftBar's plugin folder.
# Darwin: writes plugins and starts the overlay.
# Linux: refuses. This workspace cannot see the Mac plugin folder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MARKER="swiftbar-one-screen-bottom"
DEFAULT_MAC_PLUGINS="/Users/andrew/.config/swiftbar/plugins"
BASE="https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main"
MAC_CURL="${BASE}/macos-install.sh"

mac_commands() {
  cat <<EOF
cd ${DEFAULT_MAC_PLUGINS}
curl -fsSL ${MAC_CURL} -o apply.sh
chmod +x apply.sh
./apply.sh --apply
EOF
}

usage() {
  mac_commands
}

if [[ -n "${SWIFTBAR:-}" ]]; then
  exit 0
fi

linux_refuse() {
  mac_commands >&2
  exit 1
}

DEST_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      DEST_ARG="$1"
      shift
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  linux_refuse
fi

resolve_dest() {
  local dest=""
  if [[ -n "$DEST_ARG" ]]; then
    printf '%s\n' "$DEST_ARG"
    return
  fi
  if dest="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null)"; then
    dest="${dest%\"}"
    dest="${dest#\"}"
  fi
  if [[ -z "$dest" ]]; then
    dest="${SWIFTBAR_PLUGINS_PATH:-}"
  fi
  if [[ -z "$dest" ]]; then
    if [[ -d "$HOME/.config/swiftbar/plugins" ]]; then
      dest="$HOME/.config/swiftbar/plugins"
    elif [[ -d "$DEFAULT_MAC_PLUGINS" ]]; then
      dest="$DEFAULT_MAC_PLUGINS"
    elif [[ -d "$HOME/.config/swiftbar" ]]; then
      dest="$HOME/.config/swiftbar"
    else
      dest="$HOME/.config/swiftbar/plugins"
    fi
  fi
  printf '%s\n' "$dest"
}

have_local_sources() {
  [[ -f "$ROOT/one-screen-bottom.5s.sh" \
     && -f "$ROOT/one-screen-bottom-launch.5s.sh" \
     && -f "$ROOT/lib/bar-state.sh" \
     && -f "$ROOT/bin/bottom-overlay.swift" ]] \
    && grep -Fq 'constrainFrameRect' "$ROOT/bin/bottom-overlay.swift" \
    && ! grep -Fq 'level = .statusBar' "$ROOT/bin/bottom-overlay.swift"
}

install_file() {
  local rel="$1" dest="$2" mode="$3"
  local src="$ROOT/$rel"
  mkdir -p "$(dirname "$dest")"
  if have_local_sources && [[ -f "$src" ]]; then
    install -m "$mode" "$src" "$dest"
    return
  fi
  curl -fsSL "$BASE/$rel" -o "$dest"
  chmod "$mode" "$dest"
}

DEST="$(resolve_dest)"
mkdir -p "$DEST/bin" "$DEST/lib"

install_file "one-screen-bottom.5s.sh" "$DEST/one-screen-bottom.5s.sh" 755
install_file "one-screen-bottom-launch.5s.sh" "$DEST/one-screen-bottom-launch.5s.sh" 755
install_file "lib/bar-state.sh" "$DEST/lib/bar-state.sh" 644
install_file "bin/bottom-overlay.swift" "$DEST/bin/bottom-overlay.swift" 644

# shellcheck source=lib/bar-state.sh
. "$DEST/lib/bar-state.sh"
bar_mark_open "$DEST"

BIN="$DEST/bin/bottom-overlay"
SRC="$DEST/bin/bottom-overlay.swift"
if ! /usr/bin/swiftc -O -o "$BIN" "$SRC" 2>/tmp/swiftbar-bottom-overlay.log; then
  echo "Installed keeper into $DEST, but swiftc failed. See /tmp/swiftbar-bottom-overlay.log" >&2
  echo "SwiftBar will retry compile on refresh." >&2
  open "swiftbar://refreshallplugins" >/dev/null 2>&1 || true
  exit 1
fi
chmod +x "$BIN"

pkill -f "$MARKER" >/dev/null 2>&1 || true
pkill -f '/bin/bottom-overlay' >/dev/null 2>&1 || true
sleep 0.4

nohup "$BIN" --plugins-dir "$DEST" --marker "$MARKER" \
  >/tmp/swiftbar-bottom-overlay.out 2>&1 &
disown || true

open "swiftbar://refreshallplugins" >/dev/null 2>&1 || true

if [[ -f "$0" && "$0" != *bash && -r "$0" ]]; then
  src_dir="$(cd "$(dirname "$0")" && pwd)"
  dest_dir="$(cd "$DEST" && pwd)"
  if [[ "$src_dir" != "$dest_dir" || "$(basename "$0")" != "apply.sh" ]]; then
    install -m 755 "$0" "$DEST/apply.sh"
  fi
fi

echo "Installed into $DEST"
echo "One display: bottom strip with × to close. Two displays: strip hides."
echo "Closed: ⬇ in SwiftBar reopens. It will not auto-open while closed."
