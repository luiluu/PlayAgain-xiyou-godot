# 交付：claude/wukong-hp-cost

- 车道／工作者：C 规则（暂由 A 车道接）／悟空（Claude）
- 基线：从 claude/wukong-battle-gaps 末提交 8816923d 切出（总装要求）；交付前已合 main（含已合并的 battle-gaps）。
- 状态：可合并

## 变更记录草稿

## 2026-10-31 【Claude·悟空·未经Codex检验】技能 HP 费用、蚀术命中判定（dev.待定）

- **技能 HP 费用（YEP_SkillCore，上期交付单记的缺口）**：15 个技能写了 `<HP Cost: n>`／`<HP Cost: n%>`（834、2358 破血狂攻、3913～3929 搏命、4780、5633、5635、5637、5757、5763、6037、7471 天照；上期写的 17 个多算了 5724、9944 两条 MP／TP 备注），重制原来不收。现在：
  - `XBattleLogic.note_costs` 同一套正则多认 HP；`skill_hp_cost`＝⌊基础＋最大HP×比例⌋、不低于 0（YEP_SkillMasteryLevels 的 HP 费用公式是原样、费用为正时至少 1，等于不变）。
  - `can_use`：canPaySkillCost 先看 HP（`can_pay_hp`：费用 0 能付，否则生命要**大于**费用），再看 MP／TP。
  - 付费：MP、TP 之后直接减生命（paySkillHpCost 是 `_hp -= 费用`，不走伤害；`pay_hp`），地图上用技能（技能页）同样扣。
  - 异化（installAlienationAdvanced Adv:126-128）：空壳在战斗中按开场参照生命上限算费用、看护盾够不够、从护盾扣；嫁祸看活着的保护者生命、由保护者付；连命看生命池、从池扣（`XAlienBattle.hp_cost_mhp`／`can_pay_hp`／`pay_hp`）。
  - 显示：战斗技能窗与技能页照 YEP drawHpCost 在 TP、MP 左边加「nHP」（文字色 18、图标 1266）。说明卡原版不显示 HP 费用，不加。
  - 智能 AI（Codex_SmartBattleAI costMultiplier）：费用倍率加 1.5×HP 费用÷当前生命，付完剩不到 25% 生命再 +4、不到 50% +1.6。
- **蚀术命中判定（审查第 2 期 D2／P3）**：`apply` 里的 `used` 原来是「目标活着或技能对阵亡友方」，改成原版 testApply：`(scope 为 9／10) == 目标已阵亡`。复活类技能打活目标不算命中、蚀术不封印。正常战斗选目标时 scope 9／10 只会选到阵亡友方，所以这处只在直接 apply 时有差别。
- **参照**：
  - `mv_oracle/battle_gaps_probe.cjs` 加 15 例 `hp.*`（角色 1 生命上限加 5000；费用、生命为满／等于费用／费用＋1 时 canPaySkillCost、满血付费后的生命），共 237 例，`tests/fixtures/battle_gaps_oracle.json` 已更新。
  - `mv_oracle/alien_affix_probe.cjs`（同步探针）加 4 例：`battle.hollow.hpcost`（护盾够／护盾 1 时不能用、硬用扣到 0）、`battle.lifelink.hpcost`、`battle.scapegoat.hpcost`（都用搏命 3913）、`battle.erosion.used`（新步骤 `apply`：直接对活着的 e0 apply 选定的 1924，临时把 scope 改成 9 时不封印，照旧时封印 1926 并封自己的 1924）。
- **专项**：`xiyou_battle_gaps` 加 HP 费用比对（952 项）；`xiyou_alien_affix` 支持 `apply` 步骤，HP 费用用例另比能否使用（2079 项）。

## 交接板

- 下一步：无新增。
- 用户试玩说明：破血狂攻、搏命、天照等写了生命消耗的技能，现在会扣生命，生命不够（不大于消耗）时用不了；技能列表里显示「nHP」。异化空壳从护盾扣、连命从生命池扣、嫁祸由保护者付。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| （无） | | | | | | | |

本期没有新 O 号。

## 进度账

- 战斗规则：补技能 HP 费用一项，完成度不变（量小）。

## 下期清单

- 谷雨按最大 MP 比例收费（installCombatPowerRuntime 的 `CFG.mp`：⌈mmp×比例×mcr⌉ 再吃通用减耗，第 5 节下限同样适用）没移植，谷雨上线时一起做。
- 生命心钢（installNativeHeartsteelRuntime）算生命上限的副本 paramMax(0)＝∞，心钢上线时要绕开 99999999 上限（XActor.param_max）。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 参照：`battle_gaps_probe` 237 例、`alien_affix_probe` 60 例，都无报错（正式冻结 v0.28）。
- 同步：合 main 后 `同步正式西游.py --accept-additions` 退出码 0，「新增用例，已接受」（alien_affix.json 56→60，新用例放在末尾；同时带进 main 的 star_warehouse.json）。
- 专项：`xiyou_battle_gaps` 952/952，`xiyou_alien_affix` 2117/2117。反向验证：生命等于费用也算能付 937/952；不扣生命 937/952；used 改回旧写法 2116/2117（battle.erosion.used.1 多封印）；异化 HP 费用照普通角色处理 2070/2079（空壳 hpcost 三项等）；复原后全过。
- 选测：云端被挡（Actions 额度用完，job 未启动），改在本机 `检查.sh --affected main`：169 个 Godot 场景与工具回归全部通过，8241 秒（期间等其他车道占的槽）。同源检查选中但没加 --oracle、未跑（合并时带 --oracle）。
- 改动的原沙僧核心文件（请审查重点看）：`battle_logic.gd`（`note_costs` 认 HP、`skill_hp_cost`／`can_pay_hp`／`pay_hp`、`can_use`、行动付费、`apply` 的 `used`）。另改 `alien_battle.gd`（`hp_cost_mhp`／`can_pay_hp`／`pay_hp`）、`smart_ai.gd`（`cost_multiplier`）、`battle_scene.gd`、`ui/skill_scene.gd`。没碰白龙的渡鸦钩子。

## 本分支提交

- d24b8112 技能 HP 费用、蚀术命中判定、参照与专项
- 合并 main（bbacb4fa，alien_affix_probe 冲突：main 的 flare.gain 用例在前、本期用例在后）
- （本提交）交付单可合并
