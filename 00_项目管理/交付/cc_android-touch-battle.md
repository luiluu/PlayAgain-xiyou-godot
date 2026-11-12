# 交付：cc/android-touch-battle

- 车道／工作者：大厅两个调试 NPC（v0.01.01 玩家反馈，第三期）／cc（项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-12 【cc·线程·未经审查】大厅全图鉴 NPC 放回（只解锁怪物图鉴）、99 级 NPC 只在测试模式出现（dev.待定）
- 起因：玩家（玲樱）v0.01.01「大厅右边那个一键解锁 NPC 还是保留着吧」，指的是 Map004 事件 55「全图鉴获取」（原版一直显示）。重制 content1 起把 55 和 69「测试游戏角色技能」（一键 99 级）当调试事件没放（切片 keepEvents 不列），玩家版两个都看不到。Kyo 11-12 定：全图鉴 NPC 保留，但「成就和称号不一键解锁」；99 级那个「隐藏起来，只开放给测试模式」。
- 新模块 `XLobbyDebugNpc`（`core/lobby_debug_npc.gd`），照 XRift 的路子在运行时放行，不改切片、不用同步：
  - 事件 55：放回大厅；读图时只留「EnemyBook complete」（怪物图鉴全部登记）和「图鉴获取完毕」一句，原版前面的 GetAcReward 一串（全部成就）、ConfigManager.DesignationN（全部称号）和两句「…获取完毕」去掉（O-待定·大厅全图鉴 NPC，`BOOK_NPC`／`BOOK_ONLY`）。
  - 事件 69：放进地图，照原版 installTestGateRuntime 把开关 2501 对齐成测试模式开没开（进地图一次、之后每 30 帧查一次，只在变了时写并刷新事件；原版每帧查，重制不每帧读解锁文件）。测试模式没开时第 0 页空页，看不见（O-待定·测试模式 99 级 NPC，`TEST_GATE`）。
- 专项：新 `xiyou_lobby_debug_npc`（12 项：放行名单、只留图鉴、无成就称号、两种回退、插件指令登记全部图鉴、开关跟测试模式对齐且不重复写、页条件）。`xiyou_event_compare` 比原版翻译时把 `BOOK_ONLY` 关掉（照原版整页对照）；`xiyou_achievement` 的「事件里的成就脚本都认得」改读原样的转换产物。
- 玩家可见：大厅右边（24,23）多一个「全图鉴获取」NPC，对话一次登记全部怪物图鉴；不给成就和称号。
- 未完成／已知问题：没实机走到大厅点它看。`xiyou_floor_reach004` 的「55、69 不进 keepEvents」照旧成立（切片没改）。

## 交接板

- 下一步：随 v0.01.02 修复补丁一起出，等 Kyo 说「推」。
- 用户试玩说明：大厅右边找「全图鉴获取」NPC，对话后怪物图鉴应全部登记，成就、称号不变；开测试模式后大厅右下（28,29）出现小鸟（一键 99 级），关掉就消失。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·大厅全图鉴 NPC | `modes/xiyou/core/lobby_debug_npc.gd` `XLobbyDebugNpc.BOOK_NPC`、`BOOK_ONLY`（`keep_event`、`patch_map`）；`core/xdb.gd`、`map/map_scene.gd`；`tests/xiyou_lobby_debug_npc.gd`、`tests/xiyou_event_compare.gd`、`tests/xiyou_achievement.gd` | Map004 事件 55「全图鉴获取」一直显示，一次给全部成就、全部称号、全部怪物图鉴（重制原先没放） | 放回大厅，只登记全部怪物图鉴，不给成就和称号 | 玩家反馈 v0.01.01 要保留；Kyo 11-12「成就和称号不一键解锁」 | `XLobbyDebugNpc.BOOK_NPC = false`（不放）；`BOOK_ONLY = false`（照原版整页） | cc | 已接受（Kyo 11-12 定） |
| O-待定·测试模式 99 级 NPC | `modes/xiyou/core/lobby_debug_npc.gd` `XLobbyDebugNpc.TEST_GATE`（`sync`）；`map/map_scene.gd`（`load_map`、`_physics_process`）；`tests/xiyou_lobby_debug_npc.gd` | installTestGateRuntime：事件 69 第 1 页以开关 2501 为条件，进地图和每帧把 2501 对齐测试模式（重制原先整个没放） | 照原版放进地图并同步开关；每 30 帧查一次 | Kyo 11-12「隐藏起来，只开放给测试模式」 | `XLobbyDebugNpc.TEST_GATE = false`（不放、不同步） | cc | 已接受（Kyo 11-12 定） |

## 进度账

- 无

## 验证

- `xiyou_lobby_debug_npc` 12/12、`xiyou_floor_reach004`、`xiyou_lobby_shops`、`xiyou_lobby_corruption`、`xiyou_test_mode`、`xiyou_map`、`xiyou_event_compare*` 四片、`xiyou_achievement`、`xiyou_enemy_book`、`xiyou_battle_ui`、`xiyou_platform` 通过（`xiyou_event_compare_c` 与 `xiyou_achievement` 先挂、改测试后重跑过）。`选测.py` 因 `xdb.gd` 列 478 个，`XLobbyDebugNpc.patch_map` 只动 Map004 事件 55，没全跑。
- `语法检查.py`、`工具回归.py` 通过。

## 待交叉核查

- `modes/xiyou/core/lobby_debug_npc.gd`（新）、`core/xdb.gd`、`map/map_scene.gd`、`tests/xiyou_lobby_debug_npc.gd`（新）、`tests/xiyou_event_compare.gd`、`tests/xiyou_achievement.gd`。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 大厅全图鉴 NPC、测试模式 99 级 NPC
- （本提交）合并 main、第三期交付单
