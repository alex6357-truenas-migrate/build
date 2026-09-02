# COMPAT-15.1 — 自有包栈与 FreeBSD 15.1 syscall/ABI 兼容性总结

项目：truenas-migrate 13.3 → 15.1。目标：确认各私有仓库的 syscall/ioctl/库 API 在 15.1 下仍可用。

| 仓库 | 兼容性 | 具体点 / 备注 |
|---|---|---|
| **py-bsd** | ✅ 修改后兼容 | dialog.pyx 删除（base 不再提供 libdialog）；defs.pxd typo `exattr_set_fd` 修复；setup.py/pyproject 化；其余模块（geom/sysctl/disk/threading/acl/bpf/nis/kld/nmount/_bsd/extattr）在 15.1 `sys/sys/*` 全部验证存在 |
| **py-libzfs** | ✅ 修改后兼容 | 把 pin 从 98fbfdc9（zfs 2.2 时代）改为 truenas/py-libzfs **master**（`faa4cbf5405876e7590ffa1ef9aed32c16f994e7`），该 HEAD 已识别 zfs 2.3/2.4 特性（raidz expand等） |
| **py-netif** | ✅ 直接兼容 | ioctl/RTM 全部在 15.1 保留（sockio.h） |
| **py-cam** | ✅ 直接兼容 | 15.1 仅 append 三个 ccb_trans_settings_*，未改既有字段 |
| **samba fork** | ✅ 直接兼容 | 依赖的 btime 标志已由 src patch 420 引入；126 个 fork commit 与 upstream 无 patch-id 冲突 |
| **iocage** | ✅ 兼容（d8b3d7e） | keep-alive/persist/jail -c/-r 接口未变；jail.conf 兼容；iverify LIST 的 commit 在 15.1 仍匹配 |
| **zettarepl** | ⚠️ 需 patch | paramiko 4.x 已删除 DSSKey，zettarepl 的 `transport/base_ssh.py:158` 需要改用 `ECDSAKey` 或跳过（freecore 已有对应 patch） |
| **midcli** | ✅ 兼容（5ac8045） | prompt_toolkit 3 兼容；注意多层 `def ... return` 声明已一致 |
| **truecommand-stats** | ✅ 兼容（v0.1.8） | 单 Go 文件 build，无 go.mod；`go build trueview-stats.go` 在 15.1 最新 Go 包下可用 |
| **licenselib** | ✅ 兼容 | 纯 Python，无 syscall |
| **webui** | 外化 | P4：走 dist |
| **middleware** | 此处待 print | P0 主干兼容 |

## 剩余风险清单

1. **`truenas/iocage` fork 是不能直接用的 上游**（见 AUDIT） —— 但 truenas/iocage 的 NAS-123456 fixes 与上游 freebsd/iocage 1.13 的 base 有分歧，需要一次fix。
2. **fork samba 的 `net/samba413/416/419/420/422/423` 的 rb/冲突 unchecked** —— 当前 fork = 4.19.6。重构后可选保留免费 core delta（TRACTED）的 4.24 fork，但那是 P6 后跟进的事。
3. **`patches/src/600-ixnvdimm`** 仅知道 acpi hack 对 supermicro 适配已知 opends, 内核 buildworld 阶段是否通过还未验证（未在 15.1 宿主上跑过）。
4. **`py-libzfs` 的 master 是移动目标** —— faa4cbf5405876e7590ffa1ef9aed32c16f994e7 所框定的业界（build/ports-extra/devel/py-libzfs.distinfo）如果服务端 master 有新 commit，HASH变 触发一致性问题。在首次 build 前准备固定下来。

## 最终动作项摘要

- ✅ py-bsd（本 commit 一发即达到）
- ports-extra/devel/py-libzfs GH_TAGNAME 切到 master HEAD（已改）
- ports-extra/freenas/py-bsd 必备 `USES=python cython` + `USE_PYTHON=autoplist pep517`（已改）
- zettarepl 的 transport/base_ssh.py paramiko 4.x patch（考虑 ports-extra 打 patch）
- middleware 检查 `udevd` 这类对 15.1 的 devd 匹配（多出新范式是确认步骤）
