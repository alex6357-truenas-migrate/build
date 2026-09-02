# py-bsd (truenas/py-bsd master @ be67e03, tag TN-13.3-U1.2) vs FreeBSD 15.1 兼容性核对

- 对证树：`F:\zvault\nas-build\src15`（freebsd releng/15.1 + TrueNAS patch, HEAD `0014d3d`, branch `truenas/15.1-patches`）
- 方法：逐模块把 `defs.pxd` / 各 `.pyx` 引用的 syscall / ioctl / 库 API 与 src15 中的头文件、库目录、内核配置 grep 对证。
- 重要前提：Cython 的 `cdef extern struct/enum` 声明**不参与版式 codegen**——生成的 C 文件包含真实系统头，字段名/类型最终由 C 编译器按真实头文件解析。因此 defs.pxd 中字段**顺序/宽度与真头不一致**只要类型宽度能覆盖，编译和运行通常仍正确；真正的断点是：(1) pyx 代码实际**访问**了 15.1 头文件中**已不存在**的字段名；(2) 调用了已删除的**函数/常量**(生成 C 引用不存在符号)；(3) 函数返回类型声明与真头冲突且返回值被使用。以下「所需修复」按这个判据分级。

## 结论总览

| 模块 | 15.1 可用？ | 严重度 |
|---|---|---|
| geom.py | ✅ | — |
| sysctl.pyx | ✅ | — |
| disk.pyx / disk_ioctl.pxd | ✅ | — |
| threading.pyx | ✅ | — |
| acl.pyx | ✅ | 低（defs 清理） |
| extattr.pyx | ⚠️ 部分 | **高**（defs.exattr_set_fd 拼写错误，fd-set 路径编译/链接失败） |
| bpf.pyx | ✅ | 低 |
| nis.pyx / yp_client.c | ✅ | — |
| kld.pyx | ✅ | — |
| nmount（_bsd.pyx 内） | ✅ | — |
| _bsd.pyx（procstat/kvm/kinfo 等） | ✅ | 中（defs 结构声明过期但字段访问全部仍合法；PS_FST_TYPE 新枚举建议补齐） |
| devinfo.pyx | ✅ | 低（devinfo_free 返回类型；DS_BUSY 已删但未被使用） |
| dialog.pyx | ❌ | **高**（libdialog 已从 base 删除，仅剩 libbsddialog，API 不同） |
| setup.py | ❌ | **高**（distutils 已死、需迁 pyproject/setuptools；`-ldialog`） |

---

## 逐模块核对

### geom.py（纯 Python，`kern.geom.confxml`）【✅ 可用】
- `sysctl kern.geom.confxml` 在 15.1 仍存在：`sys/geom/geom_kern.c:197` `sysctl_kern_geom_confxml`，`:207` `SYSCTL_PROC(_kern_geom, OID_AUTO, confxml, ...)`。
- 修复：无 syscall 层问题。注意 `geom.py` 依赖 Py2 时代的 `six`（`import six` / `six.next`），Python 3.12+ 环境下需要装 six 或改 `next(iter(...))`；这是运行时依赖问题，不属于本核对范围但建议顺手处理。

### sysctl.pyx（`sysctl/sysctlbyname/sysctlnametomib`）【✅ 可用】
- libc 三函数与 `sys/sysctl.h` 在 15.1 存在；`CTL_NET/PF_ROUTE/NET_RT_DUMP`（文件内硬编码注释段）未变更。defs.pxd 中 `KERN_PROC_*`（ALL/PID/PGRP/SESSION/TTY/UID/RUID/PROC/RGID/GID/INC_THREAD）在 15.1 均存在。
- 修复：无。

### disk.pyx（`sys/disk.h`）【✅ 可用】
- `DIOCGSECTORSIZE`（'_d',128）、`DIOCGMEDIASIZE`(129)、`DIOCGIDENT`(137)、`DISK_IDENT_SIZE=256` 全部在 `sys/sys/disk.h:28/35/65/66` 原样存在。
- 修复：无（`disk_ioctl.pxd` 声明即真值）。补充：DIOCGIDENT 的 buffer 大小以 `DISK_IDENT_SIZE` 为准，disk.pyx 内部硬编码大小需与该值一致（当前一致）。

