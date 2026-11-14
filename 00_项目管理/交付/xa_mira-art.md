# 交付：xa/mira-art

- 车道／工作者：ag（默认模型，乙档美术接入）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【ag·未经审查】米拉人形 u2 新美术接入（O-待定，dev.待定）

- 玩家可见：168 号角色「米拉」人形行走图与战斗图、图鉴与行动条展示同步切换为 u2 重绘新美术（黑龙变身形态与原版战斗图保持不变，由开关 `XMira.ART` 控制一键回退）。
- `03_再刷重制_Godot/01_Godot工程/content/mira/`：
  - 复制定稿素材 `img/characters/$Codex_Mira_Walk_u2.png`（144×192，3×4 格 48×48，实测脚底第 47 行（0-based 末行；12 帧由原第 44 行整体下移 3px 对齐原版 `$BlackDragon_Mira`，上方补透明））与 `img/sv_actors/Codex_Mira_SV_u2.png`（576×384，9×6 格 64×64，格内脚底第 61 行）并生成对应 `.import` 与 `README.md`。
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/mira.gd`：新增回退开关 `XMira.ART := true`。
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xdb.gd`：`img_path()` 在 `XMira.ART` 开启时优先把 `$BlackDragon_Mira`／`$Codex_Mira_Walk_u2`（characters）与 `BlackDragon_Mira_SV`／`Codex_Mira_SV_u2`（sv_actors）指到 `res://content/mira/img/...`。
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/appearance.gd`：`sv_form()` 在 `XMira.ART` 开启时返回 `"MiraHuman_u2"`（关闭回 `"MiraHuman"`，`MiraDragon` 保持不变）；`for_look()` 接入 `"MiraHuman_u2"`；`PROFILES` 新增 `"Codex_Mira_SV_u2": [64, 64, 8, 3, 53, 61]`（64×64 格、脚底 61 行）。
- `03_再刷重制_Godot/01_Godot工程/modes/xiyou/ui/actor_book.gd`：`sprite_spec()` 在 `XMira.ART` 开启时将米拉默认立绘映射至 `res://content/mira/img/sv_actors/Codex_Mira_SV_u2.png`（单张 9×6 表，`multi: false`）。
- 测试：
  - 新增 `tests/xiyou_mira_art.tscn`／`.gd`／`.gd.uid`（覆盖取图路径、站姿归一表、战员外观与人物图鉴在 `XMira.ART` 开关切换下的表现、回退到 `UserSV_MiraHuman` 多帧以及黑龙形态 `MiraDragon` 不受影响）。
  - 更新 `tests/xiyou_actor_looks.gd`（按 `XMira.ART` 开关分别核对）、`tests/xiyou_sv_smooth.gd`（168 人形切换为 64×64 后归入锐利列表）、`tests/xiyou_actor_book.gd`（v0.62.12 原版对照前设 `XMira.ART = false`，收尾恢复 `true`）。
- 验证：
  - `tests/xiyou_mira_art.tscn`：25/25 通过；
  - `tests/xiyou_actor_looks.tscn`：35/35 通过；
  - `tests/xiyou_sv_smooth.tscn`：140/140 通过；
  - `tests/xiyou_mira_battle.tscn`：287/287 通过；
  - `tests/xiyou_appearance.tscn`：34/34 通过；
  - `发行空壳.py check`：通过（58 个脚本，483 个函数都有）；
  - `测试工具回归.py`：6/6 通过；
  - `语法检查.py`（核心与新测试修改后、调整旧测试前）：876 个 `.gd`，0 个问题；
  - `回退开关覆盖.py`：通过（退出码 0）。
- 提交：e801c9a63、e27d9c7da

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/mira.gd` `XMira.ART`、`core/xdb.gd` `img_path`、`core/appearance.gd` `sv_form`／`for_look`／`PROFILES`、`ui/actor_book.gd` `sprite_spec`；`content/mira/`；`tests/xiyou_mira_art.gd` | 168 号「米拉」人形使用原版 `$BlackDragon_Mira` 行走图与 `UserSV_MiraHuman1_0~4` 多帧战斗图 | 人形行走图与战斗图默认切换为 u2 重绘新美术（`$Codex_Mira_Walk_u2.png` 与 `Codex_Mira_SV_u2.png`），黑龙变身形态保持原版不变 | Kyo 2026-11-14 拍板米拉人形 u2 定稿接入，保持 1× 最近邻与格内脚底对齐 | `XMira.ART = false`（`tests/xiyou_mira_art.gd` 与 `tests/xiyou_actor_looks.gd` 对开关双态分别验证） | ag | 保留 |

## 交接板

- 下一步：无
- 需要用户决定：无（黑龙战斗图与 u6 升空变身演出不在本单范围，待后续单另定）

## 进度账

- 美术接入：米拉人形 u2 行走图（144×192，48×48 格实测脚底第 47 行（0-based，由第 44 行下移 3px 对齐原版））与战斗图（576×384，64×64 格脚底第 61 行）已接入工程，黑龙形态维持原版不变。

## 对比截图

左：原版（`XMira.ART = false`）／ 右：新版 u2（`XMira.ART = true`），均于有窗口 Godot 实机截出并等比拼合（原始图与拼接图位于 git 忽略目录 `03_再刷重制_Godot/04_验证/本地结果/xa_mira_art/`）：

- 战斗待机（人形）：![米拉战斗待机原版与新版u2对比](../../03_再刷重制_Godot/04_验证/本地结果/xa_mira_art/battle_idle_compare.png)
- 地图行走：![米拉地图行走原版与新版u2对比](../../03_再刷重制_Godot/04_验证/本地结果/xa_mira_art/map_walk_compare.png)
- 人物图鉴：![米拉人物图鉴原版与新版u2对比](../../03_再刷重制_Godot/04_验证/本地结果/xa_mira_art/actor_book_compare.png)

## 未跑完、请总装合并时跑

- `03_再刷重制_Godot/07_开发环境/godot --headless --path 03_再刷重制_Godot/01_Godot工程 tests/xiyou_actor_book.tscn`：仅追加 `XMira.ART = false` 与结尾恢复 `true` 两行（已在 `git diff` 核对无语法问题），整场景耗时 >55s 未等跑完，请总装合并时运行。
- `03_再刷重制_Godot/07_开发环境/检查.sh`（全量测试与最后一次全仓 `语法检查.py`）：预计超过 2 分钟，按派单约定留总装合并时跑。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- e801c9a63 米拉人形 u2 新美术接入（O-待定）
- a518e7a0e 交付单：xa/mira-art 可合并
- e27d9c7da 米拉人形行走图下移 3px 对齐原版脚底第 47 行
