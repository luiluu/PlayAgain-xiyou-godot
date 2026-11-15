# 交付：cc/ui-skin-5c

- 车道／工作者：B 界面·新界面第 5C 批（设置主页与子页、文本输入、返回标题、两个设置项）／cc（Sonnet＋medium，本单配 Sonnet＋medium，因为是套 1B 模板换皮＋两个设置项存盘，接线不复杂）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·未经审查】新界面第 5C 批：设置主页换模板页、子页居中、文本输入与返回标题换皮、「界面风格」「界面动效」两个设置项（O-待定，dev.待定）

- 玩家可见：无（新皮肤只在天启篇存档里开，天启篇没对玩家开放；重制版 0.01.x 与西游存档保持旧界面，已逐像素对照）。开发版里进天启篇存档开设置：主页变成左分类环（常规／战斗／遇敌／画面／声音／挂机与操作）、中间设置项、右边一句话说明；画面里多出「界面风格：新／原版」「界面动效：全部／简化／关」两行。
- 依据：第 0 期交付单「第 1～6 期拆批建议」5C 行；设计稿 `重制设定/界面风格提案_v0.7/README.md` 第四节；盘点清册 `xa/ui-audit`（#32～39、#41、#42：设置页「35+ 项挤在 400×460 窄框、无分类无说明、混着三条宣传行、Battle Camera 未汉化、画质与手机按键沉在最底」）；小A文字审口径「设置：画面、声音、挂机与操作」「返回标题」。
- 做了什么：
  - **设置主页（#32）**：新增 `modes/xiyou/ui/skin/skin_options_page.gd`（`XSkinOptionsPage`，套 `XSkinTemplatePage`）。`XOptionsScene` 的状态机（`_list`、`index`、`ok`、`_side`、子页）一行逻辑没动，新皮肤开着时只是换画法：`_refresh` 转给 `skin.sync()`，按键先给 `skin.input`。左：分类环（环心写这一类的项数）；中：这一类的设置项（左名右状态）；右：详情牌（名字、状态、一句话说明、操作提示）。上下选项、确定切换或进子页、左右调整、Q／E 换分类、取消返回、点圆球也能换类（触屏没有 Q／E）。新布局里不列的行：三条宣传行（「此游戏为免费游戏！」「总群请加…」「不要在闲鱼买到这个版本！」）、灰着点不了的（测试模式、GM 工具、待提交反馈；本机有解锁文件时才列）；`Battle Camera` 显示成「战斗镜头」。旧界面里这些行照旧都在。
  - **子页（#33～39）**：画质与字体、手机按键、挂机主界面与四个子页、消息提醒、屏蔽掉落、角色换装——都还是旧页面（`XMVWindow` 窗口，已被第 0 期自动换成黑面板＋红乙选中条），新皮肤开着时放进一个居中的 1280×720 外框（`SkinSubPageHost`，窗口宽过 16:9 时居中，拖窗口、转屏跟着挪），背景用设置页自己的黑底（子页自己的新皮肤黑底藏掉，免接缝）。不重排版面，字体沿用。
  - **文本输入（#41，`XTextPrompt`）**：新皮肤开着时换主题、黑面板、输入框（细线边、聚焦朱红边、朱红光标），加半透明黑罩；关着时一行旧代码不变。
  - **返回标题（#42，`XGameEndPanel`）**：新皮肤开着时叫「返回标题」（旧界面仍「回到标题」，与 main 一致），窗口在宽屏里居中；点击坐标减掉居中偏移。
  - **两个设置项**（存 `XConfig`，**只新增两个键**，旧档读不到时用默认）：`codexUiSkin`（布尔，默认 true＝新）、`codexUiMotion`（整数，-1 没选过／0 全部／1 简化／2 关，默认 -1）。`XUiSkin.on()` 在天启篇存档里再问 `XConfig.ui_skin_new()`；`XUiSkin.motion()` 在 `motion_override` 之后问 `XConfig.ui_motion()`，没选过时仍是「省电模式按简化、否则全部」。设置页里：「界面风格」切换后**本页立刻换风格**（旧／新布局、背景整套换掉），并且关设置页时连主菜单一起回地图（`to_map`，菜单是按旧风格建的，重开才换，说明里已写「切换后返回地图时生效」）；「界面动效」循环三档，立刻生效。`XUiSkin.selectable()`：设置页要不要列这两行（总开关开、且是天启篇存档或调试强开；玩家选「原版」时 `on()` 是 false 但这行还得在，好选回来）；动效一行只在新皮肤开着时列。