### threading.pyx（`sys/thr.h`）【✅ 可用】
- `thr_self`/`thr_set_name` 声明在 `sys/sys/thr.h:76,82`（`#ifndef _KERNEL` 区，userland 可见）✅；syscall 经 libc 封装。
- 修复：无。注意 `get_thread_name` 依赖 `_bsd.kinfo_getproc(...).threads`（kinfo_proc 路径，见 _bsd 节）。

### acl.pyx（`sys/acl.h`）【✅ 可用，defs 微清理】
- NFSv4 常量全部在：`ACL_BRAND_NFS4/ACL_TYPE_NFS4`、`ACL_ENTRY_TYPE_ALLOW/DENY`、`ACL_ENTRY_FILE_INHERIT/DIRECTORY_INHERIT/NO_PROPAGATE_INHERIT/INHERIT_ONLY/INHERITED`（sys/acl.h:248-254）、`ACL_EVERYONE/ACL_USER_OBJ/.../ACL_MASK`、perm 位 `ACL_READ_DATA ... ACL_SYNCHRONIZE` 及复合 `ACL_READ_SET/WRITE_SET/MODIFY_SET/FULL_SET`（:222-235）、`ACL_FIRST_ENTRY/NEXT_ENTRY`。
- 函数全部在 `sys/acl.h` 声明，含 `acl_delete_def_link_np`、`acl_delete_link_np`、`acl_get_brand_np`、`acl_valid_link_np`、`acl_is_trivial_np`（:419）、`acl_strip_np`（:420）。实现位于 `lib/libc/posix1e/`。
- 修复（可选清理）：defs.pxd 中 `acl_perm_t` 被声明两次（一次 `ctypedef enum acl_perm_t`，一次 `ctypedef unsigned int acl_perm_t`），Cython 历史上容忍，建议去掉其一。

### extattr.pyx（`sys/extattr.h`）【⚠️ fd-set 路径断裂 —— 既存 bug，15.1 下必然编译失败】
- 头文件本身在 15.1 完整存在：`sys/sys/extattr.h` 提供 `EXTATTR_NAMESPACE_*`/`EXTATTR_NAMESPACE_*_STRING` 及全部 12 个 `extattr_{get,set,delete,list}_{fd,file,link}` 原型 ✅。
- **但** `defs.pxd:493` 把 `extattr_set_fd` 错拼为 **`exattr_set_fd`**（少了 't'），而 `extattr.pyx:266,268` 恰好调用的就是 `defs.exattr_set_fd`（`set()` 传入 fd/fileno 的分支）。生成的 C 会调用不存在的符号 `exattr_set_fd`：现代 clang（15.1 工具链）对隐式函数声明直接报 error；即使降级为 warning，链接也会失败。
- 修复：把 defs.pxd 声明改为 `ssize_t extattr_set_fd(...)`（或对 extattr.pyx 两处调用同时改为正确名）。注意这是 **13.x 就存在的既存 bug**——说明 middleware 走的一直是 `set(path)` 的 `extattr_set_file/extattr_set_link` 分支，fd 分支从未跑过；迁移时应先确认 middleware 是否需要 fd 形态，不需要可将修复降为文档注记。
- 另：`defs.pxd:488-490` 声明的 `EXTATTR_NAMESPACE_*_STRING` 是宏（字符串字面量），Cython 当变量声明也可用（生成代码引用宏展开），无问题。

### bpf.pyx（`net/bpf.h`）【✅ 可用】
- bpf 设备仍在 amd64 GENERIC 内核（`sys/amd64/conf/GENERIC:326 device bpf`），"15.1 是否有 bpf"成立 ✅。
- 全部 BIOC ioctl 宏在 `sys/net/bpf.h`：BIOCGBLEN:121 BIOCSBLEN:122 BIOCSETF:123 BIOCFLUSH:124 BIOCPROMISC:125 BIOCGDLT:126 BIOCGETIF:127 BIOCSETIF:128 BIOCSRTIMEOUT:129 BIOCGRTIMEOUT:130 BIOCGSTATS:131 BIOCIMMEDIATE:132 BIOCVERSION:133 BIOCGRSIG:134 BIOCSRSIG:135 BIOCGHDRCMPLT:136 BIOCSHDRCMPLT:137 BIOCGDIRECTION:138 BIOCSDIRECTION:139 BIOCSDLT:140 BIOCGDLTLIST:141 BIOCLOCK:142 BIOCFEEDBACK:144 BIOCGETBUFMODE:145 BIOCSETBUFMODE:146 BIOCGETZMAX:147 BIOCROTZBUF:148 BIOCSETZBUF:149 BIOCSETFNR:150 BIOCGTSTAMP:151 BIOCSTSTAMP:152 ✅。
- `enum bpf_direction {BPF_D_IN, BPF_D_INOUT}`（:160），`struct bpf_ts/bpf_xhdr/bpf_insn/bpf_program`（:196-…）存在；`BPF_WORDALIGN` 宏（:59，基于 `BPF_ALIGNMENT=sizeof(long)`），defs 声明为 `int BPF_WORDALIGN(int)` —— 宏作函数声明可照常展开 ✅。指令类宏 BPF_LD/…/BPF_MSH、BPF_TAX/TXA 全部在（:260-324）。
- 修复：无。defs 里 `BIOCGDIRECTION` 等是 `_IOR(..., u_int)` 值，声明为 enum 得当。

