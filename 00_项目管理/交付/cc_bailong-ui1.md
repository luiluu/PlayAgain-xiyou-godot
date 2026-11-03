# 交付：cc/bailong-ui1

- 车道／工作者：白龙（cc），派单 ui1：批量丹药数量窗样式（dev.251 留给界面的尾项）
- 基线：cc/bailong-tails1 末端（cc4cc171）；tails1 未合时本分支含它
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·白龙·未经审查】批量丹药数量窗：垫底色、触摸键、鼠标只认触摸键（dev.待定）

对照冻结 v0.28 `js/codex/runtime/installBulkPillsRuntime.js` 的 `Window_BulkPillNumber`（继承 Window_ShopNumber，`rpg_windows.js:3059～`）逐项读代码，重制 `item_scene.gd` 已一致的不动：宽 456、高 fittingHeight(8)＝324、居中（412,198）、「服用数量」系统色居中、物品名、× 与数字位置、光标框、「持有：N 颗」右对齐、按键说明、±1／±10 夹在 1～库存。

差在三处，已改：
- **底色**：原版 `_refreshBack` 在皮肤透明处垫 `#111827`，不透明度 255。`XMVWindow` 加 `backdrop`（默认透明，别的窗不受影响），数量窗设 `#111827`。
- **触摸键**：Window_ShopNumber 有五个键（-10、-1、+1、+10、确定 96 宽，ButtonSet.png 冷帧），间距 16 整排居中，y＝buttonY＝192（窗体坐标）；`TouchInput.date > Input.date`（最近一次输入是鼠标）时才显示。重制原来一个都没画。现在 `_touched` 跟最近一次输入（键盘按下清、鼠标按下置），数量窗上叠 `bulk_buttons` 画五键。
- **鼠标**：原版 `isOkTriggered` 只认键盘，窗内其它位置左键不确定、滚轮（Window_Selectable.processWheel 只滚动）不改数量，右键取消。重制原来「窗内左键＝确定、滚轮 ±1」是错的，改成：左键只响应触摸键（-10／-1／+1／+10／确定），滚轮无效，右键取消。

没改丹药结算逻辑（`XBulkPills` 未动）。

- 局限：只按原版代码读数复现，没有在浏览器里用 `ui_reference` 截原版画面逐像素比；触摸键的位置、尺寸和皮肤帧来自 `Window_ShopNumber.createButtons／placeButtons` 的代码。

优化登记草稿：无

## 待交叉核查

- `item_scene.gd` 数量窗鼠标行为改动（左键不再确定、去掉滚轮）：这是对原版的纠正，但属玩家操作变化，请核。
- `mv_window.gd` 加 `backdrop` 属性（默认不影响其它窗）。

## 交接板

- 下一步：无。
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 无

## 验证

- 语法检查 489 个 .gd 0 个问题。
- 并行测试（--jobs 2，不跑全量）：xiyou_bulk_pills 113（新增窗体读数、触摸键布局与可见性、窗内左键与滚轮无效、四个按键改数量共 10 项）、xiyou_item_bag 160、xiyou_item_list 38、xiyou_window_rects 9、xiyou_panels 35、xiyou_event_compare 5、xiyou_popup_overlap 8、xiyou_book_capacity_ui 85、xiyou_guyu_ui 791，全过。
- 日志：`03_再刷重制_Godot/04_验证/本地结果/并行测试/20261103_050406_a_cjjajj/`
- 没跑：选测名单其余场景与全量，留总装。

## 本分支提交

- 见 `git log cc/bailong-tails1..cc/bailong-ui1`
