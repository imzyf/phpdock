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
# shellcheck source=bin/.sync-config.sh
source "${SCRIPT_DIR}/.sync-config.sh"

CACHE_DIR="${LCC_SYNC_CACHE_DIR:-${SCRIPT_DIR}/.cache/upstream}"
CACHE_TTL_SECONDS="${LCC_SYNC_CACHE_TTL:-86400}"
CACHE_MARKER="${CACHE_DIR}.last-clone"
clone_dir="${CACHE_DIR}"

cache_is_fresh() {
  [[ -d "${clone_dir}/.git" && -f "${CACHE_MARKER}" ]] || return 1
  (( EPOCHSECONDS - $(<"${CACHE_MARKER}") < CACHE_TTL_SECONDS ))
}

if cache_is_fresh; then
  echo "==> Reusing cached clone at ${clone_dir} (younger than ${CACHE_TTL_SECONDS}s)"
else
  # 每个我们想要检出的路径：同步目录和独立文件（取 SYNC_FILES 条目
  # ":" 前的上游路径部分）。
  sparse_paths=()
  for p in "${SYNC_DIRS[@]}" "${SYNC_FILES[@]}"; do
    sparse_paths+=( "/${p%%:*}" )
  done
  echo "==> Cloning ${UPSTREAM_REPO} (${UPSTREAM_BRANCH}: ${sparse_paths[*]#/})"
  rm -rf "${clone_dir}"
  mkdir -p "${clone_dir}"
  git clone --depth=1 --filter=blob:none --sparse -q \
    --branch "${UPSTREAM_BRANCH}" "${UPSTREAM_REPO}" "${clone_dir}"
  git -C "${clone_dir}" sparse-checkout set --no-cone "${sparse_paths[@]}"
  echo "${EPOCHSECONDS}" > "${CACHE_MARKER}"
fi

# nullglob：空目录下 glob 展开为空而不是留下字面量 "*"，
# 配合下面的数量检查把「上游目录空了」变成显式报错。
shopt -s dotglob nullglob

# 按仓库根的相对路径（含目录前缀）匹配 EXCLUDE_GLOBS。
# 不能交给 rsync --exclude：这里逐个顶层条目传输，rsync 只看得到
# 传输根下的裸文件名，带 "/" 的模式锚定在传输根，永不命中。
is_excluded() {
  local path="$1" glob
  for glob in "${EXCLUDE_GLOBS[@]}"; do
    # 右侧不加引号才按 glob 匹配
    # shellcheck disable=SC2053
    [[ "${path}" == ${glob} ]] && return 0
  done
  return 1
}

for dir in "${SYNC_DIRS[@]}"; do
  src="${clone_dir}/${dir}"
  # 配置里的目录在上游没了 = 同步已失效，直接失败，别留下过期的本地副本。
  if [[ ! -d "${src}" ]]; then
    echo "!! ${dir} not found upstream - update SYNC_DIRS in bin/.sync-config.sh" >&2
    exit 1
  fi
  entries=( "${src}"/* )
  if (( ${#entries[@]} == 0 )); then
    echo "!! ${dir} is empty upstream" >&2
    exit 1
  fi
  echo "==> Refreshing upstream files in ${dir}/ (local-only files preserved)"
  mkdir -p "${ROOT_DIR}/${dir}"
  # 刷新原位置上游拥有的每个条目。仅存在于本地的条目永远不会被触碰。
  for entry in "${entries[@]}"; do
    name="${entry##*/}"
    # 被排除的条目连同本地副本一起放过，不删也不覆盖。
    if is_excluded "${dir}/${name}"; then
      echo "  - ${dir}/${name} (excluded)"
      continue
    fi
    rm -rf "${ROOT_DIR:?}/${dir}/${name}"
    rsync -aq "${entry}" "${ROOT_DIR}/${dir}/"
    echo "  - ${dir}/${name}"
  done
done

# 每项是 "上游路径" 或 "上游路径:本地路径"；没有 ":" 时源和目标
# 路径相同（原样镜像），写了 ":" 则改名落地。
for entry in "${SYNC_FILES[@]}"; do
  src_rel="${entry%%:*}"
  dest_rel="${entry#*:}"
  src="${clone_dir}/${src_rel}"
  # 同 SYNC_DIRS：配置里的文件上游没了就是同步失效，直接失败。
  if [[ ! -f "${src}" ]]; then
    echo "!! ${src_rel} not found upstream - update SYNC_FILES in bin/.sync-config.sh" >&2
    exit 1
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
