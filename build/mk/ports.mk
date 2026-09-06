# build/mk/ports.mk — poudriere 装配 + 批量构建（替代 core-build build-ports.py）
# 前置：make setup patches（work/ports 已存在且 patches/ports 已应用）。
# 依赖 poudriere（ports-mgmt/poudriere 或 poudriere-devel；后者非必需）。

POUDRIERE_ETC?=	${OBJS}/poudriere/etc
# jail/树名跟随 FREEBSD_BRANCH（releng/15.1 → build-151-tn2026Q3；
# poudriere 禁止 jail 名含 '.'，去小数点）
POUDRIERE_JAIL?=	build-${FREEBSD_BRANCH:C,.*/,,:S,.,,g}
POUDRIERE_TREE?=	tn${PORTS_QUARTER}
POUDRIERE_JAIL_SRC_TAR?=	${OBJS}/jail.txz
JAIL_ROOT?=	${OBJS}/jail

# 把 ports-extra 合入 work/ports 后（一次性）注册到 poudriere；
# stamp 依赖 ports-extra 全量文件，任一修改即重 merge
PORTS_EXTRA_FILES!=	find ${EXTRA_PORTS} -type f -not -path '*/.git/*' 2>/dev/null
${WORK_PORTS}/.build-ports-merged: ${PORTS_EXTRA_FILES}
	BUILD_ROOT=${BUILD_ROOT} WORK_PORTS=${WORK_PORTS} \
		sh ${TOOLS_SH}/ports-merge.sh
	touch ${WORK_PORTS}/.build-ports-merged

# 供 poudriere jail 使用的 world：用同一 work/src（make world）installworld 到 JAIL_ROOT 作 pack 成 txz
${POUDRIERE_JAIL_SRC_TAR}: skeleton-jail
	tar -C ${JAIL_ROOT} -cjf ${POUDRIERE_JAIL_SRC_TAR} .

POUDRIERE_BASE?=	${OBJS}/poudriere

# 生成 poudriere 环境（etc 根 + make.conf + 树 + jail 注册）
poudriere-setup: ${WORK_PORTS}/.build-ports-merged ${POUDRIERE_JAIL_SRC_TAR}
	mkdir -p ${POUDRIERE_ETC} ${POUDRIERE_ETC}/poudriere.d
	sed -e 's|@@BASEFS@@|${POUDRIERE_BASE}|g' \
	    -e "s|@@NAS_NULLFS@@||g" \
	    ${CONF}/poudriere.conf.tmpl > ${POUDRIERE_ETC}/poudriere.conf
	cp ${CONF}/pkg-make.conf ${POUDRIERE_ETC}/poudriere.d/make.conf
	POUDRIERE_ETC=${POUDRIERE_ETC} poudriere ports -l -q 2>/dev/null | \
		awk '{print $$1}' | grep -qx ${POUDRIERE_TREE} || \
		POUDRIERE_ETC=${POUDRIERE_ETC} poudriere ports -c -p ${POUDRIERE_TREE} -m none -M ${WORK_PORTS}
	# jail 已存且 txz 更新过(txz 由 skeleton-jail 每次重烤)就重建 jail;
	# 注意 poudriere 的 jail -u 对 -m tar 方式不支持(round16 实测报错),
	# 只能 -d 后 -c。stamp 落在 jail 目录里,jail -d 连 stamp 一起清,
	# 新建 jail 不会触发重建分支。
	_stamp=${POUDRIERE_BASE}/jails/${POUDRIERE_JAIL}/.build-txz-stamp; \
	if [ -f "$$_stamp" ] && [ "${POUDRIERE_JAIL_SRC_TAR}" -nt "$$_stamp" ]; then \
		POUDRIERE_ETC=${POUDRIERE_ETC} poudriere jail -d -j ${POUDRIERE_JAIL} -y; \
	fi; \
	POUDRIERE_ETC=${POUDRIERE_ETC} poudriere jail -l -q 2>/dev/null | \
		awk '{print $$1}' | grep -qx ${POUDRIERE_JAIL} || \
		POUDRIERE_ETC=${POUDRIERE_ETC} poudriere jail -c -j ${POUDRIERE_JAIL} -v ${FREEBSD_REL_VER} \
		-a ${MACHINE_ARCH} -m tar=${POUDRIERE_JAIL_SRC_TAR}; \
	touch "$$_stamp"

# skeleton-jail 分解：仅做 world 安装（不含 kernel，对应 core-build make-conf-jail）
# 依赖 make world 已完成（buildworld 产生对象树）
skeleton-jail: world
	${BUILD_ENV} ${MAKE} -C ${WORK_SRC} \
		DESTDIR=${JAIL_ROOT} SRCCONF=${SRC_MAKE_CONF:Q} \
		installworld distribution
	# kmod 类 ports（drm-kmod/open-vm-kmod/gpu-fw）构建要读 jail 内 /usr/src：
	# poudriere NULLFS 直挂 host src 在 15.1 会 EDEADLK（P4 实测），
	# 改为把打了补丁的 sys 树复制进 jail 镜像（273MB，可接受）。
	mkdir -p ${JAIL_ROOT}/usr/src
	rm -rf ${JAIL_ROOT}/usr/src/sys
	cp -Rp ${WORK_SRC}/sys ${JAIL_ROOT}/usr/src/sys
	# nas_source 同样复制进镜像：NULLFS_PATHS 经 ref jail 持久挂载，
	# 中途 rebinding host 不会刷新 ref 的旧 vnode（13 轮实测 jail 内空目录）。
	rm -rf ${JAIL_ROOT}/usr/nas_source
	mkdir -p ${JAIL_ROOT}/usr/nas_source
	for d in $$(cd ${WORK_ROOT}/middleware/src && ls); do \
		cp -Rp ${WORK_ROOT}/middleware/src/$$d ${JAIL_ROOT}/usr/nas_source/$$d; \
	done
	cp -Rp ${WORK_ROOT}/py-bsd ${JAIL_ROOT}/usr/nas_source/py-bsd
	cp -Rp ${WORK_ROOT}/licenselib ${JAIL_ROOT}/usr/nas_source/py-licenselib

# 批量构建全部 port
# builder 并发别用满 ncpu: -J 20 时 rust+node+llvm 同开必 OOM(实测 node24 was killed)
POUDRIERE_MAX_JOBS?=	10
ports-bulk: poudriere-setup
	POUDRIERE_ETC=${POUDRIERE_ETC} poudriere bulk -w -J ${POUDRIERE_MAX_JOBS} \
		-j ${POUDRIERE_JAIL} -p ${POUDRIERE_TREE} \
		-f ${CONF}/ports.list

# ---- 对外 ----
ports: ports-bulk

.PHONY: ports ports-bulk poudriere-setup skeleton-jail