- 开关：不新增开关。整体回退＝`XUiSkin.ENABLED = false`（设置页回旧页、两行不出现、文本输入与返回标题回旧）；玩家自己回退＝设置里选「界面风格：原版」。
- 改的文件（独占）：`modes/xiyou/ui/skin/skin_options_page.gd`（新）、`modes/xiyou/ui/options_scene.gd`、`modes/xiyou/ui/text_prompt.gd`、`modes/xiyou/ui/game_end_panel.gd`、`tests/xiyou_ui_skin_5c.gd`／`.tscn`（新专项）、`tests/xiyou_ui_skin_offshot.gd`（皮肤关闭对照的页面名单加四页）。
- 改共用文件（只加分支、关着时原逻辑不变）：`modes/xiyou/core/xconfig.gd`（`DEFAULTS` 加两个键、动效档读取、`ui_motion`／`set_ui_motion`／`ui_skin_new`）、`modes/xiyou/ui/skin/ui_skin.gd`（`on()` 加问设置、`selectable()`、`motion()` 加问设置）。
- 配置存盘兼容：旧 `options.json` 没有这两个键 → 读到默认（新／没选过）；`codexUiMotion` 不是数字 → 默认；其余键的读写一行没动。
- 已有设置项（画质 `XGraphics`、字体大小 `XFontScale`、画面平滑、画面特效等）只换皮，默认值和存盘键都没改。
- 按键提示：新设置页的提示照 1A 让位做法（右边让出右下角版本号，`XSkinMainMenu.hint_right`），已看 16:9／20:9 截图，不压版本号。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/ui/skin/skin_options_page.gd`、`modes/xiyou/ui/options_scene.gd`（`_build_list`、`_show_skin`、`_set_ui_skin`、`_open_page_skin`）、`modes/xiyou/ui/text_prompt.gd`、`modes/xiyou/ui/game_end_panel.gd`、`modes/xiyou/core/xconfig.gd`（`codexUiSkin`、`codexUiMotion`）、`modes/xiyou/ui/skin/ui_skin.gd`（`on()`、`selectable()`、`motion()`）；`tests/xiyou_ui_skin_5c.gd` | 设置页是居中 400×460 窄框，35+ 项挤一列，一次见 12 行，无分类无说明，混着三条宣传行和未汉化的 Battle Camera，画质与手机按键沉在最底；文本输入、返回标题是旧窗口 | 天启篇存档里设置页换成分类环＋列表＋一句话说明，宣传行与灰着的死项不列，子页居中放；文本输入与返回标题换新皮肤；加「界面风格：新／原版」「界面动效：全部／简化／关」两个设置项（天启篇才列），存配置 | 盘点清册 #32～39、#41、#42；Kyo 2026-11-15 拍板界面风格并说「动手」；第 0 期交付单 5C 行 | `XUiSkin.ENABLED = false`：设置页、文本输入、返回标题一律旧界面、两行不出现（`tests/xiyou_ui_skin_5c.gd`、`07_开发环境/皮肤关闭对照.py` 验证；关对照加了设置子页三张与返回标题）；玩家可在设置里选「界面风格：原版」 | cc | 保留 |

## 新增可见文字（交付后协调派小A文字审）

| 文字 | 在哪 | 说明 |
| --- | --- | --- |
| 设置 | 新设置页页名 | 与主菜单子项名一致 |
| 常规、战斗、遇敌、画面、声音、挂机与操作、其他 | `XSkinOptionsPage.CATS`／`OTHER`：分类环的名字与列表小标题 | 「其他」只在有归不进前六类的项时出现（现在一般没有） |
| 项 | 分类环心的小字（「12 项」） | |
| 操作 | 详情牌小标题 | |
| 确定切换，左右键直接选择。／确定进入。／确定或左右键调整。 | 详情牌「操作」下的一句 | 按这一项是开关、子页、还是档位选 |
| 确定／切换、左右／调整、Q / E／换分类、取消／返回 | 按键提示 | |
| 战斗镜头 | 原 `Battle Camera` 在新设置页里的名字 | 旧界面仍是 Battle Camera |
| 界面风格（新／原版）、界面动效（全部／简化／关） | 设置页新增两行，旧布局里也有（选了原版时） | 小A定叫法 |
| 设置项的一句话说明共 38 条 | `XSkinOptionsPage.DESC`，如「在地图上显示当前所在的坐标。」「开启后角色始终奔跑，不用再按住加速键。」「「新」是天启篇的新界面，「原版」沿用旧界面。切换后返回地图时生效。」 | 请逐条审措辞；「屏蔽掉落」「挂机」「战斗伤害记录」「战斗变速」几条我没有原版说明可对，说明是按名字推的，请核事实 |
| 返回标题 | 新皮肤下返回标题窗口的第一项 | 旧界面仍「回到标题」；与主菜单子项「返回标题」统一 |

文本输入窗口里的提示文字和默认文字都是调用方传入的，这批没有新增。

## 需要协调确认

- **「界面风格」设置项在重制版里出不出现**：稿里没写清，按「重制版不出现、天启篇默认新」做（`XUiSkin.selectable()` 只在天启篇存档或调试强开时为真）。要让重制版也能选，把 `selectable()` 改成别的条件即可；但重制版现在开关本身不开新皮肤（`on()` 靠 `XTianqiLine.open_for`），等 Kyo 另说才给重制版开。
- **宣传行在新设置页隐藏**：「总群请加…」「不要在闲鱼买到这个版本！」「此游戏为免费游戏！」三条（原版 `wxxonoff`／`wxlonoff`／`wxtonoff`，会话级开关）新布局不列，按盘点清册建议“放关于弹窗”；关于弹窗这批没做，旧界面里照旧在列表中。要不要在新界面某处保留，请定。
- **分类图标是占位**：分类环的圆球用现有图标号（688、160、193、100、384、1001），美术出了分类图标后改 `XSkinOptionsPage.CATS` 的第三项。
- 子页内文字的蓝色（旧系统色）与新皮肤色不统一，子页没重排，这批不动；要重排由后续批次。

## 交接板

- 下一步：5A／5B（小A，套 1B 模板）与 6（小A）不依赖本批；本批合并后设置页新布局进总装选测。
- 用户试玩说明：无（天启篇没对玩家开放）。开发版进天启篇存档：菜单→系统→设置，看分类环；画面分类里能选「界面风格」「界面动效」。
- 需要用户决定：无（见上「需要协调确认」，按默认做完）。

## 进度账

- 天启篇新界面：第 5C 批完成：设置主页（#32）新布局、子页（#33～39）居中放进新黑底、文本输入（#41）、返回标题（#42）换皮；子页版面未重排。

## 可优化（流程／工具／效率）

- 已做：`07_开发环境/皮肤关闭对照.py` 的页面名单（在 `tests/xiyou_ui_skin_offshot.gd`）加了设置子页三张（画质、消息提醒、屏蔽掉落）与返回标题，西游存档与天启篇关新皮肤两种共 8 张新对照；回退：删名单里那几项。
- 建议：设置子页（挂机主界面 13 个窗口拼合、手机按键拖拽布局）要真正按新稿重排才能去掉旧窗口的拼接感，工作量大（挂机主界面单页就是一批），归后续界面车道，不急。
- 建议：新界面里「Q／E 换页」类按键提示对触屏玩家无意义，等触屏按键提示统一方案出来（6 期）后再一起改。

## 验证

- 专项 `tests/xiyou_ui_skin_5c.tscn`：无头 75/75；有窗口 93/93（多 18 项：截图 9 页 × 16:9／20:9）。覆盖：
  - 存盘：默认（新、没选过）、写读回环、**旧档没有两个键读到默认**、动效档不是数字读回默认且不影响其它键（音量 60 照读）；用 `TestEnv.isolate` 的 `path_override`，不读本机真实 options.json；
  - 开关：天启篇默认 `on()` 真、选原版 `on()` 假但 `selectable()` 真、西游存档两者都假且写 true 也不开；动效：没选过按省电模式、选过按选的、`motion_override` 优先、越界夹住；
  - 设置主页（天启篇）：建新布局、旧窗口藏、新增两行在列表里、宣传行与灰项不列、分类环项数与环心、确定切换且右侧状态更新、详情牌名字与说明、上下选项、Q／E 换分类并首尾循环、声音类左右调音量、点环圆球换类、画面类有两个新行、动效循环三档与行文字、选原版→本页换旧布局（`win` 显示、`to_map` 真、背景换成旧底图、状态「原版」）、选回新→新布局和黑底、取消关页；
  - 设置主页（西游存档）：不建新布局、两个新行不出现、宣传行仍在、`to_map` 假；
  - 子页：画质、消息提醒、屏蔽掉落、挂机设置（带地图预览）各自打开→放进外框、外框居中、设置页自己的背景还在、关子页后新布局回来且外框删净；西游存档开子页没有外框；
  - 文本输入：新界面有黑罩和输入框皮肤，西游存档没有；返回标题：新界面窗口在居中的外框里、确定→返回标题信号、再选取消→关；西游存档照旧无偏移。
- **开关关掉与 main 一致**：`python3 03_再刷重制_Godot/07_开发环境/皮肤关闭对照.py` → 主菜单、状态、物品、技能、装备、设置、装备检索、设置子页三张（画质、消息提醒、屏蔽掉落）、返回标题，加战斗三张，× 西游存档默认／天启篇存档 `ENABLED = false`，共 25 张逐像素 SAME（版本号都 dev.602，没有版本号差异）。
- 选测（本地并行 2，29 个场景全过，260 秒；清单：`xiyou_ui_skin`、`_1b`、`_1c`、`_menu`、`_battle`、`_5c`、`_offshot`，`xiyou_options_basic`／`_misc`、`xiyou_platform`、`xiyou_list_paging`、`xiyou_battle_options`、`xiyou_power`、`xiyou_power_hidden`、`xiyou_test_mode`、`xiyou_graphics_options`、`xiyou_notice_options`、`xiyou_hangup_options`、`xiyou_costumes`、`xiyou_font_size`、`xiyou_screen_fx`、`xiyou_flow`、`xiyou_tianqi_e2e`、`xiyou_determinism`、`xiyou_smart_ai`、`xiyou_ui_page_details`、`xiyou_window_rects`、`xiyou_game_over`、`xiyou_event_compare`）；日志 `04_验证/本地结果/并行测试/20261115_094009_9vxltljk/`。`xconfig.gd` 的改动使 `选测.py main --list` 扩到 206 个场景，本地没全跑：只在 `DEFAULTS` 加两个键、加两个读写函数，其余键的解析一行没动；整轮交总装 `--affected --cloud`。
- `语法检查.py`：0 个问题。`发行空壳.py check`：通过（58 个脚本 492 个函数都有；新文件不在发行包）。`工具回归.py`：全部通过（99 秒）。
- 截图（有窗口，git 忽略目录 `03_再刷重制_Godot/04_验证/本地结果/ui_skin_5c/`，每张 16x9＝1280×720、20x9＝1600×720）：`ui_skin_5c_options_screen`（设置主页画面分类）、`ui_skin_5c_options_old_style`（选原版后本页回旧布局）、`ui_skin_5c_sub_graphics`／`_notice`／`_pingbi`／`_costumes`／`_hangup`（子页，20x9 居中）、`ui_skin_5c_text_prompt`、`ui_skin_5c_game_end`。
- 给总装：`合并车道.sh --finish --affected --cloud`（改了 `xconfig.gd`，选测扩到 206 个，本地没跑全）。

## 本分支提交

- 见 git log（分支 cc/ui-skin-5c）。

## 小A 乙档核查

- **核查对象**：`cc/ui-skin-5c`（交付提交 `c94188fd1`，对比基线 `17be52a65`），只读核查，未改游戏代码。
- **总结论**：**不通过**（**P1：0**，**P2：2**，**P3：3**；**文字必改：5 条 `DESC` 事实／歧义问题 + 状态叫法中英不统一**）。返工量很小且全在天启篇/皮肤展示层或文字，修完重核即可合，**不需转 co 甲档**。
- **核查口径区分**：
  - **核了规则本身／前台实跑**：无头跑 `xiyou_ui_skin_5c.tscn`（75/75）、`xiyou_ui_skin_offshot.tscn`（23/23，核了 `ENABLED = false` 下 22 页+1 战构建不崩）、`xiyou_options_basic.tscn`（148/148）、`xiyou_options_misc.tscn`（105/105）、`xiyou_graphics_options.tscn`（60/60）、`语法检查.py`（913 个 `.gd` 0 问题）、`发行空壳.py check`（58 脚本 492 函数通过）、`回退开关覆盖.py`（未引入新缺口），以及 `charset_song.txt`/`charset_hei.txt` 字集覆盖校验（原文本及下文建议改字均 0 缺字）。
  - **只看代码／按文档与提交口径核对**：`git diff 17be52a65..c94188fd1` 全量源码、设置项真实规则源码（`XPingbi`、`XDamageRecord`、`XBattleTiming`/`XSequencePlayer`/`MVAnimation`、`XHangUpOptionsScene`、`XEncounterTarget`、`XGraphics`、`XFestLobby`/`XRiftAlien` 等）、`XSkinLayout.request_wide` 与 `XMenuScene`/`XMapScene` `to_map` 流程、协调所看截图 3 问与 `ba1f7ed` 口径对比。

### 逐项核查

1. **开关与回退（核了规则代码＋无头实跑 `xiyou_ui_skin_5c` / `offshot`）**：
   - `XUiSkin.ENABLED = false` 时 `on()` 与 `selectable()` 恒为 `false`（`ui_skin.gd:131-149`）；`XOptionsScene` 不建 `skin`、`XTextPrompt` 与 `XGameEndPanel` 走旧代码，`codexUiSkin`/`codexUiMotion` 两行在设置页不出现。
   - 重制版（西游存档 `XTianqiLine.open_for(XState.current) == false`）下，`selectable()` 与 `on()` 均返回 `false`，即使 `codexUiSkin = true` 也不显示「界面风格」且保持旧界面；天启篇存档默认 `codexUiSkin = true`（新），切到「原版」时 `on()` 变为 `false` 回旧界面，而 `selectable()` 仍为 `true` 保留「界面风格」行供切回，同时隐藏「界面动效」行（`if XUiSkin.on()`）。
   - `tests/xiyou_ui_skin_offshot.gd` 在 `PAGES` 补入 4 个子页/终局面板共 11 页 × 2 套场景 + 3 战斗 = 25 张（无头 `23/23` 通过；未在本地有窗重跑 `皮肤关闭对照.py` 逐像素比对）。
2. **存盘与测试隔离（核了 `xconfig.gd` 规则＋`TestEnv` 源码＋无头实跑）**：
   - `git diff 17be52a65..c94188fd1 -- modes/xiyou/core/xconfig.gd` 确认**只新增两个键**：`codexUiSkin`（默认 `true`）与 `codexUiMotion`（默认 `-1`），`codexUiMotion` 已列入 `set_flag()` 排除列表。旧 `options.json` 缺键或 `codexUiMotion` 非数字时回落默认且钳制 `-1..2`，其余设置项（画质、字体、画面平滑、画面特效、坐标显示、音量、战斗变速、定向遇怪等）默认值与存盘键名**一行未动**。
   - `tests/xiyou_test_env.gd:14-16` `TestEnv.isolate()` 将 `XSave.dir_override` 与 `XConfig.path_override` 指到 `user://test_xiyou_ui_skin_5c/` 并清理测试目录下旧 `options.json`，**不会读写本机真实 `options.json`**。
