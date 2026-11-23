# 交付：luiluu/t415

- 车道／工作者：天启篇／小A（T415）
- 状态：可合并

## 变更记录草稿

## 2026-11-23 【小A·天启篇·未经审查】T415 天启篇大厅不写漩涡 maxStage 与 _remakeLobbyCorruption（dev.待定）

- 依据：T091 初审 P2-6（T412 dev.859 遗留）。`XRift.stage()` 读取跨存档配置 `whisper_seen("rift3")`，合入 T412 后天启篇存档进入方桌大厅时，`XLobbyCorruption.setup()` 无条件向 `s.flags["_remakeLobbyCorruption"]` 写入 `maxStage = 3`，且 `XTianqiHall.run_host()` 代调 `lobby_fx.after_event(src)` 及 `wants_after()`、`on_action(CRACK_CELL)` 也会经由 `record(s)` 写入该键，违反「天启篇存档不动」。
- 代码改动：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/lobby_corruption.gd`：
    - `setup()` 写 `maxStage` 前加 `not XTianqi.active(s)` 守卫，天启篇存档进大厅零写入；
    - `wants_after()`、`after_event()` 保留天启篇追记台词照常显示（含 `XTianqiHallText.CORRUPTION_AFTER_LINES` 希禾 50／仓库管理员 24 以及大工匠 7／镜子 21／动保 43 等），天启篇去重改走**会话内表** `_tq_said_session`（按 `XState.get_instance_id()` 隔离，表项超 16 时清已释放实例），不再调用 `record(s)`、不写 `_remakeLobbyCorruption`／`maxStage` 也不改 `flags.tianqi`；
    - `on_action(CRACK_CELL)` 天启篇同样走会话内计数 `_tq_crack_session`，保留两段调查文案、不写存档；西游档全部路径照旧。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_hall.gd`：
    - `run_host()` 第 167 行照常代调 `host.lobby_fx.after_event(src)` 并更新注释（说明天启篇由 `after_event` 内部走会话内去重，不写 `_remakeLobbyCorruption`／`maxStage`），合并源（希禾 60→50、仓库管理员 8→24）追记台词照常显示且存档零写入。
- 专项与验证：
  - 新增专项 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_lobby_maxstage.tscn`（含 `.gd` 与 `.gd.uid`）：`21/21` 通过，覆盖 `XRift.stage() == 3` 下天启篇首次／再次进大厅 `flags` 与建层前后完整存档序列化字节一致、`tianqi_hall.gd:167`（希禾 60→50、仓库管理员 8→24）与 `wants_after`/`after_event`（大工匠 7、镜子 21）及裂缝两段调查文案照常出现＋会话内去重＋零写 `_remakeLobbyCorruption`、已写过 `maxStage=3` 老档原样保留、西游档照旧写入 `maxStage=3`／`said`／`crack`。
  - 本机相关回归：`tests/xiyou_lobby_corruption.tscn` 45/45、`tests/xiyou_tianqi_hall.tscn` 74/74、`tests/xiyou_rift3_xufeng.tscn` 53/53。
  - `03_再刷重制_Godot/07_开发环境/发行空壳.py check`：81 个脚本 782 个函数全部通过（退出码 0）；`03_再刷重制_Godot/07_开发环境/天启篇存档登记.py` 退出码 0。
  - 云端选测（提交 `9a6e18b777`，基准 `fe1f3e26cfd6ab4444af1fbe8f9d1689a0445e1f`）：**通过**（3 片 75 个场景全绿，最长一片 9.7 分钟），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45185931779 。

## 交接板

- 下一步：合并 `luiluu/t415` 后关闭 T415（T091 初审 P2-6）；无需改动 `rift.gd`、`rift_alien.gd`（与 T413 无冲突）。
- 用户试玩说明：无玩家可见变化（天启篇大厅追记台词与裂缝调查文案照常显示，仅不再往天启篇存档写入 `_remakeLobbyCorruption`／`maxStage`；西游档行为完全不变）。
- 需要用户决定：无（已被写过 `maxStage=3` 的天启篇老档无运行时影响，本次未做旧档清理；详见下文说明）。

## 进度账

- 天启篇／大厅与存档隔离：修补 T091 P2-6（`XLobbyCorruption` 与 `XTianqiHall` 不再往天启篇存档写入 `_remakeLobbyCorruption`／`maxStage`，同时保留天启篇大厅追记台词），主表百分比不变。

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XTianqiHall.run_host` | 1 处（`git grep -nE '[^[:alnum:]_]run_host[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/'`） | 调用方 1 处逐处结论：`modes/xiyou/map/map_scene.gd:970` 仅在 `XTianqiHall.intercepts(...)` 为真（天启篇大厅宿主事件）时调用；本次 `run_host` 仅更新第 166-167 行注释，调用逻辑与原版一致（继续调 `host.lobby_fx.after_event(src)`，由 `after_event` 内部对天启篇走会话内去重、不写存档），西游档不走 `run_host`，不会被改坏。 |

