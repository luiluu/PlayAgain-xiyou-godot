# 交付：cc/bajie-walk1

- 车道／工作者：A 内容·地图事件／八戒（cc，项目线程「完成再刷西游Godot引擎重制」）
- 状态：可合并
- 基于：main 4db3bbd1（含 mapev1 dev.394、battlefix2 dev.396）

## 变更记录草稿

## 2026-11-07 【cc·八戒·未经审查】复量「走 10 格」原版对重制的真实秒数：已一致，只加专项（dev.待定）

- 起因：总装请求（battlefix2 分支没含 mapev1 的 `move_distance_scale`，量到重制每格 16 帧、原版 8 帧）。两单都合进 main 后在 main 上复量。
- 原版（冻结 v0.28／v0.62.12，jsdom 参照 newGame 实测）：玩家 moveSpeed 4，`ConfigManager.alwaysDash` 默认 true（不按 Shift 就跑，realMoveSpeed 5）；`js/rpg_οbjects.js` distancePerFrame＝2×2^速度÷256 → 跑一格 4 帧、按 Shift 走一格 8 帧；Drill_SpeedGear 1.6 使 `SceneManager._deltaTime`＝1/96。跑 10 格 40 帧≈0.417 秒，走 10 格 80 帧≈0.833 秒。
- 重制（main 4db3bbd1，headless 照入口设齿轮，真实地图场景按住方向键）：跑 10 格 41 帧 0.416 秒，走 10 格 81 帧 0.832 秒（多的 1 帧是起步那帧计入）。两者一致，代码不用改。
- 新专项 `tests/xiyou_walk_speed`（9 项）：齿轮 96 帧／秒；跑、走各 10 格的帧数（允许差 1）；墙钟不快于原版 15% 以上（机器忙时只会更慢，慢的只打印不判）。
- 玩家可见：无（只加测试）。

## 交接板

- 下一步：无
- 用户试玩说明：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- `xiyou_walk_speed` 9／9（本机直跑）。只加测试，没改游戏代码。
- `语法检查.py` 通过。

## 待交叉核查

- 无核心文件改动。

## 本分支提交

- 交付单 cc_bajie-walk1＋专项 xiyou_walk_speed（本提交）
