# SwiftBar — bottom on one screen

One display: strip sits on the physical bottom of the screen (Dock may overlap it). App windows stay above it. Fullscreen can cover it. SwiftBar’s own menu extras still live in the system menu bar; this overlay is the bottom strip. × closes it and keeps it closed. ⬇ in SwiftBar shows only while it is down.

Two displays: strip hides. Your lower-display menu bar stays.

```
cd /Users/andrew/.config/swiftbar/plugins
curl -fsSL "https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh?v5" -o apply.sh
chmod +x apply.sh
./apply.sh --apply
```

Gitea `awb/swiftbar-one-screen-bottom` both ways with GitHub. SSH Host `hidin` only. No tokens.

```
git clone https://github.com/presempathy-awb/swiftbar-one-screen-bottom.git
cd swiftbar-one-screen-bottom
git remote add hidin git@hidin:awb/swiftbar-one-screen-bottom.git
bash scripts/gitea-bidir.sh
```

Re-run `bash scripts/gitea-bidir.sh` after commits on either side.
