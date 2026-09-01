#!/bin/sh
# repo-sync.sh — 按 repos.conf 拉取/同步 build15 的全部仓库
# 语义对应 core-build 的 checkout.py：clone 缺失仓库、fetch 已存在仓库、检出 pin。
# 零 python 依赖；仅 POSIX sh + git。
set -eu

BUILD15_ROOT=${BUILD15_ROOT:?}
WORK_ROOT=${WORK_ROOT:?}
REPOS_CONF=${REPOS_CONF:-$BUILD15_ROOT/repos.conf}
CHECKOUT_SHALLOW=${CHECKOUT_SHALLOW:-}

# shellcheck disable=SC1090
. "$REPOS_CONF"

# 收集全部 REPO_* 变量名（经环境可见；repos.conf 的变量被 source 后可用 eval 读）
repo_names() {
    awk -F= '/^REPO_[A-Z_]+=/ { sub(/^REPO_/, "", $1); print $1 }' "$REPOS_CONF"
}

# 判断字段 2 是 40 位十六进制 sha 还是分支名
is_sha() {
    case $1 in
    *[!0-9a-fA-F]*) return 1 ;;
    ????????????????????????????????????????) [ ${#1} -eq 40 ] ;;
    *) return 1 ;;
    esac
}

sync_one() {
    _name=$1
    eval "_spec=\$REPO_${_name}"
    # 拆字段：url ref path role（repos.conf 保证无空格于各字段内）
    set -- $_spec
    _url=$1 _ref=$2 _path=$3 _role=$4

    [ "$_role" = ref ] && { echo "[repo] skip $_name (role=ref)"; return 0; }

    _dest=$WORK_ROOT/$_path
    mkdir -p "$WORK_ROOT"

    if [ -d "$_dest/.git" ]; then
        echo "[repo] update $_name ($_path)"
        git -C "$_dest" fetch origin --prune
    else
        echo "[repo] clone $_name → $_path ($_ref)"
        _clone_opts=
        [ -n "$CHECKOUT_SHALLOW" ] && ! is_sha "$_ref" && _clone_opts="--depth 1"
        # shellcheck disable=SC2086
        git clone $_clone_opts "$_url" "$_dest"
    fi

    if is_sha "$_ref"; then
        git -C "$_dest" checkout --detach "$_ref"
    else
        git -C "$_dest" checkout "$_ref" 2>/dev/null || \
            git -C "$_dest" checkout -b "$_ref" "origin/$_ref"
        git -C "$_dest" merge --ff-only "origin/$_ref" || true
    fi
}

mkdir -p "$WORK_ROOT"
for _n in $(repo_names); do
    sync_one "$_n"
done
echo "[repo] done"
