# 交付：luiluu/cc-font-v00300（T100）

- 车道／工作者：B 界面／cc 车道（Sonnet 5.5＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·天启篇·未经审查】新界面字体改回玩家版那一款（T100，dev.待定）

- 依据 D153（Kyo 11-16「现在玩家玩的 v00300 字体就很舒服了」）。
- **v0.03.00 玩家版实际字体**（查自 `core/game_font.gd`、`modes/xiyou/ui/xui.gd`）：全部旧页统一一款 `modes/xiyou/generated/fonts/FZLanTYJW_ZhongCu.TTF`（方正兰亭中粗，经 `GameFont.current()`），关掉子像素定位（与 MV 度量一致），落回系统字体 PingFang SC／微软雅黑；默认字号 26（`XUI.FONT_SIZE`，乘字体大小设置）；Label／Button／RichText 描边 1px、黑色 0.45 透明；标题、正文、数字没有分款，同一款。
- 修前新皮肤（`XUiSkin.font(kind)`）用三款裁字字体：标题思源宋体 Heavy、正文思源黑体 Medium、数字 Barlow Condensed Medium，描边 0。
- 修后：加开关 `XUiSkin.FONT_V00300`（默认 true），`font()` 对 title／body／num 一律返回 `GameFont.current()`；`XUiSkin.theme()` 描边同旧页（1px、黑 0.45）。false＝回到三款裁字字体（文件还在 `content/ui_skin/fonts/`，没删）。所有调用处（约 60 处，主菜单、战斗列表、工坊、祭坛、提示窗……）都走 `font()`，一处改全到位。
- 数字字体：**换**成同一款。理由：玩家版数字一直是这款；Barlow 窄体与汉字不同族，同一行里「Lv 1」「8000」与汉字高低粗细不齐（见修前截图）；三款并成一款后「选中」「升级」等换 kind 的地方不可能再换字形。代价：窄体省的宽度没了，血条旁数字宽一点，截图里未见挤行。
- 页签选中不换字体：新皮肤页签（`skin_tab_strip.gd`）选中与否本就都用 body 字体、只放大字号（`XSkinSelScale`）；现在三个 kind 同一字体，工坊 `_skin_label` 的 title／body 切换也不再换字形。没有碰 T095 的 `skin_template_page.gd`／`skin_main_menu.gd`／`skin_key_hints.gd`，rebase 无冲突风险。
- 专项：`xiyou_ui_skin` 加 `t100_all_kinds_game_font`、`t100_theme_default_font`；原三款字体断言包在开关关的区段里照验（回退支）。
- 修前修后截图（工具 `tests/t100_font_shots.tscn`，`--old` 拍修前）：`04_验证/本地结果/t100_font/old_*.png`／`new_*.png`（未入库）：01 主菜单、02／03 工坊页签、04 战斗指令窗、05 战技列表、06 选择难度。选择难度页本来就是旧页（XUI），修前修后一样，如实标明。
- 玩家可见：天启篇新界面的字体换成与现版一致的方正兰亭。

## 交接板

- 下一步：无
- 需要用户决定：无（开关默认接受；Kyo 若想数字保留窄体，把 `font()` 里 num 改走旧路径即可）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 语法检查通过（985 个 .gd）；`xiyou_ui_skin` 及其 `_1b／1c／3a／3b／4a／4b／5c／battle／close／hud／menu／p1fix`、`xiyou_ui_sel_scale`、`xiyou_ui_art_phase01`、`xiyou_list_pager`、`xiyou_tianqi_ring_style` 共 17 个场景全过。
- 开关 `FONT_V00300` 未登记 O 号（总装未分配）；如需登记合并时补。

## 本分支提交

- 见 git log
