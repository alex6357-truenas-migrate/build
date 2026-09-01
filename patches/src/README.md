# TrueNAS 15.1 Patch 集

本目录把 TrueNAS `os` 仓库（`truenas/13.3-stable`，HEAD `54a090f`）相对上游 FreeBSD 的全部定制修改，**以 FreeBSD 15.1 为基线重新整合**为一组可独立 apply 的 patch 文件，按优先级四分类组织。

- **上游基线**：`origin/releng/15.1` = `aadd58dddcbc78f4d5594827b46b5633552b15ce`（2026-07-28）
- **os fork 基点**：`deb948cd8dc2efb341ce96e1b7a56c9fbc662ba1`（freebsd releng/13.3，2024-07-01）
- **原始改动规模**：61 个非 merge 自有 commit / 52 文件 / +4611 -265
- **本 patch 集规模**：12 个整合 patch（覆盖全部 61 个原 commit）+ 12 项建议移除说明

## 1. 优先级四分类

| 类别                    | 数量        | 含义                                                                        | 是否生成 patch                        |
| ----------------------- | ----------- | --------------------------------------------------------------------------- | ------------------------------------- |
| **MUST**（必须）        | 8 patch     | 新功能或修复，影响内核接口/总体行为/稳定性，TrueNAS 产品形态/中间件集成必需 | ✅ 生成                               |
| **RECOMMENDED**（推荐） | 1 patch     | 仅性能优化，不改接口/行为/不引起后期不稳定                                  | ✅ 生成                               |
| **OPTIONAL**（可选）    | 4 patch     | iX 自有硬件驱动 / 争议项 / 需决策                                           | ✅ 生成                               |
| **REMOVE**（建议移除）  | 12 原commit | 上游 15.1 已有等价实现，保留会与上游重复冲突                                | ❌ 只写说明（见 `remove/REMOVED.md`） |

## 2. 目录结构

```text
patches/
├── README.md                       # 本文件
├── must/                           # 必须应用（8 patch）
│   ├── 100-bhyve-vnc/              # bhyve VNC/libhyve-remote（1 整合 patch）
│   ├── 200-boot-lua/               # boot/lua 菜单 + pmbr-datadisk（1 整合 patch）
│   ├── 300-rc-mountd/              # rc 框架 + NFS 导出（1 整合 patch）
│   └── 400-kernel-misc/           # 内核必须项（4 独立 patch：410/420/430/440）
├── recommended/                    # 推荐优化（1 patch）
│   └── 500-memmove-perf.patch
├── optional/                       # 可选（4 patch）
│   ├── 600-ixnvdimm/               # iX NVDIMM 驱动+工具（1 整合 patch）
│   ├── 700-rc-subr-revert.patch    # 争议点：rc.subr revert
│   ├── 710-acpi-package-hack.patch # 硬件相关：Supermicro NVDIMM ACPI hack
│   └── 720-yp-retries.patch        # 争议点：yp 重试次数
└── remove/                         # 建议移除说明（无 patch）
    └── REMOVED.md                  # 12 项 + 对应上游 commit
```

## 3. apply 顺序与依赖关系

**命名约定**：`NNN-<描述>.patch`，三位数字编码 apply 顺序：组内十位递增，组间留百位间隔（100/200/300/400/500/600/700）。

**组内强依赖**：同功能域 patch 视为一组同时应用（本集中每个功能域已是**整合 patch**，单文件即代表整组，内部无顺序问题）。
**组间相对独立**：MUST 四组、RECOMMENDED、OPTIONAL（ixnvdimm/3 争议项）之间无代码依赖，可任意顺序；建议按编号顺序 apply。

推荐 apply 顺序（冲突最小、语义连贯）：

