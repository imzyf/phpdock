#!/usr/bin/env bash
#
# Prune docker-compose.yml's build.args for workspace, php-fpm and
# php-worker down to just LARADOCK_PHP_VERSION, since those services
# build FROM a prebuilt image and no longer need upstream's
# feature-install args.
#
# Usage: bin/prune-build-args.sh

set -euo pipefail

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"
SERVICES=(workspace php-fpm php-worker)

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  exit 0
fi

for service in "${SERVICES[@]}"; do
  echo "==> Pruning build.args for ${service} in docker-compose.yml"
  tmp_file="$(mktemp)"
  awk -v service="${service}" '
    $0 ~ "^    " service ":[ \t]*$" { in_service = 1; print; next }
    /^    [A-Za-z0-9_-]+:[ \t]*$/ { in_service = 0; in_args = 0; print; next }
    in_service && in_args && /^          - / { next }
    in_service && in_args { in_args = 0 }
    in_service && /^        args:[ \t]*$/ {
      print
      print "          - LARADOCK_PHP_VERSION=${PHP_VERSION}"
      in_args = 1
      next
    }
    { print }
  ' "${COMPOSE_FILE}" > "${tmp_file}"
  mv "${tmp_file}" "${COMPOSE_FILE}"
done
