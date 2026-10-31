# 交付：cc/bailong-raven3b

- 车道／工作者：E 角色专属／白龙_8（cc，项目线程「完成再刷西游Godot引擎重制」，接白龙_7）
- 状态：选测在跑（跑完改「可合并」）

## 变更记录草稿

## 2026-10-31 【cc·白龙_8·未经审查】渡鸦第三期：神话形态、残响与狩猎、收割与回响（dev.待定）

照原版 installNativeRavenRuntime.js 的战斗包装（isMyth／mythPower 第 100～101 行，defenseFactor 第 161～167 行，setupRaven 第 503～528 行，
gainSoulFrom 与 Game_Enemy.die 第 954～976 行，Game_Action.apply 第 993～1032 行，numRepeats 第 1036～1044 行，directDamage／endAction 第 1051～1073 行，
startTurn／endTurn／endBattle 第 1074～1095 行，伤害钩子 raven 第 1117～1127 行），重制 `XRaven` 第三期：

1. **神话形态**（存在 `XState.raven.myth`，只在战斗内，不存档）：`_invoke` 普通 apply 之后 `XRaven.applied`——<CodexRavenMyth> 的神话封解 10127、学了它、不在形态中 → 3 回合（原版不看命中）。回合结束减一；敌人倒下得魂时不到 5 回合加一；结束战斗、`sync`（setupRaven：升级、进阶、招募）清零。神话之力＝形态中且学了神话余响 10170：伤害钩子的普通／黑暗伤害各 +1、最终伤害 +1.5，魔防穿透 +5%（封顶 95%）。
2. **死亡残响 10132／三羽成环 10133**（`XState.raven.residue`／`hunter`，存档 codexRaven，旧档没有＝0／否）：学了 10132 时得魂后残响 +1（最多 3）；`start_turn` 清「本回合有敌人倒下」、`on_enemy_death` 置位，`end_turn`（米拉之内、宠物捕捉之外）时渡鸦在出战成员里、本回合没有敌人倒下就再 +1；学了 10133 且残响满 3 进入狩猎。`sync` 时没学 10132 清残响、没学 10133 清狩猎。
3. **收割与回响**（`act`／强制行动在黑闪收尾之后、种族收尾之前调 `XRaven.finish`，即各专属模块 endAction 包装的最里层）：<CodexRavenDamage> 技能按目标累计本次行动的实际 HP 伤害（多段、全体逐目标）；狩猎中先清狩猎与残响，对存活目标直接扣累计 ×1（神话之力 ×1.5，冥界收割）；神话之力时对仍存活的目标再扣 ×0.85（回响）。直接扣血是 gainHp，不经伤害计算，记录里 `type: regen`、`raven: harvest／echo`，倒下照常得魂（残响从 0 加回 1、神话续期）。
4. **apply 包装其余两项**：渡魂鸦啄 10122 每次施放第一次命中回 floor(2% 最大 MP)（至少 1）；亡者盛宴 10124／万魂归鸦 10126 命中时，学了夜蚀余烬 10134 直接附加黑暗侵蚀 1663，否则二阶的盛宴按普通附加状态（效果 21）附加。
5. **numRepeats**：冥羽连葬 10123 加 floor(额外攻击次数)，包在黄泉 numRepeats 包装里层；10123 运行时 repeats 为 1、行动序列两段，所以额外次数 N 时打 2×(1＋N) 段（参照证实）。
- 不移植：魔法反射时原版同一行动对渡鸦自己累计伤害、行动结束对自己追加（重制反射支不记帧，罕见）；神话形态战斗图 Raven_Mythic_SV、R.Fx 特效、受击动作替换；技能说明的灵魂进度行、技能分类与指令窗、法宝 4001 运行时字段、熟练度上限、商店／掉率／图鉴、旧档迁移（派单写明不做）。
- 参照：新探针 `mv_oracle/raven_battle_probe.cjs`（真实 BattleManager／Game_Action，Math.random 0.5）29 例：模块 1、神话形态 2、神话之力伤害 2、残响 5、收割／回响 8、鸦啄回 MP 1、黑暗侵蚀 6、冥羽连葬再动 4。产物拷成 `tests/fixtures/raven_battle_oracle.json`，**不接全量同步**。
- 专项 `tests/xiyou_raven_battle`（356 项）：每次施放的扣血段（命中段、直接扣血）逐条比目标与次序，数值比本例第一段命中的比值（1e-6）；每步后的神话回合、残响、狩猎、灵魂、MP、敌人倒下与侵蚀逐项比；另核残响／狩猎存档往返、旧档。测试的规则流整数照 Math.randomInt 取中点（原来返回原始 uint 时伤害浮动随数量级乱跳，比值对不上）。
- 米拉 G3（审查第 11 期提醒）：`tests/xiyou_mira_battle` 加 `otb.second_slot`——米拉带「再次行动」44 有两个行动位，第一个放解放·黑龙，同回合第二个行动位照常普通攻击（只在重制；原版解放后的 clearActions 在 OTB 下不影响后面的行动位，按读码）。