| 顺序 | patch                                                   | 说明                                       | 文件数 | 改动量   |
| ---- | ------------------------------------------------------- | ------------------------------------------ | ------ | -------- |
| 1    | `must/100-bhyve-vnc/100-bhyve-vnc-libhyve-remote.patch` | bhyve VNC（libhyve-remote + escape hatch） | 7      | +529/-15 |
| 2    | `must/200-boot-lua/200-boot-lua-menu.patch`             | boot 菜单 + pmbr-datadisk                  | 5      | +185/-74 |
| 3    | `must/300-rc-mountd/300-rc-mountd.patch`                | rc 框架 + NFS 导出健壮性                   | 7      | +141/-8  |
| 4    | `must/400-kernel-misc/410-kern-conf-zvol-name.patch`    | zvol 名放宽（独立）                        | 1      | +0/-7    |
| 5    | `must/400-kernel-misc/420-utimensat-birthtime.patch`    | utimensat BTIME flag                       | 2      | +39/-28  |
| 6    | `must/400-kernel-misc/430-inode-gen-sysctl.patch`       | unprivileged inode gen                     | 1      | +9/-2    |
| 7    | `must/400-kernel-misc/440-ctl-ha-truncated.patch`       | CTL HA 不杀连接                            | 1      | +1/-1    |
| 8    | `recommended/500-memmove-perf.patch`                    | memmove 性能（独立）                       | 1      | +3/-3    |
| 9    | `optional/600-ixnvdimm/600-ixnvdimm.patch`              | iX NVDIMM 驱动+工具（按需）                | 11     | +3499/-1 |
| 10   | `optional/700-rc-subr-revert.patch`                     | 争议点：rc.subr revert                     | 2      | +2/-18   |
| 11   | `optional/710-acpi-package-hack.patch`                  | Supermicro NVDIMM ACPI hack                | 2      | +4/-0    |
| 12   | `optional/720-yp-retries.patch`                         | yp 重试 20→5                               | 1      | +1/-1    |

**依赖说明**：kernel-misc 的 4 个 patch（410/420/430/440）彼此独立、互不依赖，可任意顺序或单独 apply。ixnvdimm（600）是一个大整合 patch，内部 25 个原 commit 已合并为一次应用。其余各组无跨组依赖。

## 4. 如何应用

```bash
# 在干净的 FreeBSD 15.1 源码树（releng/15.1 checkout）中：
cd /usr/src  # 或 freebsd-src worktree

# MUST（按顺序）
git am /path/to/nas-build/patches/must/100-bhyve-vnc/100-bhyve-vnc-libhyve-remote.patch
git am /path/to/nas-build/patches/must/200-boot-lua/200-boot-lua-menu.patch
git am /path/to/nas-build/patches/must/300-rc-mountd/300-rc-mountd.patch
for p in 410-kern-conf-zvol-name 420-utimensat-birthtime 430-inode-gen-sysctl 440-ctl-ha-truncated; do
  git am /path/to/nas-build/patches/must/400-kernel-misc/$p.patch
done

# RECOMMENDED
git am /path/to/nas-build/patches/recommended/500-memmove-perf.patch

# OPTIONAL（按目标硬件/产品形态决策是否应用）
git am /path/to/nas-build/patches/optional/600-ixnvdimm/600-ixnvdimm.patch   # 仅有双控 NVDIMM 时
git am /path/to/nas-build/patches/optional/700-rc-subr-revert.patch         # 若保留 ix-* 脚本兼容
git am /path/to/nas-build/patches/optional/710-acpi-package-hack.patch      # 若遇 Supermicro NVDIMM
git am /path/to/nas-build/patches/optional/720-yp-retries.patch            # 若需 NIS fail-fast
```

也可用 `patch -p1 < <patch>` 替代 `git am`。`git am` 保留作者信息；`patch -p1` 仅 apply 内容。

> **重要**：本 patch 集已在 15.1 基线上用 3-way merge 重新整合，apply 时若 15.1 已有后续演进可能产生新冲突；每 patch 的 commit message 含 `Rebase notes vs 15.1` 说明整合要点。**未经完整 build world/kernel 验证**，apply 后需在目标环境 build 确认。

## 5. 单 patch 说明

每个 patch 给出：**原因**（TrueNAS 为何需要）、**功能作用**（改了什么）、**影响范围**（触及子系统与副作用）、**15.1 上游状态**（已上游/部分/未上游 + 证据）、**整合的原 commit**。

### MUST 组

#### 100-bhyve-vnc-libhyve-remote.patch — bhyve VNC / libhyve-remote

