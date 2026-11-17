# 交付：luiluu/cc-font-v00300（T100）

- 车道／工作者：B 界面／cc 车道（Sonnet 5.5＋medium，P6）
- 状态：可合并（小A 核两次退回的 P1「描边」已补齐：R1 skin/ 目录、R2 ui/ 与 map/，待复核）

## 变更记录草稿

## 2026-11-16 【cc·天启篇·未经审查】新界面字体改回玩家版那一款（T100，dev.待定）

- 依据 D153（Kyo 11-16「现在玩家玩的 v00300 字体就很舒服了」）。
- **v0.03.00 玩家版实际字体**（查自 `core/game_font.gd`、`modes/xiyou/ui/xui.gd`）：全部旧页统一一款 `modes/xiyou/generated/fonts/FZLanTYJW_ZhongCu.TTF`（方正兰亭中粗，经 `GameFont.current()`），关掉子像素定位（与 MV 度量一致），落回系统字体 PingFang SC／微软雅黑；默认字号 26（`XUI.FONT_SIZE`，乘字体大小设置）；Label／Button／RichText 描边 1px、黑色 0.45 透明；标题、正文、数字没有分款，同一款。
- 修前新皮肤（`XUiSkin.font(kind)`）用三款裁字字体：标题思源宋体 Heavy、正文思源黑体 Medium、数字 Barlow Condensed Medium，描边 0（只有 `XUiSkin.theme()` 后来加了 1px，自绘字、按钮、工坊 LabelSettings 等仍是 0）。
- 修后：加开关 `XUiSkin.FONT_V00300`（默认 true），`font()` 对 title／body／num 一律返回 `GameFont.current()`；描边也同旧页（1px、黑 0.45）。false＝回到三款裁字字体、描边 0（文件还在 `content/ui_skin/fonts/`，没删）。所有调用处（约 60 处，主菜单、战斗列表、工坊、祭坛、提示窗……）都走 `font()`，一处改全到位。
- 数字字体：**换**成同一款。理由：玩家版数字一直是这款；Barlow 窄体与汉字不同族，同一行里「Lv 1」「8000」与汉字高低粗细不齐（见修前截图）；三款并成一款后「选中」「升级」等换 kind 的地方不可能再换字形。代价：窄体省的宽度没了，血条旁数字宽一点，截图里未见挤行。
- **描边补齐（小A 核 P1 返修）**：新增 `XUiSkin.outline_size()`／`outline_color()`／`ds()`；`ds` ＝ 开关开着先 `draw_string_outline` 1px 黑 0.45（随字色透明度）再 `draw_string`，关着＝原样 `draw_string`。全部 skin_*.gd 与 `tianqi_skin_altar.gd` 的自绘字改走 `ds`（含 `skin_4a.backed_text`、`skin_art.bg_string`：READ 开着已描粗边则不叠；`skin_ring_nav` 的 Font.draw_string(RID) 上一行本就描边，不动）。Label／按钮走 theme 或各自设置：`XSkinButton.apply`（原显式 outline_size=0）、`alien_workshop._skin_label` LabelSettings、`whats_new_page`、`tianqi_title._skin_extras`、`XToast`、`XWebPanel`（1px，旧页原来 2px 黑实边，新皮肤下收成 1px 黑 0.45，同玩家版 XUI.theme）。关开关＝全部回修前。
- 新断言（修前失败：skin_button_outline、no_raw_draw_string 两条红，修后 111/111）：`t100_outline_values`、`t100_theme_outline_color`、`t100_skin_button_outline`、`t100_no_raw_draw_string`（扫 skin 目录不许再有裸 `draw_string(`，两处有注释的豁免）、`t100_switch_off_no_outline`。
- 截图脚本叠两条 toast：原因是先设 `flags.tianqi` 再 `add_actor`，会弹「只从方桌大厅招募」toast 且拒绝入队；已改成先 `add_actor` 再设标记，并清掉残留 XToast，标题不再被盖。
- **R2 返修（小A 复核 d4df5e1ba）**：ui/ 与 map/ 下新皮肤分支的裸 `draw_string` 全改走 `XUiSkin.ds`：`list_pager`、`map_transfer`（2）、`power_notice`（新皮肤 5 处）、`skill_notice`（新皮肤分支 1 处）、`prestige_notice`、`achievement_popup`、`message_box`、`map_hud`（3）、`hang_up_overlay`（3）、`tianqi_table`（2）。关开关＝原样。仍保留裸调用的是旧页自带描边／阴影的路径（`mv_canvas`、`item_scene` 的 MAX、`power_notice`／`skill_notice` 旧样式、`fest_lobby`、`designation_plate`（已自带 2px 描边）、`treasure_popup`、`map_scene` 与 `difficulty_notice` 的 1px 阴影字、`skin_art` READ 粗边、`skin_ring_nav` 的 RID 版），按「文件: 条数」登记在断言里。
- **断言扩面**：`t100_no_raw_draw_string` 现在扫 `ui/`、`ui/skin/`、`map/` 三个目录所有 .gd，裸 `draw_string(` 条数必须等于登记数（多了或少了都红）。修前（撤掉这 10 个文件的改动）失败，列出 10 个文件；修后 111/111。
- **P3，记录不改**：① `skin_4a.backed_text`、`skin_battle_ring`（标题与球字）、`skin_boss_arc`、`skin_otb_bar`、`skin_side_status`、`skin_ring_nav`:747、`tianqi_skin_altar`:459 在原有 3～5px 粗描边上又叠了一层 1px `ds`，肉眼几乎看不出差别，没去重；② `skin_party_strip`:223 深色字被加了黑边，对比度略降。**合并冲突提醒**：`skin_battle_ring`、`skin_boss_arc`、`skin_otb_bar`、`skin_side_status` 这几个文件 T125（`luiluu/cc-battle-ui-v07`）也在改，同一批 `draw_string`→`ds` 的行会冲突，合并时以 T125 的结构为准、再把 `draw_string(` 换成 `XUiSkin.ds(<画布>, ` 即可（断言会兜底）。
- 页签选中不换字体：新皮肤页签（`skin_tab_strip.gd`）选中与否本就都用 body 字体、只放大字号（`XSkinSelScale`）；现在三个 kind 同一字体，工坊 `_skin_label` 的 title／body 切换也不再换字形。没有碰 T095 的 `skin_template_page.gd`／`skin_main_menu.gd`／`skin_key_hints.gd`，rebase 无冲突风险。
- 专项：`xiyou_ui_skin` 加 `t100_all_kinds_game_font`、`t100_theme_default_font`；原三款字体断言包在开关关的区段里照验（回退支）。
- 修前修后截图（工具 `tests/t100_font_shots.tscn`，`--old` 拍修前）：`04_验证/本地结果/t100_font/old_*.png`／`new_*.png`（未入库）：01 主菜单、02／03 工坊页签、04 战斗指令窗、05 战技列表、06 选择难度。选择难度页本来就是旧页（XUI），修前修后一样，如实标明。
- 玩家可见：天启篇新界面的字体换成与现版一致的方正兰亭。

