# 交付：luiluu/t460

- 车道／工作者：小A（Neon＋high，P8；同分支另含小o T487 洪荒碑正式美术贴图）
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【小A·未经审查】T460：西游大厅洪荒碑＋进西游档一次性首通播报（dev.待定）

- **依据**：Kyo 11-24 / 11-25 拍板进 v0.04.02；本单落实卡上验收第 3 条（西游大厅洪荒碑）、第 7 条（进西游档一次性播报）及第 5 条（回退开关、天启篇不受影响）；称号、兑换码、图标与颜色（第 1、2、4、8、9、10 条）留给后续单。位置按 Kyo 11-25 新定放至大厅上方红毯楼梯右侧原花盆位 `(18, 9)` 并去花盆；名字按 Kyo 11-25 01:4x 新定为「大手子」；播报文案已由 Kyo 11-25 亲自定稿；碑图由小o T487 接入正式朱漆镇碑贴图。
- **改动**：
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/honghuang_first_clear.json`：
    - 新增首位洪荒证道者配置文件，字段 `first_clear_player` 现配为 `"大手子"`；留空时不显示名字且不弹进游播报。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/honghuang_monument.gd`（`class_name XHonghuangMonument`）：
    - 新增回退开关 `ENABLED := true`（置 `false` 即整套无痕关闭：大厅无碑、原花盆与三阶程序件完整恢复、不弹播报、不写存档标记）。
    - 大厅洪荒碑逻辑：`MAP_ID = 4`、`EVENT_ID = 82`、`CELL = Vector2i(18, 9)`（避开原版 1～77、庆典 78～81、漩涡 201～207，位于上方红毯楼梯右扶手外侧，不挡楼梯 `x=12..16` 通行，玩家从 `(18, 10)` 面朝上调查）。
    - `tile_map_data(map_id, data, s)`：仅西游档开碑时返回给 `MVTilemap` 的浅拷贝视图，清除 `(18, 8..9)` 原花盆／烛台图块（`z=3` 置 0）并将 `(18, 9)` 蓝地垫换为白大理石 `1542`；不动 `XDB.map(4)` 缓存，天启档与回退关闭原样保留花盆。
    - `hides(map_id, event_id)`：在天启档（`XTianqi.active(s)`）或 `ENABLED == false` 时隐藏 EV82（空页、可穿过、不触发）。
    - 进西游档一次性播报：`arm_entry()` 由标题读档／继续／西游新游戏及游戏内读档入口武装，进入正式地图空闲时由 `consume_broadcast(s, map_id)` 消费并写入 `s.flags["honghuang_first_clear"]["broadcast_seen"] = true`（不改 `XState` 顶层存档结构，老存档读入也只弹一次；开局三图 `1/2/221` 不打断开局，到厅后弹；天启档、留空、回退关闭均不弹不写标记）。
  - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/honghuang_monument_view.gd`（`class_name XHonghuangMonumentView`）：
    - 大厅洪荒碑视觉层：优先加载 `TEX_PATH = "res://content/lobby/honghuang_monument.png"`（小o T487 正式朱漆镇碑贴图，脚底居中锚点，挂入 `host.chars` 参与 `y_sort`）；无图时走程序兜底绘制（字体走 `XUiSkin.ds` 符合 T100 规范）。
    - 三阶整图去花盆覆盖层 `_stage3_cover`（`z_index = -8`，在 `Stage3Backdrop` -9 之上、角色与碑 0 之下）：自动从当前三阶底图（`hall_stage3_backdrop.png` 或 `hall_stage3_backdrop_fest.png`）采样干净北隔墙 `(21, 8)` 与地砖 `(18, 10)` 无缝覆盖原画入整图的花盆，平时／庆典一致且回退开关关闭即原样复原。
  - 挂点与配套修改：
    - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/xdb.gd`：`XDB.map` 接入 `XHonghuangMonument.cache_stale()` 与 `patch_map()`。
    - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/mv_event.gd`：`_is_hidden_event()` 接入 `XHonghuangMonument.hides()`。
    - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/mv_script.gd`：`run()` 转交 `CodexHonghuang.` 脚本至 `XHonghuangMonument.run_script()`。
    - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/map_scene.gd`：`load_map()` 使用 `tile_map_data()`、放行 `keep_event()`、挂载 `_setup_monument_fx()`；`_process()` 空闲时调用 `_check_honghuang_broadcast()`。
    - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/lobby_corruption.gd`：`STAGE3_DECAY_FURNITURE` 的 `north_table_e` 与 `STAGE3_DECAY_LAMPS` 的 `north_candle_e` 增加 `monument_hide` 标志，西游档开碑时隐藏、回退关碑或天启档恢复。
    - `03_再刷重制_Godot/01_Godot工程/modes/xiyou/entry.gd` & `modes/xiyou/ui/menu.gd`：标题继续／读档／西游新开局与游戏内读档切入地图前调用 `XHonghuangMonument.arm_entry()`。
  - 测试与夹具更新：
    - 新增 `03_再刷重制_Godot/01_Godot工程/tests/xiyou_honghuang_monument.gd`（＋`.tscn`）：67 项断言覆盖配置读取／留空、`(18, 9)` 碑体／去花盆／楼梯不挡／调查、一二三阶×平时庆典、老存档真写盘读档一次性播报／幂等／多档独立／开局延迟、天启大厅零影响与原花盆保留、回退开关无痕恢复，并附 8 张原尺寸实机截图模式。
    - 既有测试对齐：`tests/xiyou_fest_lobby.gd`（精确查庆典 78～81 事件）、`tests/xiyou_lobby_corruption.gd`（洪荒碑隐藏 `north_table_e`/`north_candle_e` 后腐败家具 8/庆典 6、灯 4/庆典 2）、`tests/xiyou_event_compare.gd`／`tests/xiyou_floor_reach004.gd`／`tests/xiyou_rift2_canglong.gd`（原版对照夹具同 `XFestLobby` 一并关闭 `XHonghuangMonument.ENABLED`）。
