PORTNAME=	netif
PORTVERSION=	1.0.20240503
CATEGORIES=	net python
PKGNAMEPREFIX=	${PYTHON_PKGNAMEPREFIX}

MAINTAINER=	dev@ixsystems.com
COMMENT=	Python network configuration library for FreeBSD
WWW=		https://github.com/truenas/py-netif

LICENSE=	BSD2CLAUSE

# 上游 devel/py-bsd 已过期删除（2025-12）；同名包由 ports-extra/freenas/py-bsd 供给
RUN_DEPENDS=	${PYTHON_PKGNAMEPREFIX}bsd>0:freenas/py-bsd@${PY_FLAVOR}

USES=		python
USE_GITHUB=	yes
GH_ACCOUNT=	alex6357-truenas-migrate
GH_PROJECT=	py-netif
GH_TAGNAME=	9298aa9
USE_PYTHON=	autoplist cython distutils

HAS_CONFIGURE=	yes

post-install:
	@${STRIP_CMD} ${STAGEDIR}${PYTHONPREFIX_SITELIBDIR}/netif*.so

.include <bsd.port.mk>
