#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/swiftbar-park.sh
. "$root/lib/swiftbar-park.sh"

fail=0
assert_eq() {
  local expected="$1" got="$2" label="$3"
  if [ "$got" != "$expected" ]; then
    printf 'FAIL %s: expected %s, got %s\n' "$label" "$expected" "$got"
    fail=1
  fi
}

assert_rc() {
  local expected="$1" label="$2"
  shift 2
  set +e
  "$@"
  local rc=$?
  set -e
  if [ "$rc" -ne "$expected" ]; then
    printf 'FAIL %s: expected rc %s, got %s\n' "$label" "$expected" "$rc"
    fail=1
  fi
}

assert_eq /Users/andrew/.config/swiftbar/plugins \
  "$(swiftbar_real_plugins_dir /Users/andrew/.config/swiftbar/plugins)" \
  "real plugins dir unchanged"
assert_eq /Users/andrew/.config/swiftbar/plugins \
  "$(swiftbar_real_plugins_dir /Users/andrew/.config/swiftbar/plugins/.one-screen-bottom-stub)" \
  "stub path unwraps to plugins"
assert_rc 0 "stub path detected" swiftbar_is_stub_path /tmp/.one-screen-bottom-stub
assert_rc 1 "normal path is not stub" swiftbar_is_stub_path /Users/andrew/.config/swiftbar/plugins

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
swiftbar_write_stub_keeper "$tmp"
if [[ ! -x "$tmp/.one-screen-bottom-stub/one-screen-bottom.5s.sh" ]]; then
  printf 'FAIL stub keeper not executable\n'
  fail=1
fi
if ! grep -Fq "$tmp" "$tmp/.one-screen-bottom-stub/one-screen-bottom.5s.sh"; then
  printf 'FAIL stub keeper should exec the real plugins dir\n'
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
printf 'ok\n'
