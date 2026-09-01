# build — TrueNAS Core 构建仓库（当前基线：FreeBSD 15.1）

本仓库是 TrueNAS Core 的**构建编排器**，用于取代 `core-build` 的 python 工具链，以 **bmake + POSIX sh + poudriere** 为唯一编排依赖，并复用 FreeBSD 原生构建系统（`src/Makefile.inc1`、`src/release/`、pkgbase）。

> **版本泛化**：本仓库被设计为可持续跟随 FreeBSD 演进。当前基线是 15.1（见「随 FreeBSD 升级」）；改基线只需改三个文件：`conf/freebsd.mk` 的版本锚点、`repos.conf` 中 `REPO_SRC/REPO_PORTS` 的 pin、`patches/` 与 `conf/` 的 per-version 内容。

## 布局约定（`nas-build/`）

```text
nas-build/
├── build/            # 本仓库：纯 patch + Makefile/sh 构建脚本（无第三方源码）
├── src15/            # freebsd-src worktree（测试用，非迁移产物）
├── middleware/       # truenas 运行时仓库（make setup 的本地种子）
├── webui/
├── licenselib/
├── py-bsd/
├── iocage/
└── freenas-pkgtools/ # legacy pkgtools（pkgbase 迁移完成后淘汰）
```

参考仓库（工作区根，不进构建）：`../os`（13.3 fork 源参考）、`../ports`（fork 盘点源）、`../freebsd-src` 与 `../freebsd-ports`（上游）、`../core-build`（旧构建系统参考）、`../iocage-ix-plugins`（运行时数据仓，淘汰）。

## 用法（目标环境：FreeBSD 15.1 构建机，root）

```sh
git clone <this-repo> && cd <this-repo>
make setup      # 按 repos.conf 拉取 src/ports 与各 pkg 仓库到 ./work/（优先本地种子 ../<repo>）
make patches    # 把 patches/src 与 patches/ports 注入 ./work/src、./work/ports
make release    # buildworld + buildkernel + poudriere + pkgbase + ISO
```

产物（预期，`make release` 完成后）：

- `repo/`：自签 pkg 仓库（FreeBSD-\* 基础包 + ports 包层）
- `release/<arch>/`：ISO 安装介质（含旧 dist webui + iocage）
- `objs/logs/`：构建日志

## 目录

```text
build/
├── repos.conf          # 仓库清单与版本 pin（见各 REPO_* 注释）
├── patches/
│   ├── src/            # 15.1 src 补丁（12 个整合 patch + REMOVED.md 说明）
│   └── ports/          # 15.1 ports 基线补丁（P2 定稿）
├── ports-extra/        # 私有 ports（freenas/*、truenas/*），以 overlay 合入
├── conf/               # freebsd.mk、内核配置、src.conf.*、poudriere 模板
├── build/mk|sh         # bmake 构建系统本体
└── AUDIT-15.1.md       # P0：各第三方仓库 15.1 适配审计
```

## 实施阶段追踪

| 阶段 | 内容 | 状态 |
| ---- | ---- | ---- |
| P0 | 各仓库 15.1 适配审计 → AUDIT-15.1.md | 已完成 |
| P1 | 仓库骨架（本目录 + repos.conf + 补丁迁移） | 已完成 |
| P2 | ports 基线 pin（2026Q3）+ patches/ports + ports-extra 定稿 | 已完成 |
| P3 | bmake/sh 构建系统（替代 core-build python 工具链） | 骨架完成，待 P6 验证迭代 |
| P4 | webui：预编译 dist 壳 port（`freenas/webui-dist`）+ 构建脚本 | 配置层已完成，待 dist 实物 |
| P5 | iocage：**保留 fork**，`ports-extra/sysutils/iocage` 改 USE_GITHUB | 已完成（配置层） |
| P6 | FreeBSD 15.1 全链路构建验证 | 待构建机 |
| P7 | 文档收尾 | 进行中 |

## 关键设计决策（与 core-build 的差异）

| 决策 | 说明 |
| ---- | ---- |
| os fork 不再直接进构建 | 13.3 时代 os fork 的全部有效内容已重做进 `patches/src`（12 patch）；构建直接以 upstream `releng/15.1` 为基线 |
| ports 基线 = 上游新快照 + overlay | 放弃 truenas/ports fork；私有 port 收拢进 `ports-extra/`，Mk/少量调整进 `patches/ports/` |
| 打包 = pkgbase + pkg(1) | 淘汰 freenas-pkgtools 的 tgz+manifest；更新走自签 pkg repo（pkgtools/migrate93/113 已物理删除） |
| webui 第一期不做现代化 | 用 `webui-dist` 预编译 dist 壳 port（P4）；后期单独阶段重写 |
| iocage 保留 fork | fork 带上游没有的 tarfile 安全修复等；port 从 `../iocage` 种子或 GitHub 拉 fork 源（审计见 AUDIT-15.1.md） |
| zfs 直接用 base 2.4.2 | fork（钉 2.2.5）删除；ports-extra 不再有 openzfs/openzfs-kmod |
| wsdd 用上游 ports | `net/py-wsdd` 替代 fork |
| scanlnk 剔除 | 无任何消费方 |
| core-build 已删除 | 旧 python 构建系统不再保留参考 |
| 零 python 编排层 | core-build 的 buildenv.py/dsl/*.pyd 全部废弃；运行时组件（middlewared、iocage）不受此限 |

## 随 FreeBSD 升级（新版本跟进清单）

把基线从 15.1 换成（例如）15.2/16.0 时按顺序做：

1. **改基线 pin**：`conf/freebsd.mk`（`FREEBSD_BRANCH`/`FREEBSD_REL_VER`/`PORTS_QUARTER`）；`repos.conf` 中 `REPO_SRC`/`REPO_PORTS` 第 2 字段换 SHA。
2. **重建 src 补丁**：把 `patches/src/*.patch` 在新基线工作树上重新 3-way（参照 `patches/src/README.md` 每条 Rebase notes）。
3. **审计 src.conf**：`conf/src.conf.{build,run,boot}` 中各 `FIXME` 项对照新 base 的 `share/mk/src.opts.mk`。
4. **审计内核配置**：`conf/kernel/TRUENAS*` 的 option 在新 base 的存废（参 `sys/conf/NOTES`）。
5. **ports 层**：`ports-extra/` 在新季度能否编；`patches/ports` 重新锚定（waf/python/gem/MOVED 逐条问「上游化了吗」）。
6. **ports.list 复核**：fork-only port 的上游迁移分类（如 openzfs→filesystems/）、被移除端口替换、flavor 变化。
7. **跑通构建**：`make setup patches world` → ports → packages → images 分阶段过。
8. **更新文档**：本 README 的「当前基线」、AUDIT-<新版>.md。

## 参考文档

- `patches/src/README.md`：12 patch 的逐条说明、15.1 状态、rebase 要点
- `patches/src/REMOVED.md`：12 项已被 15.1 上游采纳、丢弃的 backport
- `../../truenas-os-modifications.md`：13.3 fork 的全部定制修改与 15.1 上游核查母报告
- `../../todo.md`：会话任务清单
