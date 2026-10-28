# 交付：claude/bajie-attack-query3

- 车道／工作者：C 规则·战斗／八戒（Claude，八戒_77）
- 状态：可合并
- 基线：按派单从期二交付点 d5d34931 开（含期一、期二全部提交）。
- 本期：期二交付单「遗留」1（敌人没有可用行动）、2（禁用号角、execute「不能用」分支），先补原版探针再改。

## 原版查下来的结论（attack_query_probe skip 组实测）

- **敌人**：OTB 的 getNextSubject 里 makeActions，然后走核心 `BattleManager.processTurn`：`prepare` 后 `isValid` 为假就不 `startAction`，只 `removeCurrentAction`，下一次 processTurn 没行动就 `endAction`。所以：
  - 行动列表为空（正式数据里木桩 73～78、394～397、668、669、746 都是空列表）：`made` 为空技能、`isValid` 假，**这一轮不行动**，智能 AI 开关结果相同；
  - 选好技能、行动时已不能用（MP 不够）：同样整次跳过，不扣费。
- **角色**：OTB 下轮到时 `startOTBInput`，输入完 `selectNextCommand` 直接 `startAction`（不能输入时 `makeActions` 后也直接 `startAction`），**不看 isValid**：MP 不够照扣（扣到 0）、物品已用完照走。
- **原版没有任何「不能用就退回攻击」**：`setAttack` 只出现在混乱、反击、挂机 makeAction 的默认、自动战斗候选（makeActionList）。重制 execute 的退回是最早 WIP 时写的，没有原版依据——**敌人应跳过、角色应照常执行**，两边都不是退回。
- **禁用号角**（255／256／257／394／440，occasion 2 仅菜单）：`canUse`、`isValid`（含强制）都否；战斗物品窗不列（重制按 occasion 本来就不列）；菜单里物品动作窗「使用」灰（YEP_ItemCore `Window_ItemActionCommand.isEnabled`＝`$gameParty.canUse`；物品场景的列表本身 YEP 恒可用）。角色行动里拿着号角时 `startAction` 照走，但导入平衡的 `useItem` 包装直接返回——**不扣物品**。
- 顺带：导入平衡的 `useItem` 包装对禁用角色也直接返回，重制原注释「付费照常」不对（禁用角色 canMove 为假，只有强制行动会走到，见遗留）。

## 变更记录草稿

## 2026-10-28 【Claude·八戒·未经Codex检验】行动无效按原版：敌人没有可用行动／行动时不能用整次跳过，角色照常执行，去掉无依据的退回攻击；禁用号角不扣、菜单「使用」灰（dev.待定）

1. `battle_logic.gd`：
   - `enemy_action` 没有可用行动返回 `{}`，`decide` 给 `[null, null]`（同逃跑失败的放弃：不行动、不付费，endAction 那些收尾照常）——木桩不再普攻。
   - `execute` 的「不能用」分支：原来一律退回 `attack_skill()`；改为**敌人**（非强制）不能用就整次跳过（在 Custom Action Start 之前返回），**角色**不检查、照原样执行。
   - 禁用角色／禁用号角（`XImportedBalance.blocks`）：不扣物品、不付 MP／TP、不进冷却、不前移（useItem 被挡），仍记 action、对目标无效（原样）。
   - `act` 把空技能 `{}` 也当放弃。
2. `item_scene.gd` `_usable`：禁用号角「使用」灰（导入平衡包的 canUse）。
3. `battle_replay.gd`：自动指令比对允许「没有行动」＝技能 0。
4. `imported_balance.gd`：头注释改正（useItem 不付费、号角不扣、「使用」灰）。
5. 专项断言按原版改：`xiyou_item_use` 全部公共事件物品可用的扫描把 5 个禁用号角单列为「灰」；`xiyou_troop_events` 第 2 回合「守层者必出手」改为开战时它有无条件可用的行动才要求（开战 TP 随机 0～24，204／207 的 4161 要 TP 10、233 的 4194 要 10，条件技能第 3 回合起：r1、r4 两个种子抽到 TP 不足，原版这时也不出手；参照是 Math.random 0.5 → TP 12，出手），这时附加伤害改比「没有命中」。
6. 原版探针 `attack_query_probe.cjs` 补 skip 组（13 例）：敌人走真实 processTurn（只把最外层 startAction 换成记录）、角色走真实 selectNextCommand→startAction（实例上记 useItem），含对照例；专项 `xiyou_attack_query` 对应比行动记录、付费差、物品数、canUse、两个物品窗。

