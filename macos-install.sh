#!/usr/bin/env bash
# Install the one-screen bottom strip into SwiftBar's plugin folder.
# Darwin: writes plugins, parks SwiftBar extras off the top bar, starts the overlay.
# Linux: refuses. This workspace cannot see the Mac plugin folder.
# Payloads are embedded so one curl of this file is enough (no second GitHub fetch).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MARKER="swiftbar-one-screen-bottom"
DEFAULT_MAC_PLUGINS="/Users/andrew/.config/swiftbar/plugins"
BASE="https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main"
INSTALL_REV="v10"
MAC_CURL="${BASE}/macos-install.sh?${INSTALL_REV}"
SELF="${BASH_SOURCE[0]:-$0}"

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

is_stub_path() {
  case "${1:-}" in
    *one-screen-bottom-stub*) return 0 ;;
    *) return 1 ;;
  esac
}

real_plugins_dir() {
  local dest="${1:-}"
  dest="${dest%/}"
  dest="${dest%\"}"
  dest="${dest#\"}"
  if is_stub_path "$dest"; then
    dest="$(dirname "$dest")"
  fi
  printf '%s\n' "$dest"
}

resolve_dest() {
  local dest=""
  if [[ -n "$DEST_ARG" ]]; then
    real_plugins_dir "$DEST_ARG"
    return
  fi
  if dest="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null)"; then
    dest="$(real_plugins_dir "$dest")"
  fi
  if [[ -z "$dest" ]]; then
    dest="${SWIFTBAR_PLUGINS_PATH:-}"
    dest="$(real_plugins_dir "$dest")"
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
  real_plugins_dir "$dest"
}

have_local_sources() {
  # Installed plugin folders have overlay sources too. Only a repo checkout
  # (with tests) may copy local files; otherwise use the embedded payloads.
  [[ -f "$ROOT/tests/apply.test.sh" \
     && -f "$ROOT/one-screen-bottom.5s.sh" \
     && -f "$ROOT/one-screen-bottom-launch.5s.sh" \
     && -f "$ROOT/lib/bar-state.sh" \
     && -f "$ROOT/lib/swiftbar-park.sh" \
     && -f "$ROOT/bin/bottom-overlay.swift" ]] \
    && grep -Fq 'hideTopSwiftBar' "$ROOT/bin/bottom-overlay.swift" \
    && grep -Fq 'parkTopSwiftBar' "$ROOT/bin/bottom-overlay.swift" \
    && grep -Fq 'autoHideDock' "$ROOT/bin/bottom-overlay.swift" \
    && grep -Fq 'pinToBottom' "$ROOT/bin/bottom-overlay.swift" \
    && ! grep -Fq 'level = .statusBar' "$ROOT/bin/bottom-overlay.swift" \
    && ! grep -Fq 'desktopIconWindow' "$ROOT/bin/bottom-overlay.swift"
}

decode_base64() {
  # macOS LibreSSL `openssl base64 -d` often returns 0 with garbage.
  # /usr/bin/base64 -D is the Darwin decoder; -d is GNU.
  if [[ "$(uname -s)" == "Darwin" ]]; then
    /usr/bin/base64 -D
    return
  fi
  if echo SGVsbG8= | base64 -d >/dev/null 2>&1; then
    base64 -d
    return
  fi
  openssl base64 -d
}

file_sha256() {
  openssl dgst -sha256 "$1" | awk '{print $NF}'
}

extract_payload() {
  local rel="$1" dest="$2" mode="$3"
  local b64 expected got
  [[ -f "$SELF" ]] || return 1
  expected="$(awk -v rel="$rel" '
    $0 == "# FILE " rel {p=1}
    p && $1 == "#" && $2 == "SHA256" { print $3; exit }
  ' "$SELF")"
  b64="$(awk -v rel="$rel" '
    $0 == "# FILE " rel {p=1; next}
    $0 == "# END_FILE" {p=0; next}
    $0 == "# END_EMBEDDED_PAYLOADS" {p=0}
    p && $0 !~ /^#/
  ' "$SELF")"
  [[ -n "$b64" ]] || return 1
  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$b64" | decode_base64 >"$dest" || return 1
  if [[ -n "$expected" ]]; then
    got="$(file_sha256 "$dest")"
    [[ "$got" == "$expected" ]] || return 1
  fi
  chmod "$mode" "$dest"
}

overlay_looks_ok() {
  grep -Fq 'import Cocoa' "$1" \
    && grep -Fq 'parkTopSwiftBar' "$1" \
    && grep -Fq 'pinToBottom' "$1" \
    && grep -Fq 'hideTopSwiftBar' "$1"
}

