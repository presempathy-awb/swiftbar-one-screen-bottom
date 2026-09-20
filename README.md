# SwiftBar — bottom on one screen

macOS cannot move menu extras off the top bar. A SwiftBar refresh also cannot — it puts them back. This installer parks SwiftBar on an empty stub (StealthMode) so the top extras go away, and draws those plugins on a strip at the physical bottom of the display.

The Dock autohides while the strip is up so the strip is visible at the bottom; app windows stay above it. Fullscreen can cover it. × closes the strip, restores SwiftBar, and keeps it closed. ⬇ in SwiftBar shows only while the strip is down.

Stacked displays (one below the other): strip hides and SwiftBar comes back on the lower display’s menu bar.

Do not refresh SwiftBar to update this. Re-run apply (`?v8`, not `?v5`):

```
cd /Users/andrew/.config/swiftbar/plugins
curl -fsSL "https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh?v8" -o apply.sh
chmod +x apply.sh
./apply.sh --apply
```

Expect: “SwiftBar extras are parked off the top menu bar.” If swiftc fails, the compiler log prints in the same terminal. Check `/tmp/swiftbar-bottom-overlay.out` for `overlay rev=v8` and a small `y=` (bottom), not the top of the screen.

Gitea `awb/swiftbar-one-screen-bottom` both ways with GitHub. SSH Host `hidin` only. No tokens.

```
git clone https://github.com/presempathy-awb/swiftbar-one-screen-bottom.git
cd swiftbar-one-screen-bottom
git remote add hidin git@hidin:awb/swiftbar-one-screen-bottom.git
bash scripts/gitea-bidir.sh
```

Re-run `bash scripts/gitea-bidir.sh` after commits on either side.
