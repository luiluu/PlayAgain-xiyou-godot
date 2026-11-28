# 交付：luiluu/t587

- 车道／工作者：T587 安卓西游档点地移动走不到、往右不行／cc（Opus 5.5＋medium，职级 P8；`ctx_88177f809736`）
- 状态：可合并

## 变更记录草稿

## 2026-11-28 【cc·T587·未经审查】安卓点地目的地整体偏左上：点右边几格走不过去、斜着走（dev.待定）

- 玩家反馈（Kyo 11-28 00:47 转 QQ 群，安卓 0.04.08）：「点地走不到指定的地方」「往左边走有时没事，往右走不行」「为啥更新后屏幕点击是斜着走的」，群主说过一会儿「又好了」。
- 根因：启动时 `core/game_app.gd` 对所有平台调 `WindowFit.apply`，按屏幕 90% 居中给根窗口设 `position`。安卓引擎挪不动窗口，但 `Window.position` 照样记下（Godot 4.7.2 `window.cpp` `set_position` 没有安卓守卫；`set_size` 有，所以画面正常）。引擎算 `get_global_mouse_position` 时走 FEATURE_MOUSE 分支、把这个 position 再减一次（`viewport.cpp` `get_mouse_position`＋`window.cpp` `get_screen_transform_internal`），而安卓的鼠标坐标本来就是窗口内坐标。点地目的地（`mv_player.gd` 读 `get_global_mouse_position`）于是整体往左上偏：20:9（2400×1080）约左 4.7 格、上 0.75 格，16:9 约左 1.3 格、上 0.75 格。
  - 对上症状：点右边 4 格内，目的地落到人物左边或脚下（往右走不行）；纵向偏一格加逐格逼近（斜着走、走不到）；点左边仍往左（往左有时没事）；切后台回来、转屏等画面表面重建时，引擎回调把 position 归 0（`display_server_android.cpp` `notify_surface_changed`），所以「又好了」，冷启动又坏。
  - 哪次引入：坐标偏移 10-12 起就潜伏着，以前同一下点按还会走 ScreenTouch 分支，用触屏事件自身坐标把目的地覆盖回正确格，掩盖了它。T507（11-25，补丁线 `75a7fde6f` 摘入，0.04.05 起）为防同一下触发两次，在安卓（触屏仿鼠标开着）跳过了 ScreenTouch 分支，只剩偏的那条路。0.04.06～0.04.08 没再碰移动代码。长按跟手（按住 15 帧后）一直是偏的。
- 修法（两处，各带回退开关，同一个优化号 O-待定·T587触屏坐标）：
  - `core/window_fit.gd` `WindowFit.MOBILE_SKIP`（默认开）：移动端（安卓／iOS）`apply` 直接返回，不再设窗口大小和位置（画质设置 `XGraphics` 早就有同样的 `is_mobile` 守卫，启动这一处漏了）。新增 `mobile_skip()`／`skips()`。
  - `modes/xiyou/map/mv_player.gd` `MVPlayer.MOBILE_TAP_POS`（默认开）：移动端点地落点用事件自身坐标（`_click_pos`），长按跟手用 `_input` 记下的最近一次鼠标事件坐标（`_pointer_pos`），都不读窗口 position；桌面仍是 `get_global_mouse_position()`，一行不变。
