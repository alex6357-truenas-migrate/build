# AUDIT-15.1 — 第三方仓库 FreeBSD 15.1 适配审计（P0）

逐仓结论。每节末尾的【必要动作】会同步进 P2/P3/P4 任务。

## os（truenas/os fork）
- 角色：13.3 时代 FreeBSD 源码 fork。
- 结论：**不进 15.1 构建**。全部有效内容已重做进 `patches/src/` 的 12 个整合 patch（`nas-build/src15` 工作树 `truenas/15.1-patches` 分支已应用）。
- 必要动作：无（保持 ref 参考即可）。

## webui（truenas/webui，5b25fbff2c，detached HEAD）
- 角色：前端 UI（Angular 9.1.1 + TS 3.6.4 + webpack4 内置于 build-angular 0.901）。
- 15.1 风险：
  - `node9` port 实为 Node 6.14.1（`Makefile:4 PORTVERSION=6.14.1`）+ `USES=python:2.7,build`；新版 ports 的 libuv 1.4x 与 node6 所需 1.16 严重不兼容，且在 clang20/OpenSSL3/OpenSSL1.0.2 捆绑 asm 面前几乎不可编译。
  - `npm5`=npm 5.7.1，`python:2.7,run`，依赖 node9 port。
  - `freenas-webui` port：`EXTRACT_ONLY=`、`WRKSRC=/usr/webui` 原地构建，`fetch` 阶段写 `product.ts`、随后 `yarn install && yarn run build:prod:aot`，无离线缓存——poudriere 断网环境不可行。
  - 仓库内无 dist/ 或 release tarball；唯一产物文化是 Dockerfile（node:16-buster 构建出 dist 拷进 nginx 镜像）。
- 15.1 现状澄清：2026-08 的 freebsd-ports main **仍含** lang/python2、lang/python27、www/yarn；顾虑"python27 消失"不成立——但老链依赖矩阵整体不可行。
- 决策：
  - **主线 = 方案 C**：webui 以预编译 dist tarball 提供，ports-extra 放一个壳 port（静态文件安装到 `/usr/local/www/webui`，复用现有 `do-install`/`rsync` 逻辑）。
  - **并行低成本尝试 = 方案 B**：在 15.1 poudriere jail 里用新 ports 自带 `node20` + `yarn-node20` 构建，只需注入 `NODE_OPTIONS=--openssl-legacy-provider`（规避 webpack4/md4/OpenSSL3 冲突）并打通 yarn 离线 mirror；一次通过即升级为主线。
  - 放弃：方案 A（老链硬撑）。
- 必要动作：
  1. ports-extra 增 `freenas/webui-dist` 壳 port；
  2. 上游 webui 仓库产物 dist 的来源（Docker node:16 镜像构建 / 手工一次性构建）在实施时落实；
  3. node9/npm5 port 标 REMOVED 说明。

## middleware（truenas/middleware @ cdc3fa664d, truenas/13.3-stable）
- 角色：middlewared 后端 + nas_ports 私有 ports + freenas-installer。
- 15.1 风险：
  1. **python 版本硬假设少**：全仓库 grep `python3.9/python39/python2` 仅 `src/freenas/usr/local/share/python-gdb/libpython.py` 1 处（调试辅助，可安全更新）。middlewared 本身跟随 ports `DEFAULT_VERSIONS`（低）。
  2. **rc 补丁耦合**（高）：`src/freenas/etc/ix.rc.d/ix-*` 共 15 个脚本 + `etc/rc.d/ix-haready|ix-postinit|ix-update-scripts`；其中 devd `REQUIRE: netif ldconfig` 删除是为 ix-syncdisks 解除循环依赖，rc.subr 不自动 export `${name}_env`（src patch 700）与 ix 脚本自管环境配套。→ src 补丁 300/700 与 middleware 是**强依赖对**。
  3. **libzfs 绑定**（中）：`middlewared/plugins/pool.py`、`zfs.py`、`*_freebsd.py` 平台模块直接 `import libzfs`（client.py、events 等 8 处）；15.1 需保证 ports-extra 的 `devel/py-libzfs` 与 `filesystems/openzfs`（新分类）版本配套。
  4. **pkgtools 耦合**（高，pkgbase 迁移点）：`src/freenas-installer/etc/install.sh:1068` 调 `/usr/local/bin/freenas-install -P /.mount/${OS}/Packages -M ...-MANIFEST /tmp/data`；`ix-update`、`rc.d/ix-update-scripts` 驱动 post-install/update 脚本；middlewared `plugins/update.py` 走 `update-check-available` 外部命令链。→ pkgbase 下 ISO 装机流程须改为 `pkg install` 模式，install.sh 需改（P3/P4）。
  5. **freenas-installer port 极简**：NO_BUILD=yes，只把 `src/freenas-installer/` 脚本装上 staging——保留机制可直接用（仅 port Makefile PORTVERSION 由构建注入）。
