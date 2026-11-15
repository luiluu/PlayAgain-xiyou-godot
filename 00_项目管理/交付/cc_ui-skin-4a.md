# 交付：cc/ui-skin-4a

- 车道／工作者：B 界面·新皮肤 4A（地图 HUD、触屏键、全局横向铺满）＋战斗可读性（A5／C7／C8）／cc（Opus＋medium，派单定：动地图 HUD、全局 20:9 铺满和战斗演出，牵涉面广但不改结算）
- 分支：`cc/ui-skin-4a`（从 `cc/ui-skin-close` 7c37b8321 切出；收口批还没进 main，没有合 main——派单定收口批进 main 后再合）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·天启篇·未经审查】新界面 4A：地图 HUD 换黑金胶囊、宽屏铺满、战斗字加底、背景压暗、闪白限频（dev.待定）

- 玩家可见：天启篇新界面里，地图左上的挂机钮（原来的柠檬图）、右上的「存档备份」「地图传送」、左下的回城枫叶和坐标难度字，统一换成黑底旧金的胶囊，排在右上角（手机上排在「隐藏按键／Save」下面），不再压在左下摇杆上；挂机中的提示条换成黑金条。手机虚拟键（摇杆、A／B、信息、存档、隐藏）换成黑底旧金边。20:9 这类宽屏手机上，地图和战斗左右不再留黑边，按钮贴着屏幕安全边距摆；平板 4:3 照旧上下留边。战斗里回合提示、首领名和血量、敌人名字和血量数字都垫了深色胶囊底，雪地、沙漠上也看得清；设置「画面」里新加「战斗背景压暗：关／15%／30%」（默认 15%）。战斗变速开到 2 倍时受击闪白减半，3 倍及以上不闪白只留数字，整屏闪光每秒最多 3 次。手机上战斗指令环会让开右下的 A／B 键。只在天启篇新皮肤生效，重制版旧界面不变。
- 依据：私密设计仓 `重制设定/界面风格提案_v0.7/` README 第二节「横屏铺满」四条与第四节第 4 批（4A），Fable审_实装与方向 A5、A17、C7、C8、P1-2，小A审_美化舒适 1（亮图压暗）、9（地图 HUD 统一黑金胶囊）。
- 改动（开关全在新文件 `modes/xiyou/ui/skin/skin_4a.gd` 的 `XSkin4A`，都默认开；只在 `XUiSkin.on()` 时生效）：
  - `HUD_V2`：`XMapHUD` 三个按钮改画胶囊（程序画小图标：回城门洞、存档方盒、传送罗盘；`content/ui_skin/hud/hud_<名字>.png` 有图就用图——给小o的新图标留的口子），右上一排贴 `XSkin4A.safe_rect`，触屏时排在 y 60；坐标＋难度收成一枚胶囊放在按钮下面；回城按钮（TextureButton）开着时去掉贴图、画胶囊。`XHangUpOverlay` 快捷界面改成左上一枚胶囊（琥珀点亮＝挂机中、整枚可点），挂机提示改黑金条、按可见宽度居中。`XTouchControls` 皮肤开着时按键黑底旧金边、字旧金，原版摇杆改黑底金圈、摇杆头深褐金，空闲不透明度 0.85；`XSkinBattle.style_toggles` 自动／变速跟挂机胶囊左对齐。
  - `WIDE_V2`：`XMapScene` 在「没开菜单、没开按 1280 排的旧页面」时 `XSkinLayout.request_wide`（ui 层加进来的不是地图自己的叠加层、黑幕、战斗、新皮肤全屏页、大厅小字的，算旧页面，开着就收回 16:9，关了再铺满；令牌节点 `WideToken`）；`XBattleScene._ready` 自己 `request_wide`，原版坐标的东西照旧按 `_origin` 居中；地图快照在铺满时保留宽度（地图比画面窄时只取中间 16:9），战斗里宽快照照原尺寸铺开、16:9 快照底下垫一张放大压暗的同图延展两侧；天气暗幕和粒子、遇敌拉近、大厅氛围小字按可见宽度；`XTouchControls.default_position／drag_bounds` 按可见宽度贴边；战斗里旧图鉴页收在中间 16:9。
  - `TEXT_V2`（A5）：`XSkin4A.draw_text_backing` 深色胶囊底（不描边、62%），用在指令环「某某的回合」、首领血弧的名字和数字、敌人头顶名字和血量数字。
  - `DIM_V2`（C8）：`XConfig` 新键 `codexBattleDim`（0／15／30，默认 15，存设置文件、跟存档无关）；设置页「画面」类新加「战斗背景压暗」一行（只在新皮肤开着时列）；`XBattleScene` 在背景（含两种领域）之上、角色之下加 `BattleDim` 黑层（画面三倍大，镜头拉近拉远都盖得住）。
  - `FLASH_V2`（C7）：只压画出来的透明度，闪光帧数、行动时序、结算都不动。`MVAnimation` 目标闪光乘 `target_gain`、屏幕闪光乘 `screen_gain`；`XBattleScreen`（事件 224）乘 `flash_gain`；`XBattlerSprite.flash`（行动序列 WHITEN）按系数插值。系数：变速 1 倍 1、2 倍 0.5、3 倍及以上 0（MV 动画按 rate 算倍数，再乘全局变速齿轮）；整屏闪光离上一次画出来的不到 1/3 秒就不画（每秒最多 3 次）。
  - 战斗触屏：指令环固定右下（收口批 TOUCH_V2）时，`XSkin4A.avoid_touch_keys` 让它挪到 A／B／信息键组左边（HUD_V2 关着不动）；圆形虚拟键边框 1→2px（1px 时圆正中有一道接缝）。
