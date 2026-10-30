# 交付：claude/bailong-exclusive2

- 车道／工作者：C 规则·机制（角色专属养成）／白龙_5（Claude）
- 状态：可合并
- 分支基于 claude/bailong-exclusive1 末端（期一交付单另有一张，随期一合并）。

## 变更记录草稿

## 2026-10-31 【Claude·白龙_5·未经审查】黄泉战斗收尾：必中、连击、残梦、集真赤与随机负面、扩散（dev.待定）

照原版 installNativeYomiJingliuRuntime 的 CodexYomi 战斗包装（第 193～335、436～441 行），重制 `XYomiJingliu` 第二期：

1. **必中**（itemHit／itemEva 包装）：黄泉 10171～10174 命中 1、闪避 0；只这两项，反击、魔法反射照常（原版就只包了这两个）。`XBattleLogic.item_hit／item_eva` 调 `XYomiJingliu.sure`。
2. **连击**（numRepeats 包装）：(10174 为 6，其余 2)＋min(6, floor(幸运/6666))，取代原次数；四个技能都走默认行动序列，次数体现为重复目标。`XBattleLogic.execute` 两条路径（有／无行动序列）各调一次 `begin_action`，同时开始新行动（清「已施印」）。
3. **残梦**：meetsSkillConditions 10174 要残梦≥9（`XBattleLogic.can_use`）；paySkillCost 10174 扣 9（放在异化缄默付得起之后，缄默是外层）；战斗结束清零（`end_battle`）。层数存在 `XYomiJingliu._dream`（按角色实例，只在战斗内用，不存档；原版存在角色上但每场结束清零）。
4. **集真赤与随机负面**（apply 包装，`XBattleLogic._invoke` 掩护之后、目标是活着的敌人时）：本行动第一次结算前（10174 除外）给目标加集真赤 2627 和 [22, 32, 37, 67, 75, 88] 随机一个（原版 Math.randomInt(6)，重制 rule 流 `yomi_debuff`，floor(取数×6)）；10173 学了 10185 再施一次。结算后命中且目标有负面状态，残梦＋1（10174 不加）。
5. **扩散**：10172／10173／10174 主目标结算后，对其余活着的敌人各结算一次（伤害钩子 skillMultiplier × 0.33／0.50／0.66），同样充残梦；扩散的记录接在主目标之后进行动日志。
- 参照：新探针 `mv_oracle/yomi_battle_probe.cjs`（真实 BattleManager／Game_Action，Math.random 0.5，等级上限放开到 99，55 级）42 例：命中／闪避 16、连击 12、残梦 4、真实行动 8（四技能 × 学没学 10185，敌群 3、敌人生命加 1e12）、结束清零 1、模块常量 1。已登记进 `同步正式西游.py` 与 `oracle_additions.py`。
- 专项 `tests/xiyou_yomi_battle`（142 项）：逐例比；真实行动比每段目标、是否命中、暴击、各段伤害对第一段的比值、各敌人状态、负面状态数与残梦；另核重制默认（O-098 开）每段都暴击、段数目标不变。
- 反向验证：①关掉必中与扩散（`sure` 恒假、扩散不跑）16 项失败（闪避 4 例命中 0.18、扩散段缺失）；②不施印、连击用原次数 40 项失败。
- O-098 开关 `XYomiJingliu.CRIT_FIX` 由 `const` 改成 `static var`（测试比原版时要关掉；默认值与读取写法不变）。

## 发现（未修，交审查／总装定）

- **55 级黄泉技能伤害绝对值比原版低约 3.9%**：同一角色、同一干净目标（敌群 3 第一只，生命加 1e12），10171 原版 makeDamageValue 5067401748、重制 4868706083（比值 0.96079，四个技能、有无负面状态都同一比值）。攻击／速度／幸运与 CodexYomi.damage 原值两边一致（1455／1335／1448，89561000），差在公式之后的伤害链（疑似 55 级被动 10178～10183 某项或熟练度），与本期包装无关：本期专项只比各段比值。slice_probe 的黄泉伤害行是 1 级 0 进阶，量不到。建议派给战斗核心车道按 `yomi_battle.json` 的 act 例逐项拆。