- 必要动作（优先级排序）：
  1. 装机/更新链路从 pkgtools 迁 pkgbase：改 `install.sh`、替换 `freenas-install` 调用、重写 `update.py` 依赖段（P3）。
  2. `py-middlewared` port：确认 `USES=python` 版本解析与新版 ports 框架兼容；检查 RUN_DEPENDS 中被 fork 改名的包（参考 ports 盘点节）。
  3. rc 补丁对（src patch 300/700）在 middleware 侧做行为自测清单。

## ports fork（truenas/ports @ 9461a3499b98, 13.3-stable）
- **盘点结果**（详见 F:\zvault\_fork_log.txt / _fork_diff_names.txt）：
  - merge-base = `985bb512c990`（2024-01-04）；fork-only commit **1840**；净 diff **2924 文件 / +113k/-68k**。
  - **92 个 fork 新增 port 目录**；其中 32 个在当前上游 main 已不存在。分类：
    - TrueNAS 私有/复活（**须进 ports-extra**，约 20 个）：`net/samba`（全新 port，truenas fork 4.19.6 钉 SHA + wscript 私有 patch + 自带 rc，最重磅）、`sysutils/openzfs` + `openzfs-kmod`（truenas 钉 zfs2.2.5+iX patch，debug/release 双构建）、`devel/py-libzfs`、`net/py-netif`、`devel/py-cam`、`py-bhyve`、`py-kmip`、`py-netsnmpagent`、`py-onedrivesdk`、`sysutils/dsoperator|dssystem|throttle|scanlnk|asigrajail|areca-cli|intel-e810-nvmupdate|sedutil|py-wsdd`、`py-zettarepl`、`grub2`+`grub2-x86_64-efi`、`uefi-edk2-bhyve`、`netatalk3`、`inadyn-troglobit`、`python39-debugging`；
    - cherry-pick 后上游又删（**丢弃**）：electron25/26/27、openjdk19/20 等；
    - 其余 60 个均为 backport，上游已有，**丢弃**。
  - **Mk/ 真 patch（须进 patches/ports）**：`waf.mk` 加 WAF_ENV（samba 必需）；`python.mk` 强制 cryptography-legacy（新快照重审）；`gem.mk` GEMS_SKIP_SUBDIR 重构（仅 gitlab 系需要，可再评）；`bsd.default-versions.mk` NODEJS_DEFAULT=18（15.1 环境重审）；`kde.mk/qt.mk` 纯版本 bump（丢弃）。
  - 其他：`www/nginx-devel` 仅版本 bump（丢）；`GIDs/UIDs` 无改动；`MOVED` 撤销了 py-ws4py/libhyve-remote/net-wireguard 过期记录；`misc/freebsd-release-manifests` 13.3 manifests（丢）；顶层 Jenkinsfile（不进 overlay）。
  - 注意点：上游 2026 快照 `sysutils/openzfs` 已迁至 `filesystems/openzfs`、`py-boto3` 从 devel → www、`py-libzfs`/`py-netif` 上游**已彻底移除**（只能从 fork 移植新版）。
  - 遗留核对：rsync/freerdp/openssh-portable/collectd5/rrdtool/net-snmp/curl/powerdns-recursor 逐 port 剥离 iX 私货；`net/samba` 与上游 `samba4xx` 的 CONFLICTS/分类共存。
- 必要动作（P2）：
  1. 按上表抽 ~20 个 fork-only port 进 `ports-extra`（并对 92 个目录逐一裁决 keep/drop）；
  2. `patches/ports` 落定：waf.mk WAF_ENV、python.mk（重审）、NODEJS_DEFAULT（重审）、MOVED un-expire；
  3. 私有 port 目录名/分类对齐上游 2026 框架（openzfs → filesystems/、RUN_DEPENDS 路径调整）。

## py-bsd（truenas/py-bsd master）
- 状态：**审计进行中**。

## licenselib（truenas/licenselib master）
- 状态：**审计进行中**。

## iocage（iocage fork truenas/13.0-stable, d8b3d7e）
- **P5 决策落地**：不携带 fork 仓库；直接用 ports 基线（2026Q3）里的 `sysutils/iocage`（PORTVERSION 1.13，freebsd/iocage releases）。
  理由：15.1 的 jail(8)/ZFS 需随 ports 演进；truenas/13.0-stable 停在 13 时代。smoke 验证留 P6。
- 细节审计（python 版本/绑定兼容）：**进行中**（子公司 2 部分）。
- 必要动作：无额外 patch；`conf/ports.list` 已含 `sysutils/iocage`（来自原 ports-system.pyd 清单）。

## freenas-pkgtools
- 状态：**审计进行中**；pkgbase 决策下将作为 legacy 收缩/淘汰。

## ports fork（truenas/ports, 9461a3499b98, 13.3-stable）
- 状态：**盘点进行中**（子代理 4 执行中/待结果回填）；产出 fork-only ports 清单 → ports-extra，Mk/关键 port 修改 → patches/ports 或 REMOVED。

## freebsd-src / freebsd-ports（上游参考）
- 角色：ref；仅用于基线锚定，不进构建制品。
