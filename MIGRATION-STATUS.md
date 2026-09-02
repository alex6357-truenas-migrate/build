# TrueNAS Core 15.1 Migration — Status Document

最后更新：推送全部仓库至 `github.com/alex6357-truenas-migrate` 之后（VM 构建测试前）。
本文档记录迁移的完整状态，供后台恢复 / 他人接手使用。

## 0. 一句话状态

构建系统（bmake+POSIX sh+poudriere，pkgbase）已就绪、src 15.1 补丁已 rebase
并全部应用验证、2026Q3 ports 列表已对齐；**尚未在 FreeBSD 15.1 机器上跑过一次
完整构建**（缺构建机，VM 由用户创建中）。middleware 的 15.1 适配（pkgbase 替换
freenasOS）刚开始，是下一阶段主线。

## 1. 组织架构与分支约定

- 所有 fork 仓库在 GitHub org：`alex6357-truenas-migrate`
- 全部工作分支统一为 `main`（以后只跟 FreeBSD 前沿）
- middleware 额外保留 `truenas/15.1-stable`（= main + 15.1 适配提交）
- 上游跟踪原则：**TrueNAS 还会维护的追 truenas；TrueNAS 不再维护的
  core-only 追 freecore-project**（Codeberg 开发 / GitHub 镜像）；freecore
  有完整之处（如 middleware ports 依赖修复）可参考
- 已删除：`freenas-pkgtools`、`freenas-migrate93`、`freenas-migrate113`、
  `core-build`、`scanlnk`、`zfs` fork、`libhyve-remote`、`py-bhyve`

## 2. 仓库清单（已推送 SHA，main 分支）

| 仓库（nas-build/） | HEAD SHA | 说明 |
|---|---|---|
| build | f3365bffd589610d0786e1598563bbc6e2d36ea0 | 新建构建系统；本次新建 org 仓库并推送 |
| middleware | 73161e946622fadfc2148ba57019a7fac5a3962e（truenas/15.1-stable） | 见 §4 |
| py-bsd | 903f806f29d2cd0fd1b7e81301df6687e0924289 | +2 commits：去 dialog.pyx 等；de-six+pyproject，defs.pxd typo 修复 |
| py-libzfs | faa4cbf5405876e7590ffa1ef9aed32c16f994e7 | master pin；ZFS_ITER_* IF 编译期守卫使其兼容 OpenZFS 2.4 |
| iocage | d8b3d7e11256db59a98c588259eec5637ec92123 | 保留 fork（tarfile 修复），长期要上游化 |
| py-cam | 91f9b783e3e34e9370b3349e26c7e572b487c575 | 无修改，仅 main 化 |
| py-netif | 9298aa968e24c423caa35d2ea4f960d487f1bf10 | 无修改，仅 main 化 |
| py-zettarepl | 60ade6005d79771ffc0b3922d376a590f8602484 | repos.conf 固定 pin；paramiko 4 修复走 port files/patch |
| licenselib | 8d5441c2f927ceb224c70ee53c06ef13f14ed6ea | 保留（truenas-only 校验绑定） |
| samba | e7df0a31a95db824642546bb32ad73b25fcc660a | 保留 fork（v4-19 系）；CVE 回移审查 4.19.6→4.19.9 待办 |
| midcli | dd02941216f02402a1fafefe0602abe6ddcec813 | 无修改，仅 main 化 |
| truecommand-stats | 382928ff0308e206ce95174f6af64f196d135f72 | 无修改，仅 main 化 |
| webui | 5b25fbff2c7e7cc62a5a6b75f4c5e605c5a6a805 | P4 过渡：预构建 dist（见 §4 webui-dist） |
| webui-ng | 0f5dd7a249c537b55e5fb8ee291c2ba58e1a2bc9 | SvelteKit 重写 WIP（P5），本次建 repo 保存快照 |