### nis.pyx / yp_client.c（libypclnt）【✅ 可用】
- `lib/libypclnt` 在 15.1 base 仍在：`lib/libypclnt/{Makefile,ypclnt.h,ypclnt_new/free/connect/error/get/passwd}.c`；`lib/Makefile:207 SUBDIR.${MK_NIS}+=libypclnt`，且 `share/mk/bsd.opts.mk:63` 中 NIS 属 `__DEFAULT_YES_OPTIONS`（默认编）✅ —— 与此前审查一致。
- yp_client.c 的头 `rpcsvc/yp.h`（由 `include/rpcsvc/yp.x` rpcgen 生成）、`rpcsvc/ypclnt.h`（`include/rpcsvc/ypclnt.h` 源文件）都在，并通过 `include/rpcsvc/Makefile` INCS 安装（yp.h:6, ypclnt.h:13）✅。`ypclnt_new/connect/passwd/free/error` 签名与 15.1 `lib/libypclnt/ypclnt.h:49-54` 一致。
- libc 侧 `yp_bind/yp_match/yp_master`（lib/libc/yp/yplib.c）在 ✅。
- 注意：TrueNAS patch `0014d3d "reduce yp MAX_RETRIES 20 -> 5"` 已作用于该树（——语义微调，不影响 ABI）。
- 修复：无。

### kld.pyx（`sys/linker.h`）【✅ 可用】
- `kldload/kldunload/kldnext/kldstat` 声明在 `sys/sys/linker.h:404-409`（userland 区）✅；`kldunloadf` 新增但未被使用。
- `struct kld_file_stat`（:375-383：version/name[MAXPATHLEN]/refs/id/address/size/pathname[MAXPATHLEN]）与 defs.pxd 完全一致 ✅。
- 修复：无。

### nmount（_bsd.pyx 内，`sys/mount.h`）【✅ 可用】
- `nmount`（mount.h:1213）、`getmntinfo`（:1210）、`statfs`（:1214）、`unmount`（:1215）均在。`MNT_WAIT/MNT_NOWAIT`（:566-567）在。
- `MNT_*` 全部保留：RDONLY/SYNCHRONOUS/NOEXEC/NOSUID/NFS4ACLS/UNION/ASYNC/FORCE/SUIDDIR(:387)/SOFTDEP/NOSYMFOLLOW/GJOURNAL(:390)/MULTILABEL/ACLS/NOATIME/NOCLUSTERR/NOCLUSTERW（见 :380-447 区间 + VISFLAGMASK）✅。
- `struct statfs`（:85-110）：defs.pxd 声明的字段顺序与 13.x 相同（`f_spare[10]` 在 f_asyncreads 之后）；15.1 将该区改为 `f_nvnodelistsize(u32) + f_spare0(u32) + f_spare[9]`——**总宽度相同（80B），f_namemax 及之后所有字段偏移不变**。defs 声明因此仍产生正确布局；仅建议在 defs 中把该区改成新字段名以保持声明与真头一致（可选）。`MNAMELEN=1024/MFSNAMELEN=16` 未变。
- 修复：无（可选的 defs 同步）。

