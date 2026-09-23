# SwiftBar — bottom of a single screen

On two monitors those extras already sit on the lower display’s menu bar. This overlay stays out of that. It only runs when there is **one** screen, and then it draws the extras along the physical bottom edge.

AppKit `y=0` can still mean the top of the display. v16 checks WindowServer (Quartz) coordinates and moves the strip if it landed under the Apple menu bar.

× brings SwiftBar back. Do not refresh SwiftBar to update this. Re-run apply (`?v16`):

```
cd /Users/andrew/.config/swiftbar/plugins
curl -fsSL "https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh?v16" -o apply.sh
chmod +x apply.sh
./apply.sh --apply
```

On one screen you want `overlay rev=v16` and `visual=bottom`. `quartzY=` should be near the screen height, not `0` or `24`. The Apple menu bar with battery can stay at the top; the extra dark strip should not. On two screens you want `two-screens, leaving extras on the display menu bar`.