install_file() {
  local rel="$1" dest="$2" mode="$3"
  local src="$ROOT/$rel"
  mkdir -p "$(dirname "$dest")"
  if have_local_sources && [[ -f "$src" ]]; then
    install -m "$mode" "$src" "$dest"
    return
  fi
  if extract_payload "$rel" "$dest" "$mode"; then
    return
  fi
  curl -fsSL "${BASE}/${rel}?${INSTALL_REV}" -o "$dest"
  chmod "$mode" "$dest"
}

compile_overlay() {
  local src="$1" bin="$2" log="$3"
  local sdk="" rc=0
  {
    echo "rev=${INSTALL_REV}"
    echo "src=${src}"
    command -v xcrun || true
    command -v swiftc || true
    xcrun --show-sdk-path || true
    echo "src head:"
    head -n 5 "$src" || true
  } >"$log" 2>&1
  sdk="$(xcrun --show-sdk-path 2>>"$log" || true)"
  set +e
  if [[ -n "$sdk" ]] && command -v xcrun >/dev/null; then
    xcrun swiftc -sdk "$sdk" -framework Cocoa -framework ApplicationServices -O -o "$bin" "$src" >>"$log" 2>&1
    rc=$?
  else
    /usr/bin/swiftc -framework Cocoa -framework ApplicationServices -O -o "$bin" "$src" >>"$log" 2>&1
    rc=$?
  fi
  set -e
  return "$rc"
}

DEST="$(resolve_dest)"
mkdir -p "$DEST/bin" "$DEST/lib"

install_file "one-screen-bottom.5s.sh" "$DEST/one-screen-bottom.5s.sh" 755
install_file "one-screen-bottom-launch.5s.sh" "$DEST/one-screen-bottom-launch.5s.sh" 755
install_file "lib/bar-state.sh" "$DEST/lib/bar-state.sh" 644
install_file "lib/swiftbar-park.sh" "$DEST/lib/swiftbar-park.sh" 644
install_file "bin/bottom-overlay.swift" "$DEST/bin/bottom-overlay.swift" 644
if ! overlay_looks_ok "$DEST/bin/bottom-overlay.swift"; then
  curl -fsSL "${BASE}/bin/bottom-overlay.swift?${INSTALL_REV}" -o "$DEST/bin/bottom-overlay.swift"
  chmod 644 "$DEST/bin/bottom-overlay.swift"
fi
if ! overlay_looks_ok "$DEST/bin/bottom-overlay.swift"; then
  echo "overlay source is not valid Swift. Refusing to compile." >&2
  exit 1
fi

# shellcheck source=lib/bar-state.sh
. "$DEST/lib/bar-state.sh"
# shellcheck source=lib/swiftbar-park.sh
. "$DEST/lib/swiftbar-park.sh"
bar_mark_open "$DEST"

BIN="$DEST/bin/bottom-overlay"
SRC="$DEST/bin/bottom-overlay.swift"
rm -f "$BIN"
if ! compile_overlay "$SRC" "$BIN" /tmp/swiftbar-bottom-overlay.log; then
  echo "Installed keeper into $DEST, but swiftc failed:" >&2
  cat /tmp/swiftbar-bottom-overlay.log >&2
  exit 1
fi
chmod +x "$BIN"

swiftbar_park "$DEST"

pkill -f "$MARKER" >/dev/null 2>&1 || true
pkill -f '/bin/bottom-overlay' >/dev/null 2>&1 || true
sleep 0.4

nohup "$BIN" --plugins-dir "$DEST" --marker "$MARKER" \
  >/tmp/swiftbar-bottom-overlay.out 2>&1 &
disown || true

if [[ -f "$SELF" && "$SELF" != *bash && -r "$SELF" ]]; then
  src_dir="$(cd "$(dirname "$SELF")" && pwd)"
  dest_dir="$(cd "$DEST" && pwd)"
  if [[ "$src_dir" != "$dest_dir" || "$(basename "$SELF")" != "apply.sh" ]]; then
    install -m 755 "$SELF" "$DEST/apply.sh"
  fi
fi

echo "Installed into $DEST"
echo "Strip at the physical bottom. SwiftBar extras are parked off the top menu bar."
echo "Do not use SwiftBar refresh; that puts extras back on top. Re-run apply.sh instead."
echo "Closed: ⬇ in SwiftBar reopens. It will not auto-open while closed."

# BEGIN_EMBEDDED_PAYLOADS
# END_EMBEDDED_PAYLOADS
