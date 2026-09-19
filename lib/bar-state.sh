# Closed flag, process check, and auto-start rules for the one-screen bar.
CLOSED_FLAG_NAME=".one-screen-bottom.closed"
BOTTOM_BAR_MARKER="swiftbar-one-screen-bottom"

bar_closed_path() {
  printf '%s/%s\n' "${1:?}" "$CLOSED_FLAG_NAME"
}

bar_is_closed() {
  [[ -f "$(bar_closed_path "$1")" ]]
}

bar_mark_closed() {
  : >"$(bar_closed_path "$1")"
}

bar_mark_open() {
  rm -f "$(bar_closed_path "$1")"
}

bar_is_up() {
  pgrep -fq "$BOTTOM_BAR_MARKER" >/dev/null 2>&1
}

bar_memory_pressure_level() {
  if [[ -n "${BAR_MEMORY_PRESSURE_LEVEL:-}" ]]; then
    printf '%s\n' "$BAR_MEMORY_PRESSURE_LEVEL"
    return
  fi
  sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || echo 0
}

bar_low_resources() {
  local level
  level="$(bar_memory_pressure_level)"
  [[ "$level" =~ ^[0-9]+$ ]] || return 1
  [[ "$level" -ge 2 ]]
}

# Keeper may start the overlay only if the user has not closed it
# and the Mac is not under urgent/critical memory pressure.
bar_should_autostart() {
  local dir="${1:?}"
  if bar_is_closed "$dir"; then
    return 1
  fi
  if bar_low_resources; then
    return 1
  fi
  return 0
}

# Menu extra: only when the overlay process is gone.
# If the user closed it and memory is tight, stay silent.
bar_should_show_launcher() {
  local dir="${1:?}"
  if bar_is_up; then
    return 1
  fi
  if bar_is_closed "$dir" && bar_low_resources; then
    return 1
  fi
  return 0
}