- 震屏：战斗里没有整屏震动可调——`SHAKE SCREEN` 行动序列在重制里不演，事件 225 只在地图上，首领血弧（新皮）不震；所以 C7 的「震屏变弱」本单没有落点（见「没做的」）。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/ui/skin/skin_4a.gd` `XSkin4A.HUD_V2`；`map/map_hud.gd`、`map/hang_up_overlay.gd`、`core/touch_controls.gd`、`ui/skin/skin_battle.gd` | 地图上柠檬色挂机图、绿灰存档钮、白底绿字传送钮、左下枫叶和白字坐标难度混在一起，回城枫叶压在左下摇杆区；虚拟键灰底绿字、白底红芯摇杆 | 统一黑底旧金胶囊排右上安全边距（触屏排在隐藏／存档键下），坐标难度一枚胶囊；挂机胶囊带琥珀状态点；虚拟键黑底旧金边 | Fable审 A17、小A审 美化 9、README 第四节第 4 批 | `XSkin4A.HUD_V2 = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_4a.gd` `XSkin4A.WIDE_V2`；`map/map_scene.gd`、`battle/battle_scene.gd`、`map/screen_fx_view.gd`、`map/lobby_corruption.gd`、`core/touch_controls.gd` | 地图与战斗固定 16:9，20:9 屏左右各一条黑边 | 地图（无旧页面时）和战斗横向铺满，HUD、虚拟键贴安全边距；窄地图快照取中间 16:9、战斗两侧延展；4:3 照旧上下留边 | README 第二节「横屏铺满」、Kyo 11-15 定 D26 | `XSkin4A.WIDE_V2 = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_4a.gd` `XSkin4A.TEXT_V2`；`battle/battle_scene.gd`、`ui/skin/skin_boss_arc.gd`、`ui/skin/skin_battle_ring.gd` | 战斗里飘在画面上的字只有细描边，雪地、沙漠上看不清 | 回合提示、首领名和血量、敌人名字和血量数字垫深色胶囊底 | Fable审 A5／P1-2 | `XSkin4A.TEXT_V2 = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_4a.gd` `XSkin4A.DIM_V2`；`core/xconfig.gd`、`ui/options_scene.gd`、`ui/skin/skin_options_page.gd`、`battle/battle_scene.gd` | 亮地图战斗背景刺眼、黑界面和白背景来回切 | 设置「战斗背景压暗：关／15%／30%」（默认 15%），背景和角色之间盖一层黑 | Fable审 C8、小A审 舒适 1 | `XSkin4A.DIM_V2 = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/skin_4a.gd` `XSkin4A.FLASH_V2`；`battle/mv_animation.gd`、`battle/battle_screen.gd`、`battle/battler_sprite.gd` | 变速 2～4 倍时受击闪白、整屏闪光频率跟着翻倍 | 整屏闪光每秒最多 3 次；变速 2 倍闪白减半，3 倍及以上不画闪白（只压透明度，帧数不变） | Fable审 C7 | `XSkin4A.FLASH_V2 = false` | cc | 保留 |

## 截图（本机，不入库）

目录：`03_再刷重制_Godot/04_验证/本地结果/ui_skin_4a/`（`xiyou_ui_skin_4a -- --out=<目录> [--before|--touch] [--wide|--tablet] [--desert]` 拍）

- `map_<16x9|20x9|4x3>_<before|after|after_touch>.png`：地图（地图 5 雪地）。`before`＝4A 五个开关全关（＝收口批），`after`＝键盘，`after_touch`＝按触屏画、建虚拟键。
- `battle_<16x9|20x9|4x3>_<before|after|after_touch>.png`：战斗背景是雪地地图快照；`..._desert.png` 是沙漠战斗背景（`Sand`）。
- 20:9 的 `before` 图是视口截图（1280 宽），真窗口两侧是黑边；`after` 是 1600 宽。地图 5 本身只有 27 格宽，20:9 下地图两侧仍是地图外的黑（MV 小地图本来就这样），战斗那边已经用延展底补上。
- 皮肤关闭对照：`skin_off/`（`皮肤关闭对照.py`，32/32 与 main 逐像素一致）。

## 新文字（请小A审）

- 设置项名「战斗背景压暗」，状态「关」「15%」「30%」；说明：「在战斗背景上盖一层暗色，雪地、沙漠这类亮背景上的字和角色更清楚。可选关、15%、30%。」
- 地图 HUD 胶囊「回城」（原来是一张枫叶图、没有字；「存档备份」「地图传送」沿用原字）。
- 挂机胶囊、挂机提示条用的是原有文字（插件参数 `tipWord`「开启/关闭挂机:G」、`huWord`），只换了画法；坐标胶囊沿用原坐标和难度文字。

## 验证

- 新专项 `xiyou_ui_skin_4a`：无头 46/46；窗口 18 种组合（{改前、改后键盘、改后触屏} × {16:9、20:9、4:3} × {雪地快照、沙漠}）全过（改后 42～54 条，改前只拍图 4 条）。断言：闪白系数四档、整屏闪光限频（一秒 10 次只画 3 次）、压暗三档与设置读写（坏值回 15）、各开关关掉／皮肤关掉全回；地图 HUD 胶囊在右上安全区内、互不重叠、不进左下摇杆区、坐标胶囊在下、挂机胶囊贴左安全边距、提示条居中；20:9 地图视口 1600、开旧页面收回 1280、关掉再铺满、`WIDE_V2` 关回 16:9；HUD 跟到右边；触屏键黑底旧金、贴右边；战斗 `_origin` 居中、背景铺满、`BattleDim` 15% 盖满且在角色下、浮字底画了（关 `TEXT_V2` 不画）、3 倍速受击闪白和整屏闪光不画（帧数 12 不变）、原速照常；关皮肤 HUD／挂机钮回原位置原画法、触屏键回原色。
- 相关旧专项本地：`xiyou_ui_skin` 104、`_1b` 85、`_1c` 78、`_3a` 90、`_3b` 40、`_4b` 77、`_5c` 79、`_battle` 61、`_close` 68、`_hud` 104、`_menu` 99、`_offshot` 29、`_p1fix` 1、`xiyou_input_handled` 10，全过。改了 `xiyou_ui_skin_hud` 一条断言：自动／变速两颗的 x 在 `HUD_V2` 开着时跟挂机胶囊一起贴安全边距（24），原来是 20。
- `语法检查.py` 通过；`皮肤关闭对照.py` 32/32 SAME；`发行空壳.py check` 通过（`skin_4a.gd` 登记进 `MIXED_OK`：西游代码直接调、发行包里 `XUiSkin.on()` 恒假）；`工具回归.py` 全过。
- 回退：五个开关在 `xiyou_ui_skin_4a` 里都有字面量设 false 的断言。
- 云端选测：见下一行（`选测.py` 名单很长：改到战斗场景、MV 动画、虚拟键、设置页，按派单本地只跑单个专项，其余走云端）。
- 云端结果：c4041269e 整轮 636 场景 16 片（actions/runs/43760971632；基准 8398a28e7，收口批没进 main 所以选成整轮），625 过、11 挂：`text_fix_dump`、`text_fix_shots`、`xiyou_common_scripts`、`xiyou_dungeon`、`xiyou_enemy_book`、`xiyou_equipment`、`xiyou_gear_search`、`xiyou_inlay_book`、`xiyou_rift2_canglong`、`xiyou_troop_events_d`、`xiyou_troop_events_half`。这 11 个正是 main 上 501b6e99b（「比原版文字的参照专项关 XTextFix」、text_fix 工具场景无参数报跳过）改的测试，本分支从收口批切、还没有这次修；挂的内容都是 XTextFix 改字（如「寂静」→「寂净」、`off.same_as_source`），和 4A 无关。本地把 `xiyou_rift2_canglong`、`xiyou_enemy_book` 换成 main 的测试文件单跑 90/90、96/96（已还原）。合 main 后这 11 个随 501b6e99b 一起过。

## 交接板

- 下一步：收口批进 main 后本单再合 main（派单定）；之后 2C 战斗旧说明卡换皮、指令环位置（P2-8）可在这个底座上接着做。
- 用户试玩说明：天启篇存档在地图上看右上角的回城／存档备份／地图传送胶囊、左上挂机胶囊；宽屏手机上地图和战斗两边不再有黑边；设置「画面」里试「战斗背景压暗」三档；战斗变速开到 3 倍看受击不再闪白。
- 需要用户决定：无（压暗默认 15% 照 Fable 稿）。

## 进度账

- 新界面（天启篇）：4A＋战斗可读性完成；第 4 批剩 4B 已交，后续 2C／5A／5B。

## 没做的（留给后续批）

- 震屏：战斗里没有整屏震动的实现可调（见变更记录草稿最后一条），C7「变速越高震屏越弱」没有落点；地图上事件 225 震屏跟战斗变速无关，没动。
- 敌人头顶的血量数字胶囊和名字胶囊会叠在一起（原版名字和血条数字本来就上下交叠 11 像素，现在两枚底叠出一块深色）；要动敌人血条的排法，留 2C。
- 触屏战斗里右上「隐藏按键」压在队伍面板右上角（收口批就这样）；没挪。
- 战斗里的界面（队伍面板、行动顺序、指令环、血弧）仍在中间 16:9 里摆（安全区内），没有拆成贴两边的锚点；地图 HUD、挂机胶囊、自动／变速、虚拟键已贴边。
- 首领血弧背后那条旧公告在首领战时不显示、回合提示挪到指令环正上方（Fable P1-2 后半）没做；首领名没换成白字（照原来按难度上色），只加了底。
- 小o 的新面板材质、HUD 图标没接（派单定）；HUD 图标留了 `content/ui_skin/hud/hud_<save|transfer|return|hangup>.png` 的替换口。
- 没上真机：触屏全部是按 `XUiSkin.touch_override`／`XPlatform.force_mobile` 模拟和截图看的；刘海安全区只按 `XPlatform.safe_insets` 算，没在真机量。

## 可优化（流程／工具／效率）

- 已做：`xiyou_ui_skin_4a` 一个专项带 `--before／--touch／--wide／--tablet／--desert` 五个参数，18 种组合一条命令循环就能出全套改前改后图（回退：不带参数就是无头断言）。
- 建议：`皮肤关闭对照.py` 的基线场景里没有地图 HUD（挂机钮、存档／传送钮）这一屏，4A 改的是地图 HUD，关皮肤对照只能靠专项断言；可以加一张地图截图（归界面车道，约半小时）。

## 本分支提交

- f0dde788a 4A 本体（XSkin4A 五开关）
- （专项）xiyou_ui_skin_4a
- e292689ad 截图返修：窄地图快照、触屏指令环让开 A／B、圆键 2px 边
- c4041269e 交付单＋发行空壳登记

## 小A乙档核查

- **结论**：**不通过（待修 1 项 P2 后可合）**；`FLASH_V2` 经逐行代码与专项核查未改帧数、时序与伤害结算，**无需升甲档**。

### 一、问题清单（P1 / P2 / P3）

- **P1**：无。
- **P2-1【触屏默认「原版虚拟按键」下，右上 `Save` 键与「地图传送」胶囊上下重叠 10px】**（像素核查＋代码核查）
  - 位置：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/map/map_hud.gd`（`SKIN_TOUCH_Y := 60.0`、`_layout_skin`）、`03_再刷重制_Godot/01_Godot工程/core/touch_controls.gd`（`GHOST_TOP` 中 `"save": Rect2(110, 2, 80, 60)`）。
  - 现象：`map_hud.gd` 按改版顶栏高 40（底边 `y = 48`）设定 `SKIN_TOUCH_Y = 60.0`，但触屏默认样式为 `original`（`ghost() == true`），`Save` 键实际占 `y = 10..70`，导致 `y = 60..70` 与地图 HUD 第一排最右的「地图传送」胶囊（`y = 60..100`）重叠。
  - 证据：PNG 像素对比 `map_16x9_after_touch.png` 与 `map_16x9_after.png`（`x = 1196..1256, y = 60..70` 重叠 `60×10px`）、`map_20x9_after_touch.png` 与 `map_20x9_after.png`（`x = 1516..1544, y = 60..70` 重叠 `28×10px`）；`XTouchControls` 位于 `CanvasLayer 120` 压在 HUD 之上，点该交叠区会触发一键存档而非地图传送。
  - 建议修法：`_layout_skin()` 改按 `XTouchControls.instance.group_rects.get("top")`（或 `save` 实际矩形）的 `end.y + 8.0` 计算下移起点（或将 `SKIN_TOUCH_Y` 提高至 `78.0`），同时兼容 `original` 与 `modern` 两种虚拟键样式。