3. **切换「界面风格」立即生效与关页连菜单回地图 `to_map`（只看代码＋无头 `xiyou_ui_skin_5c` 实跑切换/退出）**：
   - `_set_ui_skin(v)`（`options_scene.gd:372-389`）立即写入 `XConfig`、置 `to_map = true`、保留原 `symbol`、重建 `_list` 与 `_bg_nodes`、调用 `_show_skin(XUiSkin.on())` 并恢复光标与刷新，无旧节点残留或空引用。
   - `XSkinLayout.request_wide`（`skin_layout.gd:89-103`）按 `tree_exiting` 计数管理 `_wide_users`：主菜单进入设置页隐藏时已释放自身 `_wide_token`（`skin_main_menu.gd:117-127`）；页内「新 → 原版」`skin.queue_free()` 触发 `tree_exiting` 使 `_wide_users` 归 0 恢复窗口比例、「原版 → 新」重建 `skin` 递增至 1，不会泄漏锁定宽屏。
   - 关闭设置页时，`XMenuScene` 检查 `page.to_map`（`menu.gd:545-548`）后释放设置页并 emit `closed`，`XMapScene.open_menu`（`map_scene.gd:2076-2088`）统一清理 `menu`、复位 `_menu_open = false`、记录 `_menu_closed_frame`、恢复 `hud.visible = true` 并跑菜单后钩子，**不会丢状态或卡住**（若同页内「新→原版→新」来回切再退出，`to_map` 仍为 `true` 会直接回地图，属预期无害）。
