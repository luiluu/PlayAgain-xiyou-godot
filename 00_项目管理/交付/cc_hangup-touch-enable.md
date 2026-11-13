# 交付：cc/hangup-touch-enable

- 车道／工作者：修安卓挂机开不了（cc 项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·项目线程·未经审查】触屏设备挂机被禁用时也显示挂机按钮，点了照 L 开启（dev.待定）

- 起因：Kyo 反馈 v0.01.07 安卓挂机还是开不了。新游戏原版开局就禁用挂机（Map001 EV1 ProhibitHangUp）；桌面上次已改成禁用时按 G 照 L 开启（KEY_ENABLES），但安卓没有 G／L 键，挂机快捷界面在禁用时也整块藏着（`XHangUp.inter_show` 要求已开启），只能回大厅找大工匠开。
- 改动（`modes/xiyou/core/hang_up.gd` `XHangUp.TOUCH_SHOW_PROHIBITED`，O-待定）：触屏设备（`XPlatform.is_touch`）上禁用时也显示快捷界面；点按钮走原来的 `XMapScene.toggle_hang_up`，禁用时照 L 的公共事件 484 开启并提示「摆烂功能已开启~！」（副本里提示去重置），再点一次开始挂机。桌面照原版藏着。KEY_ENABLES 关掉时这一项也不生效。设 false 恢复原版。
- 测试：`xiyou_hangup` 加四项（触屏禁用时按钮显示、点了开启但不开始、回退开关下藏起、桌面禁用时仍藏）；把开关默认改 false 时 `touch_prohibited_button_shown` 失败，改回通过。选测 xiyou_hangup*、xiyou_map_hotkeys、xiyou_platform 全过，语法检查通过。
- 玩家可见：安卓上挂机没开启时左上角也显示挂机按钮，点一下开启挂机功能，再点一下开始挂机。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/hang_up.gd` `XHangUp.TOUCH_SHOW_PROHIBITED`、`inter_show` | 挂机被禁用（新游戏开局就禁用）时快捷界面连按钮一起藏起来，要按 L 或找大厅大工匠开启；触屏没有 L 键 | 触屏设备禁用时也显示快捷界面，点按钮照 L 的公共事件 484 开启并提示，再点开始；桌面照原版 | Kyo 11-13 反馈 v0.01.07 安卓挂机开不了；Kyo 11-11 优化直接接受 | `XHangUp.TOUCH_SHOW_PROHIBITED = false`（禁用时不显示） | cc | 保留 |

## 交接板

- 下一步：进 v0.01.08 在线更新（推送等 Kyo 说「推」）。
- 用户试玩说明：安卓新游戏到一层，左上角有挂机按钮：点一下提示「摆烂功能已开启~！」，再点一下开始挂机。
- 需要用户决定：无

## 进度账

- 无（修玩家反馈，不改完成度）

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log
