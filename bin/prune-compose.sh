#!/usr/bin/env bash
#
# Prune docker-compose.yml volumes/services entries that aren't in
# IMAGES/EXTRA_COMPOSE_SERVICES (bin/.sync-config.sh), e.g. after syncing
# docker-compose.yml from upstream, which restores every image's
# service/volume. Also prunes lines left over in kept services that
# reference features tied to services not in IMAGES: postgres
# environment vars that only feed multi-DB init scripts (e.g.
# postgres/docker-entrypoint-initdb.d/init_gitlab_db.sh), and nginx's
# varnish backend port mapping.
#
# Usage: bin/prune-compose.sh

set -euo pipefail

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$(dirname "${BASH_SOURCE[0]}")/.sync-config.sh"

DOCKER_COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"

if [[ ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
  exit 0
fi

echo "==> Pruning docker-compose.yml volumes/services not in IMAGES"
tmp_file="$(mktemp)"
awk -v names="${IMAGES[*]} ${EXTRA_COMPOSE_SERVICES[*]}" '
  BEGIN {
    n = split(names, arr, " ")
    for (i = 1; i <= n; i++) keepset[arr[i]] = 1
    section = ""
    pending = ""
    keep = 1
  }
  /^[A-Za-z][A-Za-z0-9_-]*:$/ {
    printf "%s", pending
    pending = ""
    section = substr($0, 1, length($0) - 1)
    print
    keep = 1
    next
  }
  section == "volumes" && /^  [A-Za-z0-9_.-]+:$/ {
    key = substr($0, 3, length($0) - 3)
    keep = (key in keepset)
    if (keep) print
    next
  }
  section == "volumes" {
    if (keep) print
    next
  }
  section == "services" && ($0 == "" || /^### /) {
    pending = pending $0 "\n"
    next
  }
  section == "services" && /^    [A-Za-z0-9_.-]+:$/ {
    key = substr($0, 5, length($0) - 5)
    keep = (key in keepset)
    if (keep) { printf "%s", pending; print }
    pending = ""
    next
  }
  section == "services" {
    if (keep) print
    next
  }
  { print }
' "${DOCKER_COMPOSE_FILE}" > "${tmp_file}"
mv "${tmp_file}" "${DOCKER_COMPOSE_FILE}"

echo "==> Pruning docker-compose.yml lines for features not in IMAGES"
unused_line_patterns=(
  '(GITLAB_POSTGRES_|KEYCLOAK_POSTGRES_|SONARQUBE_POSTGRES_|POSTGRES_CONFLUENCE_)[A-Z_]*='
  'VARNISH_BACKEND_PORT'
)
tmp_file="$(mktemp)"
line_pattern="$(IFS='|'; echo "${unused_line_patterns[*]}")"
grep -vE -- "${line_pattern}" "${DOCKER_COMPOSE_FILE}" > "${tmp_file}"
mv "${tmp_file}" "${DOCKER_COMPOSE_FILE}"
