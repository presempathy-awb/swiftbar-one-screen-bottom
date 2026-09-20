# Point SwiftBar at an empty stub so extras leave the top menu bar.
# Overlay keeps reading the real plugin folder.
SWIFTBAR_DEFAULTS_DOMAIN="com.ameba.SwiftBar"
SWIFTBAR_STUB_NAME=".one-screen-bottom-stub"
SWIFTBAR_SAVED_DIR_NAME=".one-screen-bottom.saved-plugin-dir"

swiftbar_is_stub_path() {
  case "${1:-}" in
    *one-screen-bottom-stub*) return 0 ;;
    *) return 1 ;;
  esac
}

swiftbar_real_plugins_dir() {
  local dest="${1:-}"
  dest="${dest%/}"
  if swiftbar_is_stub_path "$dest"; then
    dest="$(dirname "$dest")"
  fi
  printf '%s\n' "$dest"
}

swiftbar_write_stub_keeper() {
  local dest="${1:?}"
  local stub="$dest/$SWIFTBAR_STUB_NAME"
  mkdir -p "$stub"
  cat >"$stub/one-screen-bottom.5s.sh" <<KEEP
#!/bin/bash
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
REAL=$(printf '%q' "$dest")
export SWIFTBAR_PLUGINS_PATH="\$REAL"
 if [[ -x "\$REAL/one-screen-bottom.5s.sh" ]]; then
  exec "\$REAL/one-screen-bottom.5s.sh"
fi
KEEP
  chmod 755 "$stub/one-screen-bottom.5s.sh"
}

swiftbar_park() {
  local dest current saved stub
  dest="$(swiftbar_real_plugins_dir "${1:?}")"
  stub="$dest/$SWIFTBAR_STUB_NAME"
  saved="$dest/$SWIFTBAR_SAVED_DIR_NAME"
  swiftbar_write_stub_keeper "$dest"
  current="$(defaults read "$SWIFTBAR_DEFAULTS_DOMAIN" PluginDirectory 2>/dev/null || true)"
  current="${current%\"}"
  current="${current#\"}"
  if [[ -z "$current" ]] || swiftbar_is_stub_path "$current"; then
    current="$dest"
  fi
  if [[ ! -f "$saved" ]]; then
    printf '%s\n' "$current" >"$saved"
  fi
  defaults write "$SWIFTBAR_DEFAULTS_DOMAIN" PluginDirectory "$stub"
  defaults write "$SWIFTBAR_DEFAULTS_DOMAIN" StealthMode -bool true
  killall SwiftBar >/dev/null 2>&1 || true
}

swiftbar_unpark() {
  local dest saved restored
  dest="$(swiftbar_real_plugins_dir "${1:?}")"
  saved="$dest/$SWIFTBAR_SAVED_DIR_NAME"
  restored="$dest"
  if [[ -f "$saved" ]]; then
    restored="$(tr -d '\n' <"$saved")"
    if [[ -z "$restored" ]] || swiftbar_is_stub_path "$restored"; then
      restored="$dest"
    fi
  fi
  defaults write "$SWIFTBAR_DEFAULTS_DOMAIN" PluginDirectory "$restored"
  defaults write "$SWIFTBAR_DEFAULTS_DOMAIN" StealthMode -bool false
  rm -f "$saved"
}
