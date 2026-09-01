# iocage — truenas fork（含上游没有的 tarfile 安全修复、basejail/plugin 增强，
# 见 AUDIT-15.1.md）。自 fork 版 port 改写：改用 USE_GITHUB 拉源（不再依赖
# jail 内挂载 /usr/iocage_src），并跟 ports 框架现代化走 pep517。

PORTNAME=	iocage
DISTVERSION=	1.2+tn.20241118
CATEGORIES=	sysutils python
PKGNAMEPREFIX=	${PYTHON_PKGNAMEPREFIX}

MAINTAINER=	engineering@ixsystems.com
COMMENT=	FreeBSD jail manager written in Python (TrueNAS fork with security fixes)
WWW=		https://github.com/truenas/iocage

LICENSE=	BSD2CLAUSE

RUN_DEPENDS=	${PYTHON_PKGNAMEPREFIX}click>=6.7:devel/py-click@${PY_FLAVOR} \
	${PYTHON_PKGNAMEPREFIX}tqdm>=4.10.0:misc/py-tqdm@${PY_FLAVOR} \
	${PYTHON_PKGNAMEPREFIX}coloredlogs>0:devel/py-coloredlogs@${PY_FLAVOR} \
	ca_root_nss>0:security/ca_root_nss \
	${PYTHON_PKGNAMEPREFIX}texttable>=0.8.7:textproc/py-texttable@${PY_FLAVOR} \
	${PYTHON_PKGNAMEPREFIX}requests>=2.11.1:www/py-requests@${PY_FLAVOR} \
	${PYTHON_PKGNAMEPREFIX}libzfs>=1.0:devel/py-libzfs@${PY_FLAVOR} \
	${PYTHON_PKGNAMEPREFIX}gitpython>=2.1.10:devel/py-gitpython@${PY_FLAVOR} \
	${PYTHON_PKGNAMEPREFIX}netifaces>=0.10.6:net/py-netifaces@${PY_FLAVOR} \
	rcs57>0:devel/rcs57

CONFLICTS=	py-iocage-[0-9]* iocage-[0-9]* iocage-devel-[0-9]*

USE_GITHUB=	yes
GH_ACCOUNT=	alex6357-truenas-migrate
GH_PROJECT=	iocage
GH_TAGNAME=	d8b3d7e11256db59a98c588259eec5637ec92123

USES=		python
USE_PYTHON=	autoplist pep517
BUILD_DEPENDS=	${PYTHON_PKGNAMEPREFIX}setuptools>0:devel/py-setuptools@${PY_FLAVOR} \
	${PYTHON_PKGNAMEPREFIX}wheel>0:devel/py-wheel@${PY_FLAVOR}

# fastentrypoints hack 已随 pep517 迁移删除；LICENSE 若在仓库顶层缺失请改 files/
LICENSE_FILE=	${WRKSRC}/LICENSE

.include <bsd.port.mk>
