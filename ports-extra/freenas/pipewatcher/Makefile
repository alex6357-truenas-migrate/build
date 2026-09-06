# $FreeBSD$

PORTNAME=	pipewatcher
PORTVERSION=	${PRODUCT_VERSION:C/\-.*//:C/\_.*//}
PORTREVISION=	${REVISION}

CATEGORIES=	freenas
VALID_CATEGORIES+=	freenas

MAINTAINER=	dev@ixsystems.com
COMMENT=	Pipe watcher to be used in replication

EXTRACT_ONLY=
# poudriere builder 的 jail 基础镜像是只读的，不能直接以 /usr/nas_source
# 为 WRKSRC 编译；extract 阶段复制到 ${WRKDIR}/src 并提供无人建桶写权限。
WRKSRC=${WRKDIR}/src

post-extract:
	${CP} -Rp /usr/nas_source/pipewatcher ${WRKSRC}
	${CHMOD} -R ugo+rwX ${WRKSRC}

# no checksum, we just used git!
checksum fetch:
	echo ${.TARGET} not needed because building direct

pre-clean:
	@

do-build:
	cd ${WRKSRC} && ${CC} pipewatcher.c -o pipewatcher

do-install:
	mkdir -p ${STAGEDIR}${PREFIX}/bin
	${INSTALL_PROGRAM} ${WRKSRC}/pipewatcher ${STAGEDIR}${PREFIX}/bin/

.include <bsd.port.mk>