## 我不同意的地方

- **EMBOLDEN**：小A 提到的给字体加粗（EMBOLDEN）我不同意。玩家版旧页只是 1px 黑 0.45 描边、没有合成加粗；方正兰亭中粗本身就是粗体，再 embolden 会糊字、笔画粘连、字宽变化让现有排版和裁字（`fit_text`）失准，且偏离「和玩家版一致」这个目标。要的话 Kyo 拍板后单开一单。

## 交接板

- 下一步：无
- 需要用户决定：无（开关默认接受；Kyo 若想数字保留窄体，把 `font()` 里 num 改走旧路径即可）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 语法检查通过；`xiyou_ui_skin` 及其 `_1b／1c／3a／3b／4a／4b／5c／battle／close／hud／menu／p1fix`、`xiyou_ui_sel_scale`、`xiyou_ui_art_phase01`、`xiyou_list_pager`、`xiyou_tianqi_ring_style` 共 17 个场景全过。
- 开关 `FONT_V00300` 已登记 O-551（`优化登记.md`；合并时若号被占，总装顺延）。
- 返修后复跑：上述 17 个场景＋`xiyou_alien_workshop`、`xiyou_whats_new` 全过；语法检查通过。截图已重出（修前 old_*／修后 new_*，同目录，未入库）。

## 本分支提交

- 见 git log
