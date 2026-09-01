# build15 — TrueNAS Core × FreeBSD 15.1 顶层 Makefile
# 使用：详见 README.md。所有 target 仅依赖 bmake + POSIX sh + git。

BUILD15_ROOT:=	${.CURDIR:tA}

.include "build/mk/common.mk"
.include "build/mk/repos.mk"
.include "build/mk/patches.mk"
.include "build/mk/world.mk"

ports:
	@echo "TODO(P3-ports): poudriere overlay 装配 + bulk（mk/ports.mk 待写）"

packages:
	@echo "TODO(P3-packages): pkgbase + pkg repo（mk/packages.mk 待写）"

images:
	@echo "TODO(P3-images): release(7) NAS 化 + mkisoimages（mk/images.mk 待写）"

release: setup patches world kernel ports packages images
	@echo "build15 release done (ports/packages/images 待 P3 实现)"

clean:
	rm -rf ${OBJS}
	rm -rf ${RELEASE_ROOT}

distclean: clean
	rm -rf ${WORK_ROOT}

.PHONY: setup patches world kernel ports packages images release clean distclean manifest
