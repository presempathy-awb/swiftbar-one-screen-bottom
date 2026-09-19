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
echo "GitHub -> Gitea ongoing: repo secret GITEA_TOKEN on presempathy-awb/${REPO}"
