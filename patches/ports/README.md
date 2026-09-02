# patches/ports — 15.1 ports 基线补丁

基线（`repos.conf::REPO_PORTS`）：`git.freebsd.org/ports.git` **2026Q3** 头
`d870b633c555cfe87437686a0f0b5ca202fbb74b`（2026-08-08）。
（2026-09 VM 首测 re-pin 到 `56ce79b768`，见 repos.conf；MOVED 补丁已针对新
pin 重生成。）

## 已删除（2026-09 VM 首测核实）

| 删除文件 | 删除理由 |
| ---- | ---- |
| `default-versions-fork.patch` | `NODEJS_DEFAULT 18`：2026Q3 已无 node18（只剩 20/22/24/26）；webui 走预构建 dist 后 ports.list 无任何 node 消费者 |
| `gem-skip-subdir-fork.patch` | gem.mk 重构仅服务 gitlab+cargo 生态；ports-extra 唯一 gem port（sidekiq71）不引用 GEMS_SKIP_SUBDIR，标准路径即可 |
| `python-mk-crypto-legacy-fork.patch` | 13.3/py3.9 时代为绕 rust 工具链而强制 cryptography-legacy；15.1/py3.12 上游默认 rust cryptography 正常工作，无需 legacy |

来源：全部自 truenas/ports fork `9461a3499b98` vs merge-base `985bb512c990` 的 diff 抽取。
**命名约定**：`*-fork.patch` = 从 fork 直接抽出的原始 diff，上下文锚在 fork 基线上；
应用到 2026Q3 前需复核（文件演进可能要求重锚），apply 顺序按文件名排序。

## 清单与裁决

| 文件 | 性质 | 裁决 | 备注 |
| ---- | ---- | ---- | ---- |
| `waf-env-fork.patch` | waf.mk 加 `WAF_ENV`（让 host-style env 注入 waf） | **保留** | fork 的 `net/samba` 依赖；行数极小，重锚风险低 |
| `default-versions-fork.patch` | `NODEJS_DEFAULT 18` | **重审** | 13.3 时代为老的 webui 链服务；新链（P4-B 方案 node20）不需要；大概率**丢弃** |
| `gem-skip-subdir-fork.patch` | gem.mk GEMS_SKIP_SUBDIR 重构 | **倾向丢弃** | 仅服务 gitlab 生态，TrueNAS 不涉及；实施时确认无遗留引用即删 |
| `MOVED-unexpire-fork.patch` | 撤销 libhyve-remote / py-ws4py / net-wireguard 的过期记录 | **保留** | `devel/libhyve-remote`、`www/py-ws4py` 由 ports-extra 提供；MOVED 记录影响 pkg 更名追踪 |
| `python-mk-crypto-legacy-fork.patch` | 强制 cryptography-legacy 替代 rust flavors | **重审** | 为 py3.9 设计；2026Q3 默认 python 3.11+ 且 `py-cryptography-legacy` 可能已移除——大概率**丢弃** |

## 尚未写入但预期属于本目录的 patch（P2 后半段）

1. `net/samba`（ports-extra）若与上游 `net/samba4xx` 并存冲突：CONFLICTS 声明 / 分类名修正；
2. middleware 装机链迁移 pkgbase 时涉及的 ports 侧补丁（如 net-snmp、openssh-portable 的 iX 私货剥离，依据 `_fork_diff_names.txt` 逐个核对）；
3. `ports-extra/*/Makefile` 的 `VALID_CATEGORIES+=freenas truenas` 注册 patch（往 `Mk/bsd.local.mk` / 分类层 Makefile 注册新分类）。

## 已知 fork 内其他必要修改（须在 P2b 评估是否也要转成 patch 进这里）

依据 fork-vs-upstream diff 中这些 port 的 M 项（未全部复核）：
`net/rsync`, `emulators/freerdp`, `security/openssh-portable`, `net-mgmt/collectd5`,
`databases/rrdtool`, `net-mgmt/net-snmp`, `ftp/curl`, `dns/powerdns-recursor` 等——逐 port
甄别"iX 私货 vs 纯版本落后"，真私货进本目录或 ports-extra。