- **原因**：TrueNAS bhyve 需要基于 libhyve-remote（`libvncserver`，pkg `libhyverem`）的 VNC 控制台，比 bhyve 原生 `rfb.c` 更完整（口令/兼容性），并把 vm 销毁与 VNC 等待联动避免 bhyve 挂死。
- **功能作用**：在 fbuf PCI 设备旁挂 `usr.sbin/bhyve/vncserver.c`（dlopen `/usr/local/lib/libhyverem.so`，32×32 CRC 脏矩形 + kqueue 定时线程 + 键鼠回投）；`pci_fbuf.c` 加 `vncserver_enabled`/`vncserver_web` 配置键与二选一分发；`rfb.c`/`rfb.h` 加 `waitfd` 参数与 `RFB_WAIT_INTERVAL` escape hatch（每秒 `fstat(waitfd)` 探测 vm 是否销毁，销毁则 `errx(the VM was destroyed)`）；`lib/libvmmapi/vmmapi.c` `vm_limit_rights` 增补 `CAP_FSTATAT` 放行沙箱内 `fstat`。
- **影响范围**：bhyve（虚拟机 VNC 控制台）、vmmapi capsicum 权限。默认走原生 rfb，仅当 fbuf 配置含 `vncserver` 且装了 `libhyverem` 时启用 vncserver 路径。依赖外部 `libhyverem ≥ 0.1.4.1`。
- **15.1 上游状态**：**未上游**（整体）。15.1 无 `vncserver.c`、`pci_fbuf.c` 无 vncserver 分发、`rfb.h` 无 `vncserver_init`/`RFB_WAIT_INTERVAL`、`vmmapi` 无 `CAP_FSTATAT`。注意 15.1 的 `rfb_init` 多了 `sa_family_t family` 参数（IPv6/AF_UNIX 演进），本 rebase 保留了它并叠加 TrueNAS 的 `waitfd` 与分发。
- **整合原 commit**：`a60cb17a143` `d87fdb68cbb` `6ff4af7a16e` `c18542fb46f` `b45456226e2` `a343da24e50` `cc792d3faec` `9a67aff59b3` `2057cfd7cb0`（9 个）。
- **Rebase 要点**：15.1 把 `vga.c`/`xmsr.c`/`spinup_ap.c` 移到 `amd64/Makefile.inc`，本 rebase 仅向主 Makefile 加 `vncserver.c`；15.1 `rfb_softc` 加了 `pixfmt`/`new_pixfmt`/`pixrow`/`fbname`（像素格式协商），与 os 的 libhyve-remote ABI 占位字段并列保留。

#### 200-boot-lua-menu.patch — boot 菜单 / Lua / pmbr-datadisk

- **原因**：TrueNAS 需要 boot 菜单显示产品名（TrueNAS）、EFI 串口控制台正确选择、数据盘的保护性 MBR（避免数据盘被误当可引导盘）。
- **功能作用**：`stand/lua/menu.lua` 加 `serialboot()`、`multi_serial`/`single_serial` 条目、`productname()` 回退、按启动方式分支选 `comconsole,efi`/`comconsole,vidconsole`、检测 `efi_8250_uid`；`stand/lua/drawer.lua` 加宽菜单框 75×14；新增 `stand/i386/pmbr-datadisk/{Makefile,pmbr-datadisk.S}`（只保护不引导的 PMBR，打印"data disk can not boot, halted"并死循环）。
- **影响范围**：boot loader、boot 菜单显示、EFI 串口引导。不影响内核运行时。pmbr-datadisk 只装在数据盘，不影响系统盘引导。
- **15.1 上游状态**：**未上游**（整体）。15.1 `menu.lua` 无 `serialboot`/`productname`/`efi_8250_uid`；`drawer.lua` 无 75×14 几何；无 pmbr-datadisk。15.1 `menu.welcome.entries()` 上游新增了 `chainload`/`vendor`/`loader_needs_upgrade` 条目，本 rebase **保留**了它们（与 TrueNAS 串口/产品名定制共存）。
- **整合原 commit**：`4ee6e5d3202` `e333bed4417` `638ffd167b6` `7700892abcf` `67e33322a1a` `bc48c1bede3`（6 个）。
- **Rebase 要点**：15.1 menu.lua/drawer.lua 上游演进较大（+66/+97 行），3-way merge 仅 2 冲突/文件，已解决（几何值用 os 75×14 y=9；菜单条目保留上游链式加载项）。

#### 300-rc-mountd.patch — rc 框架 / mountd / NFS

