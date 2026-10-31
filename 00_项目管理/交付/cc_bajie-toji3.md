# 交付：cc/bajie-toji3

- 车道／工作者：C 规则／八戒（cc，八戒_93）
- 状态：可合并
- 分支从 cc/bajie-toji2 末端 233f08c6 切（总装八派），工作树 `.claude/worktrees/charming-thompson-b2b988`。机制编号沿用 toji1 交付单「机制对照」。

## 做到哪

- ✓ ⑦ 术师杀手（#17、#19）：受魔法伤害 ×0.2、反弹 26.4%、反弹技能换属性
- ✓ ⑤ 武器库追击 50%（#20 借用溅射、#28 追击）：随机咒具、借用特效、天逆鉾 50% 封印
- 甚尔原版运行时 37 项里只剩智能 AI 档案（#11）与画面两项（#24 显示、#25 说明框熟练度行）没做；读档 repair 照 toji1 交付单不跑

## 变更记录草稿

## 2026-10-31 【cc·八戒_93·未经审查】伏黑甚尔 171 第三期：术师杀手、武器库（dev.待定）

1. **术师杀手 10207**（`modes/xiyou/core/toji.gd`）：被别人的魔法生命伤害打时受伤 ×0.2（伤害钩子 toji 受击一支，`XToji.incoming_ops`）；结算（含 Confirm 与固定减伤）为正时记反弹（基数 0.264×结算值÷0.2、属性取结算行的属性），那次 apply 后甚尔用 10224 打回出手者：内部行动、不判黑闪、不再触发反弹、技能属性换成记下的属性。
2. **武器库 10211**（进阶 1 次后）：主技能 50% 先用随机另一把可切咒具的武器库技能（10220～10223）打一次目标（倒了换第一个活着的），本次主技能借它的特效：借游云＋1 段、借万里锁每段 16% 溅射、借释魂刀物理穿透 0.33、借天逆鉾且 50% 掷中时附封印；武器库·万里锁自己也 16% 溅射。随机数走 rule 流（toji_armory／toji_pick／toji_spear）。熟练度重制恒 0，不记 _actionMastery。
3. **接线**：`battle_logic.gd` 三处——`_damage_value` 拆出 calc 后接 `XToji.record`（记反弹）、`_invoke` 默认支末尾接 `XToji.reflect`、startAction 的 `XToji.begin` 改成把武器库追击的结果写进日志；`actor_damage_hooks.gd` 加 `XToji.incoming_ops`。
4. **参照与专项**：`toji_battle_probe.cjs` 加 slayer（敌人魔法普攻打甚尔与 1 号、物理技能 3 打甚尔）与 armory（进阶 1，'rng' 步给定只喂甚尔 startAction 的随机数）两段，`xiyou_toji_battle` 774 项（反弹那下按固定比值 0.96079 换算后差 1 以内：基数来自敌人个位数的伤害）。
   - 反向验证（临时改代码，已还原）：去掉受击 ×0.2 3 项失败、去掉反弹行动大量失败（反弹行没了、之后各步错位）、去掉借万里锁溅射 1 项、去掉借游云＋1 段 1 项。

## 下期

- 期三：智能 AI 档案 aiProfile（#11：切换技能给后续主技能、主技能段数／倍率／溅射／穿透估值，只读不改形态）。
- 画面车道：说明框熟练度两行（#25）；切换与主技能在技能页、战斗中的显示（逻辑在 `XToji.listed`）；反弹、武器库追击的日志与弹字（逻辑结果已在行动日志里，type hit）。

## 优化登记草稿

优化登记草稿：无

## 交接板

- 下一步：见「下期」。
- 用户试玩说明：甚尔被敌人法术（含西游里的普攻）打只掉两成血，还会反弹一下；进阶后普攻有一半几率先甩出一把别的咒具，并借到它的特效。
- 需要用户决定：无

## 验证

- `xiyou_toji_battle` 774/774、`xiyou_toji` 71/71。
- 同步 `同步正式西游.py --accept-additions`：测量不变（toji_battle.json 两段新用例已在本工作树产物里），来源核对 0 问题。
- main 在 233f08c6 之后的新提交（镜流第二期收尾、审查第 15 期）没碰本分支文件，没合（照车道须知「验收只做一轮」）。
- 相关战斗场景 33 个（甚尔两项、宿傩／黄泉／镜流两期／米拉／饿狼两项／渡鸦、行动序列、combat、battle_gaps、smart_ai 四段、异化两项、小猫、琦玉、state_effects、battle_events、otb、actor_modules、wtype、shield、种族、battle_common_events、custom_damage、settlement、imported_balance）全部通过；按改动选测超过 40 个的全量交合并时跑。

## 待交叉核查

- 甲档（战斗核心）：`battle/battle_logic.gd`（三处，见变更记录草稿第 3 条）——原沙僧核心文件，请重点核；`toji.gd` 第三期段；`core/actor_damage_hooks.gd` 一处。
- 丙档：`toji_battle_probe.cjs` 两段、`xiyou_toji_battle`。

## 本分支提交

- 6506db8d ⑦ 术师杀手
- d6a12770 ⑤ 武器库
- 31d3efed 交付单
- 0ca7b753 交付单可合并
- 4c4699b9 修：甚尔说明卡 dyn2（总装八急派：toji1 进 main 后 xiyou_help_card 新增甚尔技能卡 2 处对不上；原版 installDisplayPreferencesRuntime.js:540-543 按当前等级改写 10205 成长行与咒具成长系数行，重制 `character_help._dyn2` 漏了 171；改 character_help.gd、toji.gd 加 output_growth_at、xiyou_help_card 建 10 级 171；skills 657/657、xiyou_toji 71/71）
