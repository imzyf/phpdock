#!/usr/bin/env bash
#
# 把 bin/patch/*-Dockerfile 复制到对应服务目录的 Dockerfile。
#
# 命名约定：patch 文件名去掉 `-Dockerfile` 后缀即目标目录，例如
#   bin/patch/php-fpm-Dockerfile    -> php-fpm/Dockerfile
#   bin/patch/php-worker-Dockerfile -> php-worker/Dockerfile
#   bin/patch/workspace-Dockerfile  -> workspace/Dockerfile
#
# 这些 Dockerfile 是本项目定制版（改用自建镜像），已在 .sync-config.sh 的
# EXCLUDE_GLOBS 中排除，不会被上游同步覆盖，因此从 patch 单独落地。
#
# 使用方法：bin/generate-dockerfiles.sh

set -euo pipefail

ROOT_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"

PATCH_DIR="${ROOT_DIR}/bin/patch"

shopt -s nullglob
patch_files=("${PATCH_DIR}"/*-Dockerfile)
shopt -u nullglob

if (( ${#patch_files[@]} == 0 )); then
  echo "!! Skipping: no *-Dockerfile found in ${PATCH_DIR}" >&2
  exit 0
fi

for src in "${patch_files[@]}"; do
  name="$(basename "${src}")"
  dir="${name%-Dockerfile}"
  dest="${ROOT_DIR}/${dir}/Dockerfile"

  if [[ ! -d "${ROOT_DIR}/${dir}" ]]; then
    echo "!! Skipping ${name} (target dir ${dir}/ not found)" >&2
    continue
  fi

  cp "${src}" "${dest}"
  echo "==> Copied bin/patch/${name} -> ${dir}/Dockerfile"
done

echo "==> Done."