- **原因**：TrueNAS 中间件自己编排服务启动顺序，rc 脚本的 `force_depend` 会"偷偷拉起"被依赖服务、扰乱中间件状态视图；diskless/data-disk 部署需部分目录 tmpfs 化；NFS 导出失败需精确定位。
- **功能作用**：`rc.d/mountd`/`rc.d/nfsd` 注释 `force_depend`；`rc.d/devd` 删 `REQUIRE: netif ldconfig`（解 ix-syncdisks 循环依赖）；新增 `libexec/rc/rc.dynamicdiskless`（按 `/etc/dynamicdiskless` 标志把 `/conf/base/` 目录 tmpfs 覆盖挂载）；`rc.initdiskless` 把默认 md 大小由 10240 扇区改为 `physmem/1536`（≈1/3 内存）；`rc.d/mountd`/`rc.d/nfsd` 配合。（注：mountd.c 导出错误诊断与 kern_conf zvol 名放宽分别在 kernel-misc 组的 REMOVE 与 410 patch。）
- **影响范围**：rc 启动框架、NFS/mountd/devd 服务管理、diskless 启动。纯 rc（非中间件驱动）环境需在 `rc.conf` 显式 enable rpcbind/mountd 才能保证 nfsd 正常。
- **15.1 上游状态**：**未上游**（全部）。15.1 `rc.d/mountd`/`nfsd` 仍有 `force_depend`、`rc.d/devd` 仍有 `REQUIRE: netif ldconfig`、无 `rc.dynamicdiskless`、`rc.initdiskless` 仍 `md_size=10240`。
- **整合原 commit**：`05fb1b1a812` `520e9fdb52d` `a93e963fd08` `b6aaab1b019` `c7df8b01582`（5 个；另含 mountd.c 的两个 commit 已因上游采纳移入 REMOVE）。
- **Rebase 要点**：全部 rc 脚本 3-way merge 0 冲突。**rc.subr 不在本 patch**（唯一 rc.subr 改动是 abf14b58ac7，归 optional/700 争议点）。

#### 410-kern-conf-zvol-name.patch — zvol 名含空格/双引号

- **原因**：TrueNAS GUI 创建 zvol 时命名可能含空格或 `"`，但内核 `prep_devname` 拒绝这些字符，导致 zvol 创建失败。
- **功能作用**：`sys/kern/kern_conf.c` `prep_devname()` 移除 `if (isspace(*from) || *from == '"') return (EINVAL);`（7 行）。
- **影响范围**：内核设备命名校验。devctl(4) 协议消费方需自行处理含空格/引号的设备名（TrueNAS 侧 devd/中间件已适配）。
- **15.1 上游状态**：**未上游**。15.1 `kern_conf.c` 行 729 仍保留该校验。
- **整合原 commit**：`bcb2a2df228`（1 个）。
- **Rebase 要点**：0 冲突，删除即生效。

#### 420-utimensat-birthtime.patch — utimensat 显式 birthtime flag

- **原因**：SMB 协议语义需显式设置文件 birthtime；FreeBSD `setutimes` 旧行为（mtime 早于 birthtime 时把 birthtime 拉低到 mtime）会让某些 SMB 客户端把 birthtime 错误初始化为 1980。
- **功能作用**：`sys/sys/fcntl.h` 新增 `AT_UTIMENSAT_BTIME = 0x1000`（复用 `AT_UNUSED1` 位）；`sys/kern/vfs_syscalls.c` `getutimens()` 加 `bool get_btime` 读 3 个 timespec（atime/mtime/birthtime），`kern_utimensat()` 解析 flag 并以 `numtimes=3` 传 `setutimes`。
- **影响范围**：syscall ABI（新增 BSD 私有 flag）。Samba 已适配使用该 flag；未用该 flag 的程序行为不变。底层文件系统需支持 birthtime 写（ZFS 已支持）。
- **15.1 上游状态**：**部分上游**。15.1 `setutimes` 已有 `numtimes>2 → va_birthtime=ts[2]` 底层能力（13.3 也已有），但 `fcntl.h` 0x1000 仍是 `AT_UNUSED1`（注释）、`getutimens` 无 `get_btime` —— 本 patch 补的是 flag 入口，上游未采纳。
- **整合原 commit**：`eef90774e3a`（1 个）。
- **Rebase 要点**：0 冲突。15.1 `getutimens` 签名与 13.3 一致，flag-add 直接复用底层。

#### 430-inode-gen-sysctl.patch — 非特权进程读 inode generation

- **原因**：TrueNAS 用 (inode, generation) 构造 MS-SMB2 64-bit file id，Samba 进程以非特权身份运行需读 generation。
- **功能作用**：`sys/kern/kern_priv.c` 新增 `security.bsd.unprivileged_inode_gen`（RWTUN，默认 0）；`priv_check_cred_vfs_generation()`/`_slow` 在 sysctl 非零时允许非 root、非 jail 凭据读生成号。
- **影响范围**：放开一项原本需 root 的信息读取。默认关闭，管理员按需开启；jail 中仍拒绝。generation 可被用于预测 NFS file handle，故默认保守。
- **15.1 上游状态**：**未上游**。15.1 `kern_priv.c` 有 `priv_check_cred_vfs_generation` 函数（早有）但无 `unprivileged_inode_gen` sysctl。
- **整合原 commit**：`d17966534f2`（1 个）。
- **Rebase 要点**：0 冲突。