本地（F:\zvault 根）上游只读参考：freebsd-src、freebsd-ports、truenas/os、
truenas/ports、iocage-ix-plugins。`F:\zvault\nas-build\src15` 是
freebsd-src 的测试 worktree（origin 指 git.freebsd.org，**不要推送**），
分支 truenas/15.1-patches 上应用了 12 个补丁，仅作验证用。

## 3. 构建系统（build 仓库，本仓库）现状

- `Makefile` + `mk/{common,repos,patches,world,ports,packages,images}.mk` +
  `sh/{repo-sync,repo-manifest,apply-patches,ports-merge,webui-dist-pack}.sh`
- 目标：`setup` → `patches` → `world`/`kernel` → `ports` → `packages` →
  `images` → `release`；另有 `clean`/`distclean`
- `repos.conf`：双解析（sh source-able）manifest，`REPO_<NAME>="<url> <branch|sha> <subdir> <role>"`；
  role=build/pkg/ref；从 `BUILD_ROOT/../<subdir>` 本地 clone 后改写 origin
  - REPO_SRC 固定 releng/15.1 = `aadd58dddcbc`
  - REPO_PORTS 固定 2026Q3 = `d870b633c555cfe87437686a0f0b5ca202fbb74b`
- `conf/freebsd.mk`：版本锚点 FREEBSD_BRANCH=releng/15.1、
  FREEBSD_REL_VER=15.1-RELEASE、PORTS_QUARTER=2026Q3（追新时只改这里 + pins）
- `conf/src.conf.{build,run,boot}`：已对照 15.1 `src.opts.mk`（158 个合法
  WITHOUT_*）审计，dead options 全清；`WITH_OPENSSH_NONE_CIPHER` 旋钮已删；
  `CFLAGS+=-DNS_REREAD_CONF` 保留；`WITHOUT_ZFS` 移除（用 base ZFS 2.4.2），
  world.mk 把 zfs 加进 KERN_MODULES
- `conf/ports.list`：已对齐 2026Q3 实际（e2fsprogs/fusefs-*/mtools →
  filesystems/；novnc-websockify → devel/py-websockify；删 gio-fam-backend、
  ipfs-go、samba-nsupdate；net/py-wsdd 用上游）
- `patches/src/`：12 个 mbox 补丁，已 rebase 到 releng/15.1 `aadd58dddcbc`；
  apply 脚本自动分辨 git-am / git-apply；`REMOVED.md` 记录被收掉的补丁