4. **协调看截图请核 ①②③（只看代码＋规则核实）**：
   - **① `ui_skin_5c_options_screen` 中「界面动效」显示「关」**：是**测试状态，不是默认值**。正式默认 `codexUiMotion = -1`，`XUiSkin.motion()`（`ui_skin.gd:174-180`）在未选过时默认返回 **`Motion.FULL`（「全部」）**（仅在开启省电模式 `XGraphics.low_power()` 时默认 **`Motion.SIMPLE`（「简化」）**）。原因是 `tests/xiyou_ui_skin_5c.gd:158` 为截图稳定性设置了 `XUiSkin.motion_override = XUiSkin.Motion.OFF`，直到 L208 截完 `ui_skin_5c_options_screen` 后才在 L213 重置为 `-1`（记为 **P3-1**）。
   - **② 同页「画面特效 ON」「画面平滑 OFF」英文与「界面风格 新」「界面动效 关」中文叫法不统一（记为 P2-2）**：
     - **建议统一后的中文叫法**：`ON` → **`开`**、`OFF` → **`关`**；其中 `battleAniSpeed`（「战斗变速」）第 4 档原显示 `OFF`，统一中文建议改 **`原速`**（同步把 `DESC["battleAniSpeed"]` 末尾改为「`「原速」为正常速度。`」）。
     - **补丁与改动边界必须分清**：`ON`/`OFF` 来自 `XOptionsScene.status_text()` 与 `XConfig.battle_speed_text()`，覆盖 `画面特效`、`画面平滑`、`始终奔跑` 等**重制版玩家也看得到的旧设置项**。
       - **推荐方案 A（只改 `XSkinOptionsPage` 展示层）**：保留 `XOptionsScene.status_text()` 与 `XConfig.battle_speed_text()` 原样（继续返回 `"ON"`/`"OFF"`），仅在 `XSkinOptionsPage`（`sync()` 右列与 `_sync_card()` 副标题）做映射转换（`"ON"→"开"`、`"OFF"→"关"`、`battleAniSpeed` 的 `"OFF"→"原速"`）。这样**不影响重制版 0.01.x 玩家看到的旧设置页、不用走重制版发布补丁（`发布补丁.py`）**、25 张 `皮肤关闭对照` 仍 100% SAME，且旧测试 `xiyou_options_basic` 等断言 `== "ON"/"OFF"` 全部不破（只需同步更新 `tests/xiyou_ui_skin_5c.gd:175` 的 `"ON"/"OFF"` 断言）。
       - **方案 B（改共用 `XOptionsScene` / `XConfig` 返回值）**：若要求旧设置页也一并汉化 `ON`/`OFF`，会改变重制版玩家可见界面，**必须走重制版发布补丁流程**并更新既有设置测试与皮肤关闭对照基线。
   - **③ 子页（画质设置等）版面未重排、字为旧蓝色（`XUI.SYSTEM` `#84aaff`）、无按键提示**：
     - **属有意留后续批，不是 5C 范围遗漏**。交付单「做了什么」「需要协调确认」「可优化」已明确 5C 目标为「设置主页套模板页＋子页居中外框保宽屏不变形」，子页重排另开批次（挂机主界面 13 窗＋范围图＋4 子页单页即是一批，手机按键需等第 6 期触屏统一按键提示方案）。
     - **建议**：保持留后续批，不卡 5C：把「画质设置／消息提醒／屏蔽掉落／角色换装」4 个简单子页合并为 1 批套 `XSkinTemplatePage`（自动切黑体、替换 `XUI.SYSTEM` 蓝字为 `TEXT_2`/`GOLD`、带 `XSkinKeyHints`）；「挂机设置」单独 1 批；「手机按键」归第 6 期。若协调介意重排前子页蓝字刺眼，可仅在这些子页内按 `if XUiSkin.on():` 把说明色换成 `XUiSkin.TEXT_2`（**切勿全局修改 `XUI.SYSTEM`**，以免波及未重排旧窗与重制版）。
