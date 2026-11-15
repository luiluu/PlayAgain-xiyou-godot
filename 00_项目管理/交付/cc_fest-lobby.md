# 交付：cc/fest-lobby

- 车道／工作者：乙 大厅庆典（cc，Sonnet＋medium；本单配 Sonnet＋medium，因为照现有大厅叠加层先例做、加文案，机械活）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·未经审查】冠军庆典·乙：大厅庆典叠加层＋庆典使者贺礼＋报名处＋全部文案（O-待定，dev.待定）

- 玩家可见：庆典期间进方桌大厅，南段挂着「恭喜 BLG 夺得 2026 全球总决赛冠军」的红金横幅和彩旗，奖杯立在漩涡北边，天上飘彩带、偶尔放烟花，大厅换成欢快的背景音乐；奖杯左边有「报名处」、右边有「庆典使者」。第一次找使者说贺词并领贺礼（庆典币 50、精魂 5000、中治疗药水 ×10、中魔力药水 ×10），之后可问「冠军之路是什么」「四支战队」；调查奖杯有三段话。活动结束后收尾期只留使者，再往后什么都没有。
- 开关（全部 O-待定，一处关掉整套无痕）：`XFestLobby.ENABLED`（大厅叠加层＋使者／报名处／奖杯＋BGM）；总开关与日期读甲车道的 `XFest`（`ENABLED`、`START`、`DAYS`、`GRACE_DAYS`）。
- 新增文件（独占）：
  - `modes/xiyou/map/fest_lobby.gd`（`XFestLobby`）：叠加层（横幅、彩旗、奖杯贴图、彩带、烟花，跟「画面特效」开关和省电模式走）、Map004 追加事件 78～81 的补丁（使者 78；报名处 79、奖杯 80／81 只在活动进行中）、活动期间把大厅 BGM 换成 `BGM`、脚本入口（`CodexFest.envoy()`／`enroll()`／`trophy()`）、贺礼、使者菜单、报名处菜单。
  - `modes/xiyou/core/fest_text.gd`（`XFestText`）：**全部文案**一个文件：贺词（引用 `XFest.CONGRATS`）、奖杯三段、使者台词、报名处台词、四支战队介绍（网吧队／银河战舰队／大魔王队／内战幻神队，各一句，不点真名）、位置名与敌人显示名函数 `enemy_name(队序,位序)`、四个称号文字、五条成就文字、六位 NPC 彩蛋台词＋气泡小字、大厅飘字。
  - `tests/xiyou_fest_lobby.gd`／`.tscn`：专项 110 项。
  - `content/fest/`：co 交的美术（`Fest_Banner.png` 768×96、`Fest_Trophy.png` 96×144、`Fest_Confetti_01～04.png`，已接上，没有图时程序画占位照旧能用）。
- 改共用文件（各只加几行，不改原行为）：
  - `modes/xiyou/core/xdb.gd`：`map()` 里多一行 `XFestLobby.patch_map`。
  - `modes/xiyou/map/map_scene.gd`：`keep_event` 多一个 `or`，加 `fest_fx` 变量和 `_setup_fest_fx()`（换图拆旧、大厅且活动中才建）。
  - `modes/xiyou/map/mv_script.gd`：`run()` 开头多 5 行，`CodexFest.` 开头的脚本转交 `XFestLobby.run_script`。
  - `tests/xiyou_event_compare.gd`：对照原版语义关掉 `XFestLobby.ENABLED`（同文件里其它优化开关的惯例；使者等是追加的 Map004 事件，原版没有）。
