# 交付：luiluu/t339

- 车道／工作者：T339 界面细节 D3 手感升级（cc，Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【cc·未经审查】界面细节 D3：拖拽零延迟、列表像素跟手、0ms 按下反馈（惯性默认关）（dev.待定）

- 接 T336 的 `DETAIL_V1`（关＝回旧死区 10／整行跳／无按下微缩）：
  - `skin_drag.gd`：死区触屏 `SLOP_TOUCH=8`／鼠标 `SLOP_MOUSE=5` 并扣除（起拖首帧位移 1px，不再突跳）；`is_touch_event()` 统一按 `DEVICE_ID_EMULATION` 或触屏机判；最后 80ms 速度采样；可选惯性与 24px 橡皮筋回弹挂 `INERTIA_ENABLED := false`（默认关，松手即停，Kyo 试手感后再定）。
  - `skin_list.gd`：删掉自带的 `DRAG_SLOP` 手写拖动改接 `XSkinDrag`；`scroll_px` 像素级 1:1 跟手（上下截断到 `[0, max_scroll_px]`）；按下 0ms 给那一行预按轻底（alpha 0.35），拖过死区立即撤销；拖拽时滚动条拇指 0.92、松手 0.6s 后回 0.68；方向键／滚轮／翻页仍整行跳并清掉零头；剪裁只裁上下不裁左右（左右各放宽 26px），D51 左外小箭头完整。
  - `skin_button.gd`：`wire_press_feedback`（`XSkinButton.apply` 自动接）按下 0.05s 缩到 0.97、松手 0.10s 回焦点倍率；自绘件用 `press_rect`／`press_color`（缩 0.97＋压暗 22%；「关」档不缩只下沉 1px）。
  - `skin_confirm.gd`／`skin_card.gd`／`skin_stepper.gd`：自绘按钮按下 0ms 微缩压暗；`skin_card.gd` 新增按下态（原来按下即触发没有按下画面）。
  - `skin_battle_list.gd`：按着的行预按轻底、「详情」胶囊微缩压暗，拖起来撤销；`skin_battle_2c.gd`：结算详单拖动统一走 `XSkinDrag`；`skin_status_page.gd`／`skin_gear_detail.gd`／`skin_card.gd`／`skin_battle_list.gd` 的 `motion()` 传触屏判据。
- T336 核查转来：P2-1 `_InputTracker` 在根下新增／调序时（`child_order_changed`）挪回末位，并在 `XUiSkin.on()` 里提早挂上（不再等首次问聚焦环）；P3-2 触屏虚拟键（`core/touch_controls.gd`）与底部提示胶囊（`skin_key_hints.gd`）合成的键盘事件带 `skin_synth_input` meta，`note_input` 跳过。
- 新增 `tests/xiyou_ui_detail_d3`：93 项（带窗口 100 项，含两组验收图的像素断言）。更新旧测试 `xiyou_ui_skin_close` 两条（`list_drag_scrolls`、`r_drag_slop`）到新手感（原断言正是被规范改掉的整行跳与不扣死区）。
- 玩家可见：列表手指拖动跟手不再整行硬跳、起拖不再突跳；按钮、确认／详情牌钮、数量条按下立即微缩压暗；点列表行立刻有预按底色。

## 交接板

- 下一步：无
- 用户试玩说明：手机／平板上拖物品两列列表、点按钮与确认弹窗钮的手感；惯性与回弹默认关，想试手感把 `XSkinDrag.INERTIA_ENABLED` 改 true
- 需要用户决定：惯性与橡皮筋回弹（Q2）要不要开——请 Kyo 实机试手感后定

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 我不同意的地方 / 偏离

- 规范「松手 0.6s 后恢复 0.68」我落成：滚动条常态 0.68 是 `draw_scrollbar` 里写死的，高亮时在拇指上再叠一层使合成 0.92（`scroll_alpha()` 可查）；没改 `ui_skin.gd` 的画法。
- 「惯性不越界」：规范同时写了「超界最多拉出 24px 橡皮筋」，我按后者实现（滑行中最多越出 24px、0.16s 缓出落回 `[lo,hi]`），单测断言「越出≤24 且最终落在边界内」。
- 方向键整行跳：拖出来的行内零头在第一次按方向键时对齐到最近整行（整屏会微移）；点选一行不对齐（该行已完整可见就不动画面，免得点一下内容跳）。
- `skin_battle_2c.gd` 只把详单拖动收口到 `XSkinDrag`（详单按行滚，不做像素跟手）；结算页底部提示胶囊（`XSkinKeyHints`，不在独占文件内）没做按下微缩。
- `core/touch_controls.gd`、`skin_key_hints.gd` 各加一行 meta（P3-2 要求，超出规范 D3 文件清单）。
- 手柄摇杆经 `key_repeat.gd` 的 `push_input` 合成的键盘事件未加 meta（走 `get_viewport().push_input`，仍会判成键盘，手柄摇杆本来也该算「有手柄在用」，没动）。
- 数量条只给六个按钮类控件里的自绘钮接了按下态；数字框点按（弹数字键盘）没接。

## 验收对照

1. 按 D3 改 `skin_drag`／`skin_list`／六个按钮类控件：✓（`skin_battle_2c` 只收口拖动、`XSkinKeyHints` 没接，见上）
2. 触屏／鼠标拖拽与按下单测：✓（触屏 7px 不起拖、9px 首帧 1px；鼠标 4px／6px；惯性关松手即停、开则不越 24px 回边界；按下 0ms 预按、滑动取消不触发 `activated`）
3. 两组关键帧：`00_项目管理/归档/交付截图/T339_D3/list_drag_halfrow.png`（半行位置、左外箭头完整、滚动条高亮、上下剪裁）、`button_press_triple.png`（常态｜悬停｜按下 0.97）：✓（原尺寸、无声）。悬停那格用的是现有 HOVER 样式，S4 抬升属 D1b，未画。
4. T336 核查 P2-1／P3-2：✓（单测：切场景挂新节点后监听仍在末位；合成键盘事件不记键盘；触屏虚拟键事件带 meta）

## 文字

- 无新增玩家可见字（截图里的标注字只在测试里）。

## 本分支提交

- 见 git log
