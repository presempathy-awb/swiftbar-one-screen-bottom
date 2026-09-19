# SwiftBar — bottom on one screen

On the Mac:

```
1. cd /Users/andrew/.config/swiftbar
2. curl -fsSL https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/macos-install.sh -o apply.sh
3. chmod +x apply.sh
4. ./apply.sh --apply
```

Gitea `awb/swiftbar-one-screen-bottom` only (both ways with GitHub):

```
1. export GITEA_TOKEN=... GH_MIRROR_TOKEN=...
2. curl -fsSL https://raw.githubusercontent.com/presempathy-awb/swiftbar-one-screen-bottom/main/scripts/gitea-bidir.sh | bash
```

Re-run 2 after GitHub commits. Gitea commits push-mirror to GitHub on their own.
