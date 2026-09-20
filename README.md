# SwiftBar — bottom on one screen

The macOS menu bar cannot host extras at the bottom. This overlay parks SwiftBar, hides the top menu bar while it is up, and draws the plugins on a strip at the physical bottom of the lowest display (the bottom screen). Dock may overlap it. × restores the top menu bar and SwiftBar.

Do not refresh SwiftBar to update this. Re-run apply (`?v10`):

```
cd /Users/andrew/.config/swiftbar/plugins
curl -fsSL "https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh?v10" -o apply.sh
chmod +x apply.sh
./apply.sh --apply
```

Expect: “SwiftBar extras are parked off the top menu bar.” `/tmp/swiftbar-bottom-overlay.out` should show `overlay rev=v10`, `topHalf=false`, and `y=` equal to `screenMinY` (bottom), not the top of the screen.

Gitea `awb/swiftbar-one-screen-bottom` both ways with GitHub. SSH Host `hidin` only. No tokens.

```
git clone https://github.com/presempathy-awb/swiftbar-one-screen-bottom.git
cd swiftbar-one-screen-bottom
git remote add hidin git@hidin:awb/swiftbar-one-screen-bottom.git
bash scripts/gitea-bidir.sh
```

Re-run `bash scripts/gitea-bidir.sh` after commits on either side.
