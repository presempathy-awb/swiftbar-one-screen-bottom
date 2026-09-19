#!/usr/bin/env bash
# One-time GitHub <-> Gitea setup for swiftbar-one-screen-bottom only.
# Needs GITEA_TOKEN (Gitea write) and GH_MIRROR_TOKEN (GitHub write).
set -euo pipefail

GITEA_HOST="${GITEA_HOST:-https://git.telpher.stream}"
GITEA_OWNER="${GITEA_OWNER:-awb}"
REPO="swiftbar-one-screen-bottom"
GITHUB="https://github.com/presempathy-awb/${REPO}.git"
GITEA="${GITEA_HOST}/${GITEA_OWNER}/${REPO}.git"

if [[ -z "${GITEA_TOKEN:-}" || -z "${GH_MIRROR_TOKEN:-}" ]]; then
  echo "export GITEA_TOKEN=... GH_MIRROR_TOKEN=..." >&2
  exit 2
fi

api() {
  local method="$1" path="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -fsS -X "$method" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$data" \
      "${GITEA_HOST}/api/v1${path}"
  else
    curl -fsS -X "$method" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      "${GITEA_HOST}/api/v1${path}"
  fi
}

if ! curl -fsS -H "Authorization: token ${GITEA_TOKEN}" \
  "${GITEA_HOST}/api/v1/repos/${GITEA_OWNER}/${REPO}" >/dev/null 2>&1; then
  api POST "/repos/migrate" "$(cat <<EOF
{
  "clone_addr": "${GITHUB}",
  "repo_name": "${REPO}",
  "repo_owner": "${GITEA_OWNER}",
  "mirror": false,
  "private": false,
  "service": "git",
  "description": "SwiftBar one-screen bottom strip. Bidirectional with GitHub presempathy-awb/${REPO}."
}
EOF
)" >/dev/null
  echo "created ${GITEA}"
else
  echo "exists ${GITEA}"
fi

mirrors="$(api GET "/repos/${GITEA_OWNER}/${REPO}/push_mirrors" || echo '[]')"
if ! grep -Fq 'github.com/presempathy-awb/swiftbar-one-screen-bottom' <<<"$mirrors"; then
  api POST "/repos/${GITEA_OWNER}/${REPO}/push_mirrors" "$(cat <<EOF
{
  "interval": "8h0m0s",
  "remote_address": "${GITHUB}",
  "remote_username": "presempathy-awb",
  "remote_password": "${GH_MIRROR_TOKEN}",
  "sync_on_commit": true
}
EOF
)" >/dev/null
  echo "added Gitea push-mirror to GitHub (Gitea -> GitHub)"
else
  echo "Gitea push-mirror already present"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone --mirror "$GITHUB" "$tmp/repo.git"
git -C "$tmp/repo.git" push --mirror "https://oauth2:${GITEA_TOKEN}@${GITEA_HOST#https://}/${GITEA_OWNER}/${REPO}.git"
echo "pushed GitHub -> Gitea"

workflow="$(cat <<'YML'
name: sync-gitea
on:
  push:
    branches: [main]
  workflow_dispatch:
jobs:
  gitea:
    if: github.repository == 'presempathy-awb/swiftbar-one-screen-bottom'
    runs-on: ubuntu-latest
    concurrency:
      group: sync-gitea
      cancel-in-progress: false
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Push main to Gitea
        env:
          GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
        run: |
          set -euo pipefail
          if [[ -z "${GITEA_TOKEN:-}" ]]; then
            echo "Set GitHub secret GITEA_TOKEN for this repo only." >&2
            exit 1
          fi
          git push --porcelain \
            "https://oauth2:${GITEA_TOKEN}@git.telpher.stream/awb/swiftbar-one-screen-bottom.git" \
            HEAD:refs/heads/main
YML
)"
content="$(printf '%s' "$workflow" | python3 -c 'import base64,sys; print(base64.b64encode(sys.stdin.buffer.read()).decode())')"
wf_api="https://api.github.com/repos/presempathy-awb/${REPO}/contents/.github/workflows/sync-gitea.yml"
sha="$(curl -fsS -H "Authorization: Bearer ${GH_MIRROR_TOKEN}" -H "Accept: application/vnd.github+json" "$wf_api" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sha",""))' || true)"
body="$(python3 - "$content" "$sha" <<'PY'
import json, sys
content, sha = sys.argv[1], sys.argv[2]
payload = {"message": "Add Gitea sync workflow for this repo only", "content": content}
if sha:
    payload["sha"] = sha
print(json.dumps(payload))
PY
)"
curl -fsS -X PUT \
  -H "Authorization: Bearer ${GH_MIRROR_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  -d "$body" \
  "$wf_api" >/dev/null
echo "GitHub -> Gitea ongoing: repo secret GITEA_TOKEN on presempathy-awb/${REPO}"