### _bsd.pyx（libprocstat / libkvm / libutil / libc）【✅ 可用，defs 建议更新】
函数层面全部存在（`lib/libprocstat/libprocstat.h` v15.1）：
- `procstat_open_sysctl/open_core/close/getprocs/freeprocs/getfiles/freefiles/getargv/freeargv/getenvv/freeenvv/freegroups/getpathname/get_pipe_info/get_pts_info/get_sem_info/get_shm_info/get_socket_info/get_vnode_info` —— 签名未变 ✅（:200-268）。
- `PS_FST_TYPE_*`（VNODE..SEM）与 `PS_FST_FFLAG_*`、`PS_FST_UFLAG_*`、`PS_FST_VTYPE_*` 常量值未变（:45-104）✅。**新增** `PS_FST_TYPE_PROCDESC=13/DEV=14/EVENTFD=15/INOTIFY=16`（:71-74）：`_bsd.pyx` 的 `DescriptorType()` 如果遇到这类 fd 会 `ValueError` —— 建议在 `_bsd.pyx` 补枚举 + defs.pxd 补常量（健壮性修复，非编译阻塞）。
- `struct filestat`：15.1 在尾端 **新增 `fs_cap_rights`**（:129）；defs 未声明。前面所有字段（fs_type..fs_path, next STAILQ entry）名/序不变；_bsd.pyx 访问路径不受影响 ✅。
- `struct vnstat`：变化——`vn_dev`/`vn_fsid` 从 uint32 变 **uint64**，且 `vn_mntdir` 位置移到 `vn_fsid` 之后（:131-140）。defs.pxd 声明（vn_fileid, vn_size, **vn_mntdir**, vn_dev[u32], vn_fsid[u32], ...）已过期。由于 Cython extern 结构字段由真头解析，运行时取值仍正确；但 defs 中 `uint32_t` 的宽度声明使 Cython 对该字段的 Python 打包按 32 位处理（fsid/dev 实际值 <2^32，无实质损失）。**建议**把 defs 改为新顺序/新宽度（文件 `defs.pxd` 413-421 行）。
- `struct sockstat`：**`inp_ppcb` 已被移除**（即用户关心的字段——15.1 头部 :158-172 以 `so_addr` 开头），尾部**新增 `sendq/recvq`**。defs.pxd:399-411 仍声明 `uint64_t inp_ppcb` 为首字段。因 `_bsd.pyx` 只访问 `dname/dom_family/proto/sa_local/sa_peer`（不开 inp_ppcb），**该声明不触发 C 编译错误，也不造成读数错位**（extern struct 不生成版式）——但还是强烈建议把 `inp_ppcb` 从 defs 删除、补上 `sendq/recvq`，保持声明为真值，避免后续有人误用（一旦访问 `ss.inp_ppcb` 即为 C 编译错误）。
- `kinfo_proc`（`sys/sys/user.h:119-222`）：15.1 结构与 defs.pxd:238-306 的声明**整体差异很大**（defs 漏掉 ki_layout 之后 7 个指针字段、ki_pctcpu、ki_reaper/ki_reapsubtree、`struct priority ki_pri` 等，且 defs 中 `ki_oncpu/ki_lastcpu` 宽度为 u_char 而真头是 int、新增 ki_oncpu_old/ki_lastcpu_old）。但 _bsd.pyx/threading.pyx 实际访问的字段 **ki_pid, ki_ppid, ki_comm, ki_uid, ki_tid, ki_tdname, ki_moretdname, ki_start, ki_rusage, ki_rusage_ch** 全部以同名存在（字段类型 timeval/rusage/lwpid_t 未变）→ 编译与运行均正确 ✅。defs 建议整体重写为真头子集（13.x 起即不准，非 15.1 回归）。
- `closefrom`（`lib/libc/sys/closefrom.c`）、`setproctitle`（`lib/libc/gen/setproctitle.c`）、`login_tty`/`kinfo_getproc`（`lib/libutil/libutil.h:122,125`）、`kvm_open/kvm_getswapinfo/kvm_close` + `struct kvm_swap{ksw_devname[32],ksw_used,ksw_total,ksw_flags}`（`lib/libkvm/kvm.h:71-75,95,108,112`）全部在 ✅。
- 修复：defs.pxd 的 vnstat/sockstat/filestat/kinfo_proc 声明同步（如上）；_bsd.pyx 补 PS_FST_TYPE 新枚举。
- 备注：`Process.threads` 依赖 `defs.kfold` 未涉；`c_statfs "statfs"` 的别名写法无问题。`sys/syslink.h`（即"kd4444msg"所指 kld* 部分）已归 kld.pyx 一节核准。

