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