5. **文字审（对照 `ba1f7ed` 口径＋实查 38 条设置源码＋字集覆盖）**：
   - `ba1f7ed` 口径（`XUiSkin.GROUPS` `"画面、声音、挂机与操作"`、`"返回标题"` 统一）、`XSkinOptionsPage` 标题/分类名/按键提示格式（`Q / E` 空格、`智能战斗 AI` 空格、`OFF 为原速` 空格、全角标点）均符合规范。
   - 交付单「新增可见文字」表中标注“按名字推”的 4 条及 `codexEncounterTarget` 经对照真实游戏源码核实，**有 5 条存在事实错误、以偏概全或歧义**，列为「文字必改」。

### 问题清单（P1 / P2 / P3）

- **P1**：无。
- **P2-1（`屏蔽掉落` 详卡操作提示错误｜只看代码）**：
  - `modes/xiyou/ui/skin/skin_options_page.gd:196` `_sync_card()` 先判 `if XOptionsScene._group(sym) in ["flag", "session"]`，后判 `elif PAGE_SYMBOLS.has(sym):`。由于 `pingbiDrop` 在 `XConfig.SESSION_FLAGS` 中，`_group("pingbiDrop")` 返回 `"session"`，导致详情卡「操作」写成了**「确定切换，左右键直接选择。」**，而实际 `options_scene.gd:250` 确定是进入 `XPingbiScene` 子页。
  - **改法**：把 `if PAGE_SYMBOLS.has(sym):` 提前到 `elif XOptionsScene._group(sym) in ["flag", "session"] or ...:` 之前。
