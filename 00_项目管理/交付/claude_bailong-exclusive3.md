# 交付：claude/bailong-exclusive3

- 车道／工作者：C 规则·机制（角色专属养成）／白龙_6（Claude）
- 状态：可合并
- 分支基于 claude/bailong-exclusive2 末端（期二已并入 main）。

## 变更记录草稿

## 2026-10-31 【Claude·白龙_6·未经审查】米拉解放·黑龙与黑龙形态（dev.待定）

照原版 installNativeMiraRuntime.js 的战斗包装（第 50～78、131～178、236～323 行），重制 `XMira` 第二期：

1. **技能条件**（meetsSkillConditions，`XBattleLogic.can_use` 调 `XMira.meets`）：黑龙技 10148～10152 只在黑龙形态，人形技 10140～10143 黑龙形态不能用，解放 10146 要进阶 3、50 级、学会且不在黑龙形态，10147 永远不能单放。
2. **禁忌 10166**（进阶 2）：主动技 MP／TP 消耗 ×0.75 取整（`skill_cost` 调 `XMira.cost`，在被动减耗之后、异化缄默与种族之前）；付费时登记生命代价 max(1, floor(最大生命×10%))，本次行动结束（原 endAction 之前）扣，未命中照扣、最低留 1（`act`／强制行动各一行 `pay_hp`）。
3. **解放**（原 endAction 之后，`liberate`）：用 10146 且进阶 3、学了 10146 → 加黑龙形态 2592；学了终焉 10167 再清名单状态与全部减益。原版随后 clearActions：OTB 每个行动位开头重新 makeActions，清掉也不影响本回合后面的行动位，重制不做（按代码阅读，没有单测）。
4. **终焉**（黑龙形态且学了 10167）：名单 40 个状态加不上（`XActor.add_state` 调 `XMira.resists`），减益全挡（`sequence_buff` 调 `blocks_debuff`，在异化路由之后）。
5. **不灭龙血 10154**：黑龙形态受伤 ×0.8（伤害钩子 mira 原有；原版另有一层 makeDamageValue ×0.8，实测只生效一次，比值 0.8000）；回合结束活着回 floor(最大生命×5%)（`turn_end_battler` 末尾 `turn_end`）。
6. **修雷德劫火 10162**（55 级、进阶 3）：黑龙形态或用解放时，本回合对每个敌人命中的火属性生命伤害累计（`apply` 末尾 `after_apply`）；回合结束（原 endTurn 之前，小猫剑圣之后、神秘生物逃跑之前）对活着的目标再扣 floor(累计×30%)；回合开始清空。
7. **战斗结束**：删 2592／2597／2598／2599，清代价与劫火（`end_battle`）。
- 参照：新探针 `mv_oracle/mira_battle_probe.cjs`（真实 BattleManager／Game_Action，Math.random 0.5，等级上限放开到 99，进阶写 `_AdvancedNum` 后照 CodexSkillProgression.sync 同步技能）30 例：技能条件 5、费用 2、真实行动＋回合结束 17、终焉 2、受伤 3、结束 1、模块常量 1。168 是超强角色，原版只在挑战开关或混沌难度下让他入队出战（BossDifficulty），探针开挑战开关 2494，不开时米拉不在 battleMembers、回合结束不跑他的 onTurnEnd。已登记进 `同步正式西游.py` 与 `oracle_additions.py`。
- 专项 `tests/xiyou_mira_battle`（285 项）：逐例比技能条件、技能同步后的已学列表、费用、行动段目标、行动后生命／TP／状态／减益、劫火累计、敌人状态、回合结束各人生命变化、终焉、受伤比值、战斗结束。伤害绝对值另有固定差（见「发现」），劫火与追加按重制自己的伤害核对。
- 反向验证：①技能条件恒真、解放不加形态 53 项失败；②劫火追加、不灭龙血回血、禁忌减耗与扣血都关掉 43 项失败。
- 新优化 O-待定（`XMira.DEBUFF_FIX`，见「优化登记草稿」）。

## 优化登记草稿

| 编号 | 项目 | 原版问题 | 重制做法 | 理由 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 米拉终焉解放时清减益（XMira.DEBUFF_FIX） | 解放·黑龙收尾清减益调的是不存在的 `removeDebuff`，米拉学了终焉、身上有减益时一放解放就抛 TypeError（参照 act.liberate.end.debuff） | 照说明清掉全部减益 | 原版接线错误，会报错停下 | `XMira.DEBUFF_FIX = false`：不清减益（不照搬报错） | Claude（白龙_6） | 待用户决定 |

## 发现（未修，交审查／总装定）

