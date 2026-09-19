# SwiftBar — bottom on one screen

On the Mac:

```
1. cd /Users/andrew/.config/swiftbar
2. curl -fsSL https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh -o apply.sh
3. chmod +x apply.sh
4. ./apply.sh --apply
```

Gitea `awb/swiftbar-one-screen-bottom` both ways with GitHub. SSH Host `hidin` only. No tokens.

```
1. git clone https://github.com/presempathy-awb/swiftbar-one-screen-bottom.git
2. cd swiftbar-one-screen-bottom
3. git remote add hidin git@hidin:awb/swiftbar-one-screen-bottom.git
4. bash scripts/gitea-bidir.sh
```

Re-run 4 after commits on either side.