### devinfo.pyx（libdevinfo）【✅ 可用】
- `lib/libdevinfo` 在 15.1 base 存在（`lib/Makefile:52 libdevinfo`），头文件 `lib/libdevinfo/devinfo.h` 签名齐全：`devinfo_init`（:81）、`devinfo_foreach_rman`（:133）、`devinfo_foreach_rman_resource`（:124）、`devinfo_handle_to_device/resource/rman`（:93-98）✅。链接参数 `-ldevinfo` 有效。
- 差异 1：`devinfo_free` 真头返回 **void**（:88），defs.pxd 声明为 `int`。`devinfo.pyx:84` 不取返回值 → 编译无碍；建议把 defs 改成 void。
- 差异 2：`devinfo_rman.dm_start/dm_size` 真头为 `rman_res_t`（=uint64_t），defs 声明 `unsigned long` —— LP64 下同为 8 字节 ✓，无实质影响。
- 差异 3：defs.pxd 的 `sys/bus.h` 枚举 `device_state` 中声明了 `DS_BUSY=40`；**15.1 已删除 DS_BUSY 及 DS_DETACHING/DS_DETACHED，枚举止于 DS_ATTACHED=30**（`sys/sys/bus.h:54-59`）。`devinfo.pyx` 未引用 DS_BUSY → 不编译出问题；建议从 defs 删除，并注意若 middleware 曾经按 state 能取 40 判断 busy，15.1 基础设施不再产生该值。
- 修复：低优先级 defs 清理（devinfo_free→void；删 DS_BUSY）。

### dialog.pyx（libdialog）【❌ 需移植】
- 15.1 base 中 **libdialog 已删除**：`lib/Makefile` 只有 `libbsddialog`（:40，`INCS=bsddialog.h`），全树无 `lib/libdialog/**`，亦无 `dialog.h/dlg_keys.h` 供给。defs.pxd:877-952 的 `DIALOG_*`/`dlg_*` 声明均无对应头 -> `bsd.dialog` 无法编译。
- 所需修复：移植到 **libbsddialog** API（`bsddialog.h` + `-lbsddialog`），属 API 级重写而非符号改名；若 py-bsd 的 dialog 无消费方，直接从扩展列表剔除。`setup.py:49` 的 `-ldialog` 同步处理。

### setup.py【❌ 需迁构建】
- `from distutils.core import setup` + `Cython.Distutils.*`（setup.py:29-32）——Python 3.12 起 distutils 移出 stdlib，15.1 base python 无法直接跑（除非装了 setuptools 提供的 shim）。
- 库参数核对：`-lutil`、`-lprocstat`、`-ldevinfo`、`-lypclnt` 在 15.1 均有效 ✅；`-ldialog` 失效 ❌（见上）。
- 修复：迁 `pyproject.toml`(build-system: setuptools + cython) + `Extension(...)` 列表迁移；`cython_compile_time_env={'PY2': six.PY2}`（extattr）在 Py3 下恒 False，可去。

---

## defs.pxd 建议修改清单（供后续动手时逐项落地）

1. `sys/mount.h` 区：`f_spare[10]` → `f_nvnodelistsize` + `f_spare0` + `f_spare[9]`（可选，偏移等价）。
2. `libprocstat.h` 区：
   - `sockstat`：删除 `uint64_t inp_ppcb`；末尾加 `unsigned int sendq/recvq`（可选）。
   - `vnstat`：改为 `vn_fileid u64, vn_size u64, vn_dev u64, vn_fsid u64, vn_mntdir char*, vn_type int, vn_mode u16, vn_devname[...]`。
   - `filestat`：可补 `fs_cap_rights`（尾部，非必需）。
   - 补 `PS_FST_TYPE_PROCDESC/DEV/EVENTFD/INOTIFY` 并在 `_bsd.pyx` 的 `DescriptorType` 里补同名成员。
3. `sys/user.h` 区（kinfo_proc）：按真头 15.1 修订或仅保留访问字段并剔除改名/退役别名（低优先级，当前不阻塞）。
4. `sys/extattr.h` 区：`exattr_set_fd` → `extattr_set_fd`（**必须**，否则 fd 形态 set 路径编译失败）。
5. `devinfo.h` 区：`devinfo_free` 返回类型改 void；删除 `devinfo_dev` 之外无用的 stale 项（可选）。 
6. `sys/bus.h` 区：删除 `DS_BUSY = 40`（15.1 已不存在；未被代码使用）。
7. `dialog.h/dlg_keys.h` 两区随 dialog 模块移植或删除。
8. `acl.h` 区：去掉重复 `acl_perm_t` typedef（可选）。
