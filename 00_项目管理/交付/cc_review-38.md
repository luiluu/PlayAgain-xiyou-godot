# 交付：cc/review-38

- 车道／工作者：审查／cc
- 状态：**可合并**（只改文档）

## 变更记录草稿

## 2026-11-04 【cc】核查 审查第 38 期（甲 7 批、丙 1 批、文档批）

- 核查覆盖：cc/bajie-rules5 a4a51a12、cc/wukong-tail3 11205986、cc/nezha-tools59 71fd1a50、cc/nezha-tools60 481d7149、cc/bajie-rules6 3330d0ad、cc/wukong-tail4 951e3c60、cc/bajie-fix1b 34d4ffc3、cc/bailong-ui4b 0bf40577
- 结论：无 P1；**P2 一条**——强制行动队列与公共事件预约不在开战时清，上一场残留在下一场被执行（rules5 带入，fix1b 的金剪追加、反击、往世乐土放大了概率；实测复现）；P3 九条。其余通过。
- 详见 `00_项目管理/核查报告_20261104_审查第38期.md`。
- 未做：没有重跑各批专项与选测；没有试玩。

## 交接板

- 待修：P2-1 交 C 规则／八戒（`_start_battle_effects` 清 `_forces`、`_reserves`，评估追加是否同检查内跑到队列空，补专项）。P3 九条见报告。
- 待交叉核查：本分支 `核查: 无`。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 无。

## 验证

- 临时 Godot 脚本复现 P2-1（`scratchpad/review38_tmp.gd`，不入库）。其余为读码。
