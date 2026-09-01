# build/mk/packages.mk — pkgbase + 自签 pkg repo（替代 build-packages.py / create_*-distribution.py）
# 策略：
#   1) src `make packages` → pkgbase（FreeBSD-* 包），在 ${OBJS}/repo 落下 base 仓
#   2) ports 仓（poudriere 输出 ${POUDRIERE_ETC}/../data/packages/<jail>-<tree>）拷入合并
#   3) pkg repo 重建 + 可选 minisign/公钥签名（PKG_REPO_KEY 指定时）

PKGBASE_REPO?=	${PKG_REPO}/base
PKG_FINAL?=	${PKG_REPO}/final
POUDRIERE_BASE?=	${OBJS}/poudriere
POUDRIERE_DATA?=	${POUDRIERE_BASE}/data/packages/${POUDRIERE_JAIL}-${POUDRIERE_TREE}

# src pkgbase 打包（须 world+kernel 已构建）
packages-base: world kernel
	${BUILD_ENV} ${MAKE} -C ${WORK_SRC} \
		SRCCONF=${SRC_MAKE_CONF:Q} \
		KERNCONFDIR=${CONF}/kernel KERNCONF=TRUENAS \
		MODULES_OVERRIDE='${KERN_MODULES}' \
		NO_PKG_VERSIONS=yes PORTSDIR=${WORK_PORTS} \
		packages
	mkdir -p ${PKGBASE_REPO}
	# pkgbase 输出在 ${OBJS}/src.<machine>/repo/<version>/
	_repo=$$(find ${OBJS} -maxdepth 3 -type d -name 'FreeBSD-*' 2>/dev/null | head -1); \
	if [ -n "$$_repo" ]; then cp -R "$$_repo"/* ${PKGBASE_REPO}/; fi

# 合并 pkgs 出最终仓（base + ports）
packages-merge: packages-base
	mkdir -p ${PKG_FINAL}
	cp -R ${PKGBASE_REPO}/* ${PKG_FINAL}/ 2>/dev/null || true
	if [ -d ${POUDRIERE_DATA}/All ]; then cp -R ${POUDRIERE_DATA}/All/* ${PKG_FINAL}/; fi

# pkg repo 索引 +（可选）签名
packages-repo: packages-merge
	cd ${PKG_FINAL} && pkg repo .
.if defined(PKG_REPO_KEY)
	ssh-agent sh -c "ssh-add ${PKG_REPO_KEY} 2>/dev/null || minisign -S -s ${PKG_REPO_KEY} -m ${PKG_FINAL}/meta.pkg" || true
.endif

# 最终清单 *包含 URL 元数据的 meta* 由 release 写出
packages: packages-repo

.PHONY: packages packages-base packages-merge packages-repo