- **P2-2（设置主页状态词中英混用｜看截图＋读代码）**：
  - 见上 #4②：`ON`/`OFF` 与中文「新」「原版」「全部」「简化」「关」同屏混用。按**推荐方案 A**在 `XSkinOptionsPage` 展示层统一为 **`开` / `关`**（`battleAniSpeed` 的 `OFF` → **`原速`**，同步修改 `DESC["battleAniSpeed"]` 及 `tests/xiyou_ui_skin_5c.gd:175`），**不动重制版可见旧代码**；若协调拍板走方案 B 改共用函数，需明示走重制版发布补丁。
- **P3-1（`options_screen` 截图显示「界面动效 关」非默认｜看截图＋读测试）**：
  - `tests/xiyou_ui_skin_5c.gd:158` 在 `await shots("ui_skin_5c_options_screen")`（L208）前设置了 `motion_override = OFF`，导致协调审图时看到「关」而非默认「全部」。建议在 L208 截完主屏图前保持 `-1`（或改在截完后如需固定动效再设 `OFF`）。
- **P3-2（设置主页存在双层 `SkinBackdrop`｜只看代码）**：
  - `XOptionsScene._add_backdrop()`（`options_scene.gd:199`）与 `XSkinTemplatePage._ready()` 各建一层 `SkinBackdrop`（外层保子页隐藏 `skin` 时不断底，主页面内层不透明底板遮住外层）；无画面缺陷，仅多 1 个被遮挡的 `Embers` 粒子节点，留待后续或加 `has_backdrop` 控制即可。
