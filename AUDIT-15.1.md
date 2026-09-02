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

## py-bsd（truenas/py-bsd master @ be67e03, 2022-05）
- 角色：middlewared 刚需的 BSD syscall Python 绑定（Cython）。
- 15.1 风险：
  - **确定断点**：`bsd/dialog.pyx` 链 `-ldialog`，而 15.1 base 只有 bsddialog（src15 `lib/` 无 libdialog、`usr.bin` 无 dialog）。→ 删 bsd.dialog 扩展；安装器 `src/freenas-installer/etc/install.sh` 里 20 处 `dialog(1)` 调用的壳层级也要迁移（或自带 `sysutils/dialog` 包）。
  - **确定次断点**：`setup.py:29` 用 distutils，Python 3.12+ 已删；需迁 setuptools/pyproject。Cython 3 兼容性未验证（多数 .pyx 无 `language_level=3` 头且无 Py2 时代 `Cython.Distutils` 用法）。
  - **defs.pxd 失真但当前有害度"低"**：kinfo_proc/sockstat/vnstat 等声明与 src15 头布局不一致，但 Cython 按真实头解析字段名，所访问字段均存在 → 编译可通过；作为 ABI 地雷列入 CI smoke test。
  - 已核实保留可用的：statfs/nmount/EVFILT_*/thr_self/thr_set_name/DIOC*/sysctl KERN_PROC_* 等。
- 决策：**保留但收缩**。动作：① 删 dialog/nis/bpf/extattr 等 middleware 未用的扩展；② setup.py 迁 setuptools/pyproject 去 six；③ ports-extra Makefile 从 `autoplist distutils` 改 `autoplist pep517`；④ 对 defs.pxd 做 sanitize 并建立字段级 ABI CI 核对。
- 迁移等级：**中**（dialog 是唯一硬断点，Cython 3 风险待编译确认）。

## licenselib（truenas/licenselib master @ 8d5441c, 2025-11-10）
- 角色：纯 Python 许可证编解码库（无 C 扩展）。
- 15.1 风险：几乎为零；setup.py 老式 setuptools 格式、classifiers 残留 py2.7/3.4 文字（无功能问题）。
- 决策：**保留**。动作：仅打包层现代化（pyproject + pep517）。
- 迁移等级：**低**。

## iocage fork（truenas/iocage truenas/13.0-stable @ d8b3d7e, 2024-11-18）
- 角色：jail 管理器；middleware 插件生态依赖。
- 关键事实：
  - fork vs 上游 master 树 diff 只有 ~300 行，但含上游没有的 tarfile 提取安全修复（#356/#357/#360）、basejail/plugin 智能升级端点；
  - fork 体全 CLI/subprocess 化（不绑 py-libzfs），`iocage_lib/zfs.py` 走 zfs/zpool CLI；
  - 15.1 jail(8) 兼容性良好（`jail -f <conf> -c`、`persist`、`ioc-<uuid>` 命名、ipl/fib 均 OK）；唯一观察点是 `ioc_common.py` 版本解析对 "15.1" 的合法性（`float("15.1")` 正常）；
  - middleware pin 的是 fork 源（`py-middlewared` port RUN_DEPENDS）。
- 决策（P5 终审，**替代早先的"换上游 ports"**）：保留 fork。落地：`ports-extra/sysutils/iocage` 由 fork port 改写为 `USE_GITHUB truenas/iocage @ d8b3d7e...`，`USES=python`、`USE_PYTHON=autoplist pep517`，去 fastentrypoints/pytest-runner。IOCage 源仓库进 repos.conf（REPO_IOCAGE）。
- 长期 TODO：把 fork 的担外 patch 上游化回 freebsd/iocage。
- 迁移等级：**低**（配置层已落地）。

## iocage-ix-plugins（truenas master @ b9858e0, 2023-01）
- 角色：iocage 插件运行时索引仓库（数据仓，非 OS 构件）。
- 结论：**不进 nas-build**；与 OS 构建解耦。

## freenas-pkgtools（truenas master @ 294a2ce, 冻结 3 年）
- 角色：12→13.3 时代的 train/sequence/manifest 更新系统（pkgbase 迁移决策下大半过时）。
- 不可替代资产（pkg 无等价）：
  - `lib/Update.py:1403-1650` 的 boot environment 创建/迁移/trampoline；
  - `lib/Manifest.py:42-54` 的 train×Sequence×Notice/EOL。
