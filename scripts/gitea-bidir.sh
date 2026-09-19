#!/usr/bin/env bash
# GitHub <-> Gitea for swiftbar-one-screen-bottom only.
# Gitea is SSH Host hidin. No tokens, no credential URLs.
set -euo pipefail

REPO="swiftbar-one-screen-bottom"
BRANCH="main"
HIDIN_URL="git@hidin:awb/${REPO}.git"
GITHUB_URL="https://github.com/presempathy-awb/${REPO}.git"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

commands() {
  cat <<EOF
1. git clone ${GITHUB_URL}
2. cd ${REPO}
3. git remote add hidin ${HIDIN_URL}
4. bash scripts/gitea-bidir.sh
EOF
}

die_commands() {
  local status="${1:-2}"
  commands >&2
  exit "$status"
}

forbid_tokens() {
  local name
  for name in \
    GITEA_TOKEN \
    GH_MIRROR_TOKEN \
    GH_TOKEN \
    GITHUB_TOKEN \
    GITEA_ACCESS_TOKEN \
    GITEA_PASSWORD \
    GH_PASSWORD \
    GITHUB_PASSWORD \
    GH_MIRROR_PASS
  do
    if [[ -n "${!name:-}" ]]; then
      echo "unset ${name} — hidin SSH only, no tokens" >&2
      die_commands 2
    fi
  done
}

url_has_embedded_credentials() {
  local url="$1"
  case "$url" in
    *oauth2:*|*x-access-token:*)
      return 0
      ;;
  esac
  [[ "$url" =~ ^https?://[^/@]+:[^/@]+@ ]]
}

forbid_tokens

case "${1:-}" in
  --help|-h)
    commands
    exit 0
    ;;
  --dry-run)
    printf 'github %s\n' "$GITHUB_URL"
    printf 'hidin %s\n' "$HIDIN_URL"
    exit 0
    ;;
  "")
    ;;
  *)
    echo "unknown option: $1" >&2
    die_commands 2
    ;;
esac

if url_has_embedded_credentials "$GITHUB_URL" || url_has_embedded_credentials "$HIDIN_URL"; then
  echo "refusing credential URL" >&2
  exit 2
fi

if [[ -d "$ROOT/.git" ]]; then
  if git -C "$ROOT" remote get-url hidin >/dev/null 2>&1; then
    existing="$(git -C "$ROOT" remote get-url hidin)"
    if [[ "$existing" != "$HIDIN_URL" ]]; then
      echo "hidin remote must be ${HIDIN_URL}" >&2
      exit 2
    fi
  else
    git -C "$ROOT" remote add hidin "$HIDIN_URL"
  fi
fi

export GIT_TERMINAL_PROMPT=0
if [[ -z "${GIT_SSH_COMMAND:-}" ]]; then
  export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=15"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git init --bare -q "$tmp/sync.git"
git --git-dir="$tmp/sync.git" remote add github "$GITHUB_URL"
git --git-dir="$tmp/sync.git" remote add hidin "$HIDIN_URL"

if ! git --git-dir="$tmp/sync.git" fetch --quiet github \
  "+refs/heads/${BRANCH}:refs/remotes/github/${BRANCH}"; then
  echo "GitHub fetch failed" >&2
  die_commands 1
fi

github_sha="$(git --git-dir="$tmp/sync.git" rev-parse "refs/remotes/github/${BRANCH}")"

hidin_ok=0
if git --git-dir="$tmp/sync.git" fetch --quiet hidin \
  "+refs/heads/${BRANCH}:refs/remotes/hidin/${BRANCH}"; then
  hidin_ok=1
fi

if [[ "$hidin_ok" -eq 0 ]]; then
  if git --git-dir="$tmp/sync.git" push hidin \
    "refs/remotes/github/${BRANCH}:refs/heads/${BRANCH}"; then
    echo "hidin ${BRANCH} <- GitHub ${github_sha:0:12}"
    exit 0
  fi
  echo "hidin SSH failed — Host hidin on the Mac, no tokens." >&2
  die_commands 1
fi

hidin_sha="$(git --git-dir="$tmp/sync.git" rev-parse "refs/remotes/hidin/${BRANCH}")"

if [[ "$github_sha" == "$hidin_sha" ]]; then
  echo "GitHub and hidin ${BRANCH} match ${github_sha:0:12}"
  exit 0
fi

if git --git-dir="$tmp/sync.git" merge-base --is-ancestor "$hidin_sha" "$github_sha"; then
  git --git-dir="$tmp/sync.git" push hidin "refs/remotes/github/${BRANCH}:refs/heads/${BRANCH}"
  echo "hidin ${BRANCH} <- GitHub ${github_sha:0:12}"
  exit 0
fi

if git --git-dir="$tmp/sync.git" merge-base --is-ancestor "$github_sha" "$hidin_sha"; then
  if git --git-dir="$tmp/sync.git" push github "refs/remotes/hidin/${BRANCH}:refs/heads/${BRANCH}"; then
    echo "GitHub ${BRANCH} <- hidin ${hidin_sha:0:12}"
    exit 0
  fi
  echo "hidin ${BRANCH} is ahead (${hidin_sha:0:12}). GitHub write is SSH on the Mac, not a token." >&2
  cat >&2 <<EOF
1. git remote add hidin ${HIDIN_URL}
2. git fetch hidin
3. git merge hidin/${BRANCH}
4. git push origin ${BRANCH}
EOF
  exit 1
fi

echo "diverged: GitHub ${github_sha:0:12} hidin ${hidin_sha:0:12} — will not force" >&2
exit 1
