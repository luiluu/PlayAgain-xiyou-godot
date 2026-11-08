# 交付：cc/ui6

- 车道／工作者：B 界面／FD3（cc）
- 状态：可合并

## 方案

**来由**：平台车道盘点 Mehmet_GhostButtons 时记下「没做：摇杆拽拉换页（有 LB／RB 与 Q／E 翻页，手机上缺换页手势，若 Kyo 要再说）」。Kyo 11-07：「先做吧，然后设置里做开关」。

**原版**（`js/plugins/Mehmet_GhostButtons.js` `Sprite_JoyStick.processTouch`）：摇杆朝左／右按着时，按住满 36 帧（`_pressedTime >= 36`）、推的深度 `_pressure >= 0.65`、`_pageTime >= 24`、而且手指这一帧在动（`TouchInput.isMoved()`）时，对窗口层里活动的列表窗调用 pageup／pagedown 处理（没有就 cursorPageup／cursorPagedown），播光标音，`_pageTime` 归零。两个计数都从按下那帧起算，所以第一页在第 36 帧，之后每 24 帧一页。翻页时左右键照样按着。

**重制**（`core/touch_controls.gd` `_stick_page_tick`，在 `_physics_process` 每帧跑）：

- 同样的三个数：深度 ≥ 摇杆半径 × 65%（`PAGE_PRESSURE`）、按满 36 帧（`PAGE_HOLD`）、之后每 24 帧（`PAGE_INTERVAL`）。左＝`ui_page_up`，右＝`ui_page_down`，发一次按下加松开。各页现在已经认 Q／E、LB／RB 的翻页（`XMenu.page_dir` 等），所以页面不用改。地图上没有页面认这两个动作，推着走路不会翻东西（原版地图上也没有活动列表）。
- 跟原版不同的两处（新功能本身，不另占 O 号，写在同一个 O-待定里）：
  1. 原版还要求手指「这一帧在动」，按稳不动不翻，得来回晃才翻。重制按稳就翻。
  2. 原版翻页时左右键还按着，网格列表的光标会一边翻页一边横着走。重制一开始翻页就停掉这一次按住的左右连发（键仍算按着，松手照常松开）。翻页前那 36 帧里的左右连发跟原版一样。
- 换方向、松手、切开关时三个计数都清零。

**设置开关**：设置 →「手机按键设置」新增一行 **「摇杆拖动翻页」**（开／关，默认开），排在「按键透明度」后面、「调整UI位置」前面。左右键或点选切换，存在 `user://touch_controls.json` 的 `stick_page`，「恢复默认」回到开。页面列表窗加高一行（`LIST_RECT` 高 280→316）。

**顺手修的旧 bug（做这单时测出来的）**：O-225 起摇杆按住的连发改成发方向键的「回显」事件。Godot 会把带 echo 的按键也记成该动作在键盘设备上「按着」，松手只松开 InputEventAction 清不掉，所以**摇杆按住满 24 帧（约 0.4 秒）再松手，方向仍算按着**。地图上 `mv_player` 是轮询 `Input.is_action_pressed("ui_*")` 的，手机上推摇杆走一段松手，人物会一直往那边走，直到再推一次别的方向。用无头 Godot 4.7.2 小脚本确认过：按动作→发回显→松动作，仍是按着；再发一次方向键松开就好。现在 `_set_dir` 松开方向时顺带发该方向键的松开。这是重制自己的 bug（原版 GhostButtons 直接写 `Input._currentState`），不占 O 号、不加开关；专项加 `stick_echo_then_release`。没在安卓真机上复现（我这边没有真机），但轮询的写法决定了会卡。

**回退**：代码开关 `XTouchControls.STICK_PAGE = false` 关掉整个功能，设置页也不列这一行（`XTouchOptionsScene.rows()`）。

## 变更记录草稿

## 2026-11-08 【cc·FD3·未经审查】触屏摇杆拖动翻页，设置里可关 ui6（dev.待定）

