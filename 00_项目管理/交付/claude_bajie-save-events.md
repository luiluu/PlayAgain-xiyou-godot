# 交付：claude/bajie-save-events

- 车道／工作者：规则／八戒（Claude，八戒_77）
- 状态：可合并（待 Codex 核查；没有动独占文件）
- 基线：9cab4f5b（claude/bajie-tools-sync），开工时合了 main，又重新 `--补齐`
- 来源：总装 2026-10-27 派单。第 1 项是交接板「下一步」里云端审查留下的「存档不存事件位置／朝向／路线」，第 2 项是 mv_script 正则缓存。

## 1. 地图事件状态随存档

### 原版（探针实测）

新探针 `03_转换工具/mv_oracle/save_events_probe.cjs`：
- 冻结 v0.28，新局，Map004，只用切片保留的事件。
- 流程照原版：`$gameSystem.onBeforeSave` → `makeSaveContents` → JsonEx → `extractSaveContents` → `reloadMapIfUpdated`。
- 夹具 `tests/fixtures/save_events_oracle.json`，errors 为空。

| 事件 | 做了什么 | 同版本读档 | 版本号不同 |
| --- | --- | --- | --- |
| 72 | 改位置，朝向改成朝上 | 全部还原 | 回到初始 |
| 7 | 强制路线（向下 4 格，不可跳过）走到一半：路线索引 3，仍在强制 | 全部还原 | 回到初始 |
| 73 | 路线改不透明度 128、穿透、换图像 People1／3 | 全部还原 | 回到初始 |
| 65 | 临时消除 | 全部还原 | 回到初始 |
| 36 | 开自开关 A，因此换页 | 全部还原 | 自开关另存在 `$gameSelfSwitches`，不受影响 |

「版本号不同」指 YEP_SaveCore `reloadMapIfUpdated` 同图重载，执行 `$gameMap.setup`。

原版 `$gameMap` 存档里玩家能感知的字段：
- 每个事件：`_x/_y/_realX/_realY`（含走到一半的小数位置）、`_direction`、`_pageIndex`、`_erased`、`_moveRoute/_moveRouteIndex/_moveRouteForcing`、`_characterName/_characterIndex/_tileId`、`_opacity`、`_through`、`_transparent`、`_directionFix`、`_walkAnime/_stepAnime`、`_moveSpeed/_moveFrequency`、`_priorityType`、`_pattern`。
- 地图本身：`_displayX/Y`、远景和战斗背景、`_interpreter`（正在跑的地图事件）。

探针首版有两个问题，都已修正：
- 漏了存档前的 `onBeforeSave`（它负责写入版本号），所以首版测成了「版本号不同」；
- 选的事件里有 4 个不在切片里，改选了切片内的事件。

### 重制原来的情况

- 自开关已经随档（`selfSwitches`），临时消除也已经随档（`erasedEvents`，八戒_47 dev.129），战斗背景也随档。
- 事件的位置、朝向、强制路线、路线改过的图像和不透明度等都不随档，读档后回到初始。

### 改法

改了 4 个文件，都不是沙僧的独占文件。

- `map/mv_event.gd`：
  - 新增 `save_state()`：存页号、格子坐标和实际位置、朝向、步伐帧、图像（角色图或图块）、不透明度、穿透、透明、方向固定、行走／踏步动画、速度、频率、优先级，以及正在强制中的路线和它的索引、等待帧。
  - 新增 `restore_state()`：读档时的页号和存档时不同（地图数据改过）就不套用，留在初始状态。
- `core/xstate.gd`：
  - 新增 `map_events` 和存档键 `mapEvents`，形如 `{mapId, events: {事件ID: save_state}}`。
  - 存档时通过 `map_event_snapshot`（地图场景注册的回调）现取；地图场景已经释放时退回 `map_events`。
  - 旧档没有这个键，事件就回到初始。
- `map/map_scene.gd`：
  - `load_map` 整图重建时，如果 `map_events.mapId` 等于本图，就逐个事件套用，套完清空，只套一次。
  - 换到别的地图时和 `erased_events` 一起清空。
  - 同图场所移动本来就不重建事件，不受影响。

