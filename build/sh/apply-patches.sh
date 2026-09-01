#!/bin/sh
# apply-patches.sh [clean] <src|ports>
# 把 patches/<kind>/*.patch 按文件名顺序以 `git am` 应用到 work/<kind>。
# 幂等通过 manifest 判断（每条 patch 记一行 sha）；clean 时重置到基线。
set -eu

BUILD_ROOT=${BUILD_ROOT:?}
WORK_ROOT=${WORK_ROOT:?}
REPOS_CONF=$BUILD_ROOT/repos.conf

# shellcheck disable=SC1090
. "$REPOS_CONF"

_cmd=apply
case ${1:-} in
clean) _cmd=clean; shift ;;
esac
kind=${1:?usage: apply-patches.sh [clean] src|ports}

case $kind in
src)   _repo_var=REPO_SRC;   _dest=$WORK_ROOT/src ;;
ports) _repo_var=REPO_PORTS; _dest=$WORK_ROOT/ports ;;
*) echo "unknown kind $kind" >&2; exit 2 ;;
esac

eval "_spec=\$${_repo_var}"
set -- $_spec
_base_ref=$2
_pdir=$BUILD_ROOT/patches/$kind
_list=$(ls "$_pdir"/*.patch 2>/dev/null || true)

if [ "$_cmd" = clean ]; then
    echo "[patch-$kind] reset to base $_base_ref"
    git -C "$_dest" reset --hard "$_base_ref" 2>/dev/null || \
        git -C "$_dest" checkout --detach "$_base_ref"
    rm -f "$_dest/.build-patchlog"
    exit 0
fi

[ -d "$_dest/.git" ] || { echo "[patch-$kind] ERROR: $_dest missing; run make setup first" >&2; exit 1; }

# 幂等：若 .build-patchlog 存在且与当前 patch 序列的前缀一致则跳过已应用者
_log=$_dest/.build-patchlog
: >"$_log.tmp"

for _p in $_list; do
    _base=$(basename "$_p")
    if [ -f "$_log" ] && grep -q "^${_base}\$" "$_log"; then
        echo "[patch-$kind] skip $_base (already applied)"
        echo "$_base" >>"$_log.tmp"
        continue
    fi
    # mbox (format-patch 产物, 以 'From <sha> ' 开头) 走 git am；纯 diff 走 git apply + 手动 commit
    if head -1 "$_p" | grep -q '^From [0-9a-f]\{40\} '; then
        echo "[patch-$kind] am $_base"
        git -C "$_dest" -c user.name=build -c user.email=build@local \
            am --3way --committer-date-is-author-date "$_p" || {
            git -C "$_dest" am --abort 2>/dev/null || true
            echo "[patch-$kind] FAILED: $_base" >&2
            exit 1
        }
    else
        echo "[patch-$kind] apply $_base"
        git -C "$_dest" apply --3way "$_p" && \
        git -C "$_dest" -c user.name=build -c user.email=build@local \
            commit -qam "build: apply $_base" || {
            git -C "$_dest" reset --hard >/dev/null 2>&1 || true
            echo "[patch-$kind] FAILED: $_base" >&2
            exit 1
        }
    fi
    echo "$_base" >>"$_log.tmp"
done
mv "$_log.tmp" "$_log"
git -C "$_dest" log --oneline "$(git -C "$_dest" rev-parse "$_base_ref^{commit}")..HEAD" 2>/dev/null || \
    git -C "$_dest" log --oneline -n 20
echo "[patch-$kind] done"
