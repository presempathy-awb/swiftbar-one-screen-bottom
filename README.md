# SwiftBar — bottom on one screen

Two-monitor “bottom” is the menu bar on the **lower display**. This plugin starts a slim bottom strip **only when `NSScreen` count is 1**.

`apply.sh` is not in `~/.config/swiftbar` until you download it there.

## Install on the Mac

Paste this in **Terminal.app** at `~/.config/swiftbar`, not in a Linux cloud workspace:

```bash
cd /Users/andrew/.config/swiftbar
curl -fsSL https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh -o apply.sh
chmod +x apply.sh
./apply.sh --apply
```

Leave `ticker/sysbars-ticker` alone. “Ticker is already running, or its instance lock is unsafe” means that process is already up.
