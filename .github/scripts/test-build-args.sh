#!/usr/bin/env bash
#
# .github/scripts/build-args.sh 的回归测试，三部分：
#   1. 输出契约：拿仓库里真实的两个 env 文件跑，检查输出干净、幂等、与 cwd 无关
#   2. fixture：在临时目录里用假 env 文件覆盖解析与合并的边界情况
#   3. 交叉检查：输出的每个 NAME 都必须是某个 Dockerfile 声明过的 ARG
#
# 用法: .github/scripts/test-build-args.sh   （或 make test-args）

# 断言失败要继续跑完，所以不开 -e；末尾按失败计数退出。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_ARGS="${SCRIPT_DIR}/build-args.sh"

failures=0

pass() { printf 'ok   - %s\n' "$1"; }

fail() {
  printf 'FAIL - %s\n' "$1" >&2
  failures=$((failures + 1))
}

# check <描述> <期望> <实际>
check() {
  if [[ "$3" == "$2" ]]; then
    pass "$1"
  else
    fail "$1"
    printf '       want:\n%s\n       got:\n%s\n' "$2" "$3" >&2
  fi
}

echo '## 1. 输出契约（真实 .env.laradock + .env.laradock.preference）'

out="$("${BUILD_ARGS}")" || fail 'build-args.sh 退出码非 0'

check '每行都是 NAME=value' '' "$(grep -v '=' <<< "${out}")"
check '没有空值行（NAME=）' '' "$(grep '=$' <<< "${out}")"
check '没有注释残留' '' "$(grep '#' <<< "${out}")"
check '没有行尾空白' '' "$(grep '[[:space:]]$' <<< "${out}")"
check '没有重复的 NAME' '' "$(cut -d= -f1 <<< "${out}" | sort | uniq -d)"
check '同样的输入输出稳定（可 diff）' "${out}" "$("${BUILD_ARGS}")"
# ROOT_DIR 由脚本所在位置推出，不是 $PWD，所以从任何目录调用结果都该一样。
check '与调用时的 cwd 无关' "${out}" "$(cd / && "${BUILD_ARGS}")"

echo
echo '## 2. fixture（临时目录 + 假 env 文件）'

FIXTURE="$(mktemp -d)/fixture"
trap 'rm -rf "${FIXTURE%/fixture}"' EXIT
mkdir -p "${FIXTURE}/.github/scripts" "${FIXTURE}/images"
# 用软链而不是 cp：测的永远是仓库里当前那份脚本。
# BASH_SOURCE 是「调用时的路径」，所以它算出的 ROOT_DIR 是 fixture 而不是本仓库。
ln -s "${BUILD_ARGS}" "${FIXTURE}/.github/scripts/build-args.sh"

cat > "${FIXTURE}/images/.env.laradock" <<'EOF'
A=1
B=
C=3
# 整行注释
X=2   # 行尾注释
D=has spaces here
F=url#frag
A=dup-in-same-file
EOF

# 故意不带结尾换行：preference 是手改的文件，最后一行常常这样。
printf 'A=overridden-by-pref\nG=only-in-pref' > "${FIXTURE}/images/.env.laradock.preference"

# 逐条对应：B= 空值跳过；C 行尾空白剥掉；整行注释和空行跳过；X 行尾注释剥掉；
# D 带空格的值整段保留；A 被 preference 覆盖但仍占第一次出现的位置；G 追加在末尾。
# F=url 是已知取舍：值里的 # 一律当注释截断（现在没有这种值，写在这里防回归时误以为是 bug）。
check '合并 + 去重 + 覆盖' 'A=overridden-by-pref
C=3
X=2
D=has spaces here
F=url
G=only-in-pref' "$(cd "${FIXTURE}" && .github/scripts/build-args.sh)"

mv "${FIXTURE}/images/.env.laradock.preference" "${FIXTURE}/images/pref.bak"
# 同一个文件里重复的 NAME：值取最后一次，位置留在第一次。
check '缺 preference 时只读 .env.laradock' 'A=dup-in-same-file
C=3
X=2
D=has spaces here
F=url' "$(cd "${FIXTURE}" && .github/scripts/build-args.sh)"

mv "${FIXTURE}/images/.env.laradock" "${FIXTURE}/images/laradock.bak"
both_missing="$(cd "${FIXTURE}" && .github/scripts/build-args.sh)"
check '两个文件都不存在时输出为空' '' "${both_missing}"
# set -u 下空数组展开曾经是个坑，这里确认它是正常退出而不是崩掉。
if (cd "${FIXTURE}" && .github/scripts/build-args.sh > /dev/null); then
  pass '两个文件都不存在时退出码为 0'
else
  fail '两个文件都不存在时退出码非 0'
fi

echo
echo '## 3. 交叉检查：每个 NAME 都是 Dockerfile 里的 ARG'

mapfile -t dockerfiles < <(cd "${ROOT_DIR}" && ls -- images/*/Dockerfile)
orphans=()
while IFS='=' read -r name _; do
  (cd "${ROOT_DIR}" && grep -qhE "^ARG[[:space:]]+${name}([[:space:]]|=|$)" "${dockerfiles[@]}") \
    || orphans+=("${name}")
done <<< "${out}"
check '没有孤立的 build arg' '' "$(printf '%s\n' "${orphans[@]+"${orphans[@]}"}")"

echo
if ((failures > 0)); then
  printf '%d 项失败\n' "${failures}" >&2
  exit 1
fi
echo '全部通过'