- **P3-1【5 人出战阵型下 20:9 触屏指令环与队伍栏底行有 6px 轻触风险】**（只看代码）
  - 位置：`modes/xiyou/ui/skin/skin_side_status.gd`、`skin_battle_ring.gd`、`battle_scene.gd`。
  - 现象：4 人队（实测无头与像素均正常）队伍条底在 `12 + 2 + 4×58 = 246`，指令环顶在 `y ≈ 298` 无重叠；若为 5 人出战阵型（底边 `304`），20:9 触屏下指令环被 `avoid_touch_keys` 左移后右缘约在 `1278`、落入队伍面板横向范围（`1134..1424`）内，可能与第 5 行底边轻触约 `6px`。
- **P3-2【`MVAnimation` 目标闪白系数只看动画 `rate`，未叠 `XConfig.battle_speed()`】**（只看代码）
  - 位置：`modes/xiyou/battle/mv_animation.gd:289, 293`。
  - 现象：常规战斗动画均按 `XConfig.battle_speed()` 传 `frame_rate`，主路径一致；仅当个别特殊演出在 3 倍速下仍固定以 `rate = 4` 播 MV 动画时，动画内 `flashScope = 1/2` 不会随战斗变速降半／熄灭。
- **P3-3【文字审与范围外记录】**（实测＋代码核查）
  - **文字审通过**：新增可见文字——设置项「战斗背景压暗」、状态「关」「15%」「30%」、说明「在战斗背景上盖一层暗色，雪地、沙漠这类亮背景上的字和角色更清楚。可选关、15%、30%。」、地图 HUD 胶囊「回城」——全部通顺无错字、全角标点一致、与设置键名和口径吻合。挂机胶囊「开启/关闭挂机:G」与提示条沿用原插件参数 `tipWord`/`huWord`，非本单新增（触屏下保留 `:G` 后续可再简）。
  - 交付单「没做的」已如实列明敌人头顶名/血量底重叠、首领血弧后公告与回合提示挪正上方、触屏战斗右上「隐藏按键」压队伍右上角、战斗 UI 未拆两边锚点、无真机测试等，均在派单已定边界之外。

