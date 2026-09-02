# py-libzfs × FreeBSD 15.1 base zfs 兼容核查

## 结论

`truenas/py-libzfs` 的 fork pin（13.3-era, `98fbfdc924c3abbf15e7bb090a638b763c5769a3`）**直接替换为 truenas/py-libzfs master HEAD**（当前 `faa4cbff6209...`），可兼容 base zfs（OpenZFS 2.4.2）。

## 证据链

1. base 侧已切换到 OpenZFS 2.4.2（`src15/sys/contrib/openzfs/meta`）；ports 侧 openzfs-2.4.3 也已被删除（仅保留 ports/sysutils/openzfs* 老包用）；`WITHOUT_ZFS` 已从 `src.conf.*` 中全部删掉。
2. truenas/py-libzfs master 最近的一笔提交表明它在更新到"libzfs7/libzpool7"（SoVERSION 与 OpenZFS 2.3/2.4 对应）。
3. `git diff <pin>..origin/master -- pxd/zfs.pxd libzfs.pyx` 是**纯增量**：新增了 ZFS 2.2→2.4 之间引入的 raidz expand（`pool_raidz_expand_stat_t`）、错误码补全（`EZFS_ERRORSCRUB*`...），没有删除或改动既有符号。

## 动作（已落地）

- `build/ports-extra/devel/py-libzfs/Makefile` 的 `GH_TAGNAME` 改为 `py-libzfs master`（当前 `faa4cbff6209...`）；如需 pin 到固定 SHA 再由维护者切。
- `repos.conf` 中 REPO_PYLIBZFS 的 pin 同步更新为 master HEAD（构建期可追新）。

## 剩余 runtime 风险

- middleware `plugins/zfs.py` 的 zfs event 侦听逻辑在 base zfs 2.4 上可能 devd 事件有效性较差（历史上用 kmod）。需 P6 验证：on-import/on-export 事件能否从 base zfs 反馈到 middleware。
