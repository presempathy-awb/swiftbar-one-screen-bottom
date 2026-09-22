# SwiftBar — bottom of a single screen

On two monitors those extras already sit on the lower display’s menu bar. This overlay stays out of that. It only runs when there is **one** screen, and then it draws the extras along the physical bottom edge.

× brings SwiftBar back. Do not refresh SwiftBar to update this. Re-run apply (`?v15`):

```
cd /Users/andrew/.config/swiftbar/plugins
curl -fsSL "https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh?v15" -o apply.sh
chmod +x apply.sh
./apply.sh --apply
```

On one screen you want `overlay rev=v15`, `topHalf=false`, `y=` equal to `screenMinY`. On two screens you want `two-screens, leaving extras on the display menu bar` and the extras stay where they already go.