#### 440-ctl-ha-truncated.patch — CTL HA 不杀连接

- **原因**：HA 集群间每几秒因截断的 mode page 同步消息杀连接重连，反复断连引发的竞态比"mode page 未同步"严重得多。
- **功能作用**：`sys/cam/ctl/ctl.c` `ctl_isc_mode_sync()` 收到截断消息时注释掉 `ctl_ha_msg_abort(CTL_HA_CHAN_CTL)`，仅打印告警后 return。
- **影响范围**：CTL HA（SCSI target 高可用）稳定性。代价是 mode page 可能短暂不同步，CTL 上层有容错。
- **15.1 上游状态**：**未上游**。15.1 `ctl.c` 仍调 `ctl_ha_msg_abort`。
- **整合原 commit**：`61f903c5314`（1 个）。
- **Rebase 要点**：15.1 ctl.c 上游演进 +1548 行，但该 site 3-way merge 0 冲突，单行改动精确应用。

### RECOMMENDED 组

#### 500-memmove-perf.patch — memmove 反向重叠性能

- **原因**：ERMS 不优化 backward copy；Cascade Lake Xeon 上 REP MOVSQ+寄存器循环比 ERMS 反向路径快约 70%。
- **功能作用**：`sys/amd64/amd64/support.S` `memmove()` backward overlapping 分支把 ERMS 阈值 `cmpq $256` 提到 `cmpq $680`，标签 `2256`→`2680`。≤680 字节走 MOVSQ+寄存器循环，>680 走 std+REP MOVSB(ERMS)。
- **影响范围**：仅 amd64 memmove 性能阈值，不改接口/行为/正确性（两条路径都正确）。
- **15.1 上游状态**：**未上游**。15.1 `support.S` 仍 `cmpq $256`。
- **整合原 commit**：`e7f5d361ddb`（1 个）。注：`cc792d3faec`（RFB 等待间隔 3→1 秒）作为纯数值调优已折叠进 bhyve-vnc 整合 patch（`rfb.h RFB_WAIT_INTERVAL=1`），不单列。
- **Rebase 要点**：0 冲突。

### OPTIONAL 组

#### 600-ixnvdimm.patch — iX NVDIMM-N 驱动 + 工具

- **原因**：iX 双控 NVDIMM HA 场景下用 NVDIMM 做 ZIL/SLOG 持久写缓存，通过 NTB 把本地 NVDIMM 镜像到对端节点，单节点掉线写缓存不丢。上游 `dev/nvdimm` 仅有基础 NFIT 解析+pmem 盘，无 NTB 镜像/HA 同步/DSM 固件管理/IOAT NUMA。
- **功能作用**：新增 `sys/dev/ixnvdimm/{ixnvdimm.c,ixnvdimm.h,ixnvdimm_copy.S}`（NFIT 解析、NUMA-aware IOAT DMA、NTB HA 镜像、DSM 健康/固件）、`sys/modules/ixnvdimm/Makefile`、`usr.sbin/ixnvdimm/{ixnvdimm.c,Makefile}`（命令行查健康/读写 i2c/刷固件，跨 FreeBSD ioctl + Linux ndctl）；注册 `sys/conf/files.amd64`、`sys/modules/Makefile`、`etc/mtree/BSD.include.dist`、`include/Makefile`、`usr.sbin/Makefile`。
- **影响范围**：新增内核模块 + 用户态工具，依赖 `dev/ntb`/`dev/ioat`，与上游 `dev/nvdimm` 并存（不同的 newbus 树）。
- **OPTIONAL 判据**：**iX 自有硬件驱动**，仅双控 NVDIMM 平台需要；普通 NAS 无此硬件不应应用。
- **15.1 上游状态**：**未上游**。15.1 无 `sys/dev/ixnvdimm`、无 `usr.sbin/ixnvdimm`；上游有 `sys/dev/nvdimm/`（7 文件）但功能远小。
- **整合原 commit**：`ca02fa94619` `5f7b58dc6cd` `b5d295755ce` `db82359df42` `3879f6a5eb3` `b866725a3bd` `7bb9340e07d` `1590bc59d7f` `67036bc9d6d` `c4d0f444d38` `d809dbcbb36` `0a5c0b7bbdb` `c4478a23b29` `dd54c1c2495` `4f0b010add9` `02cfcc3a339` `049f1b7abc7` `f1edb6447ff` `facf1247039` `6448ef5dcf4` `cdc92e3bc99` `7797934da62` `51b32003851` `696d46c4b3f` `0a7dd68a902`（25 个）。
- **Rebase 要点**：驱动/工具源文件为新增，直接取 os HEAD；含跨版本兼容 `#if`（`facf1247039` 处理 13 vs 14 的 sbuf `bus_child_pnpinfo`，`6448ef5dcf4` 处理 `vm_phys_domain` 分段），15.1 走对应版本分支。注册文件仅 2 处小冲突（files.amd64 的 ncthwm、include/Makefile 的 nvme 演进）已解决。

