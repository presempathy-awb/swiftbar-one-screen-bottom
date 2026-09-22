# SwiftBar — bottom of each screen

macOS cannot put menu extras on the bottom of a display. This overlay quits SwiftBar while it is up and draws those plugins on a strip along the bottom edge of every screen, overlapping the Dock. The Apple menu bar stays at the top (that is the system bar). × brings SwiftBar back.

Do not refresh SwiftBar to update this. Re-run apply (`?v13`):

```
cd /Users/andrew/.config/swiftbar/plugins
curl -fsSL "https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh?v13" -o apply.sh
chmod +x apply.sh
./apply.sh --apply
```

Apply waits until the overlay logs a pin. You want `overlay rev=v13`, `topHalf=false`, `y=` equal to `screenMinY`, and `SwiftBar is not running.` Look at the physical bottom edge of the display, not the Apple menu bar.