- 位置：报名处 (20,17)、奖杯占 (21,17)(22,17)、使者 (23,17)，都在异化中心 6 格圈外（返修后）。横幅挂行 23～24、x 264～1032（进大厅第一眼看到）。
- 验证：
  - `tests/xiyou_fest_lobby.tscn`：110/110。覆盖：活动内（叠加层、事件 78～81、BGM 换、正式美术、奖杯挡路、彩带烟花、(14,16) 可走）、收尾期（只剩使者）、活动前与结束后（无节点、事件表／通行／BGM 与基线逐项相同）、两个开关各自关掉无痕、贺礼只领一次（庆典币／精魂／物品只加一次、存档往返、旧档当没领过）、使者菜单与扩展菜单项、报名处占位与看战队、画面特效关掉不放粒子、文案（真名只在贺词一处；英雄联盟／官方／选手名等禁词、西游词共 40 多项都不出现；四队名、敌人显示名、四称号、五成就、彩蛋事件号都在）。
  - `tests/xiyou_lobby_corruption.tscn` 45/45、`xiyou_lobby_debug_npc.tscn` 12/12（大厅异化层、调试 NPC 不受影响）。
  - `语法检查.py`：0 个问题。`发行空壳.py check`：通过。`工具回归.py`：全部通过。
  - 截图（有窗口实机，git 忽略目录）：`03_再刷重制_Godot/04_验证/本地结果/fest_lobby/` 下 `fest_lobby_south.png`（南段横幅彩旗）、`fest_lobby_trophy.png`（奖杯、使者、报名处）、`fest_lobby_firework.png`（烟花）、`fest_lobby_envoy.png`。