#### 700-rc-subr-revert.patch — rc.subr revert MFC r351863【冲突点·决策】

- **原因**：TrueNAS 的 `ix-*` rc 脚本自行处理环境变量，rc.subr 的 `eval "export -- $_env"`（MFC r351863）会自动导出 `${name}_env`，且 sh `export` 对变量名有限制（不能以数字开头），与 ix 脚本冲突。
- **功能作用**：`libexec/rc/rc.subr` 删除两处 `if [ -n "$_env" ]; then eval "export -- $_env"; fi`；`share/man/man8/rc.subr.8` 删除对应文档段。
- **影响范围**：rc.subr 服务启动行为。若服务依赖 `${name}_env` 自动导出且自定义 `*_cmd`，会失去该能力（需用 `command=` 形式或自行 export）。
- **OPTIONAL 判据**：**与上游相反**——15.1 上游保留 MFC r351863（行 1366/1743 仍有 `export -- $_env`），TrueNAS 选择 revert 以兼容 ix 脚本。是否保留 revert 是产品决策。
- **15.1 上游状态**：**上游保留该 MFC，本 patch 与之相反**。
- **整合原 commit**：`abf14b58ac7`（1 个）。
- **Rebase 要点**：15.1 `run_rc_command` 在该段周围有大重构（加 `rc_trace`/`_rc_svcj jailing`/`_run_rc_setup`/`_run_rc_precmd`），本 rebase **保留 15.1 全部新逻辑，仅删两处 export 块**（1365-1367、1742-1744；其中第二处是 15.1 上游在 `_offcmd` 分支新加的，TrueNAS 原 revert 时不存在，本 rebase 一并 revert 以彻底贯彻意图）。

#### 710-acpi-package-hack.patch — ACPI Package→int dirty hack【硬件相关】

- **原因**：Supermicro NVDIMM 的 ACPI 代码有 bug，同一参数既当 Package 又当 Buffer 访问，无论传什么都报错，导致 NVDIMM ACPI 评估失败、ixnvdimm 驱动初始化不了。
- **功能作用**：`sys/contrib/dev/acpica/components/executer/exconvrt.c` `AcpiExConvertToInteger()` 加 `case ACPI_TYPE_PACKAGE: break;`（不转换不报错）；`exresop.c` `AcpiExResolveOperands()` 把 `ACPI_TYPE_PACKAGE` 加进合法 operand 类型列表。
- **影响范围**：上游 ACPICA contrib 代码，属脏 hack，未来 ACPICA 升级需保留。对正确 BIOS 无副作用。
- **OPTIONAL 判据**：**硬件特定**——仅目标平台是 Supermicro NVDIMM 时需要；非该硬件可不应用。
- **15.1 上游状态**：**未上游**。15.1 `exconvrt.c` 无 `ACPI_TYPE_PACKAGE` 特例。
- **整合原 commit**：`6137bc01252`（1 个）。
- **Rebase 要点**：0 冲突。

#### 720-yp-retries.patch — yp 重试 20→5

- **原因**：NIS 配置错误时 nss 查询会阻塞 20×10=200 秒，5 次后仍失败基本是配错，应 fail-fast。
- **功能作用**：`lib/libc/yp/yplib.c` `MAX_RETRIES` 20→5。
- **影响范围**：libc 行为，影响所有 NIS 程序（登录、id 解析）。配置良好的 NIS 不受影响；故障场景更快报错。
- **OPTIONAL 判据**：libc 行为变更，是否保留 fail-fast 是部署偏好决策。
- **15.1 上游状态**：**未上游**。15.1 `yplib.c` 仍 `MAX_RETRIES 20`。
- **整合原 commit**：`1021f792f34`（1 个）。
- **Rebase 要点**：0 冲突，单行。

## 6. 升级到 15.1 的影响预判与冲突点决策

### 6.1 可直接丢弃（REMOVE 组，12 项）

这 12 项是 TrueNAS 从上游 main/stable backport 到 13.3 的修复，15.1 上游已有等价，升级时**丢弃 TrueNAS 版、采用上游版即可**，详见 `remove/REMOVED.md`。复核命令见该文件末尾。

