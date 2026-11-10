# 交付：cc/rules-gaps12

- 车道／工作者：C 规则／机制／cc（八戒，车道 GB12，审查第 75 期返工）
- 状态：可合并
- 分支基点：本地 main d206fecc5，合进了 cc/review-75（审查第 75 期报告与交付单，合并时随本分支一起进）

## 变更记录草稿

## 2026-11-10 【cc·八戒·未经审查】审查第 75 期返工：三咒凝魄限定 CE1365、同时倒下先判输、战斗内 353／340 收场（dev.待定）

- **P1-1 三咒凝魄只额外放一次只认 CE1365**：gaps10 的 `XBattleCommonEvent.EXTRA_ONCE` 原来对所有「公共事件强制出的技能效果 44 又指回自己」都生效。v0.62.12 数据里这样的公共事件有 9 个（28 风怒、110、621、945、979、980、985 堕天一击、1154 雪岭舞、1365），除 1365 外都是「掷随机数中了再放一次、再放又重掷」的概率连发，被截成最多一次。现在加 `EXTRA_ONCE_IDS := [1365]`，只有 1365 截停，其余照原版每次重掷、可以连发多次。开关与 O-247 沿用，不另发号。
- **P2-1 双方同时倒下先判输**：原版 `BattleManager.checkBattleEnd`（rpg_managers.js 2614）先判我方全灭 → processDefeat，再判敌群全灭 → processVictory，YEP 的包装不改次序。重制 `XBattleScene._main` 原来先判赢：反伤、自爆同时打死最后一个敌人和最后一个我方时，原版算输（不可输去游戏结束、可输复活 1 血、不预约 1308），重制算赢、发奖励、预约 1308。现已改成先判输，与原版一致（复现原版，不登 O 号、不加开关）。
- **P3-1 ① 战斗内 353 游戏结束**：原版 command353 直接 `SceneManager.goto(Scene_Gameover)`，不看这场可不可输，也不走 updateBattleEnd 的复活。重制原来按普通全灭收场，可输的战斗会把阵亡者复活 1 血、事件接着往下走。现在 `logic.game_over` 时不复活；`XMapScene.start_battle` 记下 `last_battle_game_over`，事件 301 据此即使可输也走结束画面（O-244），战斗淡出也按全灭的 48 帧。rules-gaps7 有意保留的「353 走普通全灭收场（end_battle(2)、战败字样）」不变。现有数据只有敌群 825（圣劫使）用 353，它只由 CE1561 以不可输开战，所以这条现在走不到，是补齐。
- **P3-1 ② 战斗内 340 中止战斗**：原版 command340 → `BattleManager.abort`（_phase＝aborting），之后敌群解释器不再更新，下一帧 `checkAbort`（在判全灭、全歼之前）→ 逃跑音效、`_escaped`、processAbort（结果 1），updateBattleEnd 走逃跑那支预约 1308。重制原来没有对应（走通用跳过）。现在 `XBattleEventRunner` 认 340：置 `XBattleLogic.aborted`、本页后面与上层公共事件停下；`XBattleLogic.is_over()`（中止／全歼／全灭）接管事件检查与回合循环的停止判断；`XBattleScene._abort_battle` 收场：逃跑音效、没有消息窗、结果 1、预约 1308。数据里（敌群页、公共事件、技能／物品效果 44、脚本）都没用到 340，属于补齐。
- 测试：`tests/xiyou_troop_events.gd` `_extra_once_scope_checks`：从数据找出全部自指公共事件（断言含 28、1154、1365 且至少 9 个），逐个造「正在跑该公共事件时强制出来的行动收尾预约」，开关开时只有 1365 不预约、关时全都预约。`tests/xiyou_battle_end_ce.gd` `_end_order_checks`：双方同时全灭→结果 2、不预约、可输复活 1 血；可输战斗 game_over→结果 2、阵亡者不复活；aborted 且全灭→结果 1、预约 1308；340 后面的 121 不执行（对照：去掉 340 时 121 执行）、`run_turn` 不再出手。
- 玩家可见：风怒、堕天一击、雪岭舞等概率连发恢复原版（可以连发多次）；同时打死双方最后一人时算战败。

