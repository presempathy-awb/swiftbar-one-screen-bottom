# SwiftBar — bottom of each screen

macOS cannot put SwiftBar extras on the bottom of a display. This overlay quits SwiftBar **and Stats** while it is up and draws those plugins on a strip along the bottom edge. The Apple menu bar stays at the top (that is the system bar). HIGH CPU / LOW DISK extras are Stats, not SwiftBar.

× brings SwiftBar and Stats back. Do not refresh SwiftBar to update this. Re-run apply (`?v14`):

```
cd /Users/andrew/.config/swiftbar/plugins
curl -fsSL "https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh?v14" -o apply.sh
chmod +x apply.sh
./apply.sh --apply
```

Apply waits until the overlay logs a pin. You want `overlay rev=v14`, `topHalf=false`, `y=` equal to `screenMinY`, `SwiftBar is not running.`, and `Stats is not running.` Look at the physical bottom edge, not the Apple menu bar. The pin line’s `topOwners=` says who is still in the top bar.
