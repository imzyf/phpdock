#!/usr/bin/env bash
#
# 从上游原文 .upstream/docker-compose.yml 修剪，只保留 SYNC_DIRS（见
# .sync-config.sh）中的服务，输出到项目根的 docker-compose.yml。
#
# 上游的 docker-compose.yml 使用 `include:` 模块化格式：每个服务是一个
# `<dir>/compose.yml`，根文件通过 include 汇总全部约 150 个服务，并在
# `volumes:` 段声明它们的命名卷。这里把不属于 SYNC_DIRS 的 include 条目
# 和命名卷剪掉，`networks:` 段原样保留。
#
# 使用方法：bin/generate-docker-compose.sh

set -euo pipefail

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
source "$(dirname "${BASH_SOURCE[0]}")/.sync-config.sh"

SRC_FILE="${ROOT_DIR}/.upstream/docker-compose.yml"
DEST_FILE="${ROOT_DIR}/docker-compose.yml"

if [[ ! -f "${SRC_FILE}" ]]; then
  echo "!! Skipping: ${SRC_FILE} not found" >&2
  exit 0
fi

echo "==> Pruning ${SRC_FILE} include/volumes not in SYNC_DIRS -> ${DEST_FILE}"
tmp_file="$(mktemp)"
awk -v names="${SYNC_DIRS[*]}" '
  BEGIN {
    n = split(names, arr, " ")
    for (i = 1; i <= n; i++) keepset[arr[i]] = 1
    section = ""
    keep = 1
  }
  # 空行原样保留，用于分隔各段。
  /^$/ { print; next }
  # 顶层段落标题（networks:/volumes:/include:）。
  /^[A-Za-z][A-Za-z0-9_-]*:$/ {
    section = substr($0, 1, length($0) - 1)
    keep = 1
    print
    next
  }
  # volumes 段：命名卷 `  <name>:`，仅保留 SYNC_DIRS 中的。
  section == "volumes" && /^  [A-Za-z0-9_.-]+:$/ {
    key = substr($0, 3, length($0) - 3)
    keep = (key in keepset)
    if (keep) print
    next
  }
  # include 段：每个条目以 `  - path: <dir>/compose.yml` 开始。
  section == "include" && /^  - path:/ {
    slash = index($3, "/")
    dir = (slash ? substr($3, 1, slash - 1) : $3)
    keep = (dir in keepset)
    if (keep) print
    next
  }
  # 段内其余（缩进）行，跟随其所属条目的保留状态。
  { if (keep) print }
' "${SRC_FILE}" > "${tmp_file}"
mv "${tmp_file}" "${DEST_FILE}"

echo "==> Done. Kept services: ${SYNC_DIRS[*]}"