- **玩家可见**：西游模式方桌大厅上方红毯楼梯右侧新增可调查的「洪荒碑」，铭刻首位洪荒证道者「大手子」；首次进入西游存档时会弹出一次性洪荒首通播报（每个存档仅弹一次）。

## 玩家可见文字（全文，Kyo 11-25 定稿）

1. **进西游档一次性播报**（配置有名 `大手子` 时弹，留空不弹）：
   ```
   【洪荒首通播报】
   恭喜「大手子」成为首位通关洪荒难度的玩家！
   这个名字已经刻在大厅的洪荒碑上，有空可以去看看。
   ```
2. **大厅洪荒碑调查文字**：
   - 配置有名字（`大手子`）时：
     ```
     【洪荒碑】
     首位洪荒证道者：大手子
     ```
   - 配置留空时：
     ```
     【洪荒碑】
     石碑上暂时还没有刻下名字。
     ```

## 交接板

- 下一步：T460 剩余验收项（第 1、2、4、8、9、10 条：称号「洪荒证道」「洪荒·阿夜」／流光色、一次性绑存档兑换码、称号图标）留待后续单；本分支与小o T487 洪荒碑美术合并后可直入 v0.04.02。
- 用户试玩说明：进西游档（老存档或新档到厅）首次会弹出一次性「洪荒首通播报」，每个存档只弹一次；方桌大厅上方红毯楼梯右侧原花盆处立起「洪荒碑」，走近 `(18, 10)` 面朝上按确认可调查查看首位洪荒证道者「大手子」。天启篇存档与大厅不受任何影响。
- 需要用户决定：无（位置、去花盆、播报第二行改字、名字改「大手子」及朱漆镇碑美术均已由 Kyo 11-25 拍板）。

## 进度账

- 西游重制／洪荒首通奖励①（T460）：本单完成大厅洪荒碑与进游一次性播报（验收第 3、5、7 条）并接入 T487 正式碑图；称号与兑换码留后续单。

## 可优化（流程／工具／效率）

