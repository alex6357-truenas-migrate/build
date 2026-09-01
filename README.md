# build15 — TrueNAS Core × FreeBSD 15.1 构建仓库

本仓库是 TrueNAS Core 从 FreeBSD 13.3 迁移到 FreeBSD 15.1 的**构建编排器**，用于取代 `core-build` 的 python 工具链，以 **bmake + POSIX sh + poudriere** 为唯一编排依赖，并复用 FreeBSD 原生构建系统（`src/Makefile.inc1`、`src/release/`、pkgbase）。

## 用法（目标环境：FreeBSD 15.1 构建机，root）

```sh
git clone <this-repo> && cd <this-repo>
make setup      # 按 repos.conf 拉取 src/ports 与各 pkg 仓库到 ./work/
make patches    # 把 patches/src 与 patches/ports 注入 ./work/src、./work/ports
make release    # buildworld + buildkernel + poudriere + pkgbase + ISO
```

产物（预期，`make release` 完成后）：

- `repo/`：自签 pkg 仓库（FreeBSD-\* 基础包 + ports 包层）
- `release/<arch>/`：ISO 安装介质（含旧 dist webui + iocage）
- `objs/logs/`：构建日志

## 目录

```text
build15/
├── repos.conf          # 仓库清单与版本 pin（见各 REPO_* 注释）
├── patches/
│   ├── src/            # 15.1 src 补丁（12 个整合 patch + REMOVED.md 说明）
│   └── ports/          # 15.1 ports 基线补丁（P2 定稿）
├── ports-extra/        # 私有 ports（freenas/*、truenas/*），以 PORTS_OVERLAY 合入
├── conf/               # 内核配置、src.conf.*、poudriere 模板
├── build/mk|sh         # bmake 构建系统本体
└── AUDIT-15.1.md       # P0：各第三方仓库 15.1 适配审计
```

## 实施阶段追踪

| 阶段 | 内容 | 状态 |
| ---- | ---- | ---- |
| P0 | 各仓库 15.1 适配审计 → AUDIT-15.1.md | 进行中 |
| P1 | 仓库骨架（本目录 + repos.conf + 补丁迁移） | 已完成 |
| P2 | ports 基线 pin + patches/ports + ports-extra 定稿 | |
| P3 | bmake/sh 构建系统（替代 core-build python 工具链） | |
| P4 | webui 旧 dist 构建或预编译 dist 兜底 | |
| P5 | iocage 决策落地（默认用上游 ports 版本） | |
| P6 | FreeBSD 15.1 全链路构建验证 | |
| P7 | 文档收尾 | |

## 关键设计决策（与 core-build 的差异）

| 决策 | 说明 |
| ---- | ---- |
| os fork 不再直接进构建 | 13.3 时代 os fork 的全部有效内容已重做进 `patches/src`（12 patch / `src15` 历史见 nas-build/patches）；构建直接以 upstream `releng/15.1` 为基线 |
| ports 基线 = 上游新快照 + overlay | 放弃 truenas/ports fork；私有 port 收拢进 `ports-extra/`，Mk/少量调整进 `patches/ports/` |
| 打包 = pkgbase + pkg(1) | 淘汰 freenas-pkgtools 的 tgz+manifest；更新走自签 pkg repo |
| webui 第一期不做现代化 | 先用旧链构建或预编译 dist（P4 决策），后期单独阶段重写 |
| iocage 保留 | 默认采用 ports 基线中的 `sysutils/iocage`（P5 验证） |
| 零 python 编排层 | core-build 的 buildenv.py/dsl/*.pyd 全部废弃；运行时组件（middlewared、iocage）不受此限 |

## 参考文档

- `../patches/README.md`（原始位置）与本目录 `patches/src/README.md`：12 patch 的逐条说明、15.1 状态、rebase 要点
- `patches/src/REMOVED.md`：12 项已被 15.1 上游采纳、丢弃的 backport
- `../../truenas-os-modifications.md`：13.3 fork 的全部定制修改与 15.1 上游核查母报告
- `../../todo.md`：会话任务清单