### 二、六项核查明细（分清实测与只看代码）

1. **界面审稿对照（4A／战斗可读性）**：
   - **实测确认**：`HUD_V2` 黑金胶囊（右上三钮＋坐标胶囊、左上挂机胶囊＋居中黑金条、触屏虚拟键黑金边 2px）与 `小A审_美化舒适 9` 一致；`TEXT_V2` 深色胶囊底已画到回合提示、首领名与血量、敌人头顶名与血量；`DIM_V2` 设置默认 `15%`、写 `codexBattleDim`、背景层盖在背景（含五条／宿傩领域）之上与角色之下，像素实测 `battle_16x9_after_desert.png` 较 `before` 亮度准确压至 `85.0%`（左 `199.2→169.3`、右 `192.0→163.4`）。
   - **唯一问题**：见 **P2-1**。
2. **20:9 铺满与 4:3**：
   - **实测确认**：`battle_20x9_after.png`／`battle_20x9_after_desert.png`（`1600×720`）左右黑边均为 0（沙漠满铺、窄地图 5 用 `SnapshotExtend` 延展两侧）；`map_20x9_after.png`（`1600×720`）两侧地图外自然留黑，HUD 贴 `safe_rect`（56px）；`battle_20x9_after.png` 左上挂机胶囊与 `自动`/`变速` 左对齐 `x = 56`；`4:3` 截图（`1024×576`，比例 `1.7778`）按 16:9 居中留边不挤；`xiyou_ui_skin_4a` 实测打开旧页面收回 16:9、关闭再铺满。
   - **只看代码**：`screen_fx_view.gd` 天气覆盖与 `lobby_corruption.gd` 大厅氛围小字居中按 `XSkin4A.view_size` 适配。