- 提交：见「本分支提交」。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/map/fest_lobby.gd` `XFestLobby`、`core/fest_text.gd`、`core/xdb.gd` `map`、`map/map_scene.gd` `_setup_fest_fx`／`keep_event`、`map/mv_script.gd` `run`；`content/fest/`；`tests/xiyou_fest_lobby.gd` | 方桌大厅没有庆典装饰、使者、报名处、奖杯，BGM 固定 TCLH-60 | 冠军庆典期间（`XFest.START` 起 `DAYS` 天，之后 `GRACE_DAYS` 天只留使者）大厅叠加横幅、彩旗、奖杯、彩带烟花，追加使者／报名处／奖杯事件，换大厅 BGM，第一次对话发一次贺礼 | Kyo 2026-11-15 为庆祝夺冠要的限时庆典（方案：私密设计仓 重制设定/冠军庆典活动_v0.2.md） | `XFestLobby.ENABLED = false`（或 `XFest.ENABLED = false`）：地图事件表、通行、BGM 与没有活动时逐项相同（`tests/xiyou_fest_lobby.gd` 两个开关分别验证）；活动日期过了也自动没有 | cc | 保留 |

## 交接板

- 下一步：冠军庆典甲车道合并后，总装出**补丁**（只推补丁和清单；等 Kyo 说「推」）；Kyo 听两首备选 BGM 定一首（见下）。
- 用户试玩说明：补丁装上后（活动日内）进方桌大厅可见横幅、彩旗、奖杯、彩带、使者（右）、报名处（左）；使者第一次领贺礼；报名处在冠军之路接通前会说「赛场还在搭台子」。
- 需要用户决定：无新增（活动天数 D20 已由甲改 15 天；奖励量 D21 按「称号成就为主＋少量资源」先填，量在 `XFestLobby.GIFT` 表里，可改）。BGM 默认 `MZre_Town1`，我没法试听，备选 `Number One`、`MVre_Town1`、`Town_real2_mvt`（`XFestLobby.BGM` 改一个字符串）。

## 进度账

- 冠军庆典：大厅庆典＋使者贺礼＋报名处＋全部文案（乙）完成；冠军之路四关（甲）、第 2 天签到／兑换／成就／彩蛋（ag）不在本单。

## 返修（co 抽核 1b753c577）

- P2① 大厅地图缓存：`XDB.map(4)` 每次读图先问 `XFestLobby.cache_stale()`（开关＋可见／进行中状态＋BGM 的戳变了就作废缓存重做补丁），跨过活动起止日再进大厅不用手动清缓存。专项新增 `cache.*` 4 项（先读大厅→改 `TODAY_OVERRIDE` 跨日期→不清缓存再进：开始日有 NPC 和叠加层、收尾期只有使者、结束后全空）；把 `cache_stale` 改成恒真后这两项会失败，确认咬得住。
- P2② 位置：使者 (23,17)、奖杯 (21,17)(22,17)、报名处 (20,17)，全在异化中心 (14,19) 的 6 格圈外（专项逐个核距离 >6）。横幅仍挂行 23～24，是叠在上空的装饰，不碰地面层，没挪。（原 (14,16) 留空的顾虑随之消失。）
- P3 使者台词改「奖杯旁边的报名处」，不再写左右。
- 专项 110/110；重截 4 张截图（`fest_lobby_south/trophy/firework/envoy.png`）。

## 与甲、ag、总装的接口（合并时请对一下）

1. **甲的 `XFest`**：已 cherry-pick 甲 `6a3efc739`、`d0eaba585`（只读用，没改 `fest.gd`、`designation.gd`）。合并时 git 会识别为同一提交，不冲突。我在 `XFest.data(s)` 里加了 3 个键：`envoy_gift`（贺礼领过）、`envoy_met`（成就「我在现场」读它）、`trophy_looks`；请甲别占用这些键名。
2. **报名处调甲的入口**：`XFestRoad.enter(interp)`（全局类 `XFestRoad` 的静态协程方法 `enter`，`interp` 是事件解释器，可 `await interp.host.…`）。甲没合进来之前报名处说「赛场还在搭台子」；类名或方法名不同的话，改 `XFestLobby.ROAD_CLASS`／`ROAD_METHOD` 两个常量即可。入口里需要选档位、开战等都自己做，我这边只负责「报名」选项和战队介绍。
3. **敌人显示名**：甲建敌人时用 `XFestText.enemy_name(队序 0～3, 位序 0～4)` 得「网吧队·上单」，队名与介绍在 `XFestText.TEAMS`。
4. **ag 第 2 天**：使者菜单加「今日签到」「兑换」往 `XFestLobby.EXTRA_MENU` 追加 `{"label": 文字, "call": Callable(interp) 协程}`，不用改本文件（收尾期也会显示这些项）；称号、成就、彩蛋文字都已在 `XFestText`（`TITLE_TEXTS`、`ACHIEVEMENTS`、`EASTER_LINES`、`BUBBLE_LINES`），彩蛋对应的 Map004 事件号已在专项里核过存在。
5. **`tests/xiyou_event_compare.gd` 会冲突**：我在「大厅全图鉴 NPC」那行后面加了 `XFestLobby.ENABLED = false`；甲的称号 41～44 接进了称号表，选称号公共事件的选项变多，`xiyou_event_compare`（m4e1p3）和 `xiyou_designation`（`table` 35≠31、选项文字）都因此失败（关掉 `XFest.ENABLED` 后 `xiyou_event_compare` 14/14，已验证）。这两处是甲那一单的后果，请甲或总装在 event_compare 里同样关 `XFest.ENABLED`（同一位置附近，可能和我加的行相邻冲突，两行都留即可），`xiyou_designation` 的期望值按甲的表更新。**不是我这一单引起的**。
6. 补丁里新增了三个 `class_name`（`XFestLobby`、`XFestText`，甲还有 `XFest`）：出补丁前按「补丁叠加验证」跑一次新增全局类。
7. `xiyou_lobby_shops` 的 `case_e54p0_base_0-0`（inventory 名字空）关掉 XFest 后在本分支同样失败，与本单无关（疑为 main 既有）。

## 可优化（流程／工具／效率）

- 已做：无。
- 建议：测试里「今天」要用 `XFest.TODAY_OVERRIDE`＋`XFestLobby.reload_map()`（清 Map004 缓存让补丁按当天重做），以后做按日期出现的内容照这个写（预计收益：免得测试被本机日期影响）。
- 建议：`event_compare` 之类对照原版的整轮测试，遇到限时活动要统一关开关；可在测试夹具 `xiyou_test_env.gd` 里加一个 `TestEnv.original_semantics()` 一次关掉所有「追加内容」的开关，以后不用每个活动去改 event_compare（归总装／测试工具车道）。

## 本分支提交

- 见 `git log main..cc/fest-lobby`（含 cherry-pick 甲 6a3efc739、d0eaba585）
