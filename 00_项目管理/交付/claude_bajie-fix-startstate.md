# 交付：claude/bajie-fix-startstate

- 车道／工作者：修复／八戒（Claude）
- 状态：可合并（待 Codex 核查；battle_logic.gd 一行为总装批准的独占文件例外）
- 基线：main 7677fe52（已含 14 期集成）
- 来源：八戒期二核查发现的 P1（[核查报告_20261027_沙僧82_集成期二](../核查报告_20261027_沙僧82_集成期二.md) 第一节），总装 2026-10-27 批准由八戒修。

## 问题

f4dff07e 让开战标签状态改走 `XResourceContext.add_state`，多了原版 isStateAddable 的一条判断：本结果槽刚去掉过的状态不能再加。重制原来既不在战斗结束时清结果槽，也不在地图走路时清，所以上场战斗结束去掉的 removeAtBattleEnd 状态一直留在 `runtime_result.removedStates` 里，第二场起开战标签状态就挂不上了。冻结数据里有 491 组标签和状态受影响。

## 修法（对齐原版，准入和开战路径不动）

1. **地图走一步**：`map_scene._on_player_step` 一开始调用新的 `XMapScene.on_player_walk(s)`，对全队（含后备）把 `runtime_result` 重置为 `empty_result()`。
   - 原版出处：`Game_Player.updateNonmoving`（走完一格、没有事件运行时）→ `Game_Party.onPlayerWalk`（YEP_CoreEngine 包装同样遍历全部成员）→ `Game_Actor.onPlayerWalk`，开头就是 `clearResult`。
   - 次序与原版一致：先清结果槽，再触发脚下事件、遇敌。
2. **战斗结束**：`end_battle` 对全队 onBattleEnd 的循环开头先清结果槽，再去掉 removeAtBattleEnd 状态。
   - 原版出处：`Game_Battler.onBattleEnd` 首句 `clearResult`，再 `removeBattleStates`。
   - 胜利时 `processVictory` 先 `removeBattleStates`，重制 `end_battle(0)` 的胜利块对应这一步。到 `Scene_Battle.terminate` 的 onBattleEnd 时结果槽已清空，所以胜利后不走路连战也能挂上开战标签；逃跑或失败后不走路，三场是挂上、挂不上、挂上交替。两种都与原版一致。

## 总装批准的独占文件例外

- 文件：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/battle_logic.gd`（沙僧独占）。
- 位置：第 1865 行。`end_battle` 里 `for b in state.members():`（第 1864 行，onBattleEnd 循环）的第一行，加了 `b.runtime_result = XResourceContext.empty_result()`。
- 只此一行；准入逻辑（`_state_add`、`XResourceContext.add_state`）和开战路径没动。
- 原版依据：`Game_Battler.onBattleEnd` 首句 clearResult；processVictory→removeBattleStates 在 terminate→onBattleEnd 之前。
- 批准人：常驻唐僧，2026-10-27。请沙僧核查。

## 新增

- 原版探针 `03_转换工具/mv_oracle/start_state_walk_probe.cjs`：真实引擎、全内存新局，只写 `.sandbox`。
  - 8 例：结束方式 {逃跑, 胜利} × 打法 {连打两场→走一步→第三场, 三场不走路} × 状态组 {龙王 1818：114 自身、113 全队；混合：193 不灭、246 破阵——狂攻、294 作战模式}。errors 全空。
  - Scene_Battle.start 需要窗口，无界面宿主跑不了。所以探针照 dsPassiveSkill processStateTags 的逐键解析，只取用到的 StartPushState、StartWTPushState 两类；addState 走真实包装链，见探针注释。
  - 开战后补一次全员 refresh，代表第一回合 onTurnStart 后的 Unit.refresh。原因：krz_state_re 的 `states()` 缓存在 addState 后不刷新，零回合就结束时，removeBattleStates 读旧缓存会漏掉别人挂来的状态（初版探针里 8 号的 113、1 号的 193 都因此没去掉，单步复现过）。真实战斗至少开一回合，不会碰到；重制没有模拟这层缓存，零回合战斗的这个差异不在本批范围。
- 夹具 `tests/fixtures/start_state_walk_oracle.json`：上面原件的拷贝。
- 专项 `tests/xiyou_start_state_walk.gd`：
  - 逐例逐场比较两名角色身上的标签状态和 removedStates，范围限于本组状态。
  - 另加一项真实地图入口：载入地图 5，`_on_player_step` 一步后，全队（含后备 9 号）结果槽清空。

## 验证

本工作树补齐并单独 import，exit 0，没有 SCRIPT、Parse 或 Compile 错误。

- **新专项**：xiyou_start_state_walk 385/385。
  - 反向验证：临时去掉两处修复，91 项失败；恢复后全过。
- **选测**（并行 2，`--full`，526 秒）：
  - 状态与事件：xiyou_state_operation 1431、xiyou_battle_start_event 50、xiyou_troop_events 6574、xiyou_enemy_book 93、xiyou_boss_lifecycle 5080。
  - 地图：xiyou_options_misc 86（含真实 `_on_player_step`）、xiyou_map 375。
  - **xiyou_rules 难度 1 四段**：xiyou_rules 115637、xiyou_rules_d1b 115733、xiyou_rules_d1c 115746、xiyou_rules_d1d 115725。
  - 以上全过。
- **xiyou_map 首跑 373/375**：缺 Map109、110、113、114、115，是本工作树 `generated/maps` 较旧（185 份对 main 190 份）。从主工作区只补缺、不覆盖地拷了这 5 份，复跑 375/375。跟本批改动无关。
- **必跑项**：MV 访问守卫 16/16，`git diff --check` 通过，夹具 JSON 可解析。
- **没跑**：全量和 xiyou_rules 其余 20 段。`检查.sh --affected` 会因 battle_logic.gd 选上整组规则段，按派单没用它。

## 可优化

- `并行测试.py` 的场景名按前缀匹配：写 `xiyou_rules` 会带上全部 24 段，`xiyou_map` 会带上 map186 系列。要精确只能写 `xiyou_rules.tscn`。本批首跑因此误跑 39 场，跑到第 15 场时停掉重来。建议在 `--help` 里写明，或者加一个 `--exact`。
- `新建工作树.sh --补齐` 对已有的 `generated/` 没补上新增的地图文件（本树少 5 份）。建议补齐时按文件比对，只补缺。

## 变更记录草稿

## 2026-10-27 【Claude·八戒·未经Codex检验】修复开战标签状态第二场起挂不上（dev.待定）

- 对齐原版两处 clearResult：地图走一步时对全队清结果槽（Game_Actor.onPlayerWalk）；战斗结束时先清再去掉 removeAtBattleEnd 状态（Game_Battler.onBattleEnd，总装批准 battle_logic.gd 一行例外）。准入不动。
- 新原版探针 8 例（胜利／逃跑 × 走一步／不走路连战），新专项逐场一致。
