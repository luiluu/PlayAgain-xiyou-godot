# 交付：cc/wukong-floor10c

- 车道／工作者：C 规则／机制·地图／悟空（cc，GD4）
- 状态：可合并

## 变更记录草稿

## 2026-11-09 【cc·悟空·未经审查】全灭两处补漏：随机遇敌战败进结束画面、解释器等结束画面走完（dev.待定）

- 修审查 70 两条 P2（O-244 补充，不另开 O 号）：
  - 随机遇敌（`map_scene.gd` `_encounter`）原来不看 `start_battle` 返回值，全灭后人 0 血留在地图；现在收 result，`result == 2` 时 `await game_over()`（挂机快速战斗同走这条路径）。
  - 事件里 301 输掉（`mv_interpreter.gd`）原来 `host.game_over()` 不 await，事件收尾 `_set_busy(false)`，结束画面盖着时人能走、能触发事件；现在 `await host.game_over()`。
  - 两处都靠 `game_over()` 自己把 busy 锁到回标题：新增 `_game_over_locked`，标题路径起锁住 `_set_busy(false)`（回退支 `GAME_OVER_TO_LOBBY = true` 先解锁，行为照旧）。选这个而不只是 await，是因为 await 完事件收尾还会 `_set_busy(false)`，只 await 的话回标题切场景的那一帧又放开。
- 测试：`xiyou_game_over` 补随机遇敌全灭（画面出现、busy、回标题）和解释器 301 输掉（画面期间 busy 不放开、方向键人不动、走完回标题）；`xiyou_flow` 守层者战败后把结束画面走完（解释器现在 await，不走完事件协程悬着，退出报资源泄漏）。反向验证：去掉两处 await 后新增 3 项断言失败。
- 玩家可见：随机遇敌全灭现在和原版一样进游戏结束画面再回标题；结束画面期间不能再走动。

## 交接板

- 下一步：无
- 需要用户决定：无

## 进度账

- 无变化

## 可优化（流程／工具／效率）

- 无

## 验证

- 选测：`xiyou_game_over`（27 项）、`xiyou_flow`（含新增 1 项）、`xiyou_map_audit` 全过；`语法检查.py` 通过。因 `map_scene.gd` 变动 `选测.py main --list` 列得很宽，按派单不跑全量，交总装按影响面选测。
- 待交叉核查：`map_scene.gd`（`_set_busy`、`game_over`、`_encounter`）、`mv_interpreter.gd` 301；`GAME_OVER_TO_LOBBY=true` 回退支照旧过（`xiyou_game_over` 第 3 段）。

## 本分支提交

- 见 git log