| TrueNAS commit | 概要                             | 上游 commit    |
| -------------- | -------------------------------- | -------------- |
| `3b770e1c8b9`  | reboot_wait_time sysctl          | `84ec7df0d796` |
| `f4c10c88420`  | cpu_reset 删 1 秒 DELAY          | `05350f093663` |
| `39807fa7e3f`  | ntb_hw_plx scratchpad 重试       | `3883c6fbf232` |
| `0c8180c1b62`  | Hyper-V vPCI BAR 写回            | `5473dee73005` |
| `7d118cbbdf9`  | mountd 导出错误日志              | `572b77f8da5e` |
| `b1d83774348`  | mountd undefined ref（配套上条） | 随上条         |
| `9fc86a79938`  | isp ISPCTL_ABORT_CMD break       | `7fa105d91f0d` |
| `498a47f09e5`  | isp use-after-free 修复          | `36abbfe061df` |
| `8452110f17a`  | isp target abort 重构            | `d353c342a12c` |
| `e65eaf24ba8`  | isp 修上一 commit 回归           | `519121f5ea03` |
| `1680e464856`  | zfsimpl features 排序            | `f993fff68979` |
| `23a3f33e3b4`  | zfsimpl 补 vdev_zaps_v2          | `5fd34912b4a5` |

### 6.2 必须保留（MUST 组，8 patch / 22 原 commit）

升级到 15.1 时这 8 个 patch 必须应用，否则 TrueNAS 产品形态（中间件集成、SMB/NFS 语义、HA 容错、虚拟化 VNC、boot 菜单）会缺失关键能力。本集已 rebase，可直接 apply。

### 6.3 按需保留（RECOMMENDED + OPTIONAL）

- **RECOMMENDED**（1 patch）：memmove 性能——无副作用，建议应用。
- **OPTIONAL ixnvdimm**（1 patch=25 commit）：仅当目标硬件有 iX 双控 NVDIMM 时应用；普通 NAS 跳过。
- **OPTIONAL 3 争议项**：按下方决策点逐项判断。

### 6.4 冲突点决策建议

#### 决策 1：rc.subr revert（patch 700）— **与上游相反**

15.1 上游保留 MFC r351863（rc.subr 自动 `export -- ${name}_env`），本 patch revert 它以兼容 ix-\* 脚本。

| 选项                              | 适用场景                                     | 代价                                                                    |
| --------------------------------- | -------------------------------------------- | ----------------------------------------------------------------------- |
| **应用 patch 700（维持 revert）** | 保留 TrueNAS ix-\* rc 脚本现状、不愿改造脚本 | 服务失去"`${name}_env`+自定义 `*_cmd` 自动导出"能力（TrueNAS 已不依赖） |
| 不应用（接受上游）                | 愿意改造 ix-\* 脚本自行处理 env，向上游靠拢  | 需逐个审查 ix-\* 脚本的对 `${name}_env` 使用方式                        |

**推荐：应用 patch 700**（保持 TrueNAS 现状，改造 ix-\* 脚本成本高、收益低）。本 patch 已 rebase 到 15.1 的重构后 `run_rc_command`，仅删两处 export 块，保留全部 15.1 新逻辑（rc_trace/svcj jailing/\_run_rc_setup）。

#### 决策 2：utimensat BTIME flag（patch 420）— **上游有底层、入口未上游**

15.1 `setutimes` 已有 `numtimes>2 → va_birthtime=ts[2]` 底层，但 fcntl.h 0x1000 仍是 `AT_UNUSED1`、无 `AT_UTIMENSAT_BTIME` flag。

| 选项                                                           | 适用场景                                         |
| -------------------------------------------------------------- | ------------------------------------------------ |
| **应用 patch 420（保留私有 flag）**                            | Samba 依赖该 flag 精确设 birthtime；TrueNAS 必需 |
| 不应用，推动上游采纳                                           | 长期目标，但短期内 Samba 无 flag 可用            |
| 改用 futimens 2-timestamp + 接受 birthtime 被 setutives 旧行为 | SMB 语义会出错，不可行                           |

**推荐：应用 patch 420**（Samba 功能依赖）。该 flag 是 BSD 私有扩展，ABI 小，维护成本低。

#### 决策 3：ixnvdimm vs 上游 dev/nvdimm（patch 600）

15.1 有上游 `sys/dev/nvdimm/`（基础 NFIT+pmem），ixnvdimm 是功能超集（NTB 镜像/HA/DSM/IOAT NUMA）。

