# 交付：cc/wukong-xuan2

- 车道／工作者：C 规则／机制／悟空（cc，悟空 xuan2，Opus medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·悟空·未经审查】洪荒尾巴量到位；璇的战斗效果盘点与第一期（dev.待定）

- 洪荒尾巴：`honghuang_curse_battle_probe` 补到 34 例，量了 7207 爆伤（暴击 524→308）、7205、7213 元素（魔法火焰 172→17）、7212、7211 掉率（0.266→0.1596）、7203／7204 开战随机 0／0.5／0.99 的回合数与之后三次回合结束。重制全部对上，没有要修的。`xiyou_honghuang_curse_battle` 342 项。
- 璇的战斗效果第一期：新 `XXuanBattle`（`modes/xiyou/core/xuan_battle.gd`）。本场数据、净化口径 `is_cleanse_state`（全部状态逐个对原版）、MP 费用（按璇 MP 上限百分比）、技能条件、回光净化第一个硬控、星纹定星（2 级起，或列星期间 1 级）、璃壁护盾、棱光双防减益、星纹蚀辉（每 3／2／1 回合驱散一项增益）、战斗结束清标记。
- 钩子：`battle_logic.gd` 的 startBattle、endBattle、`applyItemUserEffect`、`can_use`、MP 费用；`resource_context.gd` 的 `add_state`（定星挡硬控）。
- 原版参照：`mv_oracle/xuan_battle_probe.cjs`（33 例，真实 Game_Action.apply，随机固定 0.5，关五乘区和路线压制 O-050），产物手工复制为 `tests/fixtures/xuan_battle_oracle.json`，不进同步。新测试 `xiyou_xuan_battle`（246 项）。
- 验证：见下方「验证」。
- 已知问题：寄星还是空动作（绑定在第二期）；定星挡住时的台词没有接（原版写战斗日志）；星纹余辉照原版不生效，见「需要用户决定」。

## 盘点：璇的战斗效果（installNativeXuanRuntime 第 60～430、446～498、578～617 行，另有 installThreeGrowthRelicRuntime 第 198～262 行）

星纹九种实际归属（原版代码读实，第一期的部分已量）：

| 星纹 | 原版效果 | 触发条件 | 归哪期 |
| --- | --- | --- | --- |
| 余辉 | 回光溢出转护盾 | 包在 Game_Battler.gainHp 上，角色走自有方法，**实测不生效** | 不做，待决定 |
| 定星 | 净化后挡一次硬控 | 回光即可，不要绑定 | 一（已做） |
| 先照 | 手动璃壁先制；自动预支 1 星契 | 先制要手动附身；预支要自律 | 二／三 |
| 同调 | 棱光跟随宿主元素 | 只在自律的 followUp 里写 | 三 |
| 分光 | 棱光分给多个敌人 | 只在 followUp 里写 | 三 |
| 蚀辉 | 棱光驱散增益 | 棱光即可 | 一（已做） |
| 移光 | 换宿主迁移护盾 | 转移 | 二 |
| 并轨 | 副宿主：3 级共宿防御；1、2 级救援与璃壁 | 3 级要绑定；1、2 级在自律反应里 | 二／三 |
| 留辉 | 旧宿主保留共宿增益 | 转移 | 二 |

分三期，每期能单独验收：

| 期 | 内容 | 依赖 | 验收 | 估算 |
| --- | --- | --- | --- | --- |
| 一（本期） | 上面变更记录所列 | 无 | `xiyou_xuan_battle`：本体直接放技能的结果 | 约 170 行，已做 |
| 二：绑定与手动附身 | 登记 xuan 种类；寄星、转移、回身（含指令窗）；星纹标记补回（removeState）；受益者；默契结算（寄住、护主、协同、名册）；共宿（伤害 `hostDamageRate`、双防、并轨 3 级、留辉）；移光；列星（星影、目标扩展、到期）；先照先制；星盾流转定轨（10 级）、接力（20 级）；60 级法宝列星特效；台词 | `XBinding`（已有）、一期 | 手动模式一整场：换宿主、列星、护盾迁移、默契数值逐回合对原版 | 约 180 行，最大 |
| 三：星契自律（50 级＋三进阶） | 内部施放 `cast`（`XBinding` 没有，可参照 `XTusu.cast`）；保留最后 1 点、先照预支与债务；敌人行动前璃壁；行动后救援、列星、棱光 followUp；分光、同调、并轨 1、2 级；回合末释放顺序；同轨 `tongguiStrike`；附身防御与本体 `autoAction`；AI 估值 | 二期 | 自律模式跑固定随机整场，逐回合对原版 | 约 120 行 |

## 交接板

- 下一步：璇第二期（绑定与手动附身）。
- 用户试玩说明：璇的回光能净化硬控，璃壁给护盾，棱光降敌人双防；回光、璃壁、棱光、列星按 MP 上限百分比扣蓝；星谱里的定星、蚀辉进战斗开始起作用。寄星还用不了效果。
- 需要用户决定：**星纹余辉要不要修**。原版写的是回光溢出转护盾（星谱说明也这么写），但钩子挂错了地方：回光只打角色，角色的 `gainHp` 是 Game_Actor 自有方法（已确认），这层跑不到，实测 1～3 级溢出都不给护盾。而且它是开局默认配的护主星纹。我按原版继续，没做。修的话是优化项，要分配 O 号，几行就够；默认不修。

## 进度账

- 璇（177）战斗机制：盘点完成，第一期完成，第二、三期未做。

## 待交叉核查

- 改了核心文件：`battle_logic.gd`（五处一行钩子）、`resource_context.gd`（`add_state` 一行）。请看 `blocks_state` 放在 `isStateAddable` 之前是否合适：原版包在 addState 最外层，即使这个状态本来加不上也会消耗定星。

## 可优化（流程／工具／效率）

- 建议：探针写开战时要记得开 2494 和关路线压制，不然璇被移出出战、数值减半，这轮踩了两次。可以在 `shared/host.cjs` 加一个「超强者参照」的公用开关，`tusu_battle`、`binding`、`heartsteel`、`xuan_battle` 共用。归工具车道，收益不大。

## 验证

- `语法检查.py` 通过。
- 选测 `选测.py main --list` 列出 131 个场景，没有全跑。跑了 10 个全部通过：`xiyou_xuan_battle` 246、`xiyou_xuan_chart` 128、`xiyou_tusu` 327、`xiyou_tusu_battle` 4977、`xiyou_guyu_battle` 1637、`xiyou_determinism` 372、`xiyou_battle` 9、`xiyou_state_js` 1733、`xiyou_honghuang_curse_battle` 342、`xiyou_event_compare` 5。
- 没跑 `xiyou_rules*`：新钩子全部先判 `is_xuan`（`blocks_state` 先判本场数据），切片的 xiyou_rules 角色不触发这些分支；请总装按影响面选测。
- 上面这轮之后只改过一行注释。之后合了 main（含 honghuang2、tools50），`--补齐` 后重跑 `xiyou_xuan_battle`、`xiyou_honghuang_curse_battle`、`xiyou_honghuang_reward` 311、`xiyou_determinism`，全过；`探针登记检查.py` 通过。
- 没开游戏实际玩过；没跑 `反向验证.py`。

## 本分支提交

- 检查点：洪荒尾巴
- （本提交）交付：璇第一期
