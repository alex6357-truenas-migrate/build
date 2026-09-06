# $FreeBSD$

PORTNAME=	licenselib
PORTVERSION=	${PRODUCT_VERSION:C/\-.*//:C/\_.*//}
PORTREVISION=	${REVISION}
PKGNAMEPREFIX=	${PYTHON_PKGNAMEPREFIX}
CATEGORIES=	freenas
VALID_CATEGORIES+=freenas

MAINTAINER=	wg@FreeBSD.org
COMMENT=	License library for FreeNAS/TrueNAS

USES=		python
USE_PYTHON=	autoplist distutils

EXTRACT_ONLY=
# jail 镜像 /usr/nas_source 为只读，复制入可写工作区(见 ports/extra 同行先例)
WRKSRC?=${WRKDIR}/src

post-extract:
	${CP} -Rp /usr/nas_source/py-licenselib ${WRKSRC}
	${CHMOD} -R ugo+rwX ${WRKSRC}

# no checksum, we just used git!
checksum fetch:
	echo ${.TARGET} not needed because building direct


.include <bsd.port.mk>
