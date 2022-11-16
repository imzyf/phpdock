#!/usr/bin/env bash
#
# Apply bin/.env.preference onto .env.example: for each key in
# .env.preference that also exists in .env.example, overwrite the
# .env.example value and mark the line with a comment noting the
# upstream default, so the override survives a re-run of
# bin/sync-upstream.sh.
#
# Usage: bin/apply-env-preference.sh

set -euo pipefail

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
PREFERENCE_FILE="${ROOT_DIR}/bin/.env.preference"
ENV_EXAMPLE="${ROOT_DIR}/.env.example"

if [[ ! -f "${PREFERENCE_FILE}" ]]; then
  exit 0
fi

echo "==> Applying bin/.env.preference onto .env.example"
tmp_file="$(mktemp)"
awk -v pref="${PREFERENCE_FILE}" '
  BEGIN {
    while ((getline line < pref) > 0) {
      n = index(line, "=")
      if (n > 0) {
        key = substr(line, 1, n - 1)
        if (key ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
          prefs[key] = substr(line, n + 1)
        }
      }
    }
    close(pref)
  }
  {
    n = index($0, "=")
    if (n > 0) {
      key = substr($0, 1, n - 1)
      if (key ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && (key in prefs)) {
        old_value = substr($0, n + 1)
        if (prefs[key] != old_value) {
          print "  - " key ": " old_value " -> " prefs[key] > "/dev/stderr"
          print "# OVERWRITTEN by bin/.env.preference (upstream default: " old_value ")"
          print key "=" prefs[key]
          next
        }
      }
    }
    print $0
  }
' "${ENV_EXAMPLE}" > "${tmp_file}"
mv "${tmp_file}" "${ENV_EXAMPLE}"
