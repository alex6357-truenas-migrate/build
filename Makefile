# build — TrueNAS Core × FreeBSD 15.1 顶层 Makefile
# 使用：详见 README.md。所有 target 仅依赖 bmake + POSIX sh + git。

BUILD_ROOT:=	${.CURDIR:tA}

.include "build/mk/common.mk"
.include "build/mk/repos.mk"
.include "build/mk/patches.mk"
.include "build/mk/world.mk"
.include "build/mk/ports.mk"
.include "build/mk/packages.mk"
.include "build/mk/images.mk"

release: setup patches ports packages images
	@echo "build release: staged into ${RELEASE_ROOT}（M1=release(7) 介质 + pkg repo）"

# 一键产出：复刻 core-build release target 语义
	@mkdir -p ${RELEASE_ROOT}/${MACHINE_ARCH}
	@echo "[release] pkg repo: ${PKG_REPO}/final"
	@echo "[release] images: ${M1_RELEASE_DIR}"

clean:
	rm -rf ${OBJS}
	rm -rf ${RELEASE_ROOT}

distclean: clean
	rm -rf ${WORK_ROOT}

.PHONY: setup patches world kernel ports packages images release clean distclean manifest
