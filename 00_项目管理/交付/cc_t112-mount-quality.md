# 交付：cc/t112-mount-quality

- 车道／工作者：T112 天启篇稀有坐骑显示品质（cc，Sonnet＋medium 起手，额度续接后 Opus 收尾）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·T112·未经审查】天启篇低档稀有坐骑显示品质提到不朽（dev.待定）

- 依据 D160（Kyo 11-16「可以」）。只改显示：`XQuality` 新增 `show_legacy`／`show_grade`／`rare_mount`，`grade_name`、`color_text`（连带 `label`、`list_color`）和说明卡边框（`help_card.gd` `show_for`）改按显示品质；`grade`／`legacy`、掉落门槛、词条档、排序、属性数据一律不动。
- 口径：天启篇规则开着（`XTianqiDrop.on()`）＋坐骑栏（etypeId 16）＋ T099 的低档稀有装备（`XTianqiDrop.rare_gear`：原版最高掉率低于 `generic.rare_below`、品质不高于 `table_cut_grade`）。全表扫下来正好三匹：

| 坐骑 | id | 原品质（数据） | 天启篇显示 | 原版掉落 |
| --- | --- | --- | --- | --- |
| 光明独角兽 | 7997 | 普通（旧档 1） | 不朽（旧档 8） | 剑道争锋巅峰首领 1/700 |
| 嘶风逐日驹 | 7998 | 普通（旧档 1） | 不朽（旧档 8） | 剑道争锋巅峰首领 1/500 |
| 白马·洪荒 | 4483 | 普通（旧档 1） | 不朽（旧档 8） | 1/10000 |

- 为什么定「不朽」：同系的嘶风逐日驹·洪荒（1/1000）和 4473 号嘶风逐日驹都是不朽；全部装备里不朽档的掉率中位数约 1/500，三匹的掉率落在这一档或更稀。
- 西游档（没开天启篇规则）照数据显示「普通」；别的坐骑（如 4472 普通、4473 不朽）不变。
- 回退：`XQuality.RARE_SHOW = false` 回到数据原品质；`XTianqiDrop.RARE_KEEP = false` 时 `rare_gear` 也不认，显示同样回原样。
- 测试：`xiyou_tianqi_drop` 新增 `show_affected_exact`（全表只这三匹）、`show_names_tianqi`、`show_color_tianqi`、`show_window_skin`、`show_bag_instance`、`show_logic_grade_unchanged`、`show_stats_unchanged`（记录原样、属性不变）、`show_not_other_mounts`、`show_xiyou_unchanged`、`show_switch_off_restores`；原 `rare_mount_label_original` 断言（天启篇显示普通）按 D160 改掉。102/102 过。
- 截图工具 `tests/tianqi_mount_quality_shots.tscn`（不是专项，要真窗口、`--audio-driver Dummy`）：[天启篇](cc_t112-mount-quality_shots/天启篇_详情页与获得提示.png)详情页、获得提示都是不朽金色；[西游档](cc_t112-mount-quality_shots/西游档_详情页与获得提示.png)照旧普通白色。
- 玩家可见：天启篇里光明独角兽、嘶风逐日驹、白马·洪荒的品质显示为「不朽」（名字颜色、说明卡边框、获得提示跟着变），属性不变。

## 交接板

- 下一步：无
- 用户试玩说明：天启篇拿到光明独角兽／嘶风逐日驹／白马·洪荒，说明卡和获得提示显示「不朽」金色
- 需要用户决定：无

## 进度账

- 无（天启篇显示调整，不计进度）

## 我不同意的地方

- 无大异议。只提一句：显示是「不朽」但掉落门槛、法宝喂养、自动卖等仍按数据里的「普通」算（派单要求不动逻辑）。比如挂机「屏蔽掉落」门槛设在精良以上时，这三匹仍会被当低档自动卖钱——它们本来就只在原首领表、掉率极低，实际影响小；要不要让逻辑也跟显示走，留给 Kyo 以后定。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- fab605c20 T112：天启篇低档稀有坐骑显示品质提到不朽（XQuality.show_*，RARE_SHOW 可回退）
- （本提交）截图重排、全表受影响断言、交付单