- **P3-3（可选 `DESC` 措辞微调，非必改）**：
  - `codexUiSkin`：现「「新」是天启篇的新界面，「原版」沿用旧界面。切换后返回地图时生效。」→ 可微调为「「新」是天启篇的新界面，「原版」沿用旧界面。切换后本页立即生效，退出设置将返回地图。」（更贴合当前切换后本页立即换皮的实际行为）。
  - `codexScreenFx`：现「大厅里的光尘和氛围小字。」→ 代码还控制庆典大厅彩纸（`fest_lobby.gd`）与裂隙二阶预兆（`rift_alien.gd`），可微调为「大厅里的光尘、庆典粒子与氛围特效。」。
  - `dhtg`：现「对话可以跳过。只在本次游戏有效。」→ 实际 `message_box.gd` 是开启后快进并自动跳过对话（选项除外），可微调为「对话快速显示并自动跳过（选项除外）。只在本次游戏有效。」。
  - `CombatDamageShow`：现「战斗中在角色身上显示伤害数字。」→ 实际含敌人与恢复数字（`mv_animation.gd`），可微调为「战斗中在敌我双方身上显示伤害与恢复数字。」。

### 文字必改（给改好的字，均已核 `charset_hei.txt` 无缺字）

1. **`pingbiDrop`（屏蔽掉落）**：
   - 现文：`选择不想看到的掉落，进入后设置。`（错：实为过滤不掉落／不获得，并非隐藏不看，且仅过滤武器与防具）
   - 改好：`屏蔽指定品质的武器与防具掉落，进入后设置。`
2. **`CombatDamageRecordKey`（战斗伤害记录）**：
   - 现文：`战斗中记录每次伤害，方便事后查看。`（错：`damage_record.gd` 与 `battle_scene.gd:2539` 在战斗结束/逃跑/全灭时即刻销毁节点，**无法事后查看**，仅战中右下角实时显示）
   - 改好：`战斗中在右下角实时统计出战角色的伤害与占比。`
