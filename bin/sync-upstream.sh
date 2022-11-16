#!/usr/bin/env bash
#
# Sync php-fpm, php-worker, and workspace files, plus .env.example, from
# upstream laradock/laradock (master branch).
#
# Clones laradock/laradock (sparse, just the dirs/files below) into a
# persistent local cache dir and mirrors each one into the matching path
# at the repo root, unmodified (this repo keeps them unmodified, see
# README.md).
#
# The clone is cached under CACHE_DIR for CACHE_TTL_SECONDS (default 1
# day), so re-running this script the same day reuses the cached clone
# instead of cloning upstream again. Delete CACHE_DIR (or set
# PHPDOCK_SYNC_CACHE_TTL=0) to force a fresh clone.
#
# After syncing, run bin/prune-compose.sh to remove docker-compose.yml
# volumes/services entries not in IMAGES, then bin/apply-templates.sh to
# re-apply bin/templates/ (local .env.preference values and Dockerfile
# overrides) on top, since syncing otherwise reverts everything to
# upstream defaults. See: make sync
#
# Usage: bin/sync-upstream.sh

set -euo pipefail

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$(dirname "${BASH_SOURCE[0]}")/.sync-config.sh"

CACHE_DIR="${PHPDOCK_SYNC_CACHE_DIR:-${ROOT_DIR}/bin/.cache/laradock-upstream}"
CACHE_TTL_SECONDS="${PHPDOCK_SYNC_CACHE_TTL:-86400}"
CACHE_MARKER="${CACHE_DIR}.last-clone"
clone_dir="${CACHE_DIR}"

cache_is_fresh() {
  [[ -d "${clone_dir}/.git" && -f "${CACHE_MARKER}" ]] || return 1
  local age=$(( $(date +%s) - $(cat "${CACHE_MARKER}") ))
  (( age < CACHE_TTL_SECONDS ))
}

if cache_is_fresh; then
  echo "==> Reusing cached clone at ${clone_dir} (younger than ${CACHE_TTL_SECONDS}s)"
else
  echo "==> Cloning laradock/laradock (${IMAGES[*]} ${FILES[*]})"
  rm -rf "${clone_dir}"
  mkdir -p "${clone_dir}"
  git clone --depth=1 --filter=blob:none --sparse -q "${UPSTREAM_REPO}" "${clone_dir}"
  git -C "${clone_dir}" sparse-checkout set --no-cone "${IMAGES[@]/#//}" "${FILES[@]/#//}"
  date +%s > "${CACHE_MARKER}"
fi

shopt -s dotglob

for image in "${IMAGES[@]}"; do
  echo "==> Mirroring files into ${image}/"
  mkdir -p "${ROOT_DIR}/${image}"
  rm -rf "${ROOT_DIR}/${image:?}"/*
  for f in "${clone_dir}/${image}"/*; do
    name="$(basename "${f}")"
    cp -R "${f}" "${ROOT_DIR}/${image}/${name}"
    echo "  - ${image}/${name}"
  done
done

for file in "${FILES[@]}"; do
  echo "==> Mirroring ${file}"
  cp "${clone_dir}/${file}" "${ROOT_DIR}/${file}"
done

echo "==> Done. Review with: git diff"
