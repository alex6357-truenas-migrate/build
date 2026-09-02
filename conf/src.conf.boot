# src.conf.boot — 安装器（instufs.iso）目标 = build + run 之上的 紧凑裁剪
# 合理 WITHOUT_* 全部在 15.1 src.opts.mk 行为合法。

WITHOUT_BHYVE=yes
WITHOUT_DICT=yes
WITHOUT_EXAMPLES=yes
WITHOUT_ICONV=yes
WITHOUT_INETD=yes
WITHOUT_JAIL=yes
WITHOUT_KDUMP=yes
WITHOUT_LOCALES=yes
WITHOUT_LPR=yes
WITHOUT_MAIL=yes
WITHOUT_PMC=yes
WITHOUT_MAN=yes
WITHOUT_MAKE=yes
# 备注： 有没有 WITHOUT_INET6 —— 装器在成 IP 的前提下自启动就可，不需 INET6
# （如果你施工时要禁用 INET6，从 run 别加

# 15.1 已删除（勿再写）：WITHOUT_CALENDAR / DEBUG_FILES / GROFF / NIS / NLS / VT / PROFILE
