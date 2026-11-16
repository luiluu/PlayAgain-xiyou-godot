# 交付：cc/cat-again-use

- 车道／工作者：T046 猫剑 AgainUse/atkk 接进重制通用出手（cc 车道，Opus 5.5＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·战斗·未经审查】西游档通用出手接上被动再释放 AgainUse 与攻击次数 atkk（dev.待定）

- 依据：T041（总账期三补）交付单与小A核查：重制通用 `attack_repeats` 没接 dsPassiveSkill 的 `atkk`／`AgainUse`，只有小猫剑圣 `XCat.native_repeats` 读。
- 原版（冻结正式源 v0.62.12 `dsPassiveSkill.js` 1931 行起）：`Game_Action.numRepeats` 包装＝MV 本体＋被动缓存 `atkk`，再把 `AgainUseAll`＋按技能类型 `AgainUseZj`（stypeId 1）／`AgainUseMf`（stypeId 2）＋`AgainUse<技能号>` 的几率合计，`Math.random×100 < 合计` 时 +1，取整。被动缓存来源＝装备＋技能＋状态的备注（`parseInt` 取整数）；物品也吃（按 item.id 查）；敌人的缓存没有这两项。Codex 运行时（渡鸦、黄泉、云裳、流萤）都在 main.js 装，包在它外层；小猫剑圣自己的四个剑技 numRepeats 恒 1。
- 影响面比 T041 写的大：带这两个标签的不止 5 件符石，数据里有约 150 个来源——装备 63 件、技能 90 多个（含 7008 觉醒:刹那、7084 黄色闪光、7190 时之主宰、8039 龙虎天师、8053 司机真传这类 100% 再释放的角色被动）、状态 4 个（1384、1395、1730、2050），`atkk` 只有技能 1817 海军王。重制此前在西游档全部不生效。
- 改法：`XBattleLogic.passive_repeats`（实例方法，掷 `_float("again_use")`）紧贴 `attack_repeats` 外面、渡鸦里面，`execute` 的两条路（有行动序列、没有）都接；来源合计提成 `XBattleLogic.passive_again(a, item, 装备表)`，`XCat.native_repeats` 改用它（行为不变：仍读 `equip_list`、照旧过九线停用）。装备用 `stat_equips`（178 持剑时剑按翻倍视图，同原版 refreshPassiveCache 的 gearDepth）。
- 不走这层：天启篇（`XTianqiLedger.active()`，照旧只有小猫剑圣读、九线照停）；敌人；小猫剑圣的四个剑技（`XCat.casts`）。
- 开关：O-待定 `XBattleLogic.AGAIN_USE`（默认开），关掉回到 T046 之前。
- 玩家可见：西游档里带「再次释放 X%」的装备、被动、状态开始真的生效（几率多打一轮），海军王多打一段；用药水等物品也会按几率多用一次效果（同原版）。天启篇不变。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/battle/battle_logic.gd` `passive_repeats`／`passive_again`；`execute` 两处 | dsPassiveSkill numRepeats：被动 atkk 恒加、AgainUse 几率掷中 +1（重制之前通用出手没移植，西游档不生效） | 西游档通用出手照原版接上（移植缺口补齐，开关留回退）；天启篇、敌人、小猫剑技不走 | T041／小A 核查指出移植缺口 | `XBattleLogic.AGAIN_USE = false` | cc | 保留 |

## 验证

- 新专项 `xiyou_again_use` 89/89（参照 `mv_oracle/again_use_probe.cjs` → `tests/fixtures/again_use_oracle.json`，不进同步，同 cat_trial 夹具做法）：
  - 13 例（无来源、状态 1384／1730、技能 1817 atkk、10137 无百分号、198＋826＋状态 1395 合 70、atkk＋几率、符石 3852（战技／魔法各 25）、3872、3852＋1384、武器 1235、1588、技能 7008 100%）× 普攻 1／战技 9／魔法 51／物品 1 × 20 个随机数，`passive_repeats` 逐个对上原版 `numRepeats`（`oracle_numRepeats_all_match`），MV 本体也逐个对上；`oracle_has_extra_segments` 防空比。
  - 反向：`switch_off_reproduces_gap` 开关关掉 1817／1384／3872 等例子对不上原版、无来源例照旧对上。
  - `tianqi_untouched`（天启篇档恒不加）、`cat_kit_untouched`／`cat_other_skill_rolls`、`enemy_untouched`、`xiyou_rolls`。
  - `execute_wired`：角色学 7008 用药水，实战 execute 对自己打 2 次、开关关 1 次。
- 天启篇九线停：`xiyou_tianqi_nine_off`（含 `cat_again_use_off`）在选测里。
- 语法检查通过；工具快速回归全部通过（110 秒）；`检查.sh --affected main --cloud` 退出码 0（云端选测 301 个场景全过，提交 3b4fb6e97；非 Godot 检查全过）。
- 原版参照探针手跑 20 秒；探针没登记进同步（产物只做夹具）。

## 我不同意的地方

1. **天启篇改写技能的「再释放 10%」不生效**（协调 11-16 同意本单不做、另开卡）：`skill_rework.json` 有 22 处 note_add 写了 AgainUse——技能 198 雪山飞狐、3593 一念、826 倾国倾城、5483 屡获表彰、4924 金箍、2030 怨咒（Mf）、5477 步步生莲、6011 圣劫、5522 怒马纵横、5162 逆天难、5506 梦寻秘境、2727 浮冰（Mf）、3751 兔然暴富、3732 暗香盈袖（Mf）、4948 盛开谁堪摘、7477 觉醒:晓、7054 觉醒：九尾妖狐、7070 觉醒：九尾灵狐、7046 唐门绝学:控鹤擒龙、10137 魂海刻度（Mf），另 `armor:3670`、`weapon:2021`。天启篇里只有小猫剑圣读，说明写了却不生效；要接的话得定「掷中 +1 段」占不占回合预算 `take_extra`。
2. **智能 AI 估伤、屠苏估值没加**：原版 Codex_SmartBattleAI 与屠苏 `numRepeats()` 估伤也会吃 atkk 和掷一次几率（估伤带随机噪声）。重制 `smart_ai.gd`、`tusu.gd` 仍只用 MV 本体；atkk 只有 1817 一个来源，几率部分原版本来就是随机噪声，影响小，没动（动了要重核 smart_ai 16 份参照）。要对齐的话另开小单。
3. **物品也吃再释放**照原版移植了（药水按几率多用一次效果），没当缺陷修——说明写的是「再次释放」，物品算不算没定论；觉得是原版缺陷的话把物品排除是一行（`passive_repeats` 里加 `is_item` 判断）。

## 交接板

- 下一步：另开卡：天启篇改写技能的 AgainUse 是否接、占不占回合预算（见上 1）。
- 用户试玩说明：西游档里「再次释放 X%」的装备、被动、状态开始生效，有几率多打一轮；天启篇不变。
- 需要用户决定：无（上 1 由协调另开卡）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 3b4fb6e97 T046: 西游档通用出手接 dsPassiveSkill 被动 atkk／AgainUse
- ced295c77 交付单；之后补专项 .gd.uid

合并提示：交付自检判慢车道（新增 mv_oracle/again_use_probe.cjs），但这个探针只产夹具、没进 PROBES／同步，合并可用 `XIYOU_MERGE_SYNC=skip`。