| 选项                                  | 适用场景                             | 代价                                           |
| ------------------------------------- | ------------------------------------ | ---------------------------------------------- |
| **应用 patch 600，继续维护 ixnvdimm** | 目标硬件有双控 NVDIMM、需 HA 写缓存  | 长期维护私有驱动，跨版本适配（已有 13/14 #if） |
| 不应用 ixnvdimm，用上游 nvdimm        | 普通无 NVDIMM 或仅单 NVDIMM 做内存盘 | 失去 NTB HA 镜像能力                           |
| 迁移到上游 nvdimm 并补齐 HA/DSM 能力  | 长期上游化目标                       | 大工程，需把 ixnvdimm 私有能力推上游或重写     |

**推荐：双控 NVDIMM 硬件 → 应用 patch 600；无 → 跳过**。ixnvdimm 与上游 nvdimm 走不同 newbus 树，可并存不冲突，但同一设备只会被其一 probe。

#### 决策 4：ACPI Package→int hack（patch 710）— 硬件特定

| 选项               | 适用场景                                    |
| ------------------ | ------------------------------------------- |
| **应用 patch 710** | 目标平台是 Supermicro NVDIMM（有 ACPI bug） |
| 不应用             | 非 Supermicro NVDIMM 平台，该 hack 无意义   |

**推荐：按目标硬件决定**。注意它改的是上游 ACPICA contrib，未来 ACPICA 升级时需手工保留该 hack。

#### 决策 5：yp 重试次数（patch 720）

| 选项                       | 取舍                                         |
| -------------------------- | -------------------------------------------- |
| **应用 patch 720（20→5）** | 偏好 fail-fast，NIS 配错时 50s 报错而非 200s |
| 不应用（保持 20）          | 与上游行为一致，NIS 配错时容忍更长等待       |

**推荐：按部署偏好**。无 NIS 环境不受影响；有 NIS 且偶发配错的运维通常偏好 fail-fast。

### 6.5 高冲突文件与 rebase 后状态

以下文件在 13.3→15.1 间上游演进大，本集 rebase 时重点解决；rebase 后状态：

| 文件                      | 上游演进 | rebase 结果                                                                            |
| ------------------------- | -------- | -------------------------------------------------------------------------------------- |
| `sys/cam/ctl/ctl.c`       | +1548 行 | patch 440 仅单行，0 冲突，`ctl_isc_mode_sync` site 保留                                |
| `sys/kern/vfs_syscalls.c` | +884 行  | patch 420，0 冲突，`getutimens`/`kern_utimensat` 保留 15.1 结构叠加 get_btime          |
| `lib/libvmmapi/vmmapi.c`  | +1039 行 | bhyve-vnc patch，`vm_limit_rights` 0 冲突加 `CAP_FSTATAT`                              |
| `libexec/rc/rc.subr`      | +786 行  | patch 700 手工删两处 export 块，保留 15.1 run_rc_command 重构                          |
| `usr.sbin/bhyve/bhyve.8`  | +562 行  | bhyve-vnc patch，0 冲突                                                                |
| `usr.sbin/bhyve/rfb.c`    | +347 行  | bhyve-vnc patch，3 处冲突已解决（family 参数、pixfmt 字段、escape hatch）              |
| `usr.sbin/bhyve/Makefile` | +89 行   | bhyve-vnc patch，SRCS 重构已适配（vga/xmsr 移至 amd64/Makefile.inc，仅加 vncserver.c） |

### 6.6 未经完整 build 验证的声明

本 patch 集以 3-way merge 在 15.1 基线上重新整合，**已验证每个 patch 能干净 `git apply` 到 releng/15.1 HEAD**，但**未经完整 build world/kernel 验证**。特别是：

- `600-ixnvdimm`：驱动源取自 os HEAD（含 13/14 兼容 `#if`），15.1 的 `__FreeBSD_version` 应走对应分支，但 `vm_phys_domain`/`bus_child_pnpinfo` 等 API 在 15.1 的精确签名需 build 时确认。
- `420-utimensat`：`getutimens` 的 3-timespec 路径与 15.1 `setutimes` 的 `numtimes>2` 底层衔接，需 build+运行验证 Samba 场景。
- `100-bhyve-vnc`：依赖外部 `libhyverem ≥ 0.1.4.1`，且 15.1 `rfb_softc` 的 `pixfmt` 协商与 TrueNAS libhyve-remote ABI 占位字段并存，需 build 确认无字段冲突。

**apply 后务必在目标环境执行 build world + build kernel 确认。**
