# build/mk/common.mk — 路径与公共变量（替代 core-build buildenv.py + env.pyd）

.if !defined(BUILD_ROOT)
.error common.mk requires BUILD_ROOT (include from top-level Makefile)
.endif

# FreeBSD 版本锚点（泛化：改 FREEBSD_BRANCH/FREEBSD_REL_VER/PORTS_QUARTER 即跟随新版本）
.include "${BUILD_ROOT}/conf/freebsd.mk"

.export FREEBSD_BRANCH FREEBSD_REL_VER PORTS_QUARTER

# 资源目录
CONF?=		${BUILD_ROOT}/conf
PATCHES_DIR?=	${BUILD_ROOT}/patches
EXTRA_PORTS?=	${BUILD_ROOT}/ports-extra
TOOLS_SH?=	${BUILD_ROOT}/build/sh

# 工作目录
WORK_ROOT?=	${BUILD_ROOT}/work
WORK_SRC?=	${WORK_ROOT}/src
WORK_PORTS?=	${WORK_ROOT}/ports
OBJS?=		${BUILD_ROOT}/objs
RELEASE_ROOT?=	${BUILD_ROOT}/release
PKG_REPO?=	${BUILD_ROOT}/repo

# 并行与平台
HW_NCPU!=	sysctl -n hw.ncpu 2>/dev/null || echo 2
MAKE_JOBS?=	${HW_NCPU}
MACHINE_ARCH!=	uname -m

# 目标基线版本（src 树自身读出，勿写死）
# FREEBSD_VERSION!= ... P2/P3 补充

# 注意：OBJS 不可 .export —— 15.1 起 bsd.dep.mk 会拒绝对 src 子 make 暴露
# 含绝对路径的 OBJS 变量（环境继承即视为 make 变量），buildworld 直接报错终止。
.export WORK_ROOT WORK_SRC WORK_PORTS RELEASE_ROOT PKG_REPO
