#!/usr/bin/env bash
#
# 用 bin/patch/<service>/compose.yml 覆盖 bin/.upstream/<service>/compose.yml 中
# 对应的键，生成到项目根的 <service>/compose.yml。
#
# 目录约定（同 generate-dockerfiles.sh）：patch 文件所在的子目录名即服务名 /
# 目标目录，例如
#   bin/patch/php-fpm/compose.yml    -> php-fpm/compose.yml
#   bin/patch/php-worker/compose.yml -> php-worker/compose.yml
#   bin/patch/workspace/compose.yml  -> workspace/compose.yml
#
# 覆盖语义（yq `*` 深合并，patch 作为右操作数覆盖上游）：
#   - 映射（map）递归深合并：patch 未提及的键（如 build.context、volumes、
#     expose）原样保留；
#   - 列表（array）整体替换：patch 提供的 build.args 会替换掉上游的整份列表，
#     而非追加。因此只用几行 patch 就能把上游 ~90 项 build args 收敛成自建
#     镜像所需的少数几项。
# 注意：yq 会把缩进规整为 2 空格并去掉空行（语义等价，仅格式规整）。
#
# 这些 compose.yml 是本项目定制版，已在 .sync-config.sh 的 EXCLUDE_GLOBS 中
# 排除，不会被上游同步覆盖，因此从 bin/.upstream + patch 单独生成落地。
#
# 依赖：yq v4（mikefarah/yq）。使用方法：bin/generate-service-compose.sh

set -euo pipefail

if ! command -v yq >/dev/null 2>&1; then
  echo "!! yq (mikefarah/yq v4) is required but not found in PATH" >&2
  exit 1
fi

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"

PATCH_DIR="${ROOT_DIR}/bin/patch"

shopt -s nullglob
patch_files=("${PATCH_DIR}"/*/compose.yml)
shopt -u nullglob

if (( ${#patch_files[@]} == 0 )); then
  echo "!! Skipping: no */compose.yml found in ${PATCH_DIR}" >&2
  exit 0
fi

for patch in "${patch_files[@]}"; do
  service="$(basename "$(dirname "${patch}")")"
  src="${ROOT_DIR}/bin/.upstream/${service}/compose.yml"
  dest="${ROOT_DIR}/${service}/compose.yml"

  if [[ ! -f "${src}" ]]; then
    echo "!! Skipping ${service} (upstream ${src#"${ROOT_DIR}"/} not found)" >&2
    continue
  fi
  if [[ ! -d "${ROOT_DIR}/${service}" ]]; then
    echo "!! Skipping ${service} (target dir ${service}/ not found)" >&2
    continue
  fi

  echo "==> Merging bin/patch/${service}/compose.yml into ${service}/compose.yml"

  # `. as $item ireduce ({}; . * $item)`：按顺序把两个文档深合并成一个。
  # 上游为左操作数、patch 为右操作数——map 递归合并、array 整体替换。
  tmp_file="$(mktemp)"
  yq eval-all '. as $item ireduce ({}; . * $item)' "${src}" "${patch}" > "${tmp_file}"
  mv "${tmp_file}" "${dest}"

  echo "==> Wrote ${service}/compose.yml"
done

echo "==> Done."
