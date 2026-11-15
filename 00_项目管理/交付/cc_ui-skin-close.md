# 交付：cc/ui-skin-close

- 车道／工作者：B 界面·新皮肤「收口批」（换芯＋字号触屏＋舒适＋D45／D44 方案图）／cc（Opus＋medium，派单定：跨多页、碰共用皮肤组件和字号设置）
- 分支：`cc/ui-skin-close`（从 `cc/ui-skin-p1fix` 41956d0e1 切出；p1fix 进 main 后已再合 main，无冲突，合后本地重跑皮肤专项全过）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·天启篇·未经审查】新界面收口批：详情牌换芯、字号跟设置、触屏能点能拖、护眼小调（dev.待定）

- 玩家可见：天启篇新界面里，装备／物品／技能详情牌不再是旧说明卡的纯黄、大红、青蓝字，按「自带／词条／套装／说明」分节，去掉重复的品质、武器种类行和买卖价格（价格只在商店看）；战斗里技能说明框挪到行动顺序条上面，不再盖住头像。字号跟「字体大小」设置一起变大，手机上默认再大一档；手机上底部按键提示变成能点的按钮，每页左上有「‹」返回，列表能手指上下拖（松手才算点，不再一碰就用掉），打开全屏菜单时虚拟摇杆和 AB 键自动收起，战斗指令环固定在右下角。正文换成柔一点的骨白，灰字提亮，「优秀」品质绿调柔，「使用／装备／揭印」大按钮平时是旧金色、选中才变红，选目标的金圈不再一秒闪两下，队伍血条加粗，七印祭坛状态前加 ◆／◇／· 记号，主菜单组图标选中的红底调暗。只在天启篇新皮肤生效，重制版旧界面不变。
- 依据：私密设计仓 `重制设定/界面风格提案_v0.7/` 的 Fable审_实装与方向（P1-1、P1-3、P2-1、P2-8、A1～A4、A8、A20，舒适 C1～C4）、小A审_实装与方向（P1-1、P1-4、P1-5、P1-6）、小A审_美化舒适（舒适 1～4、6、7）；Kyo 11-15 定：触屏指令环固定右下、优秀绿调柔、u4 不改形只调暗选中红底、D44 暖底先出对比图不改默认、D45 小人和头像都要。
- 改动（开关全在 `XUiSkin`，都登记优化登记、默认开；关掉＝回 p1fix）：
  - `CORE_V2`：`XUiSkin.legacy_color`（旧颜色对照表）、`XSkinTemplatePage.help_rows` 过表＋去品质／种类／价格行＋一格多句拆开判、`help_sections` 分节；物品页装备牌用分节；`XBattleScene._help` 新皮肤时说明卡底边收到行动条顶上 12（`XSkinBattle.help_card_pos`）。
  - `FONT_V2`：`FS_LIST`／`FS_LIST_MAX`／`FS_AUX`／`FS_AUX_MAX`／`FS_MIN` 改成按开关取值的静态属性：×`XFontScale` 全局档 ×触屏 1.1，封顶 1.3；辅助字 14→15。页名、牌上大名字不放大；行高不动。
  - `TOUCH_V2`：`XSkinKeyHints` 触屏时画成高 44 的胶囊、点了发对应键（确定／取消动作、Q/E/X/Y/C 键码，两向键点左半右半）；新 `XSkinBackButton`（模板页左上「‹」＝取消）；`XSkinList` 拖动滚动、松手才算点、滚动条 4→8；模板页／主菜单／七印祭坛进 `skin_fullscreen` 组，`XTouchControls` 见组里有可见页就收起摇杆和按键（含「隐藏按键」钮）；`XSkinBattleRing.place_for_actor` 触屏固定右下。
  - `COMFORT_V2`：`TEXT` #f0f0ee→#e6e2dc、`TEXT_3` #7d8086→#8e8982、`QUALITY[1]` #80ff1c→#8fdc5a；`primary_button_style`（平时 #2b2318 底＋旧金边，焦点才红）用在详情牌和祭坛；`target_pulse`（选目标金圈 2.4 秒余弦，原 sin 绝对值每秒两闪）；`bar_h`（队伍条、侧栏血条 8，蓝条 TP 仍 5）；`XTianqiSkinAltar.STATE_TEXT` 加 ◆◇·；`XSkinRingNav` 选中画常态贴图＋程序暗红圆底 #7a1a14。
  - `WARM_BG`（D44，默认 false）：底、面板、线换暖炭黑；只出对比图。
  - `CENTER_STYLE`（D45，默认 `FACE`＝现在的大头像）：`SPRITE` 方案 A、`SPRITE_BADGE` 方案 B（见「截图」），等 Kyo 定。
  - 「界面动效」说明加一句「选简化或关，选中条就不再呼吸」（呼吸光可关＝已有的动效档，没另加设置项）。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/ui/skin/ui_skin.gd` `XUiSkin.CORE_V2`；`skin_template_page.gd`、`skin_item_page.gd`、`skin_battle.gd`、`battle/battle_scene.gd` | 详情牌原样灌旧说明卡的行和 MV 老颜色（纯黄价格、红属性、青蓝说明），带品质／种类／买卖价行；战斗说明卡盖行动条 | 旧颜色对照表、去重复行和价格、装备分节；战斗说明卡收到行动条上方 | Fable审 P1-1／A1／A19、小A审 P1-4／P1-6 | `XUiSkin.CORE_V2 = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/ui_skin.gd` `XUiSkin.FONT_V2` | 新页面字号写死，不认字体大小设置 | 列表、辅助字号 ×字体大小档 ×触屏 1.1（封顶 1.3），辅助字下限 15 | Fable审 P1-3／A2、小A审 舒适 5 | `XUiSkin.FONT_V2 = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/ui_skin.gd` `XUiSkin.TOUCH_V2`；`skin_key_hints.gd`、`skin_back_button.gd`、`skin_list.gd`、`skin_battle_ring.gd`、`core/touch_controls.gd` | 触屏没有能点的提示和返回，列表一碰就触发、不能拖，菜单里虚拟键压在界面上，指令环跟着角色跑 | 提示胶囊可点、左上「‹」返回、列表拖动＋松手才点、全屏菜单收虚拟键、触屏指令环固定右下 | Fable审 P2-1／P2-8／A3／A4／A8／A20、小A审 P1-1／P1-3／P1-5，Kyo 定指令环右下 | `XUiSkin.TOUCH_V2 = false` | cc | 保留 |
| O-待定 | `modes/xiyou/ui/skin/ui_skin.gd` `XUiSkin.COMFORT_V2`；`skin_card.gd`、`tianqi_skin_altar.gd`、`skin_otb_bar.gd`、`skin_party_strip.gd`、`skin_side_status.gd`、`skin_ring_nav.gd` | 正文近白、禁用灰过暗、优秀荧光绿、主按钮常驻大红、选目标每秒两闪、血条 5px、祭坛状态只靠颜色、u4 选中亮红盘 | 骨白正文、灰提亮、优秀绿 #8fdc5a、按钮平时旧金、2.4 秒慢呼吸、血条 8px、◆◇· 记号、选中暗红圆底 | Fable审 C1～C4、小A审 舒适 1～4、6、7，Kyo 定优秀绿调柔、u4 只调暗 | `XUiSkin.COMFORT_V2 = false` | cc | 保留 |

（`WARM_BG`、`CENTER_STYLE` 默认关、只是待 Kyo 定的方案，不是优化项，没登记；Kyo 定了再登记。）

## 截图（本机，不入库）

目录：`03_再刷重制_Godot/04_验证/本地结果/ui_skin_close/`（`xiyou_ui_skin_close` 带 `--out` 拍）

- 改前改后：`<页>_<16x9|20x9|4x3>_<before|after|after_touch>.png`，页＝items（武器牌分节）、equip、skill、menu、altar；`before`＝收口批四个开关全关（＝p1fix），`after`＝全开键盘，`after_touch`＝全开＋按触屏画；`*_compare.png` 左改前右改后（触屏）。
- 战斗：`battle_before/`、`battle_after/`、`battle_after_touch/`（`xiyou_ui_skin_battle -- --out=… [--close-off|--touch] [--wide|--tablet]`），各含指令环、战技列表、物品列表、选目标、8 行列表 × 16:9／20:9／4:3。
- D45：`d45_now_face_*`（现在）、`d45_A_sprite_*`（方案 A：环心 3× 站立小人，头像留在右栏队伍卡）、`d45_B_sprite_badge_*`（方案 B：环心小人＋右下叠一枚小圆头像，金边），`d45_A_vs_B_16x9.png`／`_20x9.png` 并排。小人播站立 0-1-2-1（「全部」动效档才动）。
- D44：`d44_<menu|items|altar>_cold_vs_warm.png`（左冷黑默认、右暖炭黑）。
- 皮肤关闭对照：`skin_off/`（`皮肤关闭对照.py`，32/32 与 main 逐像素一致）。

## 新文字（请小A审）

- 详情牌分节标题：「自带」「词条」「套装」「说明」。
- 七印祭坛状态：「· 未开启」「◇ 可揭开」「◆ 已揭开」。
- 触屏提示胶囊只写原提示的说明部分；两向键写成「‹ 换人 ›」「‹ 换组 ›」「‹ 翻页 ›」「‹ 调整 ›」「‹ 选状态 ›」「‹ 换分类 ›」。
- 左上返回只有一个「‹」记号，无字。
- 设置「界面动效」说明改为：「选中条呼吸光、法阵转动等界面动画。选「简化」或「关」，选中条就不再呼吸。省电模式下默认为简化。」

## 验证

- 本地专项（无头）：`xiyou_ui_skin_close` 47/47（窗口出图时 141/141），`xiyou_ui_skin` 104、`_1b` 85、`_1c` 78、`_3a` 90、`_3b` 39、`_5c` 79、`_menu` 99、`_hud` 104、`_battle` 61（窗口 66，含 `--close-off`、`--touch`、`--wide`、`--tablet` 九种组合全过）、`_p1fix` 1、`_offshot` 29，全过。改了这几个旧专项里依赖旧值的断言：`xiyou_ui_skin` 色值验关掉开关时的定稿值；`_1b`／`_1c` 点列表补发松手；`_3a` 状态字、`_menu` u4 选中贴图随 `COMFORT_V2`；`_battle` 环跟角色两条在触屏固定时跳过。
- `语法检查.py` 通过；`皮肤关闭对照.py` 32/32 SAME。
- 回退：四个开关在 `xiyou_ui_skin_close` 里都有字面量设 false 的断言（各自回到 p1fix 的值或行为）。
- 云端选测：3589548049（选测 152 场景，基准 238cd1822；因为 p1fix 还没进 main，选测把 p1fix 的改动也算进去了），结果见下一行。
- 云端结果：3589548049 选测 152 场景 6 片全过（actions/runs/43749341412）。

## 交接板

- 下一步：本单可直接合（p1fix 已进 main、已合）；之后按 Fable 审的顺序排 4A。
- 需要用户决定：D45 选 A 还是 B（`XUiSkin.CENTER_STYLE`）；D44 要不要换暖炭黑（`XUiSkin.WARM_BG`）。图见「截图」。
- 用户试玩说明：天启篇存档里看物品／装备详情牌、战斗技能说明、手机上点底部提示和左上返回、拖列表。

## 进度账

- 新界面（天启篇）：收口批完成，后续 4A／2C／5A／5B 可以在这个底座上铺。

## 没做的（留给后续批）

- 战斗里的旧说明卡（XHelpCard）只挪了位置，卡里还是旧颜色和旧框（2C 一起换成皮肤卡）；技能页牌只过了颜色表，没按「效果／用法」分节（技能说明结构不同，留 5A）。
- 触屏胶囊底边和面板下沿贴得很近（胶囊高 44、离底 10）；4A 全局铺满时一起调底边距。
- 触屏指令环只是整环挪到右下，没按拇指弧线重排、开列表时环不淡出（Fable A20 后半）。
- 页签统一（A6）、提示道（A7）、确认弹窗／数量选择件等 Fable「先做」里不在本单的项没做。
- 呼吸光：没加单独的设置项，靠已有「界面动效」档（简化／关）关掉；没做 8 秒无操作自动停。
- 没上真机：触屏全部是按 `XUiSkin.touch_override` 模拟和截图看的。

## 可优化（流程／工具／效率）

- 已做：`xiyou_ui_skin_battle` 加 `--close-off`、`--touch` 参数，`_1b`／`_1c`／`_3a` 截图加 4:3，以后出改前改后图不用再写一次（回退：不带参数就是原行为）。
- 建议：截图专项统一一个「开关全关拍改前」的参数约定（现在 p1fix 用 `_pair`、本单用 `--close-off`），归界面车道。

## 本分支提交

- 7b996112b 收口批 1 换芯
- e1dfec4c1 收口批 2 字号与触屏
- 2d5d0ea29 收口批 3 舒适
- eedda4502 收口批 4 D45／D44
- 358954804 合并 main

## 小A乙档核查（2026-11-15，Antigravity）

- **结论**：**不通过（需修 2 项 P1 触屏硬伤后再合）**。CORE_V2、COMFORT_V2 与 D45/D44 对比图整体实装扎实、四个开关回退完备；但 TOUCH_V2 存在两处可直接复现的触屏故障（祭坛胶囊底边裁切、`"Y / 取消"` 与 `"上下"` 胶囊点按无效且文案错位），另有三项 P2 覆盖度／宽窄屏适配问题及文字审细节需处理或记录。

### 一、问题清单（P1 / P2 / P3）

- **P1-1【祭坛触屏提示胶囊底边被裁切出屏幕】**（实测＋像素核查）
  - 位置：`modes/xiyou/ui/skin/tianqi_skin_altar.gd:220`（同款隐患：`modes/xiyou/ui/tianqi_title.gd:305`）。
  - 现象：`relayout()` 用固定常量 `XSkinKeyHints.H`（`22`）算 `y`，未调 `hints.height()`（触屏为 `TOUCH_H = 44`），导致触屏下 `y = 688`、底边伸到 `732 > 720`。
  - 证据：无头探测实测 `altar_hints rect=(707,688,494,44)` 超出视口底边；PNG 像素检测 `altar_16x9_after_touch.png`、`altar_20x9_after_touch.png`、`altar_4x3_after_touch.png` 最底一行（`y = h - 1`）均见 16～20 个胶囊非背景像素（其余页面底部均正常留空 10px）。
- **P1-2【`"Y / 取消"` 与 `"上下"` 触屏胶囊点击无效且显示错位】**（实测＋代码核查）
  - 位置：`modes/xiyou/ui/skin/skin_key_hints.gd:42-67`、`skin_equip_page.gd:107`、`tianqi_skin_altar.gd:211`、`skin_status_page.gd:37`（旧页附带：`map_transfer.gd:170` `再点地图名`）。
  - 现象：① `detail_hints()`（`["Y / 取消", "收起"]`）与祭坛规则态（`["Y / 取消", "关闭"]`）：`is_pair()` 因包含 `"/"` 误判为双向键，把单键胶囊画成 `‹ 收起 ›` / `‹ 关闭 ›`，且 `key_events("Y / 取消")` 返回 `[]`，触屏点按无反应（`fire()` 返回 `false`）；② `["上下", "滚动"]` 未被 `is_pair()` 与 `key_events()` 识别（只认 `"左右"` 与 `"↑ / ↓"`），既少画了 `‹ ›`，点击也完全无反应。
- **P2-1【左上 `‹` 返回未覆盖主菜单与祭坛页，且模板页右货币被连带左移 36px】**（像素核查＋代码核查）
  - 位置：`skin_template_page.gd:151, 406-412`、`skin_main_menu.gd`、`tianqi_skin_altar.gd`、`skin_party_status.gd`。
  - 现象：交付单玩家可见描述写「每页左上有『‹』返回」，`Fable审 P2-1/A4` 也要求整页左上固定 `‹`；目前仅 `XSkinTemplatePage` 子类（物品/装备/技能/状态/设置）有 `XSkinBackButton`，`XSkinMainMenu` 与 `XTianqiSkinAltar`（尤其规则态无 `‹` 易卡住）均未加。另 `skin_template_page.gd:408` 把 `m += XSkinBackButton.W` 加在共享 `m` 上，使顶栏右上货币 `view.x - m` 也多左移 36px。
- **P2-2【列表触屏拖动未覆盖状态页／战斗列表，部分全屏子页未进 `skin_fullscreen`】**（只看代码）
  - 位置：`skin_status_page.gd:311-323`、`skin_battle_list.gd`（继承 `battle_list.gd:160-200`）、`skin_gear_detail.gd`、`skin_party_status.gd`。
  - 现象：`小A审 P1-1` 点名了 `skin_list.gd`、`skin_status_page.gd`、`skin_battle_list.gd` 三处，本单只改了 `XSkinList`；状态页与战斗列表仍无 `InputEventScreenDrag`、仍用 `2/4px` 滚动条且战斗列表仍是按下即选中/触发。另 `XSkinPartyStatusPanel`、`XAlienWorkshop`、`XMapTransfer` 未进 `skin_fullscreen` 组；物品/装备打开 `search_panel` 或设置进子页藏起 `skin` 时，虚拟摇杆与 AB 键会重新弹出盖在子页上。
- **P2-3【130%＋触屏字号在窄屏／左环／未接入控件处局部越界或未跟放】**（实测字宽＋只看代码）
  - 位置：`skin_ring_nav.gd:268`、`skin_list.gd:22-23`、`skin_battle_list.gd:10, 184`、`skin_status_page.gd:242`、`skin_main_menu.gd`。
  - 现象：① 实测字体宽度：`130%`＋触屏（`FS_LIST=25, FS_AUX_MAX=22`）下，`XSkinRingNav` 选中态按 `25px` 画字，右侧球位（`item_pos.x=258`）的「重要物品 0」（宽 120px）、「挂机与操作」（宽 125px）会超出左栏右沿 `300px` 约 18～20px 伸入间隙；`4:3`（`960×720`）下设置中栏宽仅 `228px`，长设置项（需 `367px`）和两列物品名（每列约 `110px`）需缩到 16 号并大量截成 `…`。② 只看代码：`XSkinList.font_size` 在构造时取值，设置页现场改字号不即时刷新当前列表；`skin_status_page.gd:242` 字号上限写死 20；`skin_battle_list.gd:184` 行高固定 44 且技能名未用 `fit_text` 截字，长技能名配右消耗＋「TP不足」仅余约 116px 宽，大字号有压字风险。
- **P3【文字审与小瑕疵】**（实测＋代码核查）
  - **文字审 1（漏列与冲突）**：`tianqi_skin_altar.gd:212` 新增 `["← / →", "切换印"]`（显示 `‹ 切换印 ›`），交付单「新文字」一节漏列（另 `message_box.gd` 有 `‹ 换位 ›`、`‹ 调数 ›`）；`"Y / 取消"` 被误判后呈现为带双向箭头的 `‹ 收起 ›`/`‹ 关闭 ›`（修 P1-2 即除）；`tianqi_skin_altar.gd:418` 环心进度数字下方直接复用了 `STATE_TEXT[2]`，导致环心显示 `◆ 已揭开`，建议环心去掉 `◆ ` 仅留「已揭开」。
  - **文字审 2（复核通过）**：分节标题「自带」「词条」「套装」「说明」（实测 152 武器＋254 防具走 `help_rows`/`help_sections` 后 `bad_rows_count=0`，无残留品质/种类/价格行或 `\c[...]`）、祭坛状态「· 未开启」「◇ 可揭开」「◆ 已揭开」、左上「‹」无字、设置「界面动效」新说明（核 `ui_skin.gd:313-325` `breathing()` 逻辑一致）均通顺准确。
  - **P3-3（范围外留后续与键盘记号）**：`XSkinBackButton` 在 `TOUCH_V2=true` 且非触屏时也常驻显示（代码已注“只是个记号”）；战斗旧 `XHelpCard` 仅挪位未换卡、技能与消耗品未分节、触屏指令环未淡出重排、无真机触屏测试，交付单均已如实标明留后续批。

### 二、核查对照与验证口径（实测 vs 只看代码）

1. **三份审稿对照**
   - **已修实测确认**：`CORE_V2` 旧色表去纯黄（`items_16x9` 黄像素 `254→0`）＋装备分节（152 武器/254 防具实测 `0` 残留行）＋战斗说明卡收至行动条上方（`battle_after` 差异框底止 `y≤541`）；`COMFORT_V2` 骨白正文 `#e6e2dc`、提亮灰 `#8e8982`、柔和绿 `#8fdc5a`、主按钮平时旧金 `#2b2318`（`equip_16x9` 亮红像素 `18814→0`）、血条 8px、祭坛 `◆◇·`（`xiyou_ui_skin_close`＋像素采样确认）；`target_pulse` 2.4s 慢呼吸与 `u4` 暗红选底 `#7a1a14`（专项断言＋代码确认）；D45 与 D44 默认态未改、对比图准确落在环心／徽章／底色。
   - **未修／部分修**：见 P1-1、P1-2、P2-1、P2-2、P2-3。
