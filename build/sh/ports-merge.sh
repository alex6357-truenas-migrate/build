#!/bin/sh
# ports-merge.sh — 把 ports-extra 合入 work/ports 的对应分类
# 处理：目录复制 + 分类 Makefile 的 SUBDIR 注册（若缺失）+ freenas/truenas 分类头文件
set -eu

BUILD_ROOT=${BUILD_ROOT:?}
WORK_PORTS=${WORK_PORTS:-$BUILD_ROOT/work/ports}
EXTRA=${EXTRA:-$BUILD_ROOT/ports-extra}

[ -d "$WORK_PORTS/.git" ] || { echo "[ports-merge] ERROR: $WORK_PORTS missing; make setup" >&2; exit 1; }
[ -d "$EXTRA" ] || { echo "[ports-merge] ERROR: ports-extra missing" >&2; exit 1; }

# 新增分类 Makefile 骨架（若该分类在上游树中不存在）
mkcategoriy() {
    _cat=$1
    _mdir=$WORK_PORTS/$_cat
    if [ ! -f "$_mdir/Makefile" ]; then
        mkdir -p "$_mdir"
        { echo "# $_cat category (build overlay)"; echo ""; echo "COMMENT = TrueNAS ports"; echo ""; } >"$_mdir/Makefile"
    fi
    grep -qE '^\.include <bsd\.port\.(pre\.)?mk>' "$_mdir/Makefile" || {
        printf '\n.include <bsd.port.mk>\n' >>"$_mdir/Makefile"
    }
}

cd "$EXTRA"
find . -mindepth 2 -maxdepth 2 -type d | sed 's|^\./||' | sort | while read -r _p; do
    _cat=${_p%%/*} _name=${_p##*/}
    mkcategoriy "$_cat"
    _dst=$WORK_PORTS/$_p
    if [ -e "$_dst" ]; then rm -rf "$_dst"; fi
    mkdir -p "$(dirname "$_dst")"
    cp -Rp "$EXTRA/$_p" "$_dst"
    # 分类 Makefile 注册 SUBDIR（幂等）
    grep -qE "^[[:space:]]*SUBDIR[[:space:]]*\+=?[[:space:]]+$_name\$?" "$WORK_PORTS/$_cat/Makefile" || {
        printf '    SUBDIR += %s\n' "$_name" >>"$WORK_PORTS/$_cat/Makefile"
    }
    echo "[ports-merge] $_p"
done

# uid/gid：freenas/truenas 等真私货如有 UIDs/GIDs 增补（占位；P2b 决定）
echo "[ports-merge] done"
