# 交付：cc/floor-boss-lose

- 车道／工作者：A 内容·楼层／悟空（cc）
- 基线：main 6bc1af076 切出（派单第十七批追加一 GD5）
- 工作地点：主工作区之外的 scratchpad `git clone --shared`（远程控制线程不能自建工作树），推回本库分支
- 状态：可合并

## 一、Boss 输分支盘点（新源 v0.62.12）

临时脚本扫了正式源全部地图、公共事件、敌群页里的 301（战斗处理）：

- **可输的战斗 126 场**（v0.28 时 55 场），其中**输了有后续指令的 36 场**（v0.28 时 17 场；多出来的是死神觉醒、剑道争锋两条线）。
- 36 场里 **26 场在切片里**，它们的「输了」变体已在事件对照里（accept5 的 4 个 `l1`，其余是分段甲 i4／i5 带的 `battleResult: 2`），共 37 个变体。本期单跑 `xiyou_event_compare --only=<这 37 个> --coverage`：**37／37 跟原版一致**，再按覆盖逐条核：**每场的输分支里每条指令都走到**（m180e12p0 小萝莉输分支按 10 个存档位分 10 支，i4_3＋i5_102～111 合起来走全）。
  - 输分支内容分几类：剑道争锋 9 场「317 改参数 ×3～5＋355＋123」（输了也给点属性、关独立开关）；死神觉醒 9 场多是一条 355 或 318／313；秃头男、萨麦尔格（扣积分）、嘤族之光、副本协会主席、张无忌／张三丰心魔战是文字＋开关／变量。
- **10 场在切片外，不用做**：Map137 测试图 3 场（作者调试图，切片说明里写明不入包）；Map226～231 共 7 场（输分支非空的有 227、230、231 的 7 个事件），这几张图在 MapInfos 里已经是空（编辑器里删了的孤图），全库没有场所移动或脚本指过去。
- 可输但输分支为空的 90 场：输赢后续一样，没有东西可比。

## 二、查出并修好的真差：战斗结束没预约 CE1308

- 原版 `BattleManager.updateBattleEnd`（rpg_managers.js 2696）：**没逃跑且全灭**时，可输就 `reviveBattleMembers`（倒下的出战者 1 血）回地图、不可输去 Scene_Gameover，**两种都不预约**；**其余（胜利、逃跑）预约公共事件 1308「战斗结束变量清除」**。v0.28 起就有。
- CE1308 做的事：清 1204 太极之力、1212 查克拉临时提升、1282～1287 命运连锁、1565／1566 一护技能号、1175 蜀山技能判断、965 不朽，966 开拓置 1；关 2261～2266 元素开关；一护在队时 1573 强者证明＝持有物品 1982 数，开关 1558 时去状态 960、忘 6136 并还一本 1914；町甄在队时纯真值 372 回初值 373（会 5519 再加 6）；欠债开关 2220 时 980 减一，减到 0 全员忘 8091 并关 2220。
- 重制全工程没有这一步（搜不到 1308），事件对照的参照探针直接调战斗回调、不走 updateBattleEnd，所以一直量不到。后果是这些战斗变量会从上一场带进下一场。
- 修法：`battle_scene.gd` 新增 `reserve_battle_end_event(state, result)`，胜利（`_victory` 之后）和逃跑（`_escape_success`）调用，预约 `BATTLE_END_COMMON_EVENT`（1308）；全灭那支不调。回地图后由 `XMapScene._process` 的预约公共事件照常跑（单槽、地图事件跑完才轮到它，同原版 setupStartingEvent）。全工程只有 `map_scene.start_battle` 一处建 XBattleScene，随机遇敌、挂机、事件战斗都走这里。
- 回退：`XBattleScene.BATTLE_END_COMMON_EVENT = 0` 回到不预约。这是补原版行为，不算优化，不占 O 号。

## 三、原版参照与专项

