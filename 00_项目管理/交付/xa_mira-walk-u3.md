# 交付：xa/mira-walk-u3

- 车道／工作者：ag（默认模型，乙档美术替换）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【ag·未经审查】米拉人形行走图换 u3 定稿（dev.待定）

- 玩家可见：168 号角色「米拉」地图行走图更新为 u3 定稿版本，体态与原版同高。
- `03_再刷重制_Godot/01_Godot工程/content/mira/`：
  - 将 `img/characters/$Codex_Mira_Walk_u2.png`（及 `.import`）替换为 Kyo 11-15 定稿的 `$Codex_Mira_Walk_Final.png`（与 `$Codex_Mira_Walk_u3.png` 逐字节一致，144×192，3×4 格 48×48，实测每格可见高 47、脚底第 47 行 0-based，与原版 `$BlackDragon_Mira` 同高），通过 `godot --headless --import` 重新生成 `.import`，同步更新 `content/mira/README.md`。
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xdb.gd`、`mira.gd`：`XDB.img_path()`（`XMira.ART` 开启时）与 `XMira.ART` 注释改指 `res://content/mira/img/characters/$Codex_Mira_Walk_Final.png`（仍归属 `O-465` 开关）。
- `03_再刷重制_Godot/01_Godot工程/tests/xiyou_mira_art.gd`：更新行走图路径与 `_walk()` 断言为 `walk.foot_row_47`（末行 47）及 `walk.height_47`（可见高 47）。
- 验证：
  - `godot --headless --import`：通过（导入 `$Codex_Mira_Walk_Final.png` 并生成 `.import`）；
  - `tests/xiyou_mira_art.tscn`（无头＋有窗口截图双跑）：26/26 通过；
  - `语法检查.py`：876 个 `.gd`，0 个问题。
- 提交：3f2625fd0

## 优化登记草稿

优化登记草稿：无

## 交接板

- 下一步：无
- 需要用户决定：无

## 进度账

- 美术接入：米拉人形行走图已替换为 u3 定稿 `$Codex_Mira_Walk_Final.png`（144×192，48×48 格可见高 47、脚底第 47 行 0-based，与原版同高）。

## 对比截图

左：原版（`XMira.ART = false`）／ 右：新版 u3 定稿（`XMira.ART = true`），均于有窗口 Godot 实机截出并等比裁剪拼接（位于 git 忽略目录 `03_再刷重制_Godot/04_验证/本地结果/xa_mira_walk_u3/`）：

- 地图行走：![米拉地图行走原版与u3定稿对比](../../03_再刷重制_Godot/04_验证/本地结果/xa_mira_walk_u3/map_walk_compare.png)

## 未跑完、请总装合并时跑

- `03_再刷重制_Godot/07_开发环境/检查.sh`（按派单约定不在车道跑 `并行测试.py` 与全量，留总装合并时按影响面选测／全量运行）。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 3f2625fd0 米拉人形行走图换 u3 定稿（`$Codex_Mira_Walk_Final.png`）
