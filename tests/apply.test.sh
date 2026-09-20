#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

fail=0
out=""
assert_contains() {
  local hay="$1" needle="$2" label="$3"
  if ! grep -Fq -- "$needle" <<<"$hay"; then
    printf 'FAIL %s: missing %s\n' "$label" "$needle"
    fail=1
  fi
}

assert_not_contains() {
  local hay="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" <<<"$hay"; then
    printf 'FAIL %s: should not mention %s\n' "$label" "$needle"
    fail=1
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  out=""
  set +e
  out="$("$root/apply.sh" --apply 2>&1)"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    printf 'FAIL apply.sh --apply should fail on %s\n' "$(uname -s)"
    fail=1
  fi

  assert_contains "$out" "cd /Users/andrew/.config/swiftbar/plugins" "cd plugins"
  assert_contains "$out" "curl -fsSL" "curl installer"
  assert_contains "$out" "macos-install.sh?v7" "cache-bust v7"
  assert_contains "$out" "chmod +x apply.sh" "chmod"
  assert_contains "$out" "./apply.sh --apply" "apply"
  assert_not_contains "$out" "1. cd" "no numbered steps"

  assert_not_contains "$out" "Looked in:" "no fake search"
  assert_not_contains "$out" "/home/ubuntu/.config/swiftbar" "no linux plugin path"
  assert_not_contains "$out" "/home/ubuntu/Library" "no linux Library path"
fi

help_out="$("$root/apply.sh" --help)"
assert_contains "$help_out" "cd /Users/andrew/.config/swiftbar/plugins" "help cd plugins"
assert_contains "$help_out" "./apply.sh --apply" "help apply"
assert_contains "$help_out" "macos-install.sh?v7" "help v7"
assert_not_contains "$help_out" "1. cd" "help unnumbered"

installer="$(cat "$root/macos-install.sh")"
assert_contains "$installer" "one-screen-bottom-launch.5s.sh" "installs launcher"
assert_contains "$installer" "lib/bar-state.sh" "installs bar-state"
assert_contains "$installer" "lib/swiftbar-park.sh" "installs park helper"
assert_contains "$installer" "bin/bottom-overlay.swift" "installs overlay"
assert_contains "$installer" "have_local_sources" "ignores stale parent copies"
assert_contains "$installer" "tests/apply.test.sh" "installed plugins dir is not a checkout"
assert_contains "$installer" 'INSTALL_REV="v7"' "cache-bust GitHub curls"
assert_contains "$installer" "extract_payload" "embedded payloads"
assert_contains "$installer" "BEGIN_EMBEDDED_PAYLOADS" "payload markers"
assert_contains "$installer" "swiftbar_park" "parks extras off the top bar"
assert_contains "$installer" "Do not use SwiftBar refresh" "refresh is the wrong fix"
assert_not_contains "$installer" "open \"swiftbar://refreshallplugins\"" "install must not relaunch top extras"

overlay="$(cat "$root/bin/bottom-overlay.swift")"
assert_contains "$overlay" "constrainFrameRect" "window cannot snap to the menu bar"
assert_contains "$overlay" "bottomBarRect(screenFrame: screen.frame)" "true bottom of the display"
assert_contains "$overlay" "pinToBottom" "re-pin if AppKit lifts the strip"
assert_contains "$overlay" "autoHideDock" "Dock yields the physical bottom"
assert_contains "$overlay" "return .normal" "windows can sit above the strip"
assert_contains "$overlay" "workAreaMinY" "work area sits above the strip"
assert_contains "$overlay" "hideTopSwiftBar" "SwiftBar extras leave the top menu bar"
assert_contains "$overlay" "parkTopSwiftBar" "park extras onto a stub directory"
assert_contains "$overlay" "StealthMode" "hide SwiftBar’s own extra"
assert_contains "$overlay" "one-screen-bottom-stub" "stub plugin directory"
assert_contains "$overlay" "hasStackedLowerDisplay" "only stacked displays hide the strip"
assert_contains "$overlay" "placement(screens:" "geometry, not raw screen count"
assert_contains "$overlay" 'overlayRev = "v7"' "log the build that actually parked extras"
assert_not_contains "$overlay" "orderFrontRegardless" "raising every second pins it on top"
assert_not_contains "$overlay" "bottomBarRect(screenFrame: screen.visibleFrame)" "strip origin is not visibleFrame"
assert_not_contains "$overlay" "fullScreenAuxiliary" "fullscreen windows can cover it"
assert_contains "$overlay" 'title: "×"' "close control"
assert_contains "$overlay" ".one-screen-bottom.closed" "closed flag"
assert_not_contains "$overlay" "level = .statusBar" "statusBar pins to the top"
assert_not_contains "$overlay" "NSPanel" "NSPanel constrains to the top"
assert_not_contains "$overlay" "desktopIconWindow" "desktop level hides the strip behind the Dock"

python3 "$root/scripts/pack-macos-install.py" >/dev/null
packed="$(awk '$0 == "# FILE bin/bottom-overlay.swift" {p=1; next} $0 == "# END_FILE" {p=0} p && $0 !~ /^# MODE /' "$root/macos-install.sh")"
if [[ -z "$packed" ]]; then
  printf 'FAIL packed overlay payload missing\n'
  fail=1
else
  decoded="$(mktemp)"
  printf '%s\n' "$packed" | openssl base64 -d >"$decoded" || {
    printf 'FAIL overlay payload did not decode\n'
    fail=1
  }
  if [[ -s "$decoded" ]] && ! cmp -s "$decoded" "$root/bin/bottom-overlay.swift"; then
    printf 'FAIL packed overlay does not match bin/bottom-overlay.swift\n'
    fail=1
  fi
  rm -f "$decoded"
fi

if [[ "$fail" -ne 0 ]]; then
  printf '%s\n' "$out"
  exit 1
fi
printf 'ok\n'
