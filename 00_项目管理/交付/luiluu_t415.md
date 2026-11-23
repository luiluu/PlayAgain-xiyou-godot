# 交付：luiluu/t415

- 车道／工作者：天启篇／小A（T415）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【小A·天启篇·未经审查】T415 天启篇大厅不写漩涡 maxStage 与 _remakeLobbyCorruption（dev.待定）

- 依据：T091 初审 P2-6（T412 dev.859 遗留）。`XRift.stage()` 读取跨存档配置 `whisper_seen("rift3")`，合入 T412 后天启篇存档进入方桌大厅时，`XLobbyCorruption.setup()` 无条件向 `s.flags["_remakeLobbyCorruption"]` 写入 `maxStage = 3`，且 `XTianqiHall.run_host()` 代调 `lobby_fx.after_event(src)` 及 `wants_after()`、`on_action(CRACK_CELL)` 也会经由 `record(s)` 写入该键，违反「天启篇存档不动」。
- 代码改动：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/lobby_corruption.gd`：
    - `setup()` 写 `maxStage` 前加 `not XTianqi.active(s)` 守卫，天启篇存档进大厅零写入；
    - `wants_after()`、`after_event()` 均加 `XTianqi.active(s)` 守卫直接返回，避免经由 `record(s)` 写入 `_remakeLobbyCorruption`；
    - `on_action(CRACK_CELL)` 仅对非天启篇存档调 `record(s)` 计数 `crack`，天启篇存档不写档（直接返回首段调查文本）。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_hall.gd`：
    - `run_host()` 第 167 行代调 `host.lobby_fx.after_event(src)` 前加 `not XTianqi.active(s)` 守卫，与 `lobby_corruption.gd` 形成双层守卫，合并源（希禾 60→50、仓库管理员 8→24）路径对天启篇存档零写入。
- 专项与验证：
  - 新增专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_lobby_maxstage.tscn`（含 `.gd` 与 `.gd.uid`）：`18/18` 通过，覆盖 `XRift.stage() == 3` 下天启篇首次／再次进大厅 `flags` 与建层前后完整存档序列化字节一致、`tianqi_hall.gd:167`（60→50、8→24）及 `wants_after`/`after_event`/`on_action` 零写入、已写过 `maxStage=3` 老档原样保留、西游档照旧写入 `maxStage=3`／`said`／`crack`。
  - 本机相关回归：`tests/xiyou_lobby_corruption.tscn` 45/45、`tests/xiyou_tianqi_hall.tscn` 74/74、`tests/xiyou_rift3_xufeng.tscn` 53/53。
  - `03_再刷重制_Godot/07_开发环境/发行空壳.py check`：81 个脚本 782 个函数全部通过（退出码 0）。
  - 云端选测（提交 `04ac907a75`，基准 `2952172485042d705de5abd9b5c14a2e503e9357`）：**通过**（4 片 75 个场景全绿，最长一片 8.3 分钟），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45182741784 。

## 交接板

- 下一步：合并 `luiluu/t415` 后关闭 T415（T091 初审 P2-6）；无需改动 `rift.gd`、`rift_alien.gd`（与 T413 无冲突）。
- 用户试玩说明：无玩家可见变化（内部天启篇存档隔离修补，西游档行为完全不变）。
- 需要用户决定：无（已被写过 `maxStage=3` 的天启篇老档无运行时影响，本次未做旧档清理；详见下文说明）。

## 进度账

- 天启篇／大厅与存档隔离：修补 T091 P2-6（`XLobbyCorruption` 与 `XTianqiHall` 不再往天启篇存档写入 `_remakeLobbyCorruption`／`maxStage`），主表百分比不变。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiHall.run_host` | 1 处（`git grep -nE '[^[:alnum:]_]run_host[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/'`） | 调用方 1 处逐处结论：`modes/xiyou/map/map_scene.gd:970` 仅在 `XTianqiHall.intercepts(...)` 为真（天启篇大厅宿主事件）时调用；本次在 `run_host` 内部第 167 行加 `not XTianqi.active(s)` 守卫，仅跳过对 `lobby_fx.after_event(src)` 的代调，不改变宿主菜单、源事件本体执行与 `GIVEN_LINE` 补句，西游档不走 `run_host`，不会被改坏。 |

注：非 `core/` 下的 `modes/xiyou/map/lobby_corruption.gd` 改动了 `setup`（1 处调用 `map_scene.gd:519`）、`wants_after`（1 处调用 `map_scene.gd:798`）、`after_event`（2 处调用 `map_scene.gd:801` 与 `tianqi_hall.gd:168`）、`on_action`（1 处调用 `map_scene.gd:777`），均仅在 `XTianqi.active(s)` 为真时跳过写入，西游档分支逻辑一字未变。

## 已被写过 maxStage=3 的天启篇老档说明

- 全工程检索 `git grep -n 'maxStage\|_remakeLobbyCorruption' -- '03_再刷重制_Godot/'`：
  - `maxStage` 仅在 `modes/xiyou/map/lobby_corruption.gd:144,164` 写入，**全工程没有任何代码读取 `maxStage` 做解锁、门槛、战斗、事件或 UI 判定**（只写不读）。
  - `_remakeLobbyCorruption` 整键仅被 `lobby_corruption.gd` 自身读写；加守卫后天启篇存档不再读写该键，`XState.to_dict()`／`from_dict()` 对 `flags` 中的已有键仅原样透传，不影响存读档与任何数值／剧情。
  - 当前 `XTianqi.RELEASE_OPEN == false`，天启篇未向玩家发行，仅开发／测试老档可能含该键。
- 结论：**无任何影响，建议不清**（不在读档路径做额外清理逻辑，免得引入写老档／改存档结构风险；如后续确实要为开发老档清理该键，再另行确认）。

## 云端选测与独占范围

- 云端选测（提交 `04ac907a75`，基准 `2952172485042d705de5abd9b5c14a2e503e9357`）：**通过**（4 片 75 个场景全绿），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45182741784
- 本单修改文件（严格在独占范围内，未碰 `rift.gd`、`rift_alien.gd`）：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/lobby_corruption.gd`
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_hall.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_lobby_maxstage.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_lobby_maxstage.gd.uid`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_lobby_maxstage.tscn`
  - `00_项目管理/交付/luiluu_t415.md`

## 本分支提交

- `04ac907a7` T415 天启篇大厅不写漩涡 maxStage 与 _remakeLobbyCorruption（守卫 setup／after_event／wants_after／on_action＋专项）
