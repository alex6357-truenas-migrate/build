# build/mk/ports.mk — poudriere 装配 + 批量构建（替代 core-build build-ports.py）
# 前置：make setup patches（work/ports 已存在且 patches/ports 已应用）。
# 依赖 poudriere（ports-mgmt/poudriere 或 poudriere-devel；后者非必需）。

POUDRIERE_ETC?=	${OBJS}/poudriere/etc
POUDRIERE_JAIL?=	build15-151
POUDRIERE_TREE?=	tn15
POUDRIERE_JAIL_SRC_TAR?=	${OBJS}/jail.txz
JAIL_ROOT?=	${OBJS}/jail

# 把 ports-extra 合入 work/ports 后（一次性）注册到 poudriere
${WORK_PORTS}/.build15-ports-merged:
	BUILD15_ROOT=${BUILD15_ROOT} WORK_PORTS=${WORK_PORTS} \
		sh ${TOOLS_SH}/ports-merge.sh
	touch ${WORK_PORTS}/.build15-ports-merged

# 供 poudriere jail 使用的 world：用同一 work/src（make world）installworld 到 JAIL_ROOT 作 pack 成 txz
${POUDRIERE_JAIL_SRC_TAR}: skeleton-jail
	tar -C ${JAIL_ROOT} -cjf ${POUDRIERE_JAIL_SRC_TAR} .

POUDRIERE_BASE?=	${OBJS}/poudriere

# 生成 poudriere 环境（etc 根 + make.conf + 树 + jail 注册）
poudriere-setup: ${WORK_PORTS}/.build15-ports-merged ${POUDRIERE_JAIL_SRC_TAR}
	mkdir -p ${POUDRIERE_ETC} ${POUDRIERE_ETC}/poudriere.d
	sed 's|@@BASEFS@@|${POUDRIERE_BASE}|g' ${CONF}/poudriere.conf.tmpl > ${POUDRIERE_ETC}/poudriere.conf
	cp ${CONF}/pkg-make.conf ${POUDRIERE_ETC}/poudriere.d/make.conf
	POUDRIERE_ETC=${POUDRIERE_ETC} poudriere ports -c -p ${POUDRIERE_TREE} -m none -M ${WORK_PORTS}
	POUDRIERE_ETC=${POUDRIERE_ETC} poudriere jail -c -j ${POUDRIERE_JAIL} -v ${FREEBSD_REL_VER:U15.1-RELEASE} \
		-a ${MACHINE_ARCH} -m tar=${POUDRIERE_JAIL_SRC_TAR}

# skeleton-jail 分解：仅做 world 安装（不含 kernel，对应 core-build make-conf-jail）
# 依赖 make world 已完成（buildworld 产生对象树）
skeleton-jail: world
	${BUILD_ENV} ${MAKE} -C ${WORK_SRC} \
		DESTDIR=${JAIL_ROOT} SRCCONF=${SRC_MAKE_CONF:Q} \
		installworld distribution

# 批量构建全部 port
ports-bulk: poudriere-setup
	POUDRIERE_ETC=${POUDRIERE_ETC} poudriere bulk -w -J ${MAKE_JOBS} \
		-j ${POUDRIERE_JAIL} -p ${POUDRIERE_TREE} \
		-f ${CONF}/ports.list

# ---- 对外 ----
ports: ports-bulk

.PHONY: ports ports-bulk poudriere-setup skeleton-jail