- **战斗里的技能费用不算 `<MP Cost: x%>`**：43 个技能备注有「最大 MP 的百分比」消耗（YEP_SkillCore），如米拉 10142「70MP＋最大MP×5%」，原版 55 级进阶 1 收 742，重制战斗 `XBattleLogic.skill_cost` 只收 70。说明卡 `XCharacterHelp._cost` 自己补了百分比，所以界面显示对、实际扣得少。本期专项的 MP 费用按说明卡的算法比（与原版一致，含禁忌 ×0.75）。建议派给战斗核心车道在 `skill_cost` 补上，同时去掉说明卡里那层补算（两处一起改，否则说明卡会重复算）。
- **角色生命／MP 上限没夹 99999999**：YEP_CoreEngine 参数「Actor MaxHP」「Actor MaxMP」都是 99999999（敌人放开），原版米拉生命加 1e12 后读成 99999999；重制 `XBattler.param_max` 恒 1e30（注释写「正式版经 YEP_CoreEngine 放开上限」，对角色不对）。本期探针改成角色不加血避开。建议派给战斗核心车道核对角色八项上限。
- **55 级专属技能伤害比原版低约 3.9%**（期二黄泉已记）：米拉同一比值 0.96079（解放、黑龙四技、人形技都一样，与形态无关），说明差在公式之后的公共伤害链。

## 交接板

- 下一步：白龙期四（渡鸦灵魂积累与铸印，照 bailong-exclusive1 盘点）。米拉剩下的：黑龙战斗图（Sprite_Actor.updateBitmap 包装：换 sv_enemies/BlackDragon_Mira_Enemy、缩 0.55、下移 220、藏武器，归界面车道 B 改 battler_sprite／appearance）；深渊掉落 2903（makeRewards：地图名以「深渊」开头的胜利 1/30，依赖楼层，只记不做）。
- 用户试玩说明：米拉（挑战难度下能出战）进阶 3、50 级后能放「解放·黑龙」化身黑龙，之后只能用黑龙技；黑龙形态受伤减两成、每回合回 5% 生命，55 级起火伤在回合末再追加 30%；学了终焉后黑龙形态免疫一批负面状态和减益。进阶 2 起的禁忌让主动技省 25% 消耗，但每次施放扣 10% 生命（最低留 1）。黑龙形态暂时还是人形战斗图。
- 需要用户决定：O-待定（米拉终焉清减益，默认照说明清）。

## 进度账

- 角色与专属机制：49.5% → 50%（Claude 初值建议，待审查核定）。依据：米拉一名角色的变身与形态战斗规则补齐（战斗图、深渊掉落仍缺），按 166 名中一名专属战斗计＋0.5。

## 验证

- 专项：`xiyou_mira_battle` 285/285；直接相关 `xiyou_actor_modules` 56/56、`xiyou_yomi_battle` 142/142（本地，同步之后，日志 `04_验证/本地结果/并行测试/20261031_021112_2y9b_cva`）。
- 选测：改了战斗核心 `battle_logic.gd`／`actor.gd`，云端选测 259 个场景 258 通过（提交 ab14b6a5，基准 GitHub main 分叉点，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41151342470）。唯一失败 `xiyou_book_capacity_ui`：6 项提示框文字高度（如 textHeight 32 对 42），重跑同样失败，是云端 Linux 字体度量与 Mac 不同；本分支没碰界面与提示框，本地 85/85 通过。建议归工具车道看云端字体（同一测试在别的分支云端应同样失败）。
- 同步：本工作树 `同步正式西游.py --accept-additions` 退出 0、「测量不变」（`04_验证/本地结果/白龙6_同步.log`；开发时先手拷了 mira_battle.json，main 上是新增参照）。

## 待交叉核查（改了原沙僧核心文件）

- `modes/xiyou/battle/battle_logic.gd`（只加钩子，均为一行调用 XMira）：`skill_cost`（`cost`）、`can_use`（`meets`，黄泉之后）、`start_turn`（`start_turn`）、`act` 与 `_force_action` 的行动收尾（`pay_hp` 在 `_tick_states` 之前、`liberate` 之后）、`end_turn`（`end_turn`）、`turn_end_battler` 末尾（`turn_end`）、`execute` 付费处（`pay`）、`apply` 末尾（`after_apply`）、`sequence_buff`（`blocks_debuff`）、`end_battle`（`end_battle`）。
- `modes/xiyou/core/actor.gd`：`add_state` 加一行 `XMira.resists`。
- 八戒在改夺舍：本分支没动 `execute`／`_invoke` 的结构，只在 `execute` 付费分支加了一行。

## 可优化（流程／工具／效率）

- 建议（归工具车道）：`并行测试.py` 遇到测试脚本解析错误（Godot 打出 Parse Error 后不退出）要等满 600 秒超时；本期撞了两次。可在输出出现「Failed to load script」时立即判失败，省约 10 分钟／次。

## 本分支提交

- 25e30530 WIP：米拉解放·黑龙与黑龙形态（探针、XMira 第二期、钩子）
- be64401e mira_battle_probe 参照与专项 285 项
- ab14b6a5 合并 main
- （本提交）交付单