**和原版的一处不同**：原版版本号一变（每次发版），读档就会重载地图、事件回到初始。重制没有对应的「版本号」，和已经随档的临时消除、战斗背景一样，总是还原。由于页号不同就不套用，地图数据改过时不会把旧位置套到新事件上。

### 专项 `tests/xiyou_save_events.gd`，25/25

- 参照本身：五个事件同版本读档都还原，每个都确实被改动过；事件 7 是在路线中途存的档。
- 重制按同样的操作用真实 `XMapScene`，经真实 `XSave.save`／`load_slot` 存读档，再重开地图场景，逐项比较：位置、朝向、页、消除、强制状态和路线索引、不透明度、图像、穿透、自开关。
- 读档后强制路线会接着走完，最终向下共 4 格。
- 旧档去掉 `mapEvents`：事件回到初始，临时消除和自开关照旧随档。
- 换到 Map055 再回来：改过的事件回到初始，与原版 `Game_Map.setup` 一致。
- 反向验证：去掉套用这一步，load.7、load.72、load.73、route_finishes 四项失败。

## 2. mv_script 正则缓存：早已完成，没改

`mv_script._re` 在 0f58f16d（2026-10-22「mv_script：正则按模式串静态缓存，补回归」）已经改成按模式串静态缓存，`_statements` 里 39 处都走 `_re`。

在 `map/*.gd` 和 `mv_event_core.gd` 里查过，只有 `_re` 内部一处会编译正则，没有别的地方逐条现编译，所以这次不用改。

## 验证

本工作树合 main 后重新 `--补齐`，导入 exit 0。参照批次检查没有报不同批，上一批的工具在真实环境里也验证了。

18 场，并行 2，`--full`，用时 816 秒，全部单次通过：

| 类别 | 场景与项数 |
| --- | --- |
| 新专项 | xiyou_save_events 25 |
| 存读档、地图、场所移动 | xiyou_battleback_save 5、xiyou_save_page 40、xiyou_transfer 38、xiyou_flow 48、xiyou_map 397、xiyou_options_misc 86 |
| 解释器、脚本 | xiyou_interp_review 13、xiyou_review_regressions 29、xiyou_script 21 |
| 随档的随机与确定性 | xiyou_determinism 372、xiyou_random_streams 488 |
| 楼层流程 | xiyou_floor_run 273 |
| 事件对照 | xiyou_event_compare 5/5。上次因本树 generated 不同批而假失败，合 main 并重新补齐后通过 |
| 规则难度 1 四段 | xiyou_rules 115637、xiyou_rules_d1b 115733、xiyou_rules_d1c 115746、xiyou_rules_d1d 115725 |

- d1b、d1c 单场用了约 336 秒，并行测试工具提示「超过上限的一半」，原因是机器满载，不影响结果。
- 必跑项：MV 守卫、`git diff --check` 在提交前核对过。
- 没跑全量。
- 日志在 `03_再刷重制_Godot/04_验证/本地结果/20261027_八戒_存档/`，不入 Git。

## 待交叉核查

- 本分支提交（执行者: Claude（八戒），核查: 待Codex）。

## 可优化

- 探针选事件之前，先用 `generated/slice.json` 的 `keepEvents` 确认事件在切片里，这次首版就是因为没查才选错了 4 个。
- 共用槽排队：补齐的导入等了约 27 分钟。

## 变更记录草稿

## 2026-10-27 【Claude·八戒·未经Codex检验】地图事件位置、朝向、强制路线和路线改过的外观随存档（dev.待定）

- 照原版同版本读档不重设地图：当前地图事件的位置（含走到一半）、朝向、强制路线及其索引、路线改过的图像、不透明度和穿透等，存进新存档键 `mapEvents`，读档后套回。旧档没有这个键就回到初始；页号对不上不套；换到别的地图会清掉。
- 新原版探针（Map004 五个事件）和新专项 25 项；mv_script 正则缓存早在 0f58f16d 已完成，这次没改。
