#!/bin/sh
# repo-manifest.sh — 把每个已 checkout 仓库的「url + 实际 sha」写入 .repo-manifest
# （对应 core-build 的 repo-manifest 产物；pkgbase 场景下用于可复现与审计）。
set -eu

BUILD_ROOT=${BUILD_ROOT:?}
WORK_ROOT=${WORK_ROOT:?}
REPOS_CONF=${REPOS_CONF:-$BUILD_ROOT/repos.conf}
OUT=${OUT:-$BUILD_ROOT/.repo-manifest}

# shellcheck disable=SC1090
. "$REPOS_CONF"

: >"$OUT"
awk -F= '/^REPO_[A-Z_]+=/ { sub(/^REPO_/, "", $1); print $1 }' "$REPOS_CONF" |
while read -r _name; do
    eval "_spec=\$REPO_${_name}"
    set -- $_spec
    _url=$1 _path=$3 _role=$4
    [ "$_role" = ref ] && continue
    _dest=$WORK_ROOT/$_path
    [ -d "$_dest/.git" ] || continue
    _sha=$(git -C "$_dest" rev-parse HEAD)
    echo "$_url $_sha" >>"$OUT"
done

echo "[manifest] wrote $OUT"
