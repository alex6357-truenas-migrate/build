# conf/freebsd.mk — FreeBSD 版本开关（全仓唯一版本锚点）
#
# 跟随新版本 FreeBSD 时只改本文件 + repos.conf 中 REPO_SRC/REPO_PORTS 的 pin。
# 其他所有 mk/sh 都不应出现裸 15.1 字符串。

# 目标 FreeBSD 分支与发行标记（用于 poudriere jail -v、release/runner 展示、日志）
FREEBSD_BRANCH?=	releng/15.1
FREEBSD_REL_VER?=	15.1-RELEASE

# ports 基线季度（与 FREEBSD_BRANCH 同期）
PORTS_QUARTER?=	2026Q3

# 上面两处 base SHA 仍由 repos.conf 承载（见 REPO_SRC/REPO_PORTS）。
# 提示：升级到新版本后，必须重新走 patches/README.md 的「基线变更清单」。
