#!/usr/bin/env bash
#
# PostgreSQL 18+ images moved to a pg_ctlcluster-style data layout and
# expect a volume mounted at /var/lib/postgresql (with a version-specific
# subdirectory created inside it), not /var/lib/postgresql/data.
# See: https://github.com/docker-library/postgres/pull/1259
#
# Usage: bin/patch-postgres-data-path.sh

set -euo pipefail

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
ENV_EXAMPLE="${ROOT_DIR}/.env.example"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  exit 0
fi

postgres_version="$(grep -m1 '^POSTGRES_VERSION=' "${ENV_EXAMPLE}" | cut -d= -f2-)"
major_version="${postgres_version%%[^0-9]*}"

if [[ -z "${major_version}" ]] || (( major_version < 18 )); then
  exit 0
fi

echo "==> Patching docker-compose.yml postgres volume mount for PostgreSQL ${postgres_version}"
tmp_file="$(mktemp)"
awk '{
  gsub(/\$\{DATA_PATH_HOST\}\/postgres:\/var\/lib\/postgresql\/data/, "${DATA_PATH_HOST}/postgres:/var/lib/postgresql")
  print
}' "${COMPOSE_FILE}" > "${tmp_file}"
mv "${tmp_file}" "${COMPOSE_FILE}"
