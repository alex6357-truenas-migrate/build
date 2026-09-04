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
	_nas_nullfs=$$(cd ${WORK_ROOT}/middleware/src && ls) && \
	_nas_nullfs=$$(for d in $$_nas_nullfs; do printf '/usr/nas_source/%s ' "$$d"; done; \
		printf '/usr/nas_source/py-bsd /usr/nas_source/py-licenselib') && \
	sed -e 's|@@BASEFS@@|${POUDRIERE_BASE}|g' \
	    -e "s|@@NAS_NULLFS@@|$$_nas_nullfs|g" \
	    ${CONF}/poudriere.conf.tmpl > ${POUDRIERE_ETC}/poudriere.conf
	cp ${CONF}/pkg-make.conf ${POUDRIERE_ETC}/poudriere.d/make.conf
	POUDRIERE_ETC=${POUDRIERE_ETC} poudriere ports -l -q 2>/dev/null | \
		awk '{print $$1}' | grep -qx ${POUDRIERE_TREE} || \
		POUDRIERE_ETC=${POUDRIERE_ETC} poudriere ports -c -p ${POUDRIERE_TREE} -m none -M ${WORK_PORTS}
	POUDRIERE_ETC=${POUDRIERE_ETC} poudriere jail -l -q 2>/dev/null | \
		awk '{print $$1}' | grep -qx ${POUDRIERE_JAIL} || \
		POUDRIERE_ETC=${POUDRIERE_ETC} poudriere jail -c -j ${POUDRIERE_JAIL} -v ${FREEBSD_REL_VER} \
		-a ${MACHINE_ARCH} -m tar=${POUDRIERE_JAIL_SRC_TAR}

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

# nas_source 绑定：freenas/py-middlewared 等 port 的 WRKSRC=/usr/nas_source/<repo>
# host 侧把 work/<repo> 以 nullfs(ro) 绑进 /usr/nas_source/<repo>，
# poudriere 经 NULLFS_PATHS 传入 jail（13.3 core-build 同款目录协定）。
nas-source-bind:
	mkdir -p /usr/nas_source
	for d in $$(cd ${WORK_ROOT}/middleware/src && ls); do \
		[ -d /usr/nas_source/$$d ] || mkdir /usr/nas_source/$$d; \
		mount | grep -q " on /usr/nas_source/$$d " || \
			mount_nullfs -o ro ${WORK_ROOT}/middleware/src/$$d /usr/nas_source/$$d; \
	done
	[ -d /usr/nas_source/py-bsd ] || mkdir /usr/nas_source/py-bsd
	mount | grep -q " on /usr/nas_source/py-bsd " || \
		mount_nullfs -o ro ${WORK_ROOT}/py-bsd /usr/nas_source/py-bsd
	[ -d /usr/nas_source/py-licenselib ] || mkdir /usr/nas_source/py-licenselib
	mount | grep -q " on /usr/nas_source/py-licenselib " || \
		mount_nullfs -o ro ${WORK_ROOT}/licenselib /usr/nas_source/py-licenselib

# 批量构建全部 port
ports-bulk: nas-source-bind poudriere-setup
	POUDRIERE_ETC=${POUDRIERE_ETC} poudriere bulk -w -J ${MAKE_JOBS} \
		-j ${POUDRIERE_JAIL} -p ${POUDRIERE_TREE} \
		-f ${CONF}/ports.list

# ---- 对外 ----
ports: ports-bulk

.PHONY: ports ports-bulk poudriere-setup skeleton-jail
