# build/mk/images.mk — ISO/介质产出
#
# 分两阶段（对应原 create-iso.py 的 instufs/iso 双世界思路）：
#   M1（当前）：直接复用 src/release 的 release(7) 流程产出可引导 disc1/memstick，
#      其中通过 PORTSDIR 引用已打完端口的 work/ports、KERNCONF=TRUENAS。
#   M2（TODO）：TrueNAS instufs 裁剪逻辑（白名单 bin + /rescue symlink + base.ufs.uzip
#      + freenas-installer）改写为 build/sh/mkinstall.sh 后生成分版安装器。

M1_RELEASE_DIR?=	${OBJS}/release-m1

# M1：首版可直接引导的 release 介质（FreeBSD 安装盘骨架，内核即 TRUENAS）
images-m1: world kernel packages
	mkdir -p ${M1_RELEASE_DIR}
	${BUILD_ENV} ${MAKE} -C ${WORK_SRC}/release \
		SRCCONF=${SRC_MAKE_CONF:Q} \
		KERNCONF=TRUENAS KERNCONFDIR=${CONF}/kernel \
		WITH_DVD= NOPKG=yes NOPORTS=yes NOSRC=yes \
		TARGET=${MACHINE_ARCH} \
		DESTDIR=${M1_RELEASE_DIR} \
		PORTSDIR=${WORK_PORTS} \
		release

# M2 占位（TrueNAS 安装器）：依赖 freenas-installer 与 pkgbase 装机后续
images-installer:
	@echo "TODO(M2): mk/sh 改写 create-iso.py → base.ufs.uzip + TrueNAS installer ISO"

images: images-m1

.PHONY: images images-m1 images-installer