- 外部硬依赖点：
  - middleware `plugins/update_/{download,install,pending,trains}_freebsd.py` 等 6 个 import freenasOS；`utils/osc/freebsd/app.py:14`、`alert/source/update.py:7-8`；
  - 安装器 `src/freenas-installer/etc/install.sh:1068`（freenas-install -P -M）；
  - core-build 构建侧 create_package/create_manifest/freenas-release。
- 决策：**收缩**。build 侧全淘汰换 `pkg create`/`pkg repo`/自签索引；运行侧保留 BE 层 + 薄 train manifest，其余换 `pkg check -s/-r`、`pkg-static -r <root> install`；middleware `*_freebsd.py` 改 pkg + 新 BE helper。certificates 留 1 对根证书作 repo 指纹来源。
- 迁移等级：**高**（是 pkgbase 迁移中最大的运行时改造点）。

## ports fork（truenas/ports, 9461a3499b98, 13.3-stable）
- 状态：**盘点进行中**（子代理 4 执行中/待结果回填）；产出 fork-only ports 清单 → ports-extra，Mk/关键 port 修改 → patches/ports 或 REMOVED。

## freebsd-src / freebsd-ports（上游参考）
- 角色：ref；仅用于基线锚定，不进构建制品。

---

## 上游追踪策略（UPSTREAMS）

详见 `UPSTREAMS.md`。核心规则：
- truenas 仍维护：middleware/webui/licenselib/py-bsd/samba/py-libzfs/zettarepl/midcli/truecommand-stats
- truenas 已停维护的 CORE-only：iocage、py-netif、py-cam → 追 **freecore-project**（GitHub 仓库为 release 镜像；开发主体在 Codeberg）
- freecore 不维护的功能位（VNC 用的 `py-bhyve`/`libhyve-remote`、SED 的 `sedutil`、scanlnk、licenselib、wsdd）：自持有 fork 或纯上游 ports。

---

## 追加裁决（P2b，逐用户要求）

### zfs fork → 弃用（用 15.1 base 自带 2.4.2）
- 事实：15.1 base 的 `sys/contrib/openzfs/meta` = **2.4.2**；2026Q3 ports `filesystems/openzfs` = **2.4.3**；fork 钉的是 2.2.5+iX patch（`GH_TAGNAME=4f2aa1382`）。
- 结论：**删除 fork port 与 fork 源**。fork 时代的 iX 私有 zts 修复已滚入 2.4 主线（iX 上游化习惯）。删除 `REPO_ZFS`、`ports-extra/sysutils/openzfs{,-kmod}`、`ports.list` 中 `sysutils/openzfs` 行；`src.conf.build|boot` 中 `WITHOUT_ZFS` 移除，`world.mk` 的 `KERN_MODULES` 加 `zfs`。

### samba fork → 保留（已详核）

**方法**：fork pin `4fec43c0` 相对上游 tag `samba-4.19.6`（`b400092d`）做对向差分；
用 patch-id 逐 commit 在 upstream 4.23.9（`360b66d5`）与 upstream master（`43ad97b3`）中比对。

**数据**：fork 相对 4.19.6 有 **226 个 commit（219 个非 merge）**；
其中 upstream 等价 patch（patch-id 匹配）**0 个**（上游并未吸收这些改动，
因为大部分是产品级 VFS/ACL 功能而非上游通用修复）。
上游 samba 中无下列 TrueNAS 模块的任何对应实现。

**fork 独有功能层（决定了必须保留 fork）**：
- VFS 模块：`vfs_ixnas.c`、`vfs_shadow_copy_zfs.c`、`vfs_tmprotect.c`、`vfs_truenas_audit*.c`、`vfs_winmsa.c`（ACL 持久化、ZFS 快照浏览器、tm 时间窗、审计框架、winmsa Mac 扩展属性）；
- 库：`lib/zfsacl/`（FreeBSD/Linux 双实现 +pyzfsacl pybind）、`truenas_mempool`；
- 发行触：FreeBSD 构建修复（`d9e5bac0`）、`openat2`/`smb_strtox`/`vfs_tmprotect` FreeBSD 适配。

