# 建议移除的 patch（上游 FreeBSD 15.1 已有等价）

以下 TrueNAS `os` 仓库 commit 在上游 FreeBSD 15.1 主线已有等价实现（均为 TrueNAS 从上游 main/stable backport 到 13.3 的修复），**无需生成 patch**。升级到 15.1 基线时可直接丢弃；若需保留对应功能，15.1 上游版本已具备。

核查基准：`origin/releng/15.1` = `aadd58dddcbc78f4d5594827b46b5633552b15ce`（2026-07-28）。

| TrueNAS commit | 上游 commit | 说明 | 15.1 已验证 |
|---|---|---|---|
| `3b770e1c8b9` Add kern.reboot_wait_time sysctl | `84ec7df0d796`（Colin Perciva） | 新增 `kern.reboot_wait_time` sysctl，默认 0 移除重启前 1 秒等待 | ✅ 15.1 `kern_shutdown.c` 有 `static int reboot_wait_time = 0` + `DELAY(reboot_wait_time*1000000)` |
| `f4c10c88420` x86: Remove 1 second DELAY from cpu_reset | `05350f093663` | 删除 `cpu_reset()` SMP 路径等待 AP 的 1 秒 DELAY | ✅ 15.1 `cpu_reset()` 已无该 DELAY（`cpu_reset_real` 的"等 printf"DELAY 是另一回事） |
| `39807fa7e3f` ntb_hw_plx: Workaround read-only scratchpad registers | `3883c6fbf232`（及 `7393d37b1224`/`825b7c222a6b`） | PLX Test Pattern 寄存器写入加重试+回读校验，规避 link down 后 ~100us 只读 | ✅ 15.1 `ntb_hw_plx.c` `ntb_plx_spad_write` 有重试 |
| `0c8180c1b62` Hyper-V: vPCI: Write back original BAR values after prepopulating bars | `5473dee73005`（Whel Hu） | prepopulate BAR 写全 1 后立即写回原值，修复 LSI 9211-8i HBA DDA 失效 | ✅ 15.1 `vmbus_pcib.c` `vmbus_pcib_prepopulate_bars` 含 bar_val 写回 |
| `7d118cbbdf9` mountd - improve logging of errors in export lines | `572b77f8da5e` | mountd 新增 `check_path_component`/`check_dirpath`/`check_statfs`，导出失败报告具体分量与原因 | ✅ 15.1 `mountd.c` 含 `check_path_component`（4 处） |
| `b1d83774348` Fix undefined reference in mountd.c | （随 `7d118cbbdf9` 配套） | 修复上一 commit 重构遗留的 `while (*cp && ret)` undefined reference | ✅ 15.1 版本无此回归（`while (*cp)`） |
| `9fc86a79938` isp: fix ISPCTL_ABORT_CMD switch case | `7fa105d91f0d`（及镜像 `944827bcf6f0`/`8aa9192ce98a`） | `isp.c` `ISPCTL_ABORT_CMD` case 补 `break`，避免 fall-through panic | ✅ 15.1 `isp_freebsd.c` 含相关修复 |
| `498a47f09e5` isp: Fix use after free in aborts handling | `36abbfe061df`（及镜像） | `isp_target_mark_aborted_early` 先 STAILQ_REMOVE 再释放，修 UAF panic | ✅ |
| `8452110f17a` isp: Improve task aborts handling | `d353c342a12c`（及镜像 `ec3175fc3b2c`/`1fd197d19221`） | isp target abort 重构：atpd 加 ccb 指针、`isp_find_atpd_ccb`、ACK INOT abort、ABTS 支持 BA_RJT | ✅ 15.1 含 `isp_find_atpd_ccb`/`isp_abort_atpd` |
| `e65eaf24ba8` isp: Fix abort issue introduced by previous commit | `519121f5ea03`（及镜像 `2c48a8f161c9`/`ff911710de34`） | 修 `8452110f17a` 回归：CTIO 在途(ctcnt>0)时仅标记 dead 不立即 abort | ✅ 15.1 含 `ctcnt == 0` 条件 |
| `1680e464856` Sort list of supported features for more easy handling in the future. | `f993fff68979`（Alexander Leidinger） | `stand/libsa/zfs/zfsimpl.c` `features_for_read[]` 按字母序重排 | ✅ 15.1 `features_for_read[]` 已字母序 |
| `23a3f33e3b4` stand: Fix oversight in updating OpenZFS: Add com.klarasystems:vdev_zaps_v2 | `5fd34912b4a5`（Warner Losh） | `features_for_read[]` 补入 `com.klarasystems:vdev_zaps_v2`，修 OpenZFS import 后 loader 漏同步 | ✅ 15.1 `features_for_read[]` 含 `com.klarasystems:vdev_zaps_v2`（及 `dynamic_gang_header`） |

## 移除理由

这 12 项在 TrueNAS `os`（13.3 fork）上之所以以"自有 patch"形式存在，是因为它们来自上游 main/stable 的修复，在 13.3 fork 基点 `deb948cd`（2024-07-01）时尚未进入 `releng/13.3`，TrueNAS 为获得这些修复而 backport。一旦基线升级到 15.1，这些修复已在 releng/15.1 主线，**再保留 TrueNAS 的 backport 版会与上游重复、产生冗余冲突**，故应直接丢弃。

## 升级时的确认方法

升级时复核这些是否仍在上游，可用：

```
git -C <freebsd-src> log --all --grep='reboot_wait_time'      # 84ec7df0d796
git -C <freebsd-src> log --all --grep='1 second DELAY from cpu_reset'   # 05350f093663
git -C <freebsd-src> log --all --grep='read-only scratchpad'   # 3883c6fbf232
git -C <freebsd-src> log --all --grep='Write back original BAR'  # 5473dee73005
git -C <freebsd-src> log --all --grep='Improve error message for exports'  # 572b77f8da5e
git -C <freebsd-src> log --all --grep='ISPCTL_ABORT_CMD'       # 7fa105d91f0d
git -C <freebsd-src> log --all --grep='vdev_zaps_v2'           # 5fd34912b4a5
```