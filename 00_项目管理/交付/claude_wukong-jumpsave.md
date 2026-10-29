# 交付：claude/wukong-jumpsave

- 车道／工作者：A 内容·地图／悟空_65（Claude）
- 状态：可合并

## 变更记录草稿

## 2026-10-29 【Claude·悟空·未经Codex检验】事件跳跃到一半存档，读档后仍在空中（dev.待定）

- 问题（沙僧第六期 S1／P2，见 [核查报告](../核查报告_20261028_清积压第六期.md)「S1／P2」）：`MVEvent.save_state` 只存位置与强制路线，没存跳跃峰高与剩余帧；强制路线跳到一半存档，读档后 count／peak 都是 0，事件改走普通移动插值落地，演出与剩余时序和原版不同。
- 改动：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/mv_event.gd` 的 `save_state`／`restore_state` 加 `jumpPeak`、`jumpCount`（跳跃），顺带 `stopCount`、`animeCount`（停步与步行动画计数）、`moveWait`（随机移动等待）。旧档没有这些字段时按不在跳跃、计数 0 处理（`moveWait` 缺省保留建事件时的值）。
- 原版依据：冻结 v0.28 `js/rpg_οbjects.js`（文件名里的 ο 是希腊字母）`Game_CharacterBase.prototype.initMembers` 6438–6469 行（`_jumpCount`、`_jumpPeak`、`_stopCount`、`_animationCount` 都是事件对象的字段，整个 `$gameMap` 随 JsonEx 进存档）、`isJumping`／`jumpHeight` 6524–6530、`updateJump` 6715；`tests/fixtures/save_events_oracle.json` 的 eventKeys 里也列着 `_jumpCount`、`_jumpPeak`。
- 测试：`xiyou_save_events` 加「强制跳跃存读档」一段：Map004 事件 7 强制路线跳 (0,2)，推进 4 帧（count 12、peak 8、高 24、在空中、路线索引 1），真实 `XSave.save`／`load_slot` 往返后重开地图，逐项一致；放开后再走 12 帧落到起点＋(0,2)、路线结束；再删掉存档里这几个字段当旧档读，读档后不在跳跃、路线照旧。读档开地图要过几帧，测试在地图建事件时先停住事件更新再比。修复前跑同一用例 `jump.load`、`jump.lands` 失败（读档后 0／0／0／false），修复后 31／31。

## 交接板

- 下一步：无新增；沙僧第六期 S1／P2 已修，可从待修列表移除。
- 用户试玩说明：事件跳到一半时存档，读档后接着在空中落地（以前会贴地滑过去）。
- 需要用户决定：无

## 进度账

- 无变化（存读档细节补齐）

## 顺带核的原版移动生命周期字段（只记，没改）

对照 `Game_CharacterBase`／`Game_Character`（7070–7077）／`Game_Event` 的 initMembers，重制事件存档仍没存的：

- `_waitCount`：重制的 `_route_wait` 只在强制路线时随档（`forcedRoute.wait`）。原版自主「自定义」移动路线（moveType 3）也用它，但重制事件自主移动只做了随机（moveType 1），没有自定义路线，所以眼下无影响；以后做 moveType 3 时要连路线索引一起存。
- `_originalMoveRoute`／`_originalMoveRouteIndex`：同上，依赖 moveType 3，眼下无影响。
- `_balloonId`、`_animationId`：原版随档，但读档后 Sprite 重建，气泡／动画只在 `_balloonPlaying` 前请求时才起，实际几乎看不到差别；重制不存，只记。
- `_locked`／`_prelockDirection`／`_starting`：事件执行中不能存档（菜单打不开），正常游戏里存档时都是初始值，不需要存。
- 玩家与跟随者的跳跃：玩家位置走 XState 的 x／y，不存跳跃计数。原版 `Scene_Map.updateCallMenu`（`js/rpg_scenes.js` 773–784）要等 `$gamePlayer.isMoving()` 为假才开菜单，跳跃中实际位置未到格子也算移动，所以手动存档不会撞上玩家跳到一半；只记。

## 验证

- 合过一次 main（c667ece7）后选测：`xiyou_save_events` 31／31、`xiyou_start_state_walk` 40／40、`xiyou_autosave` 10／10、`xiyou_save_page` 5／5、`xiyou_battleback_save` 5／5、`xiyou_event_compare` 385／385，6 个场景全过，无偶发。
- 没改切片、转换器、探针，不用同步；没改界面。
- 临时输出（暂存的修复版文件）在会话 scratchpad，不在工作树；本轮的本地测试日志（`04_验证/本地结果/并行测试/` 下，不入 Git）已删，临时文件已清理。

## 可优化（流程／工具／效率）

- 建议：冻结正式源的 `rpg_οbjects.js`、`rpg_managеrs.js` 文件名里混着希腊字母 ο／西里尔字母 е，`grep`／`find -name rpg_objects.js` 找不到，第一次找原版要绕一圈。可在 `冻结正式源/README.md` 写一句「真实文件名含同形字，用 `rpg_*bjects.js` 通配」（文档车道，预计每次找原版省几分钟）。
- O-114 未使用：本期是照原版补齐，不是优化，没登记优化登记，号码可回收。

## 本分支提交

- da62d867 存读档：事件跳跃到一半存档，读档后保留跳跃峰高／剩余帧及停步、动画计数
- （本提交）合 main、交付单、注释去掉 O-114
