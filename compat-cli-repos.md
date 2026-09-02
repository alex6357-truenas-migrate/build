# 15.1 Smoke 核查：iocage / zettarepl / midcli / truecommand-stats

核查日期：本次会话。源码基线：`F:\zvault\freebsd-src` `origin/releng/13.3` vs `origin/releng/15.1`（本工作区无 releng/15.1 本地分支，用 `origin/releng/15.1`，等价于 release/15.1.0 系列）。四仓均只读核查，未改动。

仓库路径以本工作区实际为准：`nas-build/py-zettarepl`（非 `nas-build/zettarepl`）、`nas-build/truecommand-stats`（任务书中的 `truecommand-controls` 在本工作区不存在）。

---

## 1. iocage（`nas-build/iocage` @ truenas/13.0-stable d8b3d7e） — 【可用】 / 【建议保持现有】

### 1.1 调用面（如何调 jail/jls/jexec/rctl）
- **启动**：iocage 生成 `/var/run/jail.ioc-<uuid>.conf`（标准 jail.conf 语法），然后 `jail [-v] -f <conf> -c`（`iocage_lib/ioc_start.py:594–599`）。
- **停止**：`jail -q [-v] -f <conf> -r ioc-<uuid>`（`iocage_lib/ioc_stop.py:316–329`）。
- **运行时修改**：`jail -m jid=... key=value`（`iocage_lib/ioc_json.py:1995`）。
- **查询**：`jls jid --libxo json`、`jls --libxo json -v`、`jls -n ip4.addr --libxo=json`、`jls -j ioc-<uuid>`；`jexec` 用于 jail 内 ifconfig/pkg/netstat。
- **RACL/RCTL**：不链 libjail，直接 shell `rctl` / `rctl -a` / `rctl -r jail:...`（`iocage_lib/ioc_json.py:293–323`），rctl CLI 13→15 无变化。
- **dataset 委托**：`zfs jail ioc-<uuid> ...`（`ioc_start.py:779`）。

### 1.2 15.1 jail(8) 行为逐项核对（diff origin/releng/13.3 → origin/releng/15.1，usr.sbin/jail、sys/kern/kern_jail.c）
| 核对点 | 结论 |
|---|---|
| `jail -f/-c/-r/-m` 同一性 | ✅ 不变。15.1 仅新增 `-C`（清理已移除 jail 的收尾命令）、`-e` 语义不变（仍是 conf 打印+分隔符，只是代码重构）。`jail -r <jail>` 停止路径逻辑等价。 |
| `persist` 语义 | ✅ 不变。`persist` 仍是内核布尔参数；iocage 生成 conf 中写裸 `persist`（`ioc_start.py:584`）在 15.1 同样合法。jail.conf 语法新增 `.include` 支持（15.x），不影响 iocage 自生成文件。 |
| `ip_hostname` / `vnet` / `epair` 选项名 | ✅ 稳定。`ip_hostname` 为 jail(8) 内部参数（config.c `[IP_IP_HOSTNAME]`，两版均存在）。`vnet`、`vnet.interface`、epair 命名约定（iocage 内部 `vnet→epairNb` 映射，`ioc_start.py:1243–1245`）与内核无耦合。 |
| 内核 jail 参数表 | ✅ 只增不删。13.3→15.1 仅新增 `allow.extattr/adjtime/settime/routing/setaudit/unprivileged_parent_tampering`；iocage 用到的 `allow.set_hostname/raw_sockets/sysvipc/quotas/socket_af/chflags/mount.mount.*`、`sysvmsg/sem/shm`、`children.max`、`enforce_statfs`、`devfs_ruleset`、`securelevel`、`exec.consolelog`、`mount.fstab` 全部保留。 |
| libjail / RCTL | iocage 不链 libjail，全部走 `rctl` CLI，无 ABI 面。jail(8) 自身仍 `LIBADD= jail kvm util`，对 iocage 透明。 |
| `zfs jail` 委托 | ✅ `zfs_do_jail` 仍存在于 15.1 的 `sys/contrib/openzfs/cmd/zfs/zfs_main.c`；jail.conf.5 的 SEE ALSO 仍列 zfs-jail(8)。 |

