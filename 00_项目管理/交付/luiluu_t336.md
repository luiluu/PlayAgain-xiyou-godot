# 交付：luiluu/t336

- 车道／工作者：T336 界面细节 D1a：ui_skin 底层＋Q1 双环对照样稿（cc，Opus＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【cc·天启篇·未经审查】界面细节 D1a：新界面底层加定宽数字、双环聚焦、输入模式、表面色阶、文字基线出口（dev.待定）

- 依据：私密仓 重制设定/界面细节规范_v0.1.md（T329 定稿）第五节卡 D1a、第三节规范 1～4；T329 核查 r2 的 P3-6、P3-7。
- 只改 `modes/xiyou/ui/skin/ui_skin.gd`（文末新增「界面细节 D1a」一节）。本卡不接任何现有页面：开关开或关，现有页面一个像素都不变（专项逐像素核了确认弹窗和详情牌）。唯一生效的改动在三字体模式（`FONT_V00300=false`，现在默认不走）：`font("num")` 包 `FontVariation` 开 tnum／lnum。
- 新增：
  - 开关 `DETAIL_V1`（默认 true）、`detail_on()`；D1b～D4 接线时一律先问它，关着走改造前画法。
  - 规范 1：`_make_tabular()`、`draw_num_right()`（右缘取整）、`draw_mono_digits()`（宋体 Heavy 逐位定宽，1、7 在格里居中）以及量宽用的 `mono_digit_cell()`、`mono_digit_slots()`、`mono_digits_width()`。格宽取 0–9 十个字宽里最大的（P3-6），按字体＋字号缓存。
  - 规范 2：`InputMode`、`note_input()`、`current_input_mode()`、`show_focus_ring()`（键盘、手柄显示，鼠标、触屏不显示；`DEVICE_ID_EMULATION` 算触屏；摇杆死区 0.35；鼠标移动超过 4px 才算）。第一次调用 `show_focus_ring()` 时，在根节点下延后挂一个只看不吞事件的监听节点 `XUiSkinInputTracker`。`draw_focus_ring()`：内黑 `#090808` 2px，贴外缘 0～2px；外淡金 `#f2d08a` 2px，2～4px；金底控件换骨白；「全部」档外环呼吸，带 4px 软晕。`draw_focus_circle()`。紧凑控件（高 < 32）的内环也写死 2px、总外扩 4px，只把透明度降到 0.90、软晕降到 3px（P3-7）。另加常量 `FOCUS_BTN_GAP=12`、`FOCUS_BTN_GAP_COMPACT=10`。
  - 规范 3：`Surface` 枚举（凹槽、S0～S4）、暖／冷两套色值，以及 `surface_c()`、`surface_grad()`（S1、S3 渐变，S3 不透明度 94%）、`surface_overlay()`、`zebra_c()`（0.08）、`sunken_c()`、`pressed_c()`。
  - 规范 4：`TEXT_CY_K=0.36`、`text_baseline_y()`、`ICON_DY_K=0.0`（等 D2 实量）、`inline_icon_rect()`、`inline_icon_gap()`。现有 62 处 `0.36` 不替换。
- **Q1 样稿**（给 Kyo 拍板）：`00_项目管理/归档/交付截图/T336_Q1双环样稿/`
  - `q1_double_ring_compare.png`：1280×720 原尺寸，手柄态。左边是现状（详情牌「装备」主钮红叠红＋左外箭头；确认弹窗焦点在「取消」，箭头压进左钮的 8px 缝），右边是改后（S3 弹窗底、内黑外淡金双环、钮距 12px）。
  - `q1_double_ring_compare_touch.png`：同一画面换成触屏态，改后不留环。
  - 样稿在专项 `tests/xiyou_ui_skin_d1a.gd` 里用 `PreviewConfirm`／`PreviewCard` 子类直接画，没改正式页面。D1b 照这个改正式件。
- 玩家可见：无（本卡不接页面）。

## 交接板

- 下一步：Kyo 看 Q1 样稿，点头后开 D1b；D1c、D2、D3 不等 Q1，可以开。
- 需要用户决定：Q1 框形控件聚焦改淡金双环（样稿见上）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 偏离与说明

- 样稿「改后」把焦点钮的红色外晕（`primary_button_style` 的 shadow 7）去掉了：焦点改由双环表示，红晕留在环外一圈会发糊。D1b 是否照此去晕，跟 Q1 一起定。
- 双环圆角按同心外扩：内环取控件圆角＋2，外环取控件圆角＋4。规范 2.4 示例代码写的是 `+1`／`+3`，同心外扩下那样会露缝。圆形环同样贴外缘画：内环 `r+1`、外环 `r+3`（规范写 `+1.5`／`+3.5`）。
- 输入监听没有走 autoload（autoload 要改 `project.godot`，不在独占文件里），改为在第一次查询时懒挂到根节点下。

## 验证

- 新专项 `xiyou_ui_skin_d1a`：无头 53/53；开窗口（`--audio-driver Dummy -- --out=`）62/62，多出的是逐像素回退、样稿环色取样（内黑、外淡金）、12px 钮距、触屏态不留环这几条。规范列的 4 条单测：①tnum 0＝1（另断言不开 tnum 时两者不等）；②111／777／888 等宽且逐位居中（34／40／50 号）；③键盘、手柄、真鼠标、模拟触屏、屏幕触摸各态；④`DETAIL_V1` 开关前后，确认弹窗＋详情牌逐像素相同。
- `语法检查.py`：1131 个 .gd，0 个问题。
- 改了现有专项 `xiyou_ui_skin` 一条断言（`fonts_load`）：三字体模式下 `font("num")` 现在是包了 tnum 的 FontVariation，断言改为认它底下的 FontFile。
- 界面专项本机并行测试 34 个场景（`xiyou_ui_skin*` 24 个＋ui_art_phase01、ui_sel_scale、list_pager、help_card_sections、party_fold、tianqi_ring_style、tianqi_six_dim_radar、big_form_menu、battle_layout），除上面那条外全过；改断言后 `xiyou_ui_skin` 111/111、`xiyou_ui_skin_d1a` 53/53。选测列出的 event_compare 四份和 t*_shots 截图工具没跑：本卡没有页面调用新函数，事件对照碰不到；云端选测交总装。
- 工具回归.py 全过。

## 本分支提交

- （见回执）
