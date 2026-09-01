# ports-extra — TrueNAS 私有 ports（合入 2026Q3 ports 杭州的 overlay）

三个来源：

- **A. ports fork 真私货**（30 个，fork 相对上游独有）：
  `net/samba`（truenas fork 4.19.6，带 wscript 私有 patch + 自有 rc 脚本）、
  `sysutils/openzfs`+`sysutils/openzfs-kmod`（钉 zfs 2.2.5 + iX patch，⚠ 与上游 `filesystems/openzfs` 2.3 冲突待裁决）、
  `devel/py-libzfs`/`net/py-netif`/`devel/py-cam`（上游已删，仅 fork 持有——15.1 ABI 复核必需）、
  `devel/libhyve-remote`（bhyve-vnc src patch 100 的运行时依赖）、
  `www/py-ws4py`（middlewared 依赖）、`www/py-django110`、`devel/py-bhyve`、
  `devel/py-kmip|py-netsnmpagent|py-onedrivesdk`、`sysutils/py-wsdd|py-zettarepl|sedutil|throttle|scanlnk|asigrajail|areca-cli|intel-e810-nvmupdate|dsoperator|dssystem`、`sysutils/grub2`+`grub2-x86_64-efi`+`uefi-edk2-bhyve`（VM 引导）、`net/netatalk3`（AFP）、`dns/inadyn-troglobit`（DDNS）、`devel/rubygem-sidekiq71`、`lang/python39-debugging`。
  - 已判定丢弃（fork-only 但无意义）：`devel/electron25/26/27`、`java/openjdk19/20`（cherry-pick 后上游又删）、`devel/py-boto3`（上游现处以 www/py-boto3 存在）。

- **B. nas_ports（来自 truenas/middleware 仓库，15 个）**：`freenas/*`（含 `py-middlewared`、`freenas-files`、`freenas-installer`、`freenas-pkgtools`、`py-bsd`、`py-licenselib`、`py-midcli`、`freenas-migrate93/113`、`arcsas`、`firmware`、`pipewatcher`、`swagger-ui`、`tc-stats`）+ `truenas/py-fenced`。

- **C. webui 构建链（来自 truenas/webui 仓库 ports/）**：
  `freenas/freenas-webui`（当代码原地构建时的 port；P4 决策后或将由 `freenas/webui-dist` 壳 port 取代）。
  `node9`（实为 node 6.14.1）与 `npm5` **不迁移**——见 AUDIT-15.1.md webui 节。

## 构建合入方式

P3 的 `mk/ports.mk` 把 `ports-extra/<category>/<port>` 合入 `work/ports`（软链或 copy），
并在 `Mk/bsd.local.mk` / 各分类 Makefile 注册 `SUBDIR +=` 与 `VALID_CATEGORIES`。

## 复核关键词（15.1 适配）

- `sysutils/openzfs` 钉旧版 vs 上游 `filesystems/openzfs` 2.3 对 FreeBSD 15.1 头文件的适配（上游更可能兼容）；
- `devel/py-libzfs`/`net/py-netif` 是 truenas private fork 版本——15.1 下是否还能编译，先看 `USES` / `GH_*` 锁定点；
- `net/samba` 私有 fork 需要 15.1 的 `AT_UTIMENSAT_BTIME`（src patch 420 提供，waf 检测候选项）。
