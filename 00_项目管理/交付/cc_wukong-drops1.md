# 交付：cc/wukong-drops1

- 车道／工作者：悟空（cc），战斗掉落与审查第 17 期两条 P3
- 基线：总装十派单，从 a0a4f4d9（raven4 末端）切出。battlelog3／raven4 进 main 后再按总装通知合一次 main。
- 状态：可合并

## 盘点

| 项 | 原版（冻结 v0.28） | 本期 |
| --- | --- | --- |
| 战斗里敌人的掉落 | 新探针 `battle_drop_probe` 实测：每件掉落概率＝dropItemRate／分母（夹到 1）。dropItemRate 被 EliteEnemy（插件表第 138 个）直接覆写成「双倍掉落 ? 1 : 0.2」×神话倍率，盖掉 dsPassiveSkill 与 GT_EquipSuitCore 的包装，再由 installNativeRavenRuntime 乘全队掉率（套装、出战 passiveIRUP 连乘、亡魂汲取 +1）。`<Enemy Drops>` 的 x% 在运行时并进 dropItems（分母 100/x），同一式。Vitsuno_Difficulty 的按序号掉率在原版整段注释掉了，难度 2 与 5 结果相同 | 做了：`XBattleLogic.drop_chances`，`_roll_drops` 改用它（随机数取法与次数不变）。**重制原来**按难度表「Drop Rate」（难度 2 为 3.0、5 以上 10.0）×(1＋出战 passiveIRUP 最大值)×套装算，没有 0.2 底、没有亡魂汲取，`<Enemy Drops>` 也照此放大 |
| 夹值层位置（审查 17 P3） | 小猫剑圣倍率在 installImportedBalanceRuntime（第 20 个），云裳包装（第 31 个，含云裳倍率、战斗内层、最后夹值）在它外面 | 改了：`XActor.param_before_alien` 改成 夹值(云裳战斗内层(云裳倍率(小猫剑圣(专属模块(原值)))))，`XActorModules.param` 去掉云裳那层。现在看不出差（小猫剑圣只管 178，云裳倍率只管 174，小猫剑圣自己也夹值），所以没法做反向；`xiyou_param_max`、`xiyou_cat`、`xiyou_yunshang` 照过 |
| 事件对照登记计数（审查 17 P3） | — | 用 `xiyou_event_compare -- --update-baseline` 重写：cases 5806／match 5803（合了 main 之后用例多了），不一致仍是那 3 例。重写会把手写的说明换成测试里写死的默认说明（只说 1 例），所以顺手改了测试：重写时保留登记里原有的说明 |

## 需要用户决定

- **战斗掉落会比现在少很多**：照原版后，普通敌人每件掉落概率是原来的「0.2×全队掉率」，不再乘难度倍率。难度 2 大约是原来的十几分之一，难度 5 以上差得更多。原版作者是有意注释掉难度掉率的（不像 O-130 经验金钱那样被插件次序吃掉），所以默认照原版、没做开关。如果 Kyo 想像 O-130 那样把难度掉率加回来，可以再做成可回退的 O 项（要先定按哪个序号的倍率乘，原版的 dropItemRateFromIndex 也一起注释掉了，没有现成写法）。

## 变更记录草稿

## 2026-11-01 【cc·悟空·未经审查】战斗掉落照原版、能力夹值层次序、事件对照登记计数（dev.待定）

- `battle/battle_logic.gd`：`drop_chances`（每件概率＝dropItemRate／分母，dropItemRate 用 `XAlienBattle.drop_item_rate`：0.2 底或双倍掉落 1、×神话、×全队掉率），`_roll_drops` 改用它；删掉不再用的 `_passive_sum`。难度不再影响掉落。
- `core/actor.gd` `param_before_alien`：小猫剑圣在里、云裳（倍率、战斗内层、夹值）在外，照原版装入次序；`core/actor_modules.gd` 的 `param` 去掉云裳那层。
- `tests/event_compare_baseline.json` 用 `--update-baseline` 重写计数；`tests/xiyou_event_compare.gd` 重写时保留原有说明。
- 新探针 `mv_oracle/battle_drop_probe.cjs`（登记进 PROBES，产物 battle_drop.json）与专项 `tests/xiyou_battle_drop`。

## 验证

- 探针 `battle_drop_probe.cjs` 6 例无错；`同步正式西游.py --accept-additions` 跑完「测量不变」（产物先手工放进 generated/oracle，同步核过一致），留了指纹。
- 选测 35 场景（CHECK_JOBS=3，宽前缀展开）全过、无偶发：`xiyou_battle_drop`（新）、`xiyou_drop_dh`、`xiyou_drop_record`、`xiyou_battle`／`xiyou_battle_*`（含 battle_gaps、battle_ui、battle_log 等 11 个）、`xiyou_cat`、`xiyou_param_max`、`xiyou_yunshang`、`xiyou_event_compare`、`xiyou_transfer`、`xiyou_enemy_book`、`xiyou_alien_battle`、`xiyou_troop_events`／`_b`～`_half`、`xiyou_zhenqi_daofa`、`xiyou_zhenqi_break`、`xiyou_actor_modules`、`xiyou_raven_artifact`、`xiyou_rules_d2`～`d2d`、`xiyou_toji`、`xiyou_toji_battle`（日志 `04_验证/本地结果/并行测试/20261101_065645__pxne1e9/`）。
- 反向：把 `drop_chances` 的 rate 改回乘难度倍率（÷0.2×难度 Drop Rate），`xiyou_battle_drop` 的 chances 全部失败（如敌人 1 难度 2：[1.0, 0.673, 0.067] 对参照 [0.449, 0.045, 0.004]），恢复后通过。夹值层次序没法反向（现在无可见差，见盘点）。
- `语法检查.py` 通过。

## 交接板

- 下一步：如果 Kyo 要难度掉率，另做 O 项（见上）。
- 用户试玩说明：战斗掉落照原版：基础 0.2 倍，神话敌人 ×5，套装、掉率被动、渡鸦亡魂汲取照原版加，难度不再影响掉率，比之前少很多。
- 需要用户决定：难度掉率要不要加回来（见上）。

## 进度账

- 战斗掉落：照原版完成，有参照。审查第 17 期两条 P3 已处理。

## 可优化（流程／工具／效率）

- 已做：`xiyou_event_compare --update-baseline` 不再把手写说明盖掉（回退：把 note 那行改回写死的字符串）。

## 本分支提交

- WIP：战斗掉落照原版、夹值层次序
- WIP：事件对照登记重写
- 交付单（本提交）