2. **本轮实测通过（前台单独运行）**
   - `语法检查.py`：949 `.gd`，0 问题。
   - `回退开关覆盖.py`：388 个开关，`ui-skin-close` 4 个新开关（`CORE_V2`/`FONT_V2`/`TOUCH_V2`/`COMFORT_V2`）均已有字面量回退覆盖，新缺口 0。
   - 专项无头：`xiyou_ui_skin_close.tscn` `47/47`、`xiyou_ui_skin_battle.tscn` `61/61`、`xiyou_ui_skin_3a.tscn` `90/90`（`xiyou_ui_skin` 104、`1b` 85、`1c` 78、`menu` 99 亦于本分支核查前期同过）。
   - 像素与数据验证：纯 Python 校验 `*_compare.png` 左右拼接与 `before`/`after_touch` 一致、`d44_*`/`d45_*`/`battle_after_touch/` 坐标与色值；`skin_off/base` 与 `skin_off/branch` 32/32 PNG SHA-256 全同；Godot 无头脚本实测全库 152 武器/254 防具/188 物品及 `130%`＋触屏字宽。
3. **只看代码**
   - `XTouchControls` 全屏隐藏交互、`XSkinStatusPage`/`XSkinBattleSkillList`/`XSkinGearDetail` 拖动缺口、键盘手柄下各页 `‹` 显隐与交互、`4:3`/`20:9` 列表实时交互效果（非实机手动点拖）。
4. **留给总装的长测试**
   - `03_再刷重制_Godot/07_开发环境/检查.sh --full`（含 `--oracle` 对照）；
   - 窗口模式实拍 `xiyou_ui_skin_close -- --out=...`（141 断言）及 `皮肤关闭对照.py` 全量重跑；
   - 云端选测／全量与安卓真机触屏实测。

