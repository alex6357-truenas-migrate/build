# UPSTREAMS.md — 追踪哪个上游的指南（构建仓库维护手册）

适用原则：
- **truenas 还在维护** → 追 `truenas/<repo>`
- **truenas 不再维护的 TrueNAS-CORE-only 衍生** → 追 `freecore-project`（GitHub 是 release 镜像；开发实际在 Codeberg `codeberg.org/freecore/<repo>`）
- **通用 FreeBSD/独立上游** → 追 `github.com/<upstream>/<repo>` 或 ports 树
- **我们自持有 fork** → `alex6357-truenas-migrate/<repo>`，向上游转化为目标

最后核对是 2026-08-31（GitHub/Codeberg API）。

## 我方仓库 × 追踪源 决策矩阵

| 仓库 | 15.1 构建角色 | 追踪源 | 原因 / 侧注 |
|---|---|---|---|
| **middleware** | 运行时核心（middlewared + nas_ports） | **tracenas/middleware**（SCALE 主线 `master` 活跃，2026/09/01 push） | truenas CORE-side 已不维护 13-stable，但 middleware 本体仍是 truenas 活跃维护的目标。freecore 在 Codeberg 的 `middleware` 有供 FreeCORE（13.3→15.0）的分支，用于跟进 CORE 侧修复（见下） |
| **webui** | 运行时前端 | **truenas/webui**（push 2026/09/01）→ P4 dist 壳支持 | freecore 在 GitHub `freecore-project/webui` 有维护版（TypeScript），可作为 CORE-side 后继（见下） |
| **licenselib** | Enterprise 授权 | **truenas/licenselib**（push 2026/08/31） | freecore 无此仓 — FreeCORE 不做企业授权链 |
| **py-bsd** | middleware ABI 绑定 | **tracenas/py-bsd**（2025/07/08）→ fork 保留现 15.1 适配 | freecore 有同名仓（2026/08/21），可能含 15.x 适配，可借鉴 |
| **iocage** | jail/plugin 管理 | **freecore-project/iocage**（GitHub，push 2026/08/27） | truenas/iocage 已停 13.0-stable（2025/07/08 起；最后 push 在 CORE 维度即归档）。 freecore 延续之并出 freecore-plugins 目录 |
| **samba** | SMB 核心 | **tracenas/samba**（默认分支已迁 `truenas/v4-24-stable`，含全部 10+ 个私有 VFS 模块，push 2026/08/31） | freecore-project/samba 也要跟：它把 truenas fork 重做成 "reviewed delta"（2026/08/21），但缺 shadow_copy_zfs/tmprotect/smblibzfs，我们不移过去，只把它当的快照看板 |
| **py-libzfs** | ZFS 结构化接口 | **tracenas/py-libzfs**（push 2026/08/31） | freecore-project/py-libzfs 也在维护；同一上游源同源 |
| **py-netif** | 网卡枚举 | **tracenas/py-netif**（2024/05/03 最后 push，实际已 arch，14 个月未动） | freecore-project/py-netif 2026/08/21 仍在动 → **换 freecore**（或等价：直接接收 freecore 的后续） |
| **py-cam** | CAM/SCSI | **tracenas/py-cam**（2022/06/09，3 年未动 = frozen） | freecore-project/py-cam 同样 2026/08/21 仍在动 → **换 freecore** |
| **py-bhyve** | bhyve 控制 | **freenas/py-bhyve**（truenas/ 已 404） | freecore 未列组织仓，但我们仍需 bhyve-vnc patch 的 libhyverem 依赖；保持 **自持有 fork**（并入 migrate 组织） |
| **libhyve-remote** | bhyve VNC | **freenas/libhyve-remote**（truenas/ 已 404） | freecore 无 → **自持有** |
| **py-zettarepl** | 复制引擎 | **tracenas/zettarepl**（push 2026/08/31 活跃） | freecore 无（他们用 middleware 自己的复制路径） |
| **midcli** | CLI | **tracenas/midcli**（push 2026/08/31） | freecore 无 |
| **truecommand-stats** | TrueCommand 统计 | **tracenas/truecommand-stats**（2022/10 已 ARCHIVED） | 无维护者；一旦用户不需要 TrueCommand 即剔除 |
| **licenselib** | Enterprise 授权 | **tracenas/licenselib**（活跃） | freecore 无 |
| **zfs** | ports openzfs | **不要 fork**。15.1 base 已带 OpenZFS 2.4.2，ports 已 2.4.3；truenas/zfs fork 的修复已并入 | freecore 也直接跟 openzfs.org/FreeBSD base |
| **wsdd** | WSD 服务 | **上游 ports** `net/py-wsdd`（@christgau 0.9） | fork 已删 |
| **sedutil** | SED 加密 | **上游 ports 无此 port**；amotin fork 的 freebsd CLI 是唯一现成实现 → **自持有 amotin/sedutil fork** | freecore 无此 port |
| **scanlnk** | 无消费 | **剔除** | freecore 也无 |

