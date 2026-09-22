# Wrap the compiled overlay in a GUI .app so AppKit actually maps windows.
overlay_app_root() {
  printf '%s/bin/SwiftBarBottom.app\n' "${1:?}"
}

overlay_app_binary() {
  printf '%s/Contents/MacOS/bottom-overlay\n' "$(overlay_app_root "$1")"
}

overlay_app_wrap() {
  local dir="${1:?}" bin="${2:?}"
  local app execbin plist
  app="$(overlay_app_root "$dir")"
  execbin="$(overlay_app_binary "$dir")"
  mkdir -p "$(dirname "$execbin")"
  cp "$bin" "$execbin"
  chmod +x "$execbin"
  plist="$app/Contents/Info.plist"
  cat >"$plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>bottom-overlay</string>
  <key>CFBundleIdentifier</key>
  <string>com.presempathy.swiftbar-bottom</string>
  <key>CFBundleName</key>
  <string>SwiftBarBottom</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticTermination</key>
  <false/>
  <key>NSSupportsSuddenTermination</key>
  <false/>
</dict>
</plist>
PLIST
  printf '%s\n' "$execbin"
}
