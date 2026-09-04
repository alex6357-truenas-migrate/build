# webui-dist — TrueNAS WebUI 预编译 dist 壳 port（P4 主线方案 C）
#
# 机制说明：
#   - 本 port 不构建前端。前端 dist tarball 由 build/sh/webui-dist-pack.sh
#     在独立环境（docker node:16-buster 或手动 node16/yarn 环境）产出；
#   - 产出物为 webui-dist-${DISTVERSION}.tar.gz + distinfo（含 sha256）；
#   - 若 tarball 已置于 poudriere DISTFILES_CACHE 且 distinfo 校验通过，
#     poudriere 断网模式下 fetch 会被跳过。
#   - 本 port 的 do-install 复用旧 freenas-webui port 的静态文件安装逻辑。

PORTNAME=	webui-dist
DISTVERSION?=	15.0.0-1
CATEGORIES=	freenas
VALID_CATEGORIES+=freenas

MISSING_PACKAGE_DEPENDS=
MAINTAINER=	dev@ixsystems.com
COMMENT=	TrueNAS WebUI (prebuilt dist, transitional package)

NO_BUILD=	yes
NO_ARCH=	yes
EXTRACT_ONLY=

DISTNAME=	webui-dist-${DISTVERSION}
# not hosted; see distinfo + DISTFILES_CACHE seeding
MASTER_SITES=	#
DISTFILES=	${DISTNAME}.tar.gz

# 若 _EXTRA_DIST_SEED 指定则直接 fetch 本地文件（供无网测试）
.if defined(EXTRA_DIST_SEED)
MASTER_SITES=	file://${EXTRA_DIST_SEED:H}/
DISTFILES=	${EXTRA_DIST_SEED:T}
.endif

do-install:
	mkdir -p ${STAGEDIR}${PREFIX}/www/webui
	# webui-dist-pack.sh 打出来的 tar 顶层是 dist/ 目录，展平到 www/webui 根
	( umask 022 && cd ${STAGEDIR}${PREFIX}/www/webui && \
	  ${EXTRACT_CMD} ${EXTRACT_BEFORE_ARGS} ${DISTDIR}/${DISTFILES} ${EXTRACT_AFTER_ARGS} && \
	  if [ -d dist ]; then \
	    ( cd dist && tar -cf - . ) | tar -xf - && rm -rf dist; \
	  fi )
	mkdir -p ${STAGEDIR}${PREFIX}/www/webui/assets
	date -u +%s > ${STAGEDIR}${PREFIX}/www/webui/assets/buildtime
	( cd ${STAGEDIR}${PREFIX}/www/webui; ${FIND} . -type f \
		| ${SED} -e 's,^\./,,g' \
		| ${AWK} '{print length, $$0}' | ${SORT} -rn \
		| cut -d " " -f 2- \
		| ${AWK} '{print "www/webui/"$$0 }' >> ${TMPPLIST} )

.include <bsd.port.mk>