**上游已有 + fork 也有**：通用 bug 修复在 fork 中的等价，patch-id 与上游均不重合 —— 但注意
这些改动大多是 fork 上下文定制的（例如 `streams_xattr` 的 ADS 覆盖逻辑、`io_uring` 策略针对 TrueNAS 版本），
上游即使做过同类问题修复也常改了上下文。这不是"上游已采纳"，而是"两库各自修过"。

**结论**：**保留 fork**（midcli/webui/middleware ACL 都与这些 VFS 模块深度耦合；
去 fork = 去 TrueNAS 产品特性）。SMB 版本 4.19.6 老于 4.19.9，安全上 CVE 待核 —— 建议 P6 阶段
把 fork 与 `git.samba.org/samba:v4-19-stable`（最新 4.19.9）做一次 scope=安全 patch 的 backport 补齐。

**迁移等级**：高（无法替换；该工作计划在 truenas-migrate 一侧长期维护）。

### wsdd fork → 换成上游 ports
- 事实：上游 `net/py-wsdd @christgau 0.9` 自带 `rc.d/wsdd`（同款 rc 名）；middleware 只按名字 `freebsd_rc="wsdd"` 消费。
- 结论：**删除** fork port（已删 `ports-extra/sysutils/py-wsdd`、`REPO_WSDD`），`ports.list` 加 `net/py-wsdd`。
- 遗留：上游 0.9 vs fork 0195eff 的发行窗可能缺小补丁；影响面为 Windows 网络发现可见性，可接受。

### sedutil → 用上 游 ports（替换裁决）

（替代之前的"保留 amotin fork"。**本裁决由 maintenance-gap 子代理纠正**：）
- 事实更正：上游 ports 已有 `security/sedutil`（kendmerry fork，`bin/sedutil-cli`）；此前审计错把 `sysutils/sedutil`(amotin fork) 当成唯一方案。
- middleware 调用点是 `sedutil-cli`（PATH 无关，含 webui SED 密码页面），两侧 API 一致。
- 结论：**用上游 ports 的 `security/sedutil`**，`ports.list` 的 `sysutils/sedutil` 改为 `security/sedutil`（已完成）；amotin fork 删除（nvme OPAL 特殊场景才有意义，本次不覆盖）。

### licenselib → 保留（仅 truenas 使用，且是产品功能）
- 消费方：middleware `plugins/system.py`、`scripts/hadetect.py`、`freenas-debug/system/system.sh`（Enterprise 授权）；webui 无直接引用。
- 结论：**保留**（纯 Python、风险低，见审计本体）。

### scanlnk → 剔除
- 消费方为 0（grep middleware 无引用）。上游只有作者 anodos325 本人仓，无"别家维护"。
- 结论：**删除** `ports-extra/sysutils/scanlnk` 与 `ports.list` 行（已做）。

### freenas-pkgtools、freenas-migrate93、freenas-migrate113 → 已物理删除
- 关联点未动：middleware 中对这些的引用保留为代码层 TODO（`ix.rc.d/ix-update`、`plugins/config.py`、`freenas-files/files/pkg-install.in`、`py-middlewared/Makefile` 里 migrate 类 import）——属于 P3 middleware 收敛任务，不影响 build 层。

### core-build → 已物理删除
- 旧构建系统不再留在工作区（参考信息全在 build/AUDIT 与本文件中）。

---

## maintenance-gap 追加裁决（子代理详核）

来源：`F:\zvault\_scratch\maintenance-gap-analysis.md`。贯穿性发现：**freecore 的"不维护"九成是"消费不 fork"**（钉死上游 commit + 在自己 nas_ports 里压一个 patch，不重写），真正彻底删除的只有 TrueCommand Cloud、HA/fenced、openvpn、truenas_audit、KMIP。

### zettarepl → 追 truenas（不 fork）
- freecore middleware 完整保留 `from zettarepl.*`（与 truenas 13.3 一字不差），只是恢复了一个 port `nas_ports/sysutils/py-zettarepl` 钉 `truenas/zettarepl@60ade60` + 一行 paramiko DSSKey patch。
- **本地动作**：仓库已放到 `nas-build/zettarepl`（12f2fd4=SCALE-era，13.3 要改用 pin 60ade60），port Makefile 需要定 pin + 补丁（待 P2b 定稿）。

