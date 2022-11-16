#!/usr/bin/env bash
#
# Remove .env.example keys not referenced anywhere in docker-compose.yml,
# along with their description comments and any subsection banner left
# with no keys under it. COMPOSE_* keys are always kept, since those are
# read by the docker compose CLI itself rather than referenced inside
# docker-compose.yml.
#
# Usage: bin/prune-unused-env.sh

set -euo pipefail

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
ENV_EXAMPLE="${ROOT_DIR}/.env.example"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  exit 0
fi

echo "==> Removing .env.example keys not referenced in docker-compose.yml"
tmp_file="$(mktemp)"
awk -v compose="${COMPOSE_FILE}" '
  BEGIN {
    while ((getline line < compose) > 0) {
      while (match(line, /\$\{[A-Za-z_][A-Za-z0-9_]*/)) {
        v = substr(line, RSTART + 2, RLENGTH - 2)
        used[v] = 1
        line = substr(line, RSTART + RLENGTH)
      }
    }
    close(compose)
  }
  function flush_comment_buf() {
    for (i = 1; i <= cn; i++) { bn++; block[bn] = cbuf[i] }
    cn = 0
  }
  function finalize_block() {
    flush_comment_buf()
    if (block_keep) { for (i = 1; i <= bn; i++) print block[i] }
    bn = 0
    block_keep = 0
  }
  {
    line = $0
    if (line ~ /^#{4,}$/ || (line ~ /^#{4,} / && line ~ / #{4,}$/)) {
      if (in_block) finalize_block()
      in_block = 0
      print line
      next
    }
    if (line ~ /^### /) {
      if (in_block) finalize_block()
      in_block = 1
      bn++; block[bn] = line
      next
    }
    if (!in_block) { print line; next }
    if (line ~ /^[ \t]*$/) {
      flush_comment_buf()
      bn++; block[bn] = line
      next
    }
    if (line ~ /^[ \t]*#/) {
      cn++; cbuf[cn] = line
      next
    }
    if (match(line, /^[A-Za-z_][A-Za-z0-9_]*=/)) {
      key = substr(line, 1, RLENGTH - 1)
      if ((key in used) || key ~ /^COMPOSE_/) {
        flush_comment_buf()
        bn++; block[bn] = line
        block_keep = 1
      } else {
        cn = 0
        removed++
      }
      next
    }
    flush_comment_buf()
    bn++; block[bn] = line
  }
  END {
    if (in_block) finalize_block()
    print "  - removed " removed+0 " unused keys" > "/dev/stderr"
  }
' "${ENV_EXAMPLE}" | cat -s > "${tmp_file}"
mv "${tmp_file}" "${ENV_EXAMPLE}"
