#!/usr/bin/env bash
#
# 合并 images/.env.laradock 与 images/.env.laradock.preference，输出去重后的
# NAME=value 行（每行一个）到 stdout。后读的文件覆盖同名变量，所以
# preference 胜出。空值行（NAME=，Dockerfile 里没默认值）跳过，避免
# 传出空的 --build-arg。首次出现的顺序被保留，输出稳定可 diff。
#
# 用法: .github/scripts/build-args.sh
#   CI（laradock-image.yml）消费它的输出，make test-args 验证其契约。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

shopt -s extglob   # 下面用 +([[:space:]]) 剥行尾空白

declare -A args=()
order=()
for f in "${ROOT_DIR}/images/.env.laradock" "${ROOT_DIR}/images/.env.laradock.preference"; do
  [[ -f "${f}" ]] || continue
  # `|| [[ -n ${line} ]]`：preference 是手改的，末尾可能没有换行，
  # 只靠 read 的返回值会把最后一行丢掉。
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="${line%%+([[:space:]])}"
    [[ -z "${line}" ]] && continue
    name="${line%%=*}"
    value="${line#*=}"
    [[ -z "${value}" ]] && continue
    [[ -v args["${name}"] ]] || order+=("${name}")
    args["${name}"]="${value}"
  done < "${f}"
done

for name in "${order[@]}"; do
  printf '%s=%s\n' "${name}" "${args[${name}]}"
done