### 1.3 唯一行为差异（非阻断）
- `allow.dying` 参数与 `-d` flag 在 15.x 起**废弃且无效果**，会在 jail 启动时向 **stderr** 打一次警告 `the 'allow.dying' parameter and '-d' flag are deprecated and have no effect.`
- iocage 在生成 conf 中写了裸 `allow.dying`（`ioc_start.py:580`）。iocage 的启动结果判定只看 `returncode`（`ioc_start.py:679–708`），stderr 警告不会导致失败；且新语义（同名 jail 总是替换 dying jail）正是 iocage 想要的。
- 结论：功能不受影响；若想静默可删该参数（1 行 patch），但非必需。

---

## 2. zettarepl（`nas-build/py-zettarepl`，需求 pin 60ade60） — 【需 patch】（1 处）/ 【建议保持现有 pin + 小 fork patch】

当前 HEAD `12f2fd4`（SCALE-era）并非目标；按 60ade60（13.3-era）核查。

### 2.1 paramiko（唯一的硬阻断点）
- `zettarepl/transport/base_ssh.py:158`（60ade60）：
  `for key_class in (paramiko.RSAKey, paramiko.DSSKey, paramiko.ECDSAKey, paramiko.Ed25519Key):`
- paramiko 4.x 已移除 `DSSKey`（ssh-dss 废止，参见 [sshtunnel #302](https://github.com/pahaz/sshtunnel/issues/302#1) 同一症状）；FreeBSD ports `security/py-paramiko` 2025 年已升至 4.x 系列（[freshports](https://www.freshports.org/security/py-paramiko#2)、[cgit log](https://cgit.freebsd.org/ports/log/security/py-paramiko)），15.1 的 pkg 即 paramiko 4.x → **运行即 `AttributeError: module 'paramiko' has no attribute 'DSSKey'`**。
- ✅ **patch 内容**：从该 tuple 删掉 `paramiko.DSSKey` —— 这正是上游后来做的事：当前 HEAD 已重构为 `_parse_private_key`，tuple 为 `(RSAKey, ECDSAKey, Ed25519Key)`。可单 commit cherry-pick 语义。
- paramiko 3.x 下可跑（DSSKey 仅 deprecated），4.x 必须 patch。
- 其余 paramiko API（`SSHClient`、`hostkeys.HostKeyEntry.from_line`、`set_log_channel`、`paramiko.ssh_exception.*`）在 3.x/4.x 均稳定。

### 2.2 Python 3.12+
- 无 `distutils` / `imp` / `pkg_resources` 依赖；setup.py + setuptools 在 3.12/3.13 正常。master 的 `pyproject.toml` 只含 mypy/ruff 配置，**无 poetry**（任务书说法不成立）；60ade60 纯 setup.py，直接 `pip install .` 即可。
- `datetime.utcnow()`（scheduler/clock.py）在 3.12 仅 DeprecationWarning，不阻断；pytz 正常。

### 2.3 zfs CLI 兼容（对 zfs 2.4.2）
- 全部使用长期稳定的 flags：`zfs list -t ... -H -o name -s name`、`zfs get -H -p`、`zfs snapshot/destroy [-r]/create -p/mount/umount/set/inherit`、`zfs send | zfs recv -s -F`。
- 无对 human 输出格式的解析；`zfs get -o value` 单行值解析不受 2.4.2 影响。
- `zfs recv -x` 支持探测（`transport/ssh.py:196–203`）是运行时探测 + 文本匹配，且 2.4.2 支持 `-x`，两条路径均安全。
- 进度条：依赖 TrueNAS 本地 zfs patch（`zfs send -V` / `ps` 里的 `zfs: sending ... (N%: cur/total)` 进程标题，`transport/progress_report_mixin.py`）。在 `freebsd-src truenas/15.1-patches` 中未找到该 patch（15.x 的 zfs patch 在 truenas/zfs 仓库，本工作区未检出）。代码对此**有降级**：探测失败则不报进度，仅日志 debug，不影响复制正确性。

---

## 3. midcli（`nas-build/midcli`，pin 5ac8045） — 【可用】 / 【建议保持现有】

- pin `5ac8045` 存在（"Add Travis CI for flake8"，很早期，但 prompt_toolkit 用法已是 2.x/3.x 共容面）。
- prompt_toolkit 2.0 → 3.x 逐项检查（`midcli/__main__.py`、`key_bindings.py`、`completer.py`）：`PromptSession` 及全部 kwargs（`message`/`complete_style`/`completer`/`complete_while_typing`/`editing_mode`/`enable_system_prompt`/`enable_suspend`/`history`/`input_processors`/`key_bindings`/`search_ignore_case`）、`prompt_toolkit.enums.{DEFAULT_BUFFER,EditingMode}`、`layout.processors.{ConditionalProcessor,HighlightMatchingBracketProcessor,TabsProcessor}`、`filters.{HasFocus,IsDone,completion_is_selected}`、`history.FileHistory`、`completion.{DynamicCompleter,ThreadedCompleter,Completer,Completion}`、`key_binding.KeyBindings` —— **全部在 prompt_toolkit 3.x 保留**，无需适配。
- `setup.py`（pin 与 HEAD 均）**无 install_requires**，`fastentrypoints` 有 try/except 兜底；运行时依赖（prompt_toolkit≥3、ply、middlewared client）由宿主机环境提供——打包时注意手工声明依赖而非依赖 setup.py。
- py3.12：无 distutils/imp，ply 兼容；setup.py 直接安装无问题。

---

## 4. truecommand-stats（`nas-build/truecommand-stats` @ 382928f，pin v0.1.8） — 【可用】 / 【建议保持现有 pin】

- v0.1.8 树极小：`src-go/trueview-stats.go` 单文件 + `build.sh`。任务书提到的 Makefile 在 HEAD/pin 均**不存在**；构建入口是 `build.sh`，核心即 `GOOS=freebsd GOARCH=amd64 go build trueview-stats.go`。
- go.mod/go.sum **不存在**（非 module 仓库）。新版 Go 对**文件模式**（`go build <file>.go`）兼容依旧，无需 module；但若要改用包模式（`go build ./...`）则必须新增 go.mod——保持 build.sh 的文件模式即可，建议**不要**升级构建方式。
- 依赖：纯 stdlib（fmt/time/encoding/json/os/exec/os/bytes/strings/strconv/context/runtime），零 module 引用 → Go 1.2x/最新版均可编译，freebsd/amd64 目标仍受支持。
- 15.1 运行时外部命令面：`vmstat -s/-P --libxo json`、`netstat -i -s --libxo json`、`ps --libxo json -ax -o pid,ppid,jail,jid,...`（`jail`/`jid` 列在 15.1 ps 仍存在）、`ifstat -a -T -b 1 1`、`gstat -bps`、`sockstat -P tcp -4 -p 2049/3260`、`sysctl -q dev.cpu`、`smbstatus -b`、`arcstat[.py]`（有存在性探测与降级）。全部为标准工具长期 flags，15.1 无输出 schema 变化风险（libxo json key 稳定）。
- 注意：二进制依赖宿主提供 arcstat（FreeNAS/TrueNAS python 工具）与 samba 的 smbstatus；缺任一则为该字段空/错误，程序有容错（每路独立 goroutine + channel 汇集）。

---

## 总结

| 仓库 | 结论 | 行动 |
|---|---|---|
| iocage (d8b3d7e) | 可用 | 保持现有；可选删 `allow.dying` 消除 15.1 启动警告（非必需） |
| zettarepl (60ade60) | 需 patch | 保持 60ade60 + 1 行 patch 删 `paramiko.DSSKey`（paramiko 4.x 必需）；py3.12/3.13 与 zfs 2.4.2 CLI 无其他问题；进度报告显示依赖 15 侧 zfs patch，已在代码中降级 |
| midcli (5ac8045) | 可用 | 保持现有；prompt_toolkit 3.x 完全兼容；打包时手工声明依赖 |
| truecommand-stats (v0.1.8) | 可用 | 保持现有；用 build.sh 文件模式 `go build`（勿改包模式），stdlib-only 兼容任何新 Go |
