# 交付：cc/hangup-touch-enable

- 车道／工作者：修安卓点挂机按钮不开始挂机（cc 项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·项目线程·未经审查】安卓点挂机按钮开了又关：触屏一下只算一次按下（挂机按钮、回城枫叶）；禁用时触屏也显示按钮（dev.待定）

- 起因：Kyo 更正 v0.01.07 安卓的问题：挂机按钮看得到也能点，但点了不会开始自动挂机。
- 原因：Godot 把触屏点一下送成两份按下，一份是第一指转出的鼠标左键（emulate_mouse_from_touch），一份是触屏事件本身，两份都会让 Button 触发。挂机按钮是按下就触发（ACTION_MODE_BUTTON_PRESS），于是同一下先开始挂机、紧接着又停掉。桌面用鼠标只有一份，所以碰不到。触屏模拟复现：点一下按钮 pressed 触发 2 次，第一次开、第二次关。
- 改动（`core/key_map.gd` `XKeyMap.ONE_PRESS_PER_TAP`、`XKeyMap.first_press`，O-待定-1）：按下即触发的按钮在 pressed 里先问 `first_press`，相隔不超过 2 帧的第二次按下不算。用在全部两个按下即触发的按钮上：挂机按钮（`hang_up_overlay.gd`，同一下只开或只关一次）和地图左下角回城枫叶（`map_hud.gd` 返回按钮，原来触屏点一下连播两声 Coin、预约两次回大厅公共事件 10）。其余按钮是松开才触发，鼠标松开先触发后按钮已不在按下状态，触屏松开不再触发，不受影响。设 false 恢复。

- 起因：Kyo 反馈 v0.01.07 安卓挂机还是开不了。新游戏原版开局就禁用挂机（Map001 EV1 ProhibitHangUp）；桌面上次已改成禁用时按 G 照 L 开启（KEY_ENABLES），但安卓没有 G／L 键，挂机快捷界面在禁用时也整块藏着（`XHangUp.inter_show` 要求已开启），只能回大厅找大工匠开。
- 另改（`modes/xiyou/core/hang_up.gd` `XHangUp.TOUCH_SHOW_PROHIBITED`，O-待定-2）：触屏设备（`XPlatform.is_touch`）上禁用时也显示快捷界面；点按钮走原来的 `XMapScene.toggle_hang_up`，禁用时照 L 的公共事件 484 开启并提示「摆烂功能已开启~！」（副本里提示去重置），再点一次开始挂机。桌面照原版藏着。KEY_ENABLES 关掉时这一项也不生效。设 false 恢复原版。
- 测试：`xiyou_hangup` 加九项：真触屏点按钮（ScreenTouch 加鼠标模拟）开始挂机、再点停止、回退开关下点一下开了又关；回城枫叶触屏点一下只发一次、回退开关下两次；触屏禁用时显示按钮、点了开启但不开始、回退开关下藏起、桌面禁用时仍藏。把 ONE_PRESS_PER_TAP 默认改成 false 时 `touch_tap_starts` 失败，把 TOUCH_SHOW_PROHIBITED 改成 false 时 `touch_prohibited_button_shown` 失败，改回都通过。选测 xiyou_hangup*、xiyou_hud、ui_smoke、xiyou_map_hotkeys、xiyou_platform、xiyou_input_handled 全过（xiyou_hangup 53/53），语法检查通过。
- 玩家可见：安卓点左上角挂机按钮能正常开始和停止挂机；点回城枫叶只回一次大厅、只响一声。挂机功能没开启时按钮也显示，点一下开启功能，再点一下开始挂机。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定-1 | `core/key_map.gd` `XKeyMap.ONE_PRESS_PER_TAP`、`first_press`；用在 `hang_up_overlay.gd` 挂机按钮、`map_hud.gd` 回城枫叶 | 不适用（原版触屏只给一份按下；重制里 Godot 把触屏点一下送成鼠标键＋触屏两份，按下即触发的挂机按钮开了又关、回城枫叶预约两次） | 同一下（相隔不超过 2 帧）只认第一次按下 | Kyo 11-13 反馈 v0.01.07 安卓点挂机按钮不开始；Kyo 11-11 优化直接接受 | `XKeyMap.ONE_PRESS_PER_TAP = false` | cc | 保留 |
| O-待定-2 | `modes/xiyou/core/hang_up.gd` `XHangUp.TOUCH_SHOW_PROHIBITED`、`inter_show` | 挂机被禁用（新游戏开局就禁用）时快捷界面连按钮一起藏起来，要按 L 或找大厅大工匠开启；触屏没有 L 键 | 触屏设备禁用时也显示快捷界面，点按钮照 L 的公共事件 484 开启并提示，再点开始；桌面照原版 | Kyo 11-13 反馈 v0.01.07 安卓挂机开不了；Kyo 11-11 优化直接接受 | `XHangUp.TOUCH_SHOW_PROHIBITED = false`（禁用时不显示） | cc | 保留 |

## 交接板

- 下一步：进 v0.01.08 在线更新（推送等 Kyo 说「推」）。安卓真机没试过。
- 用户试玩说明：安卓到一层，点左上角挂机按钮就开始挂机，再点一下停止；新游戏没开过挂机时，第一次点会先提示「摆烂功能已开启~！」，再点一下开始。
- 需要用户决定：无

## 进度账

- 无（修玩家反馈，不改完成度）

## 可优化（流程／工具／效率）

- 已做：全工程按下即触发（ACTION_MODE_BUTTON_PRESS）的按钮只有挂机按钮和回城枫叶两个，都接了 `XKeyMap.first_press`（回退 `XKeyMap.ONE_PRESS_PER_TAP = false`）；以后新加按下即触发的按钮也要先问它。
- 建议：发行入口冒烟、虚拟玩家目前都只发按键，没有真触屏点击；加一组 ScreenTouch（打开鼠标模拟）的冒烟，能更早抓到这类触屏才有的问题（归平台车道）。

## 本分支提交

- 见 git log