注：非 `core/` 下的 `modes/xiyou/map/lobby_corruption.gd` 改动了 `setup`（1 处调用 `map_scene.gd:519`）、`wants_after`（1 处调用 `map_scene.gd:798`）、`after_event`（2 处调用 `map_scene.gd:801` 与 `tianqi_hall.gd:168`）、`on_action`（1 处调用 `map_scene.gd:777`），均仅在 `XTianqi.active(s)` 为真时避免写入 `_remakeLobbyCorruption`／`maxStage`，西游档分支逻辑一字未变。

## 核查返修说明（P2-1／P3-1：追记台词副作用与去重选型）

- **初版副作用（cc 核退回 P2-1／P3-1）**：初版提交 `04ac907a7` 在 `wants_after()`、`after_event()` 与 `tianqi_hall.gd:167` 直接以 `XTianqi.active(s)` 拦截返回，导致 T133 在 `tianqi_hall_text.gd:489` 特意统一说话人的 `CORRUPTION_AFTER_LINES`（希禾 50、仓库管理员 24）以及大工匠 7／镜子 21／动保 43 等大厅追记台词在天启篇全部不再显示，且初版专项误将「不出现」当作通过。
- **返修方案与去重选型（会话内去重）**：
  - 在「写天启篇新存档键 `flags.tianqi.*`」与「会话内去重」之间选定**会话内去重**（`XLobbyCorruption._tq_said_session` 与 `_tq_crack_session`，以 `XState.get_instance_id()` 为键，表项超过 16 时清掉已释放实例）。
  - 选型理由：① 保持「天启篇存档零写入」与不改存档结构（不动 `modes/xiyou/core/tianqi_save.gd`，不新增待维护存档键）；② 同一次运行中反复进出大厅时 `XState.current` 实例不变，同一追记台词只播一次、裂缝两段文字按顺序播完，读档或开新档自动隔离不串档；③ `tianqi_hall.gd:167` 恢复代调 `lobby_fx.after_event(src)`，所有天启篇追记台词与西游档行为全部保留。
  - 专项 `tests/xiyou_tianqi_lobby_maxstage.gd` 已同步改为断言希禾 60→50、仓库管理员 8→24、大工匠 7、镜子 21 及裂缝两段文字**照常出现**、同会话二次触发**去重不重复**，同时全程不写 `_remakeLobbyCorruption`。

## 已被写过 maxStage=3 的天启篇老档说明

- 全工程检索 `git grep -n 'maxStage\|_remakeLobbyCorruption' -- '03_再刷重制_Godot/'`：
  - `maxStage` 仅在 `modes/xiyou/map/lobby_corruption.gd:144,164` 写入，**全工程没有任何代码读取 `maxStage` 做解锁、门槛、战斗、事件或 UI 判定**（只写不读）。
  - `_remakeLobbyCorruption` 整键仅被 `lobby_corruption.gd` 自身读写；加守卫后天启篇存档不再读写该键，`XState.to_dict()`／`from_dict()` 对 `flags` 中的已有键仅原样透传，不影响存读档与任何数值／剧情。
  - 当前 `XTianqi.RELEASE_OPEN == false`，天启篇未向玩家发行，仅开发／测试老档可能含该键。
- 结论：**无任何影响，建议不清**（不在读档路径做额外清理逻辑，免得引入写老档／改存档结构风险；如后续确实要为开发老档清理该键，再另行确认）。

## 云端选测与独占范围

- 云端选测（提交 `9a6e18b777`，基准 `fe1f3e26cfd6ab4444af1fbe8f9d1689a0445e1f`）：**通过**（3 片 75 个场景全绿），Run 链接：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45185931779
  - （此前初版提交 `04ac907a75` 云端选测 Run `45182741784` 4 片 75 场景亦全绿。）
- 本单修改文件（严格在独占范围内，未碰 `rift.gd`、`rift_alien.gd`、`tianqi_save.gd`）：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/lobby_corruption.gd`
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/tianqi_hall.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_lobby_maxstage.gd`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_lobby_maxstage.gd.uid`
  - `03_再刷重制_Godot/01_Godot工程/tests/xiyou_tianqi_lobby_maxstage.tscn`
  - `00_项目管理/交付/luiluu_t415.md`

## 本分支提交

- `04ac907a7` T415 天启篇大厅不写漩涡 maxStage 与 _remakeLobbyCorruption（守卫 setup／after_event／wants_after／on_action＋专项）
- `fe1f3e26c` T415 补交付单 luiluu_t415.md（云端选测 45182741784 全绿）
- `9a6e18b77` T415 返修 P2-1：天启篇大厅追记台词与裂缝两段文案照常显示、去重改走会话内表（仍零写 _remakeLobbyCorruption／maxStage）＋更新专项