3. **FLASH_V2 时序／帧数／结算核查（重点）**：
   - **只看代码＋专项实测**：逐行核查 `skin_4a.gd`、`battle_screen.gd`、`mv_animation.gd`、`battler_sprite.gd`，仅在绘制／着色时乘 `flash_gain`/`target_gain`/`screen_gain` 或做 `Color.WHITE.lerp(..., g)`；`battle_screen.gd` 的 `flash_duration`、`flash_color[3]`、`step()`、`busy()`、`trace`，`mv_animation.gd` 的 `duration`、`wait`、`flash_duration`、`screen_duration`、`hiding_duration`、`flash_opacity()`、`done`，以及行动时序、随机数、伤害结算均完全未改；`xiyou_ui_skin_4a`（46/46）与 `xiyou_mv_animation`（21/21）实测通过。**不触发升甲档条件。**
4. **五开关单独关闭与皮肤关闭全回旧**：
   - **实测确认**：`xiyou_ui_skin_4a` 实测五开关置 `false` 与 `XUiSkin.FORCE = false` 断言全部通过；`03_再刷重制_Godot/04_验证/本地结果/ui_skin_4a/skin_off/` 内 `base` 与 `branch` 32/32 张 PNG SHA-256 完全一致。
   - **只看代码**：逐项核实 `HUD_V2`/`WIDE_V2`/`TEXT_V2`/`DIM_V2`/`FLASH_V2` 各自独立置 `false` 及 `XUiSkin.on() == false` 时所有修改路径均可完整回到改前。