- `ports-extra/`：freenas/*（freenas-files、freenas-installer、py-bsd、
  py-licenselib、py-middlewared、py-midcli、arcsas、firmware、pipewatcher、
  swagger-ui、tc-stats、webui-dist）+ truenas/py-fenced +
  fork-only 原件约 30 个（已从 ports fork 挑选，详见 ports-merge.sh / 目录）

## 4. 关键决策记录

1. **pkgbase 取代 freenas-pkgtools**（更新走 `make packages` + `pkg repo`）
2. **ZFS：用 15.1 base OpenZFS 2.4.2**，放弃 truenas zfs fork
3. **iocage 保留 fork**（d8b3d7e），subprocess/CLI 调用面在 15.1 稳定
4. **wsdd/serm/sedutil**：wsdd 用上 游 port；sedutil 倾向 `security/sedutil`
   （**待定**：ports-extra 里 sedutil 副本指向 amotin fork，去留 Build 前定）
5. **webui P4 = 预构建 dist**：新增 shell port `freenas/webui-dist`
   （no-build，安装到 /usr/local/www/webui），不走 legacy node6 构建链；
   dist tarball 需先用 `sh/webui-dist-pack.sh`（node16/docker）产出
6. **middleware 分支策略 A**：保留 truenas/13.3-stable 血统改名为 main，
   在 `truenas/15.1-stable` 上做 15.1 补丁；日后大版本再 rebase

## 5. 已验证结论（analysis 依据在 F:\zvault\_scratch\*.md）

- Cython pxd 是声明性绑定：field 访问由真实头文件解析，defs.pxd 布局过时
  除非被实际访问否则无害
- py-libzfs master(faa4cbf) 的 `IF HAVE_ZFS_ITER_*` 编译期守卫 → 兼容
  OpenZFS 2.4（参见 compat-pylibzfs.md）
- truenas/os fork：fork-base deb948cd8dc2，61 own commits / 52 文件，~45 未回过
  上游（ixnvdimm、bhyve vncserver、rc 补丁 300/700、memmove、
  AT_UTIMENSAT_BTIME=patch 420 等）
- ports fork：merge-base 985bb512c990，1840 fork-only commits，92 added port dirs，
  保留 ~30 进 ports-extra
- freecore samba delta 缺 vfs_truenas_audit/tmprotect/shadow_copy_zfs 最终态；
  freecore 还在用 freenas-pkgtools
- samba fork vs 上游：见 compat-samba-fork.md；4.19.6→4.19.9 CVE 回移待审

## 6. 待办（VM 构建测试前 / 中优先级顺序）

### P3-M2 middleware pkgbase 化（下一阶段主线，未动工的实质代码）
- [ ] `update_*` plugins + `alert/source/update.py` + `utils/osc/freebsd/app.py`
      + alembic env + pytest helpers：freenasOS import 全部换成 pkg 实现
      （替换规格表已拟出但**还没写成文档/代码**；freenasOS 触及面：
      install_freebsd.py、download_freebsd.py、pending_freebsd.py、
      trains_freebsd.py 已盘点）
- [ ] bootenv 插件 beadm → bectl
- [ ] py-middlewared port：USE_PYTHON distutils → pep517；BUILD_DEPENDS
      fastentrypoints 删掉（py3.12 不兼容）
- [ ] **复核 grub2 分类改名**：py-middlewared port 里 grub2/x86_64-efi 改成
      filesystems/ 可能是错误 rename（上游 ports 无 filesystems/grub2；
      正确名在 ports-extra / sysutils）—构建前必须核对

### 构建前一批
- [ ] webui-dist 工件：跑 `sh/webui-dist-pack.sh` 产出 dist tarball + distinfo
- [ ] freenas-installer install.sh L1068 `freenas-install` → pkg-static -r 改写
- [ ] sedutil port 去留决策
- [ ] iocage fork 长期上游化（不阻塞）

### 验证
- [ ] 在 VM 上跑 `make setup patches release` 全链路（pkgbase world/kernel +
      poudriere ports + pkg repo + installer 镜像）
- [ ] 装出来开机后 middlewared 启动、webui、磁盘/zfs/jail/更新流程冒烟

## 7. 恢复指引（从任意新环境接手）

```sh
# 1. 克隆构建仓库（TrueNAS build root）
git clone https://github.com/alex6357-truenas-migrate/build.git nas-build/build
cd nas-build
# 2. 按 build/repos.conf 里的 REPO_* 拉取 pkg 仓库（均已 main 化）
for r in middleware py-bsd py-libzfs py-netif py-cam py-zettarepl iocage \
         samba licenselib midcli truecommand-stats webui; do
  git clone https://github.com/alex6357-truenas-migrate/$r.git
done
# 3. FreeBSD 15.1 构建机（VM）上：
cd build && make setup            # clone/seed src+ports
make patches                      # 12 个 src 补丁
make release                      # world/kernel pkgbase + poudriere + 镜像
```

- 版本锚点：改 `conf/freebsd.mk` + `repos.conf` 两个 pin 即可追下一版
- 本地 scratch 报告（F:\zvault\_scratch\compat-*.md 等 9 份）**不在任何 git
  仓库里**，若机器损毁需重做分析（关键结论已浓缩进本文 §5）

## 8. 已知风险

- middleware pkgbase 替换是最大未完成块；freenasOS 的 trains/update 语义
  在 pkgbase 下没有直接对应，需要设计
- freenas-installer 与 pkgbase 交界（install.sh 重写）未验证
- src 补丁只做过 apply/编译前置验证，未在完整 world build 中验证过
- webui 预构建 dist 链路（node16 环境）未跑
- samba v4-19 系 CVE 状况落后于上游 4.19.9
