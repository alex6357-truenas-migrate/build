# build/mk/world.mk — buildworld/buildkernel/installworld（替代 build-os.py + install-world.py）
# 只调 src 原生 target；变量来自 common.mk。src.conf 层叠用 cat 合并。

# 13.3 时代 products 模块清单（core-build config.pyd kernel_modules）
KERN_MODULES?=	autofs bnxt cc cfiscsi ctl dtrace efirt evdev ext2fs firewire geom hid \
	i2c if_wg ipmi ipsec iscsi khelp/h_ertt libiconv libmchain linprocfs linsysfs \
	linux linux64 linux_common mac_ntpd msdosfs_iconv ispfw/ispfw opensolaris pf pflog \
	smbfs udf usb fusefs vmm netmap nmdm ntb nvdimm ioat toecore cxgb cxgbe dummynet \
	hwpmc ibcore ipoib mlx4ib mlx5ib mthca qlnx qlxgbe qat qatfw iser fxp ice_ddp sis \
	hpt27xx hptmv hptnr hptrr
# FIXME(P3-15.1-audit): ntb/nvdimm/ioat/iser 等在 15.1 的存在性与 ixnvdimm(600) 联动核对

BUILD_ENV=	env -u DEBUG -u MAKEFLAGS MAKEOBJDIRPREFIX=${OBJS}
SRC_MAKE_CONF=	${OBJS}/src.conf.merged

# 把 build/run/boot 三档 src.conf 叠成一份
${SRC_MAKE_CONF}:
	mkdir -p ${OBJS}
	cat ${CONF}/src.conf.build ${CONF}/src.conf.run > ${SRC_MAKE_CONF}

world: ${SRC_MAKE_CONF}
	${BUILD_ENV} ${MAKE} -C ${WORK_SRC} -j${MAKE_JOBS} \
		SRCCONF=${SRC_MAKE_CONF:Q} \
		NOCLEAN=${NOCLEAN:Uno:tl} \
		buildworld

kernel: ${SRC_MAKE_CONF}
	${BUILD_ENV} ${MAKE} -C ${WORK_SRC} -j${MAKE_JOBS} \
		SRCCONF=${SRC_MAKE_CONF:Q} \
		KERNCONFDIR=${CONF}/kernel KERNCONF=TRUENAS \
		MODULES_OVERRIDE='${KERN_MODULES}' \
		NO_KERNELCLEAN=YES buildkernel
	${BUILD_ENV} ${MAKE} -C ${WORK_SRC} -j${MAKE_JOBS} \
		SRCCONF=${SRC_MAKE_CONF:Q} \
		KERNCONFDIR=${CONF}/kernel KERNCONF=TRUENAS-DEBUG \
		MODULES_OVERRIDE='${KERN_MODULES}' \
		NO_KERNELCLEAN=YES buildkernel

world-install: ${SRC_MAKE_CONF}
	${BUILD_ENV} ${MAKE} -C ${WORK_SRC} \
		SRCCONF=${SRC_MAKE_CONF:Q} \
		DESTDIR=${DESTDIR:U${OBJS}/world} \
		installworld distribution
	${BUILD_ENV} ${MAKE} -C ${WORK_SRC} \
		SRCCONF=${SRC_MAKE_CONF:Q} \
		DESTDIR=${DESTDIR:U${OBJS}/world} \
		KERNCONFDIR=${CONF}/kernel KERNCONF=TRUENAS \
		MODULES_OVERRIDE='${KERN_MODULES}' installkernel
	${BUILD_ENV} ${MAKE} -C ${WORK_SRC} \
		SRCCONF=${SRC_MAKE_CONF:Q} \
		DESTDIR=${DESTDIR:U${OBJS}/world} KODIR=/boot/kernel-debug \
		KERNCONFDIR=${CONF}/kernel KERNCONF=TRUENAS-DEBUG \
		MODULES_OVERRIDE='${KERN_MODULES}' installkernel

.PHONY: world kernel world-install
