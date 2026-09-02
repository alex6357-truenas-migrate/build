# TrueNAS samba fork × FreeBSD 15.1 核查

## 结论预览

fork `4fec43c0`（truenas/samba 4.19.6 + 226 commit 私有）**直接对 15.1 编译**；
唯一要确认的是 fork 的 `AT_UTIMENSAT_BTIME` 用法有没有在 15.1 的 fcntl.h 里被 src patch 420 提供。**yes**。

## 关键依赖链

| fork 使用点 | 依赖符号 | 15.1 提供 |
|---|---|---|
| `source3/modules/vfs_ixnas.c:1473` | `AT_UTIMENSAT_BTIME` (`0x1000`) | ✅ src15 `sys/sys/fcntl.h` 有 |
| `source3/wscript` （第450行） | `HAVE_UTIMENSAT` | ✅ 15.1 libc 自带 |
| `source3/wscript` （birthtime 检测） | `struct stat.st_birthtime` | ✅ 15.1 stat 结构新生 |
| `lib/zfsacl/zfsacl_impl_freebsd.c` | `acl_*` NFSv4 ACL API | ✅ 15.1 `sys/acl.h` 有 |
| `lib/replace/xattr.c` | `extattr_*` 扩展属性 | ✅ `sys/sys/extattr.h` 提供 |
| source3/smbd 目录 | `nmount`/`getfsstat` | ✅ `sys/mount.h` 有（另需 `mount.h` 里的 `getmntinfo`、`nmount`） |
| fork 中的 pthread_name | `thr_set_name` | ✅ `sys/thr.h` 有 |
| fork 磁盘枚举 | `DIOCG` 磁盘 ioctl | ✅ `sys/sys/disk.h` 有 |
| fork 路由 | `net/if.h` SIOC* | ✅ 15.1 仍走 ioctl（有 netlink 进化但兼容保留） |
| 嵌套标识（ `kenv` ）| sysctl 常量 | ✅ 15.1 sysctl.h （不变） |

## 需要 fork 自己处理的事

1. **fork 的 checks/configure 机制疑有前后设置在 15.1 的 openssl/samba-python 版本围外**（线上环境测试边时的黑洞）。P6 build 机上第一个确认。
2. **truenas_audit module** 确认 middleware 用不到，可以在 freecore delta 基础上删（freecore 已验证移除无影响）。
3. fork 里 `wscript_build` 的模块列表 （`source3/modules/wscript_build`） 与 upstream ports 的 patch 重叠——注意我们已经有了 `ports-extra/net/samba`，那 port 的 `Makefile` 里也有模块列表（`SAMBA4_MODULES`），两边会维护两份，需要一致（在 P2b 决议上直接锁 freecore 的 delta）。

详细过滤后，没有结构性 blocker。