- 已做：三阶整图去花盆采用运行时 `z=-8` 采样同张底图干净墙面／地砖覆盖，既零改动 1.8MB 整图原件、同时兼容平时与庆典两套三阶底图，又保证回退开关 `XHonghuangMonument.ENABLED = false` 一键无损复原。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XDB.map` | 178 处（`git grep -nE 'XDB\.map[[:space:]]*\(' -- '03_再刷重制_Godot/01_Godot工程/*.gd'`；其中 `modes/` 下 11 处、`tests/` 下 167 处） | 调用方 178 处逐处结论：`modes/` 下 `liuying.gd:825`、`xsave.gd:304,331`、`zhenqi.gd:176`、`save_scene.gd:288`、`skin_save_page.gd:167`、`tianqi_hall_intro.gd:155`、`map_scene.gd:1495` 仅读 `displayName`/`note`/判空，不受 Map004 追加 EV82 影响；`map_scene.gd:473` 载入地图事件配合 `XHonghuangMonument.keep_event` 与 `MVEvent._is_hidden_event`（`hides`），西游档可见可调查、天启档与回退开关关闭完全隐藏；去花盆改由 `tile_map_data` 提供浅拷贝视图，不污染 `XDB.map(4)` 缓存；`tests/` 下 167 处调用中涉及原版 Map004 严格事件数对照的 `xiyou_event_compare`、`xiyou_floor_reach004`、`xiyou_rift2_canglong` 已同 `XFestLobby` 对齐关闭 `XHonghuangMonument.ENABLED`。 |
| `XHonghuangMonument.ENABLED`（新增回退开关） | 本模块 `monument_active`/`should_broadcast`/`consume_broadcast`/`cache_stale`/`patch_map`/`keep_event` 及测试夹具读取，默认 `true` | 置 `false` 时 Map004 不追加 EV82、不建视觉层、保留原 `(18, 8..9)` 花盆与三阶 `north_table_e`/`north_candle_e`、不弹播报且不写 `s.flags`，已在 `xiyou_honghuang_monument.gd` 的 `rollback.*` 断言验证。 |

## 验收逐条核对

1. **验收第 1、2、4、8、9、10 条（称号／兑换码／图标／颜色）**：本单不做（按「这一单的话」留给后续单）。
2. **验收第 3 条（大厅洪荒碑可调查、文字『首位洪荒证道者：<名>』、配置读、留空不显名）**：通过。立于西游大厅 Map004 `(18, 9)` 原花盆位（不挡楼梯，全阶去花盆），从 `honghuang_first_clear.json` 读「大手子」，调查显示「首位洪荒证道者：大手子」，留空显示「石碑上暂时还没有刻下名字。」不露名字与空冒号。
3. **验收第 5 条（回退开关、天启篇不受影响）**：通过。`XHonghuangMonument.ENABLED = false` 全套无痕回退；天启大厅无碑、保留原花盆、不弹播报、不写 `s.flags`，已由 `tianqi.*` 与 `rollback.*` 专项断言＋天启大厅实机截图验证。
4. **验收第 6 条（玩家可见文字过文字审）**：通过。播报与碑文全文已由 Kyo 11-25 亲自审定定稿（第二行改「这个名字……」，名字改「大手子」）。
5. **验收第 7 条（进西游档一次性播报、每档一次、老存档读入也只弹一次）**：通过。`arm_entry()` 覆盖标题读档／继续／西游新游戏及游戏内读档，老存档真写盘读档验证弹一次并写入 `s.flags["honghuang_first_clear"]["broadcast_seen"] = true`，同局换图与存档重读不再重复，他档独立弹一次，留空不弹不写标记。

## 实机截图（均已入仓）

- 三阶腐败大厅·平时（主图）：`00_项目管理/归档/交付截图/luiluu_t460/t460_xiyou_stage3_regular.png`
- 三阶腐败大厅·庆典：`00_项目管理/归档/交付截图/luiluu_t460/t460_xiyou_stage3_fest.png`
- 二阶初步异化大厅·平时：`00_项目管理/归档/交付截图/luiluu_t460/t460_xiyou_stage2_regular.png`
- 一阶常态大厅·平时：`00_项目管理/归档/交付截图/luiluu_t460/t460_xiyou_stage1_regular.png`
- 一阶常态大厅·庆典：`00_项目管理/归档/交付截图/luiluu_t460/t460_xiyou_stage1_fest.png`
- 三阶大厅调查洪荒碑弹窗（「首位洪荒证道者：大手子」）：`00_项目管理/归档/交付截图/luiluu_t460/t460_xiyou_monument_inspect.png`
- 三阶大厅进西游档一次性播报弹窗（Kyo 定稿全文）：`00_项目管理/归档/交付截图/luiluu_t460/t460_xiyou_entry_broadcast.png`
- 天启大厅同机位对照（无碑、原花盆保留）：`00_项目管理/归档/交付截图/luiluu_t460/t460_tianqi_hall_no_monument.png`

## 测试与校验

- 云端选测：
  - 首轮（提交 `e0ba654762`，run `45515244017`）：697 个场景中 693 通过，4 项失败（`xiyou_ui_skin` 裸 `draw_string`、`xiyou_event_compare`／`xiyou_floor_reach004`／`xiyou_rift2_canglong` 原版 Map004 对照未关 `XHonghuangMonument`），均已在 `264b936f2` 修复。运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45515244017
  - 复跑（提交 `264b936f2c`，`ci/luiluu/t460`，基准 `fb0c7d2042`，777 场景、16 片）：**全部通过**（最长一片 18.0 分钟；偶发并行失败、单跑通过算通过：`xiyou_tianqi_brand.tscn`、`xiyou_tianqi_deck_phys_amp.tscn`）。后续 `366f38759` 仅改 `honghuang_first_clear.json` 与 `tests/xiyou_honghuang_monument.gd`（「阿夜」→「大手子」），不涉其他 `.gd`，本机专项 67/67 复验通过。运行页：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/45520376743
- 本机专项与静态检查（前台单跑，`--audio-driver Dummy`）：
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：82 个脚本，812 个函数全部通过（退出码 0）
  - `xiyou_honghuang_monument.tscn`：67/67 通过（含「大手子」改名后复验）
  - `xiyou_lobby_corruption.tscn`：205/205 通过
  - `xiyou_fest_lobby.tscn`：155/155 通过
  - `xiyou_tianqi_hall.tscn`：74/74 通过
  - `xiyou_ui_skin.tscn`：111/111 通过
  - `xiyou_rift2_canglong.tscn`：85/85 通过
  - `xiyou_floor_reach004.tscn`：207/207 通过
  - `xiyou_party.tscn`：58/58 通过

## 本分支提交

- `e0ba65476` T460：西游大厅洪荒碑＋进西游档一次性首通播报（含配置、回退开关、专项测试与实机截图）
- `42a74b7e1` WIP: T487 洪荒碑三款原尺寸样稿（小o）
- `1e9241c08` WIP: T487 更新三阶大厅楼梯旁原尺寸对比（小o）
- `56270a413` T460：洪荒碑迁至上方楼梯右花盆位 (18,9) 并全阶去花盆＋Kyo 定稿播报文字与实机截图
- `b2b5b3eb9` T487：接入朱漆镇碑并归档六场实机截图（小o）
- `e189fca05` Merge branch 'main' into luiluu/t460
- `264b936f2` T460：修复云端选测 4 项（XUiSkin.ds 替代裸 draw_string；原版对照夹具关闭 XHonghuangMonument）
- `366f38759` T460：配置首位洪荒证道者改名为「大手子」并更新测试断言与碑文／播报截图
- `b7df9f47a` T460：提交初版交付单 luiluu_t460.md
- `ec9302145` T487：向交付单追加正式美术段与复验记录（小o）

## T487 正式美术

- Kyo 11-25 选定 C「朱漆镇碑」。正式贴图为 96×155 透明 PNG，含 Godot 导入描述。在西游大厅沿用脚底居中锚点。
- 静音实机复验三个阶段的平时和庆典。共 42/42 项核对通过，覆盖正式贴图加载、楼梯右侧落点、原摆件移除、三阶遮罩和完整取景。六张截图均为 1280×720 原尺寸。

| 大厅 | 平时 | 庆典 |
| --- | --- | --- |
| 一阶 | `00_项目管理/归档/交付截图/luiluu_t487/t487_stage1_regular.png` | `00_项目管理/归档/交付截图/luiluu_t487/t487_stage1_fest.png` |
| 二阶 | `00_项目管理/归档/交付截图/luiluu_t487/t487_stage2_regular.png` | `00_项目管理/归档/交付截图/luiluu_t487/t487_stage2_fest.png` |
| 三阶 | `00_项目管理/归档/交付截图/luiluu_t487/t487_stage3_regular.png` | `00_项目管理/归档/交付截图/luiluu_t487/t487_stage3_fest.png` |

- 本地静音专项复验：`xiyou_honghuang_monument.tscn` 67/67，`xiyou_lobby_corruption.tscn` 205/205，`xiyou_fest_lobby.tscn` 155/155。工具回归 24/24，发行空壳检查退出码 0。
- T460 修正原版对照夹具后，本地复跑 `xiyou_event_compare.tscn` 14/14、`xiyou_floor_reach004.tscn` 207/207、`xiyou_rift2_canglong.tscn` 85/85、`xiyou_ui_skin.tscn` 111/111。
