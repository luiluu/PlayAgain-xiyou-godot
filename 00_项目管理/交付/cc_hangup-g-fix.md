# 交付：cc/hangup-g-fix

- 车道／工作者：修自动挂机 G 键没反应（cc 项目线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-13 【cc·项目线程·未经审查】挂机被禁用时按 G 照 L 开启；发行包缺天启篇数据时不再反复重读（dev.待定）

- 起因：玩家反馈 v0.01.06「自动挂机（G 键）没反应」。
- 复现：dev476 Mac 发行包（编辑器带 `--main-pack` 跑包内 pck，临时 HOME）和 main（`ReleaseEntry.simulate_release`）一样：标题新游戏走原版开局，Map001 EV1 执行 ProhibitHangUp，挂机一直是禁用；到一层按 G 什么都不发生。先按 L（公共事件 484「挂机」，EnableHangUp）或找大厅大工匠（Map004 EV7）开启后，G 正常开始挂机。原版 XdRs_HangUp `readyStart` 禁用时也是只清状态、不提示，重制照搬了，所以不是回归。调试构建走天启篇开局、不执行 ProhibitHangUp，开发时碰不到。
- 排除：检查更新弹框（9822b77ac）的 `_input` 只在弹框开着时吞键，关掉连 CanvasLayer 一起删，和 G 无关。外泄修复（cc/sweet-hawking-8906bd）排除 tianqi_data/、rift_alien.json 后挂机照常能用（把两处挪走跑 xiyou_hangup 44/44），但一场挂机测试里 `XTianqiSkills.data()` 报「读不到 skill_rework.json」7781 次、`XTianqiAffixTable.data()` 报 JSON 解析失败 146 次：读不到不记，每次 `XGojo.patch_skills` 建技能表、每次查词条都重开文件再报错。
- 改动：
  - `map_scene.gd` `toggle_hang_up`、`hang_up.gd` `XHangUp.KEY_ENABLES`（O-待定）：挂机禁用时按 G 预约 L 键绑的公共事件（484）：副本外开启并提示「摆烂功能已开启~！」，副本里提示去传送门重置；开启后再按 G 才开始。设 false 恢复原版（只清状态）。
  - `tianqi_skills.gd`、`tianqi_affix_table.gd`：读表失败记一次（`_load_failed`），之后直接返回空表、不再重读重报；`XTianqiAffixTable.reload()` 清掉这个记号。挪走 tianqi_data 后同一测试只剩各报一次。
- 测试：`xiyou_hangup` 加三项（禁用时 G 开启不开始、副本里 G 仍禁用、回退开关下 G 不开启）；把开关默认改 false 时 `g_enables_when_prohibited` 失败，改回通过。选测 xiyou_hangup*、xiyou_map_hotkeys、xiyou_gojo、xiyou_tianqi_skills、xiyou_tianqi_affix*、xiyou_affix_rate、xiyou_input_handled 全过；语法检查 0 问题。
- 玩家可见：挂机没开启时按 G 会直接开启挂机功能并提示（副本里提示去重置副本），再按一次 G 开始挂机。

## 优化登记草稿

| 编号 | 位置 | 原版 | 优化 | 依据 | 回退 | 提出 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/hang_up.gd` `XHangUp.KEY_ENABLES`；`map_scene.gd` `toggle_hang_up` | 新游戏开局 ProhibitHangUp，挂机禁用时按 G 什么都不做、没有提示，要先按 L 或找大厅大工匠开启 | 禁用时按 G 照 L 走公共事件 484：副本外开启并提示，副本里提示去重置；不直接开始挂机 | v0.01.06 玩家反馈「挂机 G 键没反应」；Kyo 11-11 优化直接接受 | `XHangUp.KEY_ENABLES = false`（禁用时 G 只清状态） | cc | 保留 |

## 交接板

- 下一步：随 v0.01.07 整包一起出（只在 Kyo 说「推」时推）。外泄修复（cc/sweet-hawking-8906bd）合并前后都不影响挂机；本分支的读表失败记号让发行包缺 tianqi_data 时不再刷错误。
- 用户试玩说明：发行包新游戏到一层按 G：提示「摆烂功能已开启~！」，再按 G 开始挂机。
- 需要用户决定：无

## 进度账

- 无（修玩家反馈，不改完成度）

## 可优化（流程／工具／效率）

- 建议：发行入口冒烟（`core/key_smoke.gd`）只认 accept/space/j/z/cancel/x/k/方向键，加上 g、l 和「到某张地图」一步，就能在真发行包里冒烟挂机；这次是用编辑器带 `--main-pack` 加 `-s` 探针跑包内 pck 才复现的（归平台车道）。
- 建议：别的天启篇数据读取（XTianqiLine、XRiftAlien 等）读不到时也只报一次；本次挂机测试里它们各报 1～6 次，不急。
- 建议：安卓玩家没有 L 键、禁用时挂机按钮也藏着，只能找大厅大工匠开；可以考虑禁用时也显示按钮、点了走同一个公共事件（需看触屏布局，归触屏车道）。

## 本分支提交

- 见 git log