## 遗留（本期不改）

1. **禁用角色的强制行动**：原版 `isValid` 包装对禁用角色恒假，但强制行动（processForcedAction→startAction）不看 isValid；useItem 被挡。重制现在同样不付费、对目标无效，但仍记一条 action（动画层面可能多一次空挥）。敌群事件强制禁用角色在正式数据里应不出现，没补探针。
2. 重制菜单「使用」对号角在非地狱难度本来就灰（超强者号角 can_acquire 链）；本期加的 `is_disabled_horn` 让各难度都按导入平衡灰，与原版一致（RED 时这一项没失败，xiyou_item_use 在开了超强者开关时才露出）。

## 待交叉核查（点名原沙僧核心文件）

- `battle_logic.gd`：enemy_action 空返回、decide、execute「不能用」分支按敌人／角色分开、blocks 不付费、act 空技能。
- 另改：`item_scene.gd`、`battle_replay.gd`、`imported_balance.gd`（注释）；探针 `attack_query_probe.cjs`；专项 `xiyou_attack_query.gd`、`xiyou_item_use.gd`、`xiyou_troop_events.gd`（A 车道的敌群事件专项，只改第 2 回合出手与附加伤害两条断言，请沙僧看是否放得过宽）。

## 交接板

- 下一步：遗留 3 Weapon Unleash（期二遗留，另派）。
- 用户试玩说明：木桩（及其它没有可用技能的敌人）轮到时不再出手；物品菜单里停用的伙伴号角「使用」是灰的。
- 需要用户决定：无

## 进度账

- 战斗规则：行动无效的处理按原版（敌人跳过、角色照常、无退回攻击）。

## 可优化（流程／工具／效率）

- `并行测试.py` 输出用回车刷新的进度行，管道给 `tail`/`head` 时看不到结果，等结束才知道；建议加 `--quiet`（只打最终汇总）或在非 TTY 时不打进度行。另：探针脚本不显式 `process.exit` 时 jsdom 计时器让进程不退出（本期临时检查脚本卡了 20 分钟），建议 `shared/host.cjs` 提供 `inspect()` 小工具或在 README 写明。归工具车道。

## 验证

- RED：撤回实现、保留新专项跑 `xiyou_attack_query`，13 项失败（木桩 made／started 出手、敌人 MP 不够仍出手且付 TP、角色 MP 不够退回成攻击、5 个号角退回成攻击）；GREEN 全过。
- 合 main：78e63123 起的 main（无冲突，没带进切片／转换器／探针改动）。
- 专项＋选测（`并行测试.py --log-dir`，50 场景）：`xiyou_attack_query`、`xiyou_event_compare`、`xiyou_smart_ai`＋`_b`／`_c`／`_d`、`xiyou_hangup`／`_auto`／`_options`、`xiyou_battle.tscn`、`xiyou_imported_balance`、`xiyou_troop_events.tscn`／`_b`／`_half`、`xiyou_battle_events`、`xiyou_determinism`、`xiyou_random_streams`（回放）、`xiyou_item_use`／`_list`／`_marks`（物品窗）、`xiyou_combat`、`xiyou_review_regressions`、`xiyou_otb`、`xiyou_state_effects`（＋`_tp`）、`xiyou_sequence_visual`（execute 调用方）、`xiyou_rules` 全 24 段。第一轮 47 过、3 个失败（item_use、troop_events、troop_events_b，原因与改法见变更记录草稿第 5 条）；改断言后这 3 个＋`_half` 重跑全过。无偶发。
- **战斗参照**：xiyou_rules 24 段与 troop_events_half（同参照 0.5）结果都不变，参照不需要重测；变的只是两个专项里依赖「退回攻击」的断言。
- 负载提示：xiyou_rules 各段在负载 15～20 时 300～540 秒，并行测试提示按场景拆分（d4、d5 已近 600 秒上限）。
- 同步 `同步正式西游.py --accept-additions`：只跑改过的 attack_query_probe（executed 1、reused 58），测量不变，产物指纹已留。

## 本分支提交

- 607dd6b3 探针 skip 组
- cf392189 行动无效按原版、号角、专项 skip 组
- 合 main
- 断言按原版（item_use、troop_events）
- （本提交）交付单

可合并
