# 交付：cc/rules-gaps8

- 车道／工作者：C 规则·木桩 826 变身后第二行动位（GB4，cc 八戒）
- 状态：**可合并**

## 交给总装

- 没改探针、切片、转换器，不用重跑同步；`event_state_probe.cjs`、`event_presets.json`、`troop_event_probe.cjs` 都没碰。
- 调查用的临时原版脚本只放在 clone 的 `mv_oracle/.sandbox/`（dev_*_gaps8），交付后随 clone 一起删。

## 变更记录草稿

## 2026-11-09 【cc·八戒·未经审查】强制行动只清掉首位那一个行动位，追加行动的格子照常出手（木桩 826 变身 937）（dev.待定）

- 原版调用次序（临时探针包 BattleManager／Game_Enemy 的 getNextSubject、makeActionOrders、makeActions、clearActions、forceAction、endAction 记次序，新源 v0.62.12）：木桩 826 HP≤20% 例开战变身 937「木桩」，937 每回合 makeActions 出两格（8111,8111），OTB 当前回合排成 `e0 e0 a1 a8 a9 a10`。回合开始 getNextSubject 取出首格 e0，敌群事件 339 的 `forceAction` 先 `clearActions`（清掉首格那次 makeActions 的结果），6068／6055／6064 都在首格里跑完；endAction 之后 getNextSubject 取第二格 e0，重新 makeActions，照常出 8111、加 1460，然后才轮到角色。不变身的黑莲 936 只有一格（`e0 a10 a8 a9 a1`），强制行动用掉了它，所以没有普通出手——上期以为两例都是两格，其实不是。
- 重制原先把「首位被强制清掉」记在人身上（`_cleared[u]`），`cleared_action` 在同一人这一回合的每一格都返回 true，937 的第二格也放弃了。改成：`cleared_action` 只查询（测试回合后还看），新增 `XBattleLogic.take_cleared(b)`，每轮到一格调一次，只有首格那一次返回 true；`run_turn`、`battle_scene` 的行动循环和 `xiyou_battle_events` 的测试循环改用它。回退开关 `XBattleLogic.CLEAR_ALL_SLOTS = true` 回到旧行为。
- 原版换种子再验：被封印者 379／383 强制把 makeActionTimes 改成 2，原版第 1 回合 8111（强制）之后第二格照样出 4218，守层者攻击 1330→1830、1470→1970，跟重制改后一致。
- 测试 `xiyou_troop_events`：去掉 `KNOWN_DIFF` 826（现在是空表）；`t1_enemy_actions` 的上限不再因为首格被清就去掉追加行动；换种子的局如果守层者第 1 回合比参照多出手（掷中了参照固定 0.5 没掷中的追加行动，参照已走到角色行动的才算），攻击／魔攻与附加伤害改比自身值、不比参照值（每份打印 `MORE_SLOT_CASES=`，四份 22／10／12／12 局，固定 0.5 的 `_half` 是 0）；`_unit_checks` 加 `cleared_slot.one`／`cleared_slot.all` 两支。
- 玩家可见：有追加行动的守层者（木桩 937、被封印者等）在开场强制行动之后，多出的那格会照常出手，跟原版一样。

## 优化登记草稿

- 无：照原版移植（修重制与原版的分歧），不占 O 号；回退开关 `CLEAR_ALL_SLOTS` 留着，测试里有字面量回退支。

## 验证

- 原版：826 两例、379／383（基础与两格）临时探针 errors 0，次序见上。
- 语法检查.py：658 个 .gd，0 问题。
- 本机专项：`xiyou_troop_events`、`_b`、`_c`、`_d`、`_half`、`xiyou_battle_events` 全过（7337／7380／7353／7300／9719／108）。
  - 首版（`cleared_action` 用掉就删）查出两处并已改：① 测试回合后还要查 `cleared_action`，用掉就删让它读成 false，几十个敌群 `t1_enemy_actions` 挂，于是拆成查询＋`take_cleared`；② 379／383 换种子 r3 掷中追加行动后第二格出 4218、攻击 +500，跟参照 0.5 的值比挂了，原版两格实测同值，改比较口径（见上）。
- 工具回归.py：全部通过（58 秒）。
- 云端选测（5dfebb50，基准 main e8967abd，`--no-upload`）：`选测.py main --list` 305 个场景（含 xiyou_determinism 等战斗核心）全过，13 片、最长一片 11.8 分钟（运行 42551558225）。

## 待交叉核查

- 改了 `battle/battle_logic.gd`（`take_cleared`、`_cleared_used`、`CLEAR_ALL_SLOTS`、`run_turn`）、`battle/battle_scene.gd`（行动循环一行）、测试 `xiyou_troop_events.gd`（比较口径放宽，请看是不是放得太宽）、`xiyou_battle_events.gd`（一行）。

## 接续要点

- 无。

## 交接板

- 下一步：无
- 用户试玩说明：木桩（Map004）打到 20% 以下变身后，第 1 回合开场三下强制之后，木桩会紧接着再出一次手，然后才轮到我方。
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 已做：无
- 建议：`troop_event_probe` 不记行动次数（makeActions 出了几格），所以换种子掷出追加行动时测试只能放宽口径。以后要动探针时可以顺手在 `actions` 之外记每回合各敌人的格数，测试就能按格数严比。

## 本分支提交

- 7ddfb1fb 强制行动只清首位那一格（首版）
- 5dfebb50 拆成查询＋take_cleared，加回退开关，测试口径
