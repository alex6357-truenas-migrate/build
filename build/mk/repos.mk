# build/mk/repos.mk — 按 repos.conf 拉取/同步仓库（替代 core-build checkout.py）
# 逻辑在 build/sh/repo-sync.sh；bmake 仅做编排与环境注入。

setup:
	@BUILD15_ROOT=${BUILD15_ROOT} WORK_ROOT=${WORK_ROOT} \
		sh ${TOOLS_SH}/repo-sync.sh

manifest:
	@BUILD15_ROOT=${BUILD15_ROOT} WORK_ROOT=${WORK_ROOT} \
		sh ${TOOLS_SH}/repo-manifest.sh

.PHONY: setup manifest