## 交接板

- 下一步：白龙期三（米拉解放·黑龙与黑龙形态）。已读完原版（installNativeMiraRuntime.js 第 50～330 行），待做清单：
  1. `dragon()` 补「在战斗中」（原版 $gameParty.inBattle()）；
  2. meetsSkillConditions：黑龙技 10148～10152 只在黑龙形态、人形技 10140～10143 黑龙形态不能用、10146 要进阶 3＋50 级＋学会且不在黑龙、10147 永远不能单放；
  3. 解放（BattleManager.endAction 之后）：用 10146 且进阶≥3、学了 10146 → 加 2592；学了 10167（终焉）再清 endOfAllImmuneStates 与全部减益；clearActions（本回合剩余行动作废）；
  4. 终焉：黑龙形态且 10167 时 isStateResist／addState 挡名单状态、addDebuff 全挡；
  5. 禁忌 10166（进阶 2）：主动技（人形 4＋解放＋黑龙 5）MP／TP 消耗 ×0.75 取整；paySkillCost 登记生命代价 max(1, floor(mhp×0.1))，endAction（原 endAction 之前）扣，最低留 1；
  6. 不灭龙血 10154：受伤 ×0.8（钩子已有）；onTurnEnd 之后活着回 floor(mhp×5%)；
  7. 修雷德劫火 10162（55 级、进阶 3）：黑龙形态或用解放时，本回合对每个敌人命中的火属性（元素 2）生命伤害累计，endTurn（原 endTurn 之前）对活着的目标再扣 floor(累计×0.3)；startTurn 清空；
  8. endBattle：删 2592／2597／2598／2599、清代价与劫火；
  9. 换图 battlerName → `BlackDragon_Mira_SV`（battle_scene，看能否只加一处）；深渊掉落 2903（makeRewards，地图名以「深渊」开头、1/30）依赖楼层，只记不做。
  挂点：`XBattleLogic.act`（endAction 包装处 XRaceBattle.finish 一带）、`end_turn`／`start_turn`、`turn_end_battler`、`can_use`、`skill_cost`、`XBattler.add_state`；参照照 yomi_battle_probe 的做法（qiyu 式真实 BattleManager，等级上限放开到 99，进阶写 `_AdvancedNum`）。
- 用户试玩说明：黄泉的四个雷电战技现在必中、按幸运多段连击；紫电双斩以外的三个技能会波及其余敌人（33％／50％／66％）；命中带负面状态的敌人攒残梦，满 9 层才能放赤雨·黄泉归葬。
- 需要用户决定：无

## 进度账

- 角色与专属机制：49% → 49.5%（Claude 初值建议，待审查核定）。依据：黄泉一名角色的战斗包装补齐（镜流仍缺），按 166 名中一名专属战斗计＋0.5。

## 验证

- 专项：`xiyou_yomi_battle` 142/142（本地）。
- 选测：改了战斗核心 `battle_logic.gd`，云端选测 130 个场景全部通过（提交 18983ef9，基准 main 分叉点 3e546f7c，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41142417678）。
- 同步：本工作树 `同步正式西游.py --accept-additions` 退出 0、「测量不变」（`04_验证/本地结果/白龙5_同步2.log`；开发时先手拷了 yomi_battle.json，同期一说明，main 上是新增参照）。

## 待交叉核查（改了原沙僧核心文件）

- `modes/xiyou/battle/battle_logic.gd`（只加钩子，均为一行调用 XYomiJingliu）：`execute` 两处次数（`begin_action`）、付费处（`pay`）；`_invoke` 末尾（掩护后 apply 包装）；`item_hit`、`item_eva`；`can_use`（`meets`，在异化逆祷之前）；`end_battle`（`end_battle`）。八戒在改夺舍，若也动 `execute`／`_invoke`，合并时注意这几行。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 18983ef9 黄泉战斗收尾；yomi_battle_probe 参照与专项
