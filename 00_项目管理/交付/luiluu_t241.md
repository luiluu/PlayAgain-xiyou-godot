# 交付：luiluu/t241

- 车道／工作者：T241 骑士血量临时系数 U 改整数百分比（cc，Sonnet＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-19 【cc·T241·未经审查】骑士血量临时系数 U 改整数百分比，先填 100（D222 丙）（dev.待定）

- U 原是 1 附近的小数倍率；改成整数百分比：骑士血量×U÷100，向零取整（整数运算），100＝不打折，6＝6%。`balance_table.json` 的 `combat_rules.boss_hp_temp_unit` 的 `crit`／`no_crit` 默认 `100`；代码在 `XTianqiBase.boss_hp_unit`（返回 int）和新增 `XTianqiBase.apply_hp_unit`，`XTianqiHorsemen.stats`／`shadow_stats` 走它。注释写明 M5 实机标定骑士血量后删。
- 旧的 1.43（3 强 1 弱量法，T227 发现 3）已不在表里；表里原值是 1，本单只换写法。
- 专项：`xiyou_tianqi_phase4`（115/115）加 U=100 血量等于原稿、U=6 时为 6%（本体、影子）；`xiyou_tianqi_horsemen` 96/96。西游档（总开关关着）仍读 100，不变。

## 交接板

- 下一步：无
- 用户试玩说明：无（默认 100，不改任何血量）
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log
