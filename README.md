# SwiftBar — bottom on one screen

One display: SwiftBar extras leave the top menu bar and a strip sits on the physical bottom (Dock may overlap it). App windows stay above the strip. Fullscreen can cover it. × closes it, brings SwiftBar back, and keeps the strip closed. ⬇ in SwiftBar shows only while it is down.

Stacked displays (one below the other): strip hides. Your lower-display menu bar stays.

```
cd /Users/andrew/.config/swiftbar/plugins
curl -fsSL "https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh?v6" -o apply.sh
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
