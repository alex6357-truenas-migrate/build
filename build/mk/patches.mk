# build/mk/patches.mk — 向 work/src 与 work/ports 注入补丁
# 实现：build/sh/apply-patches.sh <tree-kind>
# tree-kind: src → patches/src/*.patch → work/src ; ports → patches/ports/*.patch → work/ports

PATCH_STAMP=	.stamps

patches: patches-src patches-ports

patches-src:
	@BUILD_ROOT=${BUILD_ROOT} WORK_ROOT=${WORK_ROOT} \
		sh ${TOOLS_SH}/apply-patches.sh src

patches-ports:
	@BUILD_ROOT=${BUILD_ROOT} WORK_ROOT=${WORK_ROOT} \
		sh ${TOOLS_SH}/apply-patches.sh ports

# 撤销（重置到基线 ref）——重建前清理
repatch-clean:
	@BUILD_ROOT=${BUILD_ROOT} WORK_ROOT=${WORK_ROOT} \
		sh ${TOOLS_SH}/apply-patches.sh clean src
	@BUILD_ROOT=${BUILD_ROOT} WORK_ROOT=${WORK_ROOT} \
		sh ${TOOLS_SH}/apply-patches.sh clean ports

.PHONY: patches patches-src patches-ports repatch-clean
