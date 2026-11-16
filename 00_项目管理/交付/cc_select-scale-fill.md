# 交付：cc/select-scale-fill

- 车道／工作者：T040 选中放大补齐（cc，claude-sonnet-5-5＋medium，P6）；核查：小A（甲档，Hydrogen）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】选中放大补齐：队伍状态页分类页签、七印祭坛按钮、选线竖卡、工坊顶页签（dev.待定）

- 依据：T024 核查报告（小A）P2×4＋P3×3；Kyo 11-16「所有可选中项选中时都要稍放大」。全部走 T024 已有的公共实现，没有新开关：总开关仍是 `XSkinSelScale.ENABLED`，皮肤关着一律不放大。
- 实际改动清单：
  - `skin/skin_party_status.gd`：队伍状态详情页顶上四个分类页签挂 `XSkinSelScale`，选中页签 ×1.15（字号按页签高封顶、宽不够先缩字）。
  - `skin/tianqi_skin_altar.gd`：七印祭坛底部入口按钮挂 `XSkinSelScale`（按钮档 ×1.05，同 `XSkinButton.BUTTON_PEAK`），选中钮底面、选中框、字一起放大；看规则时不放大。
  - `tianqi_line_cards.gd`：选线竖卡选中那张以中心 ×1.03（`CARD_PEAK`，随原有抬起 0.12 秒一起过渡，只在新皮肤开着时）；「再想想」不拿焦点，改成鼠标／手指悬停时按钮档放大（新增 `XSkinButton.wire_hover_scale`）。
  - `alien_workshop.gd`：工坊顶上当前页签 ×1.05（不拿焦点，且容器每次排版会把子控件 scale 重置成 1，所以挂在 `sort_children` 上每次排完再给）；左列装备列表的 ScrollContainer 里加一圈 `SCALE_ROOM`＝8px 的 MarginContainer，焦点放大外扩不再被 `clip_contents` 裁掉。
  - `mv_canvas.gd`（新增 `tex_rect`／`tex`）、`warehouse.gd`、`item_row.gd`：「新」角标原来直接 `draw_texture`，选中行里文字和图标放大而角标不放大；改走 `c.tex()`，在选中行里一起放大。（核查报告写的是「仓库格子图标」，实查仓库格子的物品图标本来就走 `c.icon()`，只有这枚「新」角标绕开，所以改的是角标。）
  - `skin/skin_ring_nav.gd`：`item_scale` 和 `_ease_scales` 挂 `XSkinSelScale.ENABLED`，总开关关了环导航也回到不放大（关着时不再每帧白重画）。
- 专项：`xiyou_ui_sel_scale` 加 `_fill()` 一节（状态页签、祭坛按钮、选线卡、工坊页签和滚动余量、角标、环导航开关各自开／关断言）和 4 页截图。

## 验证

- `xiyou_ui_sel_scale`：116/116（无头 90/90，带窗口含截图 116/116）；`语法检查.py` 0 问题。
- 皮肤关闭对照：新增断言全部有「ENABLED=false → 倍数恒 1」；选线卡、祭坛、状态页签放大只在新皮肤分支里，旧界面代码路径未动。
- `检查.sh --affected main`、`交付自检.py`：见回报。

## 截图

`00_项目管理/归档/交付截图/cc_select-scale-fill/`：`party`（队伍状态页，「增益」页签选中）、`altar`（七印祭坛，「揭印」钮选中）、`cards`（选线卡，第 2 张选中）、`wstab`（工坊，「异化装备」页签选中），每页 `_sel`（放大开）和 `_off`（总开关关）各一张。

## 已知问题

- 工坊左列：焦点移到右侧操作栏时，左列选中的装备按钮缩回 1.0（放大跟焦点走，不跟「当前选中装备」）。T024 的口径就是焦点，没改；要常亮再单独定。
- 左列／操作栏的 VBox／HBox 里的按钮焦点放大（T024 `wire_focus_scale`）同样会被容器重排重置成 1，只是重排发生在焦点之前，通常看不出来；如果实机有「放大一下又掉了」的反馈，这是根因，修法同页签（挂 `sort_children`）。

## 我不同意的地方

- 核查报告 P3-1 说的「仓库格子图标」实为「新」角标，已在上面说明，处理的是角标。
- 「再想想」按钮 `FOCUS_NONE` 不是键盘选中项（取消键直接返回），所以只做了悬停放大，没有强行改成拿焦点。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 `git log main..cc/select-scale-fill`
