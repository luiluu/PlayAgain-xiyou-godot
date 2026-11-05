# 交付：cc/nezha-raven4

- 车道／工作者：C 规则·机制／哪吒（cc）
- 状态：进行中

## 变更记录草稿

## 2026-11-05 【cc·哪吒·未经审查】状态缓存时序：跨行动与嵌套 apply 的陈旧状态清除点（审查 43 P3-1、P3-2，dev.待定）

- 依据：[审查第 43 期](../核查报告_20261105_审查第43期.md) P3-1（`act()` 开头清全体 `stale_state_ids` 可能偏早）、P3-2（嵌套 apply 内层清 `rv_tp_refreshed` 外层漏标）。两条都先量原版再改。
- 量法：`mv_oracle/raven_reflect_probe.cjs` 新增 18 例（产物 `tests/fixtures/raven_reflect_oracle.json`，原有 41 例逐字节没变）。8 号生命上限 2e6、tcr 强设 0.01／2，必中黑暗 1e6 加黑暗侵蚀 1663（×1.4／0.9）。
  - `refseq.*`（P3-1）：行动 N 后侵蚀陈旧，行动 N+1 别人打 8 号两段。**敌人／队友打 8 号时，收尾 `IMMORTAL: targets, false` 的 removeImmortal 对目标 refresh，行动 N 结束时就已生效**，跟重制一样。**8 号自己放魔法被反射回自己时，出手者不在 targets 里，陈旧会跨到下一行动**：别人打它的第一击仍 ×0.9，第二击（第一击 setHp 的 refresh 之后）才 ×1.4。过回合末（onTurnEnd）或 8 号自己再行动（YEP useItem 付费后 refresh）会刷掉。重制原来在每次 `act()` 开头清全体，这一例第一击读到了新状态，跟原版不一样。
  - `refnest.*`（P3-2）：e0 对 8 号两段加侵蚀，在第一段的 applyItemUserEffect 之后（同璇回光内置棱光的位置）对 8 号再 apply 一次。内层扣了血（hit／small，TP 加 0 也算）就 setHp refresh，外层第二段 ×1.4；内层不伤害也不加状态（none）就不 refresh，外层第二段仍 ×0.9。重制原来 hit 例多标（第二段 ×0.9），none 例漏标（第二段 ×1.4），两种都错；small、tcr 0.01 碰巧对。
  - 现有游戏内容里，apply 里面再 apply 的只有璇同轨棱光，而且打的是敌人，所以 P3-2 玩家碰不到；P3-1 的反射例玩家碰得到（敌人有魔法反射时角色挨自己的状态技能）。
- 改法（`battle_logic.gd`、`action_sequence.gd`，开关 `XBattleLogic.STALE_TIMING`，`false` 回到 raven3）：陈旧状态只在原版真会 refresh 的地方清。这些地方是：出手者 useItem 付费后（`execute` 与防御支）、收尾 removeImmortal（普通路径 `execute` 末尾与序列 `IMMORTAL … FALSE`，只清目标）、受伤 setHp／setMp 值变了时（`_execute_hp_damage`／`_execute_mp_damage`；本击伤害已经算完）、回合末（原有），还有受伤充 TP 的 refresh（原有 `on_tp_refresh`）。`act()` 开头不再清全体。apply 加了按目标的层栈 `_stale_frames`：进内层前先按外层的标记把外层已加的状态定下来，外层收尾只看内层之后新加的状态。
- 专项：`xiyou_raven_reflect` 新增 `_refseq`、`_refnest`。`_refnest` 用测试里的 `NestLogic`（覆写 `_apply_core` 挂钩子）。比较各段结构、比值、对行动 N 那一击的跨行动比值和 TP。绝对伤害也跟参照对得上，比如 94382／60674。回退支 `_rollback_branch` 设 `STALE_TIMING = false`，断言 raven3 的旧结果。

## 交接板

- 下一步：无新增（审查 43 P3-1、P3-2 关掉；P3-3 措辞不在本车道）
- 用户试玩说明：敌人带魔法反射时，角色挨自己反射回来的「伤害＋加状态」技能，新状态的效果晚一击生效，跟原版一致。别的情形看不出变化。
- 需要用户决定：无

## 进度账

- 无（P3 精度修正，不动完成度）

## 可优化（流程／工具／效率）

- 建议（规则精度，归规则车道，不急）：重制在 apply 收尾才统一标陈旧，原版是在 addState 那一刻定的。所以「同一次 apply 里加状态之后还有 refresh」时重制会多标，比如同一技能加完状态又有回复效果（gainHp），或者连加两个状态（第二个 addState 的 refresh 会把第一个刷掉）。现有内容没量到这种技能，要做就改成加状态时就地标记，再补探针。
- 没做：派单第 4 条（accept2 可优化，`difficulty_enemy_probe` 掉率二分只对难度 1／9 分段）。本期先交 1、2，留给下一批。

## 验证

- 专项：`xiyou_raven_reflect` 457/457。反向验证：把 `STALE_TIMING` 默认改成 false 后，`refseq.tcr2.reflect`、`refseq.tcr2.reflect.ally`、`refnest.tcr2.hit`、`refnest.tcr2.none` 4 例比值和 1 例 TP 失败，共 5 项，还原后全过。
- 语法检查 554 个 .gd 0 问题；`工具回归.py` 全过（63 秒）。
- 选测：`选测.py main --list` 149 个场景（改了 battle_logic），走 `云端选测.py run`（提交 efb0bd65），结果：待写

## 待交叉核查

- 改了原归沙僧的核心文件：`modes/xiyou/battle/battle_logic.gd`（`STALE_TIMING`、`stale_refreshed`、`_mark_stale`、`_stale_frames`、`act`／`execute`／`apply`／`_execute_hp_damage`／`_execute_mp_damage`）、`modes/xiyou/battle/action_sequence.gd`（IMMORTAL FALSE）
- 探针 `03_转换工具/mv_oracle/raven_reflect_probe.cjs`（手跑探针，不在 PROBES，产物手抄到 fixtures）

## 本分支提交

- 5c4f83bb WIP：状态缓存时序清除点、探针 refseq／refnest、开关
