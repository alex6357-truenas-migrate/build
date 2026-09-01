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

## middleware（truenas/middleware）
- 状态：**审计进行中**（子代理 1 执行中/待结果回填）。

## py-bsd（truenas/py-bsd master）
- 状态：**审计进行中**。

## licenselib（truenas/licenselib master）
- 状态：**审计进行中**。

## iocage（iocage fork truenas/13.0-stable, d8b3d7e）
- 状态：**审计进行中**；默认决策=用上游 ports 的 sysutils/iocage，P5 落地。

## freenas-pkgtools
- 状态：**审计进行中**；pkgbase 决策下将作为 legacy 收缩/淘汰。

## ports fork（truenas/ports, 9461a3499b98, 13.3-stable）
- 状态：**盘点进行中**（子代理 4 执行中/待结果回填）；产出 fork-only ports 清单 → ports-extra，Mk/关键 port 修改 → patches/ports 或 REMOVED。

## freebsd-src / freebsd-ports（上游参考）
- 角色：ref；仅用于基线锚定，不进构建制品。
