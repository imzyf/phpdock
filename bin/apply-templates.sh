#!/usr/bin/env bash
#
# Apply bin/templates/ onto the repo root, file for file by matching
# relative path (e.g. bin/templates/php-fpm/Dockerfile onto
# php-fpm/Dockerfile, to point FROM at a prebuilt image instead of
# building from upstream's Dockerfile), so local customizations survive
# a re-run of bin/sync-upstream.sh.
#
# Usage: bin/apply-templates.sh

set -euo pipefail

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
TEMPLATES_DIR="${ROOT_DIR}/bin/templates"

while IFS= read -r -d '' tmpl; do
  rel="${tmpl#"${TEMPLATES_DIR}"/}"
  target="${ROOT_DIR}/${rel}"
  if [[ -f "${target}" ]]; then
    echo "==> Applying bin/templates/${rel} onto ${rel}"
    cp "${tmpl}" "${target}"
  else
    echo "  ! ${target} not found, skipping bin/templates/${rel}" >&2
  fi
done < <(find "${TEMPLATES_DIR}" -type f -print0)

echo "==> Done. Review with: git diff"