## 交接板

- 需要用户决定：无（三项都是对齐原版；P1-1 只把 gaps10 的范围收回到 Kyo 拍板的 CE1365）。
- 下一步：审查第 75 期的 P3-2（「自动／变速」按钮画在淡出黑幕之上）还没派，归 UI 车道；P3-3（help_card 注释的 O 号）归总装。

## 进度账

- 无（缺口修补，不改完成度）。

## 可优化（流程／工具／效率）

- 建议：审查报告说「同结构 11 个（1365 之外 10 个）」，实际 v0.62.12 数据里是 9 个（列出的也只有 8＋1365）。审查写数量时附上复现命令的输出行数更稳。没有工具改动。

## 验证

- 反向验证（`07_开发环境/反向验证.py`，五项都咬住）：EXTRA_ONCE 判断去掉 1365 限定 → xiyou_troop_events 失败；353 可输仍复活、340 不置 aborted、改回先判赢、中止放到全灭之后 → xiyou_battle_end_ce 失败。都已还原。
- `语法检查.py` 通过；`工具回归.py` 全过（67 秒）。
- 本机选测 35 个场景全过（20 分钟）：xiyou_troop_events 全部 7 段、xiyou_event_compare 全部 4 段、xiyou_battle_common_events、xiyou_battle_common_event_child、xiyou_battle_events、xiyou_battle_start_event、xiyou_cond111、xiyou_determinism、xiyou_random_streams、xiyou_script_census、xiyou_script_gaps、xiyou_flow、xiyou_dungeon、xiyou_game_over、xiyou_battle_end_ce、xiyou_battle_transition、xiyou_battle_pace、xiyou_cat_trial、xiyou_zhenqi_break、xiyou_battle、xiyou_rules（首段）、xiyou_weak_challenge、xiyou_hangup、xiyou_newsrc_boss_events、xiyou_floor31_bosses、xiyou_boss_sequence。
- 偶发：xiyou_flow 一次（`alt_enter_not_map_action`，单跑过，第 1 次）；xiyou_game_over 两次（`encounter_wipe_game_over`），第二次按规矩修了测试，见下。
- **修测试 xiyou_game_over**：2b 随机遇敌会掷先制，先制时开场「先发制人！」消息窗等按键、首回合只有我方出手等指令，60 秒超时（单跑多半掷不中）。把 `roll_encounter` 临时钉成先制可必现；2b 现在开 `XBattleScene.force_auto` 和 `XMessageBox.auto`，钉成先制也过、不钉连跑 4 次都过（临时改动已用备份还原）。另加 `XConfig.path_override`，不读本机真实设置。跟本分支的规则改动无关，是测试本身的随机。
- 选测.py 列出 369 个场景（battle_logic 改动按战斗核心选 xiyou_rules 全部段）。battle_logic 的改动只是把 `is_won() or is_lost()` 换成 `is_over()`（多一个只有 340 才会置的 aborted），aborted 为假时逐字等价，所以本机只跑了上面的事件／战斗收场相关场景，xiyou_rules 只跑首段，其余交总装合并时按影响面选测。

## 待交叉核查

- 甲：`modes/xiyou/core/battle_common_event.gd`（EXTRA_ONCE_IDS）、`modes/xiyou/battle/battle_scene.gd`（`_main` 收场次序、`_abort_battle`）、`modes/xiyou/battle/battle_logic.gd`（`aborted`／`is_over`）、`modes/xiyou/battle/battle_event_runner.gd`（340）
- 乙：`modes/xiyou/map/map_scene.gd`（`last_battle_game_over`、淡出帧数）、`modes/xiyou/map/mv_interpreter.gd`（301）、`tests/xiyou_troop_events.gd`、`tests/xiyou_battle_end_ce.gd`、`tests/xiyou_game_over.gd`（偶发修复）