## 优化登记草稿

优化登记草稿：无（本期没有改原版行为的地方）。

## 验证

- 专项 xiyou_raven_battle 356/356、xiyou_mira_battle 287/287（本机单跑）。
- 反向验证三轮，都已还原：①收割不乘 1.5、回合结束不加残响、冥羽连葬不加次数、神话之力不进伤害钩子、得魂不续期一起改，45 项失败；②收割倍率、连葬次数、夜蚀余烬不附加侵蚀、鸦啄不回 MP，56 项失败；③只改收割倍率与连葬次数，11 项失败（hunt.* 8、repeats.* 3）。
- 相关战斗选测（本机，照 garou3 的 24 个场景口径加 xiyou_raven_battle，共 25 个）：在跑。
- 没改切片、转换器、全量同步里的探针、界面，没跑同步与事件对照。分支从 main 3226cc85（已含 garou3 合并）切出，main 之后没有新提交，未再合。

## 交接板

- 下一步：渡鸦剩画面与养成——神话形态战斗图 Raven_Mythic_SV（`XRaven.is_myth` 已有）、收割／回响的战斗日志与特效（记录带 `raven` 标记）、技能说明的灵魂进度行、技能分类 [2,1,5,3]／菜单 [2,1,5,3,4] 与指令窗、法宝 4001 每级成长与等级上限、熟练度上限（变量 8）、掉率与图鉴、商店价格字段；逻辑层只剩魔法反射时的自身追加（罕见，可不做）。
- 用户试玩说明：五阶渡鸦放「神话封解」进入神话形态 3 回合（每倒一个敌人加一回合，最多 5），形态中专属魔法更疼，每次出手还追加一记 85% 的回响；残响攒满 3 层（敌人倒下或安静的回合各加一层）后，下一次专属魔法会额外收割一次本次伤害。
- 需要用户决定：无。

## 进度账

- 角色与专属机制：渡鸦 1135 行完成度 0.55 → 0.7（战斗内机制做完，约 165 行；剩画面、菜单与养成），角色约 +1.0 个百分点（1135×0.15÷8817×50≈0.97）。按行数估，不是测量值。

## 可优化（流程／工具／效率）

- 建议（工具，归哪吒）：并行测试按前缀选测时，`xiyou_battle`、`xiyou_rules` 这类短名会扩成 9／23 个场景，车道照别人交付单抄场景名很容易一下排进 50 多个。可让 `--names-file` 默认按全名匹配、前缀要显式写 `xiyou_rules*`，或超过 40 个时先停下提示。
- 建议（测试，各角色车道）：多处战斗专项的 FixedStream 整数取原始 uint 2147483648，伤害浮动 next_int_inclusive 得到的是 2^31 对 (幅度＋1) 的余数，随伤害数量级乱跳；比值比对时会冒出几个百分点的假差。本期在 xiyou_raven_battle 里改成 floor(n×0.5)（同 Math.randomInt），别的专项要比伤害比值时可照抄。

## 待交叉核查

- 原 Codex 核心文件：改了 `modes/xiyou/battle/battle_logic.gd`——`start_turn` 开头加 `XRaven.start_turn()`；`act` 在黑闪收尾之后、`_force_action` 在宿傩收尾之后各加 `XRaven.finish`；`end_turn` 在米拉之后加 `XRaven.end_turn`；`execute` 在 `XGarou.begin` 之后加 `XRaven.begin`；两处 `XYomiJingliu.begin_action(...)` 的参数里包一层 `XRaven.repeats`（改了已有两行，不是新增）；`_invoke` 普通 apply 之后加 `XRaven.applied`；`end_battle` 加 `XRaven.end_battle`。没碰 note_costs、经验奖励、防御 TP（悟空 gaps2）与甚尔（八戒 toji1）。
- 共用挂点：`actor_damage_hooks.gd` 没改（渡鸦的帧操作本来就在 capture 里，神话之力改在 `XRaven.damage_ops` 内）。
- 存档：codexRaven 多了 residue、hunter 两个键（`XRaven.to_save／from_save`）。

## 本分支提交

- 87c123be 参照探针 raven_battle_probe 与夹具
- 94653997 XRaven 战斗内机制与专项
- ea808a73 专项 356/356、米拉 G3 测试
- 951ed6a4 补 xiyou_raven_battle.gd.uid
