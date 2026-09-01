# build/mk/common.mk — 路径与公共变量（替代 core-build buildenv.py + env.pyd）

.if !defined(BUILD15_ROOT)
.error common.mk requires BUILD15_ROOT (include from top-level Makefile)
.endif

# 资源目录
CONF?=		${BUILD15_ROOT}/conf
PATCHES_DIR?=	${BUILD15_ROOT}/patches
EXTRA_PORTS?=	${BUILD15_ROOT}/ports-extra
TOOLS_SH?=	${BUILD15_ROOT}/build/sh

# 工作目录
WORK_ROOT?=	${BUILD15_ROOT}/work
WORK_SRC?=	${WORK_ROOT}/src
WORK_PORTS?=	${WORK_ROOT}/ports
OBJS?=		${BUILD15_ROOT}/objs
RELEASE_ROOT?=	${BUILD15_ROOT}/release
PKG_REPO?=	${BUILD15_ROOT}/repo

# 并行与平台
HW_NCPU!=	sysctl -n hw.ncpu 2>/dev/null || echo 2
MAKE_JOBS?=	${HW_NCPU}
MACHINE_ARCH!=	uname -m

# 目标基线版本（src 树自身读出，勿写死）
# FREEBSD_VERSION!= ... P2/P3 补充

.export WORK_ROOT WORK_SRC WORK_PORTS OBJS RELEASE_ROOT PKG_REPO
