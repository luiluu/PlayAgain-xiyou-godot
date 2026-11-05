# 交付：cc/review-46
- 状态：可合并
- 车道／工作者：cc（审查）

只含文档，无游戏代码。

## 变更记录草稿

## 2026-11-05 【cc·审查】核查 bajie-rules10、bajie-rules10c、weak-weak1、wukong-dead1、wukong-dead1b、bajie-events7、bailong-ui10、nezha-diff2（审查第 46 期，dev.待定）

- 报告：`核查报告_20261105_审查第46期.md`。P1 0、P2 0、P3 2：rules10 的隐月叠层没被陈旧状态过滤滤掉（`XActor.trait_objects` 只过滤 `states()`）；ui10 的气泡停留没跟变速档位走（原版 QuickMode 的对应物是 O-006 的四档变速，原版开了加速时停 0.75 帧，重制固定 3 帧）。
- weak1 开关关、本局标记关两种情况都逐处核过，挂点都直接返回；rules10 三个开关关时掷骰次数、顺序不变；dead1 的 `reserve_after` 在开关关时不起作用。本机复跑 8 个专项全过（weak 用本树探针重出参照：主工作区那份是 weak2 合并中的新版）。
- 核查覆盖：cc/bajie-rules10（50a3cab9）、cc/bajie-rules10c（84e19122）、cc/weak-weak1（3a3c36c6）、cc/wukong-dead1（1f757c02）、cc/wukong-dead1b（dca71d88）、cc/bajie-events7（7571149e）、cc/bailong-ui10（672dbd4b）、cc/nezha-diff2（b4044cc2）
- 方法限制：乙、丙档没跑原版实机。

## 已核／未核清单
已核：全部 8 批（派单 7 项，dead1 和 dead1b 分开算）。未核：无。

## 交接板
- 下一步：P3-1 派规则车道（八戒），让 `floor_states()` 跳过陈旧状态；P3-2 派界面车道（白龙），把变速档位接进 `balloon_wait`，或者把这条差异写进 O-006 的说明。合并 weak2 时注意：weak2 收尾前，主工作区的 `weak_challenge.json` 比 main 上的专项新。
- 需要用户决定：无

## 待交叉核查
无（审查线程自己的文档分支）。

## 可优化
无。