- 临时探针（scratchpad，经 `占槽.py`）：`endBattle(r)＋updateBattleEnd`（SceneManager.goto／pop 置空）五例：胜利、可输胜利、逃跑 → 预约 1308；可输全灭 → 不预约、出战者 1 血、去 pop；不可输全灭 → 不预约、Scene_Gameover。再在 Game_Interpreter 里跑 CE1308 七种状态（普通、欠债 2／1、一护有物品开 1558／没物品、町甄有无 5519）。参照引擎里 MOG 宝物弹窗要真场景，置空（只是提示）。
- 产物进 `tests/fixtures/battle_end_ce_oracle.json`，脚本原文放在 `probeSource` 字段（没进 mv_oracle，不登记探针）。
- 新专项 `tests/xiyou_battle_end_ce`（33 项）：真实 XBattleScene 打赢敌群 2（force_auto）、全灭可输／不可输打敌群 770，比结果、预约槽、出战者 HP；逃跑走 `reserve_battle_end_event(…, 1)`；CE1308 七例在 MVInterpreter 里跑，比变量、开关、物品、技能与状态，全对上；再设开关 0 看胜利不预约。约 125 秒。
- 反向验证（手动）：全灭那支也预约时，`end.lose.canLose_reserved`、`end.lose.cannot_reserved` 两项变红；改完用备份字节还原。

## 只盘点不改

- 空绿、门前赋值盖掉预设的两类簇：本期没碰（派单只盘点；这两类在分段甲 a6 的预设范围，改预设会撞 a6 的 event_presets.json／event_state_probe.cjs）。
- 顺带看到、没改（不在本期范围）：
  - 重制战斗回合里先判 `is_won` 再判 `is_lost`；原版 checkBattleEnd 先 `isAllDead` 走败北。双方同时倒下（反伤打死最后一个敌人）时原版算输、重制算赢。
  - 战斗里 353 游戏结束：原版直接 Scene_Gameover；重制按全灭收场，可输的战斗里会复活到 1 血继续（现有 353 只在不可输的战斗里，走不到）。
  - 敌群事件 340 中止战斗重制没有对应（原版结果 1、预约 1308）。

## 验证

- `语法检查.py`：660 个 .gd，0 个问题。
- `工具回归.py`：全部通过。
- 本机 `xiyou_battle_end_ce`：33／33。
- 选测：`选测.py main --list` 113 个（含新专项），走 `云端选测.py run --no-upload --base 6bc1af076`：**全过**（提交 5d362187，5 片，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42740038529）。
- 没改切片、转换器、探针，不用同步。

## 变更记录草稿

## 2026-11-10 【cc·悟空·未经审查】Boss 输分支盘点；战斗结束补预约公共事件 1308（dev.待定）

- 新源可输的战斗 126 场、输了有后续的 36 场：切片里的 26 场 37 个输变体事件对照全对上，输分支每条指令都走到；切片外 10 场是测试图和编辑器里删掉的孤图。
- 原版战斗打赢或逃跑后预约 CE1308「战斗结束变量清除」，全灭不预约；重制原来一直没有，太极之力、命运连锁、一护技能号、町甄纯真值、欠债等会带进下一场。`XBattleScene.reserve_battle_end_event` 补上，开关 `BATTLE_END_COMMON_EVENT`（0 回到不预约）。
- 新专项 `xiyou_battle_end_ce` 对照原版参照（`tests/fixtures/battle_end_ce_oracle.json`）。

## 交接板

- 下一步：同时倒下判输、战斗内 353 与可输、340 中止三处见交付单「只盘点不改」，要做就派给规则车道。

## 进度账

- 楼层、副本与剧情：「Boss 输分支参照」可记完成（36 场里切片内 26 场全对上，切片外 10 场不可达）；该行剩「空绿、门前赋值盖掉预设的簇」。

## 可优化（流程／工具／效率）

- 建议（给工具车道）：事件对照的参照探针只调战斗回调，`updateBattleEnd` 那一步（复活、预约 1308）事件对照永远量不到；本期用专项补了。以后如果给事件对照加「战斗后预约」，可以让 EventHost.start_battle 也按结果预约，两边一起比。
- 坑：反向验证要改「被测的那一支」；第一次改了 `result != 2` 的判断，但全灭那支根本不调用它，测试照样过，白跑一轮。

## 待交叉核查

- `modes/xiyou/battle/battle_scene.gd`：`reserve_battle_end_event` 与两处调用（胜利、逃跑），全灭那支不调。
- `tests/xiyou_battle_end_ce.gd`、`tests/fixtures/battle_end_ce_oracle.json`（probeSource 里的参照脚本）。
- 盘点结论（126／36／26／10）可用交付单里的口径抽查。

## 本分支提交

- WIP: 战斗结束预约 CE1308，xiyou_battle_end_ce 对照原版参照
- 交付提交（本提交）