5. **触屏指令环不压 A/B、不挡队伍信息**：
   - **实测确认**：`battle_16x9_after_touch.png` 与 `battle_20x9_after_touch.png` 像素核查，4 人队队伍栏占 `y = 12..246`，指令环在 `y ≈ 302..712` 且经 `avoid_touch_keys` 避让至 `A/B` 键组左侧 `12px` 外，不压 `A/B` 也不挡队伍信息。
   - **只看代码**：5 人队边界见 **P3-1**；`modern` 样式与自定义拖放矩形下 `avoid_touch_keys` 读 `pad.group_rects["actions"]` 逻辑自洽。
6. **文字审**：见 **P3-3**（通过）。

### 三、本轮运行记录与留给总装

- **本轮前台实测通过**：
  - `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：952 个 `.gd`，0 问题。
  - `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：62 脚本、534 函数全部对齐。
  - `python3 03_再刷重制_Godot/07_开发环境/交付自检.py --task ui-skin-4a --main 7c37b8321`：合并准备阶段检查全过。
  - `python3 03_再刷重制_Godot/07_开发环境/回退开关覆盖.py`：388 个开关，`XSkin4A` 五开关均已覆盖，无新缺口。
  - `xiyou_ui_skin_4a.tscn` `46/46`、`xiyou_ui_skin_hud.tscn` `104/104`、`xiyou_ui_skin_battle.tscn` `61/61`、`xiyou_ui_skin_5c.tscn` `79/79`、`xiyou_mv_animation.tscn` `21/21`。
  - 本地 36 张截图像素核查＋`skin_off/` 32/32 PNG SHA-256 校验（32/32 全同）。
- **留给总装／云端的长测试**：
  - `检查.sh --full`（如含对照加 `--oracle`）与 `皮肤关闭对照.py` 现场重跑；
  - 合并时接入 `main` 上 `501b6e99b` 以消除云端整轮中已知的 11 项 `XTextFix` 参照失败；
  - 安卓／iOS 真机刘海安全区与触屏实机手测。

