# py-bsd — middlewared 用的 BSD syscall Python 绑定（pyproject 化后的 port）
#
# 构建侧早期通过 /usr/nas_source 喂（poudriere 无网），仓库 origin 已 wipe 15.1 适配。

PORTNAME=	bsd
PORTVERSION=	1.1.0
PKGNAMEPREFIX=	${PYTHON_PKGNAMEPREFIX}

CATEGORIES=	freenas
VALID_CATEGORIES+= freenas

MAINTAINER=	dev@ixsystems.com
COMMENT=	Python wrappers for various BSD interfaces

# 构建期源码位置（由 build/ports』skeleton-jail 副载）
WRKSRC=		/usr/nas_source/py-bsd

USES=		python cython
USE_PYTHON=	autoplist pep517
BUILD_DEPENDS=	${PYTHON_PKGNAMEPREFIX}cython>0:devel/py-cython@${PY_FLAVOR} \
	${PYTHON_PKGNAMEPREFIX}setuptools>0:devel/py-setuptools@${PY_FLAVOR} \
	${PYTHON_PKGNAMEPREFIX}wheel>0:devel/py-wheel@${PY_FLAVOR}

# dialog.pyx 已删（15.1 的 base 已换 libbsddialog）；
# extattr.pyx 已去 six/py2 兼容，直接 py3-only；不需要 lang/python2。

checksum fetch:
	@${ECHO_CMD} ${.TARGET} not needed because building direct

.include <bsd.port.mk>
