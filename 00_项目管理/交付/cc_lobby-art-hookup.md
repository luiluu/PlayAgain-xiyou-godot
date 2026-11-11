# 交付：cc/lobby-art-hookup

- 车道／工作者：B 界面·大厅／大厅初步异化接正式美术（cc，项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·大厅异化·未经审查】大厅初步异化接上正式美术（dev.待定）

- `XLobbyCorruption` 裂纹与青鳞改成有图用图：`content/lobby/crack_stage2.png`（336×336，图心对准漩涡中心）、`crack_stage2_glow.png`（微光层，照旧 6 秒呼吸）、`canglong_scale.png`（32×32，画在苍龙落点）。图来自 `codex/lobby-stage2-art`（Codex 11-11 原创）。没有图（或路径置空）时照旧程序画，两个分支谁先合都行。
- 专项 `xiyou_lobby_corruption` 加 2 项：有图时裂纹用贴花、路径置空时退回程序画。
- 玩家可见：大厅漩涡周围的裂纹换成正式美术。

## 交接板

- 下一步：无（三阶「蚀骨」方向见设计稿第 4 节）。
- 用户试玩说明：进方桌大厅看漩涡周围的裂纹。
- 需要用户决定：无

## 进度账

- 无变化（美术替换占位）

## 待交叉核查

- 丙档：`modes/xiyou/map/lobby_corruption.gd` 贴花分支、`tests/xiyou_lobby_corruption.gd`。

## 验证

- 专项 `xiyou_lobby_corruption` 45/45：本分支没有图时一次；把 `codex/lobby-stage2-art` 的三张图临时放进工作树、`--import` 后又一次（看过窗口截图，贴花对准漩涡），测完删掉，没提交图。
- 只改这个专项覆盖的文件，没跑别的选测。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log