- 触屏摇杆往左或往右推深（≥ 半径 65%）按住，满 36 帧翻第一页，之后每 24 帧一页（左＝上一页、右＝下一页），照原版 Mehmet_GhostButtons `Sprite_JoyStick.processTouch`。发 `ui_page_up／ui_page_down`，各页现有的翻页接住。两处跟原版不同：原版要求手指在动才翻，这里按稳也翻；原版翻页时左右键还在连发，网格列表会横走光标，这里一开始翻页就停掉这次的左右连发。（`core/touch_controls.gd` `_stick_page_tick`）
- 设置「手机按键设置」加「摇杆拖动翻页」开／关（默认开，存 `user://touch_controls.json` 的 `stick_page`，恢复默认回到开）；列表窗加高一行。（`modes/xiyou/ui/touch_options.gd`）
- 回退 `XTouchControls.STICK_PAGE = false`：不翻页、设置里不列（O-待定·摇杆翻页）。
- 修：触屏摇杆按住满 24 帧（发过方向回显）再松手，方向仍算按着（Godot 把回显键记成键盘设备按着，松开动作清不掉），手机上推摇杆走路松手后人物会一直走。现在松开方向时顺带松开该方向键。（`core/touch_controls.gd` `_set_dir`）
- 玩家可见：手机上推摇杆走路，松手人物就停（原来按住超过约 0.4 秒再松手会一直走）。
- 专项 `xiyou_platform` 加 10 条：30 帧内不翻、70 帧翻两页、推过回显再松手方向真松开、翻页后停左右连发但键仍按着、松手松开、推浅不翻、设置关掉不翻、设置页切换与写文件、重读记住、左右键切换、回退开关不列行、恢复默认回到开；「恢复默认」行号 6→7。
- 玩家可见：手机上把摇杆往左／右推到底按住约 0.6 秒，列表就开始一页页翻（约 0.4 秒一页）；不想要可在「手机按键设置」里关。

## 优化登记草稿

| 编号 | 位置 | 原版 | 现在 | 理由 | 回退 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | 触屏摇杆拖动翻页（`core/touch_controls.gd` `_stick_page_tick`、`ui/touch_options.gd`） | GhostButtons：推深按 36 帧后每 24 帧翻页，但要手指在动；翻页时左右连发不停 | 照原版节奏；按稳也翻；翻页后停左右连发；设置里可关（默认开） | 重制原来没有这个手势（Kyo 11-07 要做、要设置开关） | `XTouchControls.STICK_PAGE = false` | cc（FD3） | 待用户决定 |

## 交接板

- 下一步：无（界面这条线 FD3 这里停）。
- 用户试玩说明：安卓上打开物品、技能等长列表，把摇杆往右推到底按住，约 0.6 秒后开始每 0.4 秒翻一页，往左是往回翻；「设置 → 手机按键设置 → 摇杆拖动翻页」可关。
- 需要用户决定：O-待定（摇杆翻页，默认开）。

## 进度账

- 界面页面：+0（补原版手势）。

## 可优化（流程／工具／效率）

- 无

## 验证

- 云端选测通过：提交 b7eac2b018，5 个场景（`xiyou_platform`、`xiyou_ui_input`、`xiyou_map_hotkeys`、`xiyou_version_label`、`xiyou_event_compare`，＝`选测.py main --list`），运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42427352436 。上一轮 3e1afc8e 挂了 `stick_page_release`、`layout_drag_clamped` 两条，就是上面那个松手方向卡住的旧 bug，修后通过。
- `语法检查.py`、`工具回归.py` 通过。没跑本机测试；没碰切片、转换器、探针。
- 安卓真机没试（手感、0.65 深度合不合适要 Kyo 实机看）。

## 本分支提交

- 3e1afc8e 摇杆拖动翻页、设置开关、专项断言
- b7eac2b0 松手同时松开回显方向键、断言
- （本提交）交付单
