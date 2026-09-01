#!/bin/sh
# repo-sync.sh — 按 repos.conf 拉取/同步 build 的全部仓库
# 语义对应 core-build 的 checkout.py：clone 缺失仓库、fetch 已存在仓库、检出 pin。
# 零 python 依赖；仅 POSIX sh + git。
set -eu

BUILD_ROOT=${BUILD_ROOT:?}
WORK_ROOT=${WORK_ROOT:?}
REPOS_CONF=${REPOS_CONF:-$BUILD_ROOT/repos.conf}
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
        # 本地种子：nas-build/<path>（与 build/ 同级）存在时优先克隆本地副本，离线可跑
        _seed=$BUILD_ROOT/../$_path
        _remote=$_url
        if [ -d "$_seed/.git" ]; then
            echo "[repo] seed from local $_seed"
            _remote=$(cd "$_seed" && pwd -P)
        fi
        echo "[repo] clone $_name → $_path ($_ref)"
        _clone_opts=
        # sha 不可直传 -b；分支可 --branch 缩小首拉数据量；本地种子不做 --depth
        if is_sha "$_ref"; then
            _clone_opts=""
        else
            _clone_opts="--branch $_ref --single-branch"
            if [ -z "$_seed" ] && [ -n "$CHECKOUT_SHALLOW" ]; then
                _clone_opts="$_clone_opts --depth 1"
            fi
        fi
        # shellcheck disable=SC2086
        git clone $_clone_opts "$_remote" "$_dest"
        # 从种子拉时把 origin 还原为真实上游，保证后续 update 走网络
        if [ "$_remote" != "$_url" ]; then
            git -C "$_dest" remote set-url origin "$_url"
        fi
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