- 两档都修：这是启动代码（选模式之前）里的平台问题，没法按 `XTianqi.active` 隔离；协调 11-28 定「平台 bug 不是玩法改动，两档都修」。只看平台，桌面（Mac／Windows）零影响。
- 新专项 `tests/xiyou_t587_touch_offset`（34 项）：根窗口放大成 2400×1080 与 1920×1080，窗口 position 设成旧版会记下的居中偏移；按引擎算法手算旧路，断言确实偏到左边的格（复现）；发真 InputEventScreenTouch 点右 1～4 格，目的地正确且真走到；长按右 1 格拖到右 4 格，每帧目的地都等于当下指下那格（镜头卷动时原版也每帧重算）；窗口 position 归 0（切后台回来）前后点同一格结果一样；桌面与两个开关关时落点等于 `get_global_mouse_position()`；`mobile_skip` 两态。
- 本机无安卓真机或模拟器，headless 和 Mac 窗口也走不到引擎那条换算分支，所以是等效模拟：需 Kyo 或玩家真机验一下（冷启动后直接点人物右边 2～3 格，应走到点的那格）。
- 玩家可见：安卓上点地移动走到点的那一格，不再往左上偏、点右边不再走不动或斜着走。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定·T587触屏坐标 | `core/window_fit.gd` `WindowFit.MOBILE_SKIP`（`apply`、`mobile_skip`、`skips`）；`modes/xiyou/map/mv_player.gd` `MVPlayer.MOBILE_TAP_POS`（`_click_pos`、`_pointer_pos`、`_input`） | 原版 MV 点地按触点算目的地；重制启动时对所有平台给根窗口设居中位置，安卓引擎把它从鼠标坐标里多减一次，点地目的地往左上偏（20:9 约左 4.7 格），T507 后不再被触屏分支掩盖 | 移动端不设窗口位置；移动端点地、长按跟手用事件自身坐标，不读窗口 position；桌面不变 | T587 安卓玩家点右边走不过去、斜着走；协调 11-28 定两档都修 | `WindowFit.MOBILE_SKIP = false`；`MVPlayer.MOBILE_TAP_POS = false` | cc（T587） | 保留 |

## 交接板

- 下一步：换家核查；进下个西游补丁（补丁线摘本分支两个代码提交，只碰 `core/window_fit.gd`、`modes/xiyou/map/mv_player.gd` 和新专项）；Kyo 或玩家安卓真机验一下（冷启动后点人物右边 2～3 格）；点地寻路是逐格贪心逼近、不是原版 A*（`mv_player.gd` `_toward`），10 月起的旧偏差，另开卡，本单没动。
- 用户试玩说明：安卓上点地移动走到点的那一格，不再偏左上、不再斜着走。
- 需要用户决定：无

## 截图

- 无（本单是坐标换算，没有画面变化；证据是专项断言，真机效果需 Kyo 或玩家验）。

## 可优化（流程／工具／效率）

- 建议：点地寻路改照原版 `findDirectionTo`（A*，搜 12 步）另开卡；现在的逐格贪心碰到障碍会停，原版能绕。

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `WindowFit.apply` | 3 处工程＋1 处测试（`git grep -n "WindowFit.apply(" -- '*.gd'`：`core/game_app.gd` 启动、`core/game_app.gd` 全屏切回窗口、`modes/xiyou/core/graphics_quality.gd` 画质窗口选项、`tests/xiyou_panels.gd`） | 只多一个移动端早退。启动那处正是本单要修的；全屏切回只在桌面按 F11／组合键；画质那处调用前已判 `not XPlatform.is_mobile()`；测试在桌面窗口跑，不受影响 |
| `MVPlayer._unhandled_input` 点地落点 | 1 处（同文件，`git grep -n "_click_pos\|_pointer_pos" -- '*.gd'`） | 桌面分支仍调 `get_global_mouse_position()`，逐项相等由专项 `desktop_*` 断言；`xiyou_touch_dest_d1d2`、`xiyou_airship_view`、`xiyou_item_transfer_no_talk` 等点地专项在云端选测里照跑 |

## 测试

- 本机：`xiyou_t587_touch_offset` 34/34。
- `发行空壳.py check`：通过（88 个脚本，879 个函数都有）。
- 云端选测：通过，516 个场景、16 片（提交 4467ed47b，基准 6c3f1ade7）；偶发 1 个 `xiyou_map_hotkeys`（并行时失败、单跑通过，算通过；本单没动快捷键）。https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/46085724266
- db1d5e601 只改两行注释（补优化号占位）和交付单，没重跑云端。

## 本分支提交

- 4467ed47b T587 安卓点地目的地偏左上：移动端不设窗口位置＋点地用事件自身坐标＋专项
- db1d5e601 开关注释补优化号占位＋交付单
- （本提交）交付单写云端结果、标可合并
