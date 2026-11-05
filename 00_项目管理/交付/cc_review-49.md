# 交付：cc/review-49
- 状态：可合并
- 车道／工作者：cc（审查）

只含文档，无游戏代码。

## 变更记录草稿

## 2026-11-05 【cc·审查】核查 dead-eventsreg2、wukong-eventsreg3、bajie-events8、bajie-events9、platform-android2、entry-release1、nezha-tools70、rules-ui15、bajie-probepath、sync-post028-2（审查第 49 期，dev.待定）

- 报告：`核查报告_20261105_审查第49期.md`。P1 0、P2 0、P3 3。
  - P3-1：eventsreg3 的 `m80e13p2#g3` 预设键还是 WIP 时的 `random`，eventsreg2 交付时改成了 `random_seq`，合并后这条变体的随机数没生效，退回 0.5，走不到 `CodexMapRemoval.notice`（参照轨迹核实；这句写法靠 eventsreg2 的 `#s1` 仍有对照）。BJ 二期做随机门时要用 `random_seq`。
  - P3-2：tools70 的 `检查.sh --cloud` 临时快照用 `git add -A`，会带上没被忽略的未跟踪文件；走合并工具时有 `dirty()` 守卫，直接跑 `检查.sh --cloud` 时没有。
  - P3-3：android2 的返回键只在入口菜单上退出，而 entry-release1 让发行构建跳过入口菜单，安卓发行包返回键在西游标题上什么都不做。
- O-120 对照关两版（dead 与 eventsreg3）核过，关掉的范围相同，留 eventsreg3 那版没问题。
- 核查覆盖：cc/dead-eventsreg2（47e6c7a2）、cc/wukong-eventsreg3（2ba50bb7）、cc/bajie-events8（32bc71a4）、cc/bajie-events9（c97c63e1）、cc/platform-android2（ff28f8b4）、cc/entry-release1（bf8fbc8c）、cc/nezha-tools70（df5f82a3）、cc/rules-ui15（ec16b9ae）、cc/bajie-probepath（fd503de7）、cc/sync-post028-2（8b2ce72b）
- 方法限制：没跑 Godot；P3-1 用主工作区 `mv_oracle/.sandbox/event_states.json`（22:25）核。

## 已核／未核清单
已核：10 条全部。未核：无。

## 交接板
- 下一步：P3-1 派事件车道（BJ 二期顺手）：`m80e13p2#g3` 键改 `random_seq` 或删掉、重量参照；`event_state_probe.cjs` 遇到不认识的预设键报错。P3-2 派工具车道（哪吒）：快照改 `git add -u`（含 `add -N`），或列出带进快照的未跟踪文件。P3-3 派跨平台车道：`XPlatform.go_back` 在 `ReleaseEntry.skips_menu()` 时把西游标题当顶层（退出或先确认）。
- 需要用户决定：无

## 待交叉核查
无（审查线程自己的文档分支）。

## 可优化
- P3-1 的根因是预设键拼错不报错，建议探针对预设键做白名单校验（已写进交接板下一步）。
