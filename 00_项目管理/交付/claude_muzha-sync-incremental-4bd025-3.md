# 交付：claude/muzha-sync-incremental-4bd025-3

- 车道／工作者：D2 同步与测试提速／木吒（Claude，重制_木吒_1）
- 状态：进行中

## 接续要点

- 用户 2026-10-26 定 floor 测试提速也做，测试专用、可回退。原先估「收益小」估错了：瓶颈不是算力，而是 `_physics_process` 每真实秒只跑 60 帧。做成测试快进 `GameApp.fast_forward()`（物理帧率与 `Engine.time_scale` 同乘 4），26 个脚本（27 个场景）选用。
- 本分支从 `-2`（0c991726，总装已合）接着做，只多快进这一项。

## 变更记录草稿

## 2026-10-26 【Claude·木吒·未经Codex检验】测试快进：floor 等真走地图战斗的测试 4 倍速（dev.待定）

- 现象：floor、variants 一类测试真走地图、打战斗。逐帧逻辑在 `_physics_process` 里，Godot 每真实秒只跑 60 个物理帧；横幅、胜利延时、淡入等计时器和补间按真实秒走，这些测试大半时间在等（goblin024 墙钟 102 秒、CPU 48 秒），不睡也快不了。
- 做法：`core/game_app.gd` 新增 `GameApp.fast_forward(n := 4)`，只在 headless 下生效：`physics_ticks_per_second = 60×n`、`max_physics_steps_per_frame = 8×n`、`Engine.time_scale = n`。物理帧的 delta 仍是 1/60 秒，逐帧逻辑、计时器、补间同比加快，彼此先后不变；单帧容许的最长耗时与原来相同。不变的只有 `ignore_time_scale` 计时器与墙钟。有窗口的游戏不经过这段。
- 选用：variants（含 _b）、heir116 与 floor 系列共 26 个脚本，在 `_run()` 开头调用。没选：算力瓶颈的（troop_events、formula_program、floor_run 三段等）、自己设 time_scale 的（opening_branches）、按帧采样画面的（battle_ui、sequence_visual）。
- 回退：`XIYOU_TEST_FAST_FORWARD=1`（设了即以它为准、对所有 headless 运行生效）。说明见 [测试提速](../../03_再刷重制_Godot/07_开发环境/测试提速.md)「测试快进」。

## 交接板

- 下一步：无（本车道这批收尾）。新写的真走地图／战斗、按条件等的测试，可在 `_run()` 开头加 `GameApp.fast_forward()`。

## 进度账

- 无（只改测试与测试专用开关，不改完成度）

## 验证

- 筛选：全局 `XIYOU_TEST_FAST_FORWARD=4` 跑 46 个候选，选用的全部通过、断言数与原来逐项相同。
- 选用后经 `并行测试.py` 跑（不设环境变量，走选用路径）：第一轮 29 个场景全过，选用部分合计约 1600→700 秒；battle_ui 并行时偶发一次（`combo_counts_in_battle` 采样时已淡出，单跑通过），已退出选用，sequence_visual 同理退出。
- 第二轮（26 个脚本 27 个场景）：待写结果。

## 可优化（流程／工具／效率）

- 已做：测试快进（回退 `XIYOU_TEST_FAST_FORWARD=1`）。
- 建议：共用槽「单槽让多槽」在多槽检查接连到来时会让单槽任务一直排不上（本车道 10-25 晚单槽测试排了约 40 分钟一个没开跑）；可给单槽任务一个最长让路时间（归哪吒）。

## 本分支提交

- 7b54bc5f WIP: 测试快进与 28 个场景选用
- 本条：退出 battle_ui、sequence_visual 选用，文档与交付单
