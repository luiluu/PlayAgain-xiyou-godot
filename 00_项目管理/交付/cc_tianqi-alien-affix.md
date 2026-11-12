# 交付：cc/tianqi-alien-affix

- 车道／工作者：天启篇·四条本线新异化词条的战斗效果（临终、再动、节俭、带毒）／cc（项目线程「完成再刷西游 Godot 引擎重制」）
- 状态：可合并

## 依赖与合并顺序

- 基于 cc/tianqi-affix-battle（词条战斗，接线在 `core/tianqi_affix_battle.gd`）并合了 cc/tianqi-alien-gear（异化装备）。**请先合这两条，再合本分支**；本分支里带着的那两张交付单（`cc_tianqi-affix-battle.md`、`cc_tianqi-alien-gear.md`）在它们合进 main 后就是 main 已删的文件，合本分支前先 `git merge main` 即可消掉。
- 本分支自己的改动：新模块 `core/tianqi_alien_affix.gd`；`core/tianqi_affix_battle.gd` 八处各一行转调（`param_rate`、`damage_ops`、`cost` 改成「原函数改名 `_xxx`＋外层乘上新模块」）；`battle/battle_logic.gd` 三行；`alien_gear.json` 加 `effects`、新词条说明带数；`tianqi_alien_gear.gd` 详情只在开关关着时写「未生效」。

## 变更记录草稿

## 2026-11-12 【cc·天启篇·未经审查】天启篇四条本线新异化词条接上战斗效果：临终、再动、节俭、带毒（dev.待定）

- 按设计仓库《天启篇序章_四线异化与异化装备重构 v0.8》第 4.2 节（★ 本线新词条）。只认天启篇存档（`XTianqiAffixBattle.on`），装备得是天启篇异化装备（`XTianqiAlienGear.tq`），战斗里认开战时冻结的那件（`XAlienation.for_actor`，和原版异化一样一人只认一件）。
- 新模块 `core/tianqi_alien_affix.gd`（XTianqiAlienAffix，开关 `ENABLED`），数在 `tianqi_data/alien_gear.json` 的 `effects`（四级先不分档，数值阶段再定）：
  - 临终（死亡）：受到致命伤害时这一下留 1 点生命，本回合里再挨打也不倒，攻击、魔攻 +50%（`param_rate`）；本回合结束时必死；每场一次。
  - 再动（战争）：第 3、6、9…回合多行动一次（`action_plus_set` 追加必定的一次）；受到的伤害 +25%。
  - 节俭（饥荒）：技能消耗 −33%（在别的减耗之后再乘）；受到的回复 −33%。设计稿是 40%，避开 4 写 33。
  - 带毒（瘟疫）：攻击打中敌人时附加原版状态「中毒」（敌人抵抗就不上）；自己开战时、每回合结束时没毒就挂上。
- 接线：`XTianqiAffixBattle` 的 `start`、`finish`、`param_rate`、`damage_ops`、`cost`、`action_plus_set`、`after_apply`、`end_turn` 各转调一处；`BattleLogic.execute_hp_damage` 一行（临终，七印灰印免死之后），行动结束和回合结束各一行取临终的战斗日志。
- 新专项 `tests/xiyou_tianqi_alien_affix`（24 项）；`xiyou_tianqi_alien_gear` 那条「新词条详情写未生效」改成「效果开着时不写」。
- 玩家可见：开发版天启篇存档里，穿着临终、再动、节俭、带毒异化装备的人战斗里有对应效果；发行版看不到（天启篇关着）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/tianqi_alien_affix.gd` `XTianqiAlienAffix.ENABLED`；`core/tianqi_affix_battle.gd` 八处转调、`battle/battle_logic.gd` 三行 | 原版没有这四条异化词条 | 天启篇异化装备的临终、再动、节俭、带毒在战斗里生效 | Kyo 11-08 定每线 4 条（v0.8 第 4.2 节），本线新词条各 1 条 | `XTianqiAlienAffix.ENABLED = false`：四条新词条没有战斗效果，装备详情写「未生效」 | cc | 已接受（Kyo 11-11 优化直接接受） |

## 交接板

- 下一步：四级数值分档（四条新词条和原 12 条都还是一档）；配置太重的词条装备时弹配置窗（v0.8 第 4.3 节）。
- 用户试玩说明：开发版天启篇档，用异化工坊把本线的终焉异化核刻到一件装备上（或打到带新词条的异化装备），穿上进战斗：临终的人被打到致命时留 1 点血、回合结束倒下；再动的人第 3 回合动两次；节俭的人技能耗得少、吃药回得少；带毒的人一直中毒、打中的敌人也中毒。
- 需要用户决定：无（节俭 40%→33% 是避开 4 的测试参数）。

## 进度账

- 天启篇异化装备（扩展账）：新四条词条战斗效果 0 → 已接；四级数值分档、配置弹窗未做。不写主表。

## 可优化（流程／工具／效率）

- 无。

## 验证

- `xiyou_tianqi_alien_affix`：24/24。
- 相关专项（Mac，本工作树，`并行测试.py`，20 个场景，189 秒，全部通过）：`xiyou_tianqi_alien_affix`、`xiyou_tianqi_alien_gear`、`xiyou_tianqi_affix_battle`、`xiyou_alien_affix`、`xiyou_alien_battle`、`xiyou_alien_workshop`、`xiyou_determinism`、`xiyou_battle`、`xiyou_tianqi_qiyin_effects`、`xiyou_tianqi_horsemen_battle`、`xiyou_tianqi_war`、`xiyou_tianqi_famine`、`xiyou_tianqi_plague`、`xiyou_tianqi_death`、`xiyou_tianqi_rewards`、`xiyou_tianqi_party`、`xiyou_tianqi_qiyin_equip`、`xiyou_tianqi_qiyin_dragon_run`、`xiyou_rules`、`xiyou_battle_drop`。
- 没跑的：`battle_logic.gd` 判整轮；本单三行都只在天启篇存档、本场建了新模块数据时起作用（`plain_none`、开关 `off_*` 覆盖），其余请总装合并时按选测照常跑。
- 反向验证（`反向验证.py`，单跑本专项）：临终不留血、不限次、回合末不死、再动每回合、节俭不减回复、带毒不续毒、打不中也上毒，7 处全部咬住（前两版测试有两处没咬住，已补断言）。
- `语法检查.py`：通过。
- `交付自检.py`：提交后跑，见回报。

## 本分支提交

- 合并 cc/tianqi-alien-gear（异化装备，新词条效果要用）
- 天启篇新异化词条战斗效果：临终、再动、节俭、带毒；专项 xiyou_tianqi_alien_affix
- 补两条断言（反向验证）；交付单
