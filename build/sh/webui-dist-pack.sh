#!/bin/sh
# webui-dist-pack.sh — 在独立环境把 truenas/webui 源码构建成 dist 包
# 用法（host 或 FreeBSD 构建机都可，要求可访问网络或预置 node_modules 缓存）：
#   sh webui-dist-pack.sh [src-dir] [out-dir]
# 输出产物：
#   <out-dir>/webui-dist-<version>.tar.gz
#   <out-dir>/distinfo   （拷入 ports-extra/freenas/webui-dist/distinfo 即生效）
#
# 推荐环境：docker node:16-buster（iX 当年官方构建镜像）或等价 nvm node16 + yarn 1.x。
set -eu

SRC=${1:-$PWD/../../work/webui}
OUT=${2:-$PWD}
VER=${WEBUI_DIST_VERSION:-15.0.0-1}
PKG=$OUT/webui-dist-$VER.tar.gz
DIST=$OUT/distinfo
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

[ -d "$SRC" ] || { echo "ERROR: webui source dir $SRC not found" >&2; exit 2; }

echo "[webui-dist] copy source $SRC → workspace"
cp -Rp "$SRC" "$WORK/webui"

# 1) 判构建环境：优先 docker；其次本地 node16+yarn
shell_build() {
    cd "$WORK/webui"
    yarn --version >/dev/null || {
        if command -v corepack >/dev/null; then corepack enable; corepack prepare yarn@1.22.19 --activate; fi
    }
    # product.ts 占位（TrueNAS；与旧 port fetch 阶段同款）
    printf "export default { product:'TrueNAS' }\n" > src/app/helptext/product.ts
    printf "var product = 'TrueNAS'\n" > src/assets/scripts/product.js
    yarn install --frozen-lockfile
    yarn run build:prod:aot
}

docker_build() {
    docker run --rm -i \
        -v "$WORK/webui":/src-ui -w /src-ui \
        node:16-buster sh -c '
            set -e
            echo "export default { product:\"TrueNAS\" }" > src/app/helptext/product.ts
            printf "var product = \"TrueNAS\"\n" > src/assets/scripts/product.js
            yarn install --frozen-lockfile
            yarn run build:prod:aot
        '
}

if command -v docker >/dev/null 2>&1; then
    echo "[webui-dist] build in docker node:16-buster"
    ( cd "$WORK/webui" && docker_build )
else
    echo "[webui-dist] build with local node16/yarn"
    shell_build
fi

[ -d "$WORK/webui/dist" ] || { echo "ERROR: webui/dist missing after build" >&2; exit 3; }

# 2) 打包 dist
mkdir -p "$OUT"
tar -C "$WORK/webui" -czf "$PKG" --exclude=.git dist

# 3) 生成 distinfo（拷入 ports-extra/freenas/webui-dist/）
{
    echo "TIMESTAMP = $(date -u +%s)"
    printf 'SHA256 (webui-dist-%s.tar.gz) = %s\n' "$VER" "$(sha256 -q "$PKG")"
    printf 'SIZE (webui-dist-%s.tar.gz) = %s\n' "$VER" "$(stat -f %z "$PKG" 2>/dev/null || wc -c <"$PKG")"
} >"$DIST"

echo "[webui-dist] done: $PKG"
echo "[webui-dist] distinfo: $DIST"
echo "接着执行：cp $OUT/distinfo <build>/ports-extra/freenas/webui-dist/distinfo"