## freecore-project 的维护范围与"为什么它们不管某些包"

freecore（网络名 freecore-project，Codeberg 主区 codeberg.org/freecore，GitHub 只是 release 镜像，问题/评论在 Codeberg）当前组织仓是：

> build · freebsd-src · freecore · freenas-pkgtools · iocage · iocage-freecore-plugins · middleware · ports · py-bsd · py-cam · py-libzfs · py-netif · samba · webui （+ profile/.github）

可以看出他们**显式不持有**的东西分几类，对应规则基本可移植到我们这边：

| 他们不持的 | 原因（可推知） | 是否影响我们 |
|---|---|---|
| `src` / `ports` fork | 直接用 freebsd 上游的 "reviewed delta" 模式（freebsd-src/ports 是 mirror+diff），不要独立 fork | 对我们也一样——nas-build/src15 只是参考，进构建的是 patches/* |
| `zfs` fork | 他们依赖 15.x base 的 OpenZFS 2.4.2（和我们选择一致） | 对齐 |
| `wsdd` / `sedutil` / `scanlnk` / `py-bhyve` / `libhyve-remote` / `truecommand-stats` / `zettarepl` / `midcli` / `licenselib` | 功能覆盖窄或需求方已变（如 truecommand 远程统计在 FreeCORE 无消费；受权链/CLI 只面向 SCALE） | 我们按上表处理 |
| `licenselib` | 企业授权链 ≠ FreeCORE 范畴 | 我们需要（truenas 仍在维护） |

一句话结论：**能追 truenas 就追 truenas；truenas ARCHIVED 或 404 的优先看 freecore-project；freecore 也没有则按"自持有 fork / 上游 ports / 剔除"三择一（见上表）。**

## 仓级追踪链接

- truenas/middleware: <https://github.com/truenas/middleware>
- truenas/webui: <https://github.com/truenas/webui>
- truenas/samba: <https://github.com/truenas/samba>（默认分支 `truenas/v4-24-stable`）
- truenas/py-libzfs: <https://github.com/truenas/py-libzfs>
- truenas/zettarepl: <https://github.com/truenas/zettarepl>
- truenas/midcli: <https://github.com/truenas/midcli>
- truenas/licenselib: <https://github.com/truenas/licenselib>
- truenas/py-bsd: <https://github.com/truenas/py-bsd>
- truenas/py-netif（frozen）: <https://github.com/truenas/py-netif> → 换 <https://github.com/freecore-project/py-netif>
- truenas/py-cam（frozen）: <https://github.com/truenas/py-cam> → 换 <https://github.com/freecore-project/py-cam>
- freecore 汇总（GitHub 镜像只）: <https://github.com/freecore-project>
- freecore 开发侧（Codeberg）: <https://codeberg.org/freecore>

## 手动推送时检查清单

把本地 nas-build/\<pkg\> 推上 `alex6357-truenas-migrate` 时：

1. `git push origin master`（或对应构建分支）→ 仓之首 push 会建仓
2. 回检 `git remote get-url origin` 指向正确 org
3. 对 samba：确认 push 的 HEAD 是 pin `4fec43c0`；org 上默认分支最好设成同一分支，避免 fork pin 漂移
4. 若 org 后续自己 host 了 truenas 上游某仓，记得在 `repos.conf` 里把该 REPO_* 行注释为 "已由 org 镜像"
