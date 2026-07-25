#!/usr/bin/env bash
#
# 从上游仓库（配置见 .sync-config.sh）同步文件到本项目。
#
# 对于 SYNC_DIRS 中的每个目录（见 .sync-config.sh），上游拥有的文件会被
# 刷新到原位置。你在旁边添加的本地文件不会被触碰，这样每次同步后可以用
# `git diff` 看到上游的更改，然后手动移植。
#
# 上游的克隆是稀疏的（仅限 SYNC_DIRS + SYNC_FILES），并在 CACHE_DIR 下
# 被缓存 CACHE_TTL_SECONDS（默认 1 天），所以同一天重新运行会重用它。
# 删除 CACHE_DIR 或设置 LCC_SYNC_CACHE_TTL=0 来强制重新克隆。
#
# 使用方法：bin/sync-upstream.sh
#
# 环境变量覆盖：
#   LCC_SYNC_CACHE_DIR   缓存的上游克隆的位置
#   LCC_SYNC_CACHE_TTL   缓存生命周期（秒）(0 = 始终重新克隆)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
source "${SCRIPT_DIR}/.sync-config.sh"

CACHE_DIR="${LCC_SYNC_CACHE_DIR:-${SCRIPT_DIR}/.cache/upstream}"
CACHE_TTL_SECONDS="${LCC_SYNC_CACHE_TTL:-86400}"
CACHE_MARKER="${CACHE_DIR}.last-clone"
clone_dir="${CACHE_DIR}"

cache_is_fresh() {
  [[ -d "${clone_dir}/.git" && -f "${CACHE_MARKER}" ]] || return 1
  local age=$(( $(date +%s) - $(cat "${CACHE_MARKER}") ))
  (( age < CACHE_TTL_SECONDS ))
}

if cache_is_fresh; then
  echo "==> Reusing cached clone at ${clone_dir} (younger than ${CACHE_TTL_SECONDS}s)"
else
  # 每个我们想要检出的路径：同步目录和独立文件（取 SYNC_FILES 条目
  # ":" 前的上游路径部分）。受保护，以便空数组在 -u 下是安全的。
  sparse_paths=()
  for p in "${SYNC_DIRS[@]:-}" "${SYNC_FILES[@]:-}"; do
    [[ -n "${p}" ]] && sparse_paths+=( "/${p%%:*}" )
  done
  echo "==> Cloning ${UPSTREAM_REPO} (${UPSTREAM_BRANCH}: ${sparse_paths[*]#/})"
  rm -rf "${clone_dir}"
  mkdir -p "${clone_dir}"
  git clone --depth=1 --filter=blob:none --sparse -q \
    --branch "${UPSTREAM_BRANCH}" "${UPSTREAM_REPO}" "${clone_dir}"
  git -C "${clone_dir}" sparse-checkout set --no-cone "${sparse_paths[@]}"
  date +%s > "${CACHE_MARKER}"
fi

shopt -s dotglob extglob

# EXCLUDE_GLOBS 语义是「完全不碰」：不从上游复制，也不删本地同名文件，所以
# 下面的循环整条跳过。（rsync --exclude 做不到：那里是先 rm 再 rsync，只排除
# 复制会把本地手写的 php-fpm/Dockerfile 删掉而不补回来。）
#
# 把数组压成一个 extglob 备选式 @(a|b|c)；空数组得到 @()，只匹配空串即谁都不保护。
# 只对 SYNC_DIRS 下的顶级条目（<dir>/<name>）生效，更深的路径不支持。
protected="@($(IFS='|'; printf '%s' "${EXCLUDE_GLOBS[*]:-}"))"

for dir in "${SYNC_DIRS[@]}"; do
  src="${clone_dir}/${dir}"
  if [[ ! -d "${src}" ]]; then
    echo "!! Skipping ${dir} (not found upstream)"
    continue
  fi
  echo "==> Refreshing upstream files in ${dir}/ (local-only files preserved)"
  mkdir -p "${ROOT_DIR}/${dir}"
  # 刷新原位置上游拥有的每个条目。仅存在于本地的条目永远不会被触碰。
  for entry in "${src}"/*; do
    name="$(basename "${entry}")"
    # shellcheck disable=SC2053  # 右侧要当 glob 用，不能加引号
    if [[ "${dir}/${name}" == $protected ]]; then
      echo "  · ${dir}/${name} (protected, left as-is)"
      continue
    fi
    rm -rf "${ROOT_DIR:?}/${dir}/${name}"
    rsync -aq "${entry}" "${ROOT_DIR}/${dir}/"
    echo "  - ${dir}/${name}"
  done
done

# 每项是 "上游路径" 或 "上游路径:本地路径"；没有 ":" 时源和目标
# 路径相同（原样镜像），写了 ":" 则改名落地。
for entry in "${SYNC_FILES[@]:-}"; do
  [[ -n "${entry}" ]] || continue
  src_rel="${entry%%:*}"
  dest_rel="${entry#*:}"
  src="${clone_dir}/${src_rel}"
  if [[ ! -f "${src}" ]]; then
    echo "!! Skipping ${src_rel} (not found upstream)"
    continue
  fi
  if [[ "${src_rel}" == "${dest_rel}" ]]; then
    echo "==> Mirroring ${src_rel}"
  else
    echo "==> Mirroring ${src_rel} -> ${dest_rel}"
  fi
  mkdir -p "$(dirname "${ROOT_DIR}/${dest_rel}")"
  cp "${src}" "${ROOT_DIR}/${dest_rel}"
done

echo "==> Done. Review upstream changes with: git diff"
