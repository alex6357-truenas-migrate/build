# $FreeBSD$

PORTNAME=	tc-stats
PORTVERSION=	0.1.8
# 15.1:freenas/truecommand-stats 里的 v0.1.8 tag 已丢失（只剩 master），
# 钉为 master 头 382928ff0308...（与 codeload.org 测试一致）
GH_TAGNAME=	382928ff0308e206ce95174f6af64f196d135f72

CATEGORIES=	freenas
VALID_CATEGORIES+=	freenas

MAINTAINER=	dev@ixsystems.com
COMMENT=	TrueCommand Stats Collection Engine

NO_BUILD=	YES

USE_GITHUB=     yes
GH_ACCOUNT=	alex6357-truenas-migrate
GH_PROJECT=     truecommand-stats

.include <bsd.port.pre.mk>

do-install:
	mkdir -p ${STAGEDIR}${PREFIX}/bin
	${INSTALL_PROGRAM} ${WRKSRC}/binaries/freebsd/trueview-stats ${STAGEDIR}${PREFIX}/bin/trueview_stats.sh

.include <bsd.port.post.mk>