3. **`battleAniSpeed`（战斗变速）**：
   - 现文：`战斗动画的播放速度。倍数越高越快，OFF 为原速。`（不准：实同时加快战斗动画、行动等待与移动节奏）
   - 改好（按现状态词）：`战斗动画与行动节奏的播放速度。倍数越高越快，OFF 为原速。`
   - 改好（若同步按 P2-2 将状态改中文 `原速`）：`战斗动画与行动节奏的播放速度。倍数越高越快，「原速」为正常速度。`
4. **`HangUp`（挂机设置）**：
   - 现文：`设置自动挂机的技能、吃药和卖出规则，进入后设置。`（以偏概全：实际含挂机范围、快速战斗、逃跑规则、技能、吃药、卖出与屏蔽掉落等 13 项）
   - 改好：`设置自动挂机的范围、逃跑、技能、吃药与卖出等规则，进入后设置。`
5. **`codexEncounterTarget`（定向遇怪）**：
   - 现文：`指定要遇到的敌群稀有度。档位越高，越难遇到。`（易误解：`XEncounterTarget.pick` 是优先匹配对应稀有度的敌群，而非越调越难遇敌）
   - 改好：`指定要遇到的敌群稀有度，档位越高对应越稀有的敌群。`
6. **状态词中英统一（P2-2）**：
   - `XSkinOptionsPage` 展示层将 `ON` → `开`、`OFF` → `关`、`battleAniSpeed` 的 `OFF` → `原速`。

### 没核到的（留总装 `--affected --cloud` 及后续环节）

- 未在本地有窗重跑 `皮肤关闭对照.py` 做 25 张逐像素比对、未重拍 `ui_skin_5c` 截图（仅按已有测试结论与 `offshot` 23/23 无头构建通过记档）；
- 未跑 `并行测试.py`、`工具回归.py`，以及因修改 `xconfig.gd` 扩到的 206 个选测场景全集（含 `xiyou_ui_skin_menu`、`1b`、`1c`、`battle_options`、`hangup_options`、`power`、`smart_ai`、`tianqi_e2e`、`virtual_player` 等），按要求留总装 `--affected --cloud`；
- 未在当前工作树直接读到 `重制设定/界面风格提案_v0.7/` 与早先 `ba1f7ed` 原提交，对照 `ui_skin.gd`、`4b780b162` 及过往交付记录的 `ba1f7ed` 口径核实。


## 核查后返工（cc，小A 17e193430 不通过后）

- P2-1：`XSkinOptionsPage._sync_card` 先判子页（`PAGE_SYMBOLS`）再判开关，屏蔽掉落详情牌改为「确定进入。」。
- P2-2：状态词只在新设置页展示层统一（新增 `XSkinOptionsPage.status_of`，右列与详情牌副标题都走它）：ON→开、OFF→关、战斗变速的 OFF→原速。`XOptionsScene.status_text`、`XConfig.battle_speed_text` 与存值不动，重制版旧设置页玩家看到的不变（皮肤关闭对照 25 张仍逐像素 SAME）。专项断言同步改（`opt_row_status_updates`），另加：英文状态词不再出现、「原速」、详情牌「确定进入」。
- 文字：必改 5 条 DESC（屏蔽掉落、战斗伤害记录、战斗变速改用「原速」版、挂机设置、定向遇怪）按小A原文；P3-3 四条润色也采纳（界面风格、画面特效、对话跳过、显示伤害数字）。这些 DESC 只在 `XSkinOptionsPage.DESC`，旧设置页不读，所以**重制版旧页未改**（旧页没有说明文字）；旧页的 ON／OFF 若要也汉化，要改共用函数并走重制版补丁，等 Kyo 定。
- P3-1：专项截图前不再把 `motion_override` 钉成 OFF，`ui_skin_5c_options_screen` 已重拍（界面动效显示默认「全部」）；全部 9 页 18 张重拍。
- P3-2：新设置页不再自建第二层 `SkinBackdrop`（只留 `XOptionsScene` 自己那层，子页盖上时也有底），专项加断言。
- 复验：专项 `xiyou_ui_skin_5c` 无头 79/79、有窗 97/97；`xiyou_ui_skin_offshot`、`xiyou_options_basic`、`_misc`、`xiyou_graphics_options`、`xiyou_ui_skin_menu` 全过；语法检查 0 问题；`发行空壳.py check` 通过；`皮肤关闭对照.py --base 17be52a65`（本分支切出点；对最新 main 比时 main 已有新类、克隆的类缓存认不得，报解析错，与本批无关）25 张 SAME。