### midcli → 追 truenas（不 fork）
- freecore 没砍，truenas 主线还在维护（绑 SCALE）——钉回 freenas/midcli@5ac8045（与 13.3 相同）即可。
- **本地动作**：仓库已收 nas-build/midcli。

### truecommand-stats → 保留源头，功能可砍
- 真身是 Go 二进制 trueview-stats；truenas 2022-10 archive 是因为 SCALE master 切到 netdata。freecore 的处理参考：保留 trueview.py + `nas_ports/freenas/tc-stats`port 改成 go build，砍 TrueCommand Cloud。我们采纳同样方案，**不 fork 不维护**。

### libhyve-remote / py-bhyve → 物理删除（本裁决替代早先"自持有"）
- freecore 没砍 VM（vm-bhyve/grub2-bhyve/edk2/novnc/py-websockify/libvncserver 都在），但砍掉了 `devel/libhyve-remote` port（"broken since 2020"，被 libvncserver+novnc 替代）与 `py-bhyve`（middleware 全分支 0 次 `import bhyve`）。
- middleware `VNC.bhyve_args` 只构造 `tcp=` 从不发 `vncserver=1`，所以 libhyve-remote 恒走 dlopen 失败回落 in-tree rfb——本就是死链路。
- **本地动作**：`ports-extra/devel/{libhyve-remote,py-bhyve}` 已删，`nas-build/{py-bhyve,libhyve-remote}` clone 已删。
- **重要**：src patch 100-bhyve-vnc-libhyve-remote.patch **仍然必须**——真正要保留的是 `rfb.c` waitfd escape hatch + `vmmapi.c` CAP_FSTATAT（freecore 把同一批 src delta 也带回来了）。

### pylzfs/py-netif/py-cam → truenas 版 py-libzfs 跟着主线，py-netif/py-cam 换 freecore
- 前文 UPSTREAMS 表已写。**py-netif / py-cam** 在 truenas 侧 frozen，freecore 有更活的维护；如果迁移需要新版，从 freecore 拿。当前仍用 truenas/freenas 的 pin（工作区已有）。

### samba → 保留 fork，且 freecore 的 delta 给了一条退路
- freecore-samba delta（9k 行修正案）明确还在 build 里启用 `vfs_ixnas vfs_shadow_copy_zfs vfs_zfs_core vfs_zfs_fsrvp vfs_tmprotect vfs_noacl vfs_winmsa vfs_zfs_space vfs_aio_fbsd`（middleware `smb_/registry.py:158` 也全部在）；被砍的只有 `vfs_truenas_audit`（我们 middleware 不生成）与 vfs_freebsd（13.3 patch 从未上游，freecore 15.0 明确 drop until carried into fork）。
- 所以就维护成本与我们 fork 差异（审计见上），**fork 继续保留**，同时 freecore 的 delta 可以作为"剔除 audit + zfs fsrvp 怎么做"的迁移参考。

### 参考裁决速查（九分法）

| 仓库 | 追踪 | 形式 |
|---|---|---|
| middleware | truenas | fork（在我们 org 上重写历史后继续 fork） |
| webui | truenas | fork（P4 产物直蒸馏 webui-dist） |
| licenselib | truenas | fork（纯 python，低风险） |
| py-bsd | truenas | fork（删 dialog/nis/extattr/bpf 收缩） |
| py-libzfs | truenas | 直接消费 |
| py-netif | freecore-project | 直接消费（truenas frozen） |
| py-cam | freecore-project | 直接消费（truenas frozen） |
| zettarepl | truenas | 直接消费钉60ade60（13.3 时期）+ DSSKey patch |
| midcli | truenas | 直接消费钉 5ac8045 |
| truecommand-stats | truenas(archived) | 直接消费钉 v0.1.8，功能砍Cloud路径 |
| samba | truenas | 深度 fork（v4-24-stable 含全部分支） |
| sedutil | upstream ports `security/sedutil` | 不 fork |
| wsdd | upstream ports `net/py-wsdd` | 不 fork |
| iocage | 自持有 truenas/icoage fork | 已 ports-extra 化 |
| libhyve-remote/py-bhyve/py-zettarepl(patch)/scanlnk | — | 删除/不需要 |
