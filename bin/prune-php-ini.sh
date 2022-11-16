#!/usr/bin/env bash
#
# Remove php-fpm/php*.ini files not matching .env.example's PHP_VERSION,
# since only one is ever mounted (see docker-compose.yml).
#
# Usage: bin/prune-php-ini.sh

set -euo pipefail

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
ENV_EXAMPLE="${ROOT_DIR}/.env.example"
PHP_FPM_DIR="${ROOT_DIR}/php-fpm"

if [[ ! -d "${PHP_FPM_DIR}" ]]; then
  exit 0
fi

php_version="$(grep -m1 '^PHP_VERSION=' "${ENV_EXAMPLE}" | cut -d= -f2-)"
echo "==> Removing php-fpm/php*.ini files not matching PHP_VERSION=${php_version}"
for ini in "${PHP_FPM_DIR}"/php*.ini; do
  [[ -e "${ini}" ]] || continue
  if [[ "$(basename "${ini}")" != "php${php_version}.ini" ]]; then
    echo "  - removing php-fpm/$(basename "${ini}")"
    rm -f "${ini}"
  fi
done
