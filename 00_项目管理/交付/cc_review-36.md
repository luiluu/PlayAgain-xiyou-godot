# 交付：cc/review-36

- 车道／工作者：审查／cc（审查 36）
- 状态：可合并
- 基线：main `51fb315f`，只加核查报告和本交付单。行号按这个基线。

## 变更记录草稿

## 2026-11-04 【cc·审查】核查 护盾一族、自动复活、璇第三期期二、选测钩子收紧、角色尾项第一批、伤害一族

- 核查覆盖：cc/nezha-tools57（6c79d5d3）、cc/bajie-rules2b（0cbde56e）、cc/bajie-rules3（2985a786）、cc/wukong-xuan4c（e5f9459f）、cc/wukong-tail1（678e8ddb）、cc/bajie-rules4（51fb315f）
- 结论：P1、P2 无。审查 35 两条 P2 都修住了。P3 两条（xuan4c `_grants60` 没有测试但代码对；rules4 行动者弹字画面没测试、没判 sprites）；P4 两条。另有一项待量：`act` 门内外其他模块在跳过回合的行为。
- 详情：[核查报告](核查报告_20261104_审查第36期.md)
- 验证：工具回归全过；反向验证 6 项 5 项咬住；`xuan_auto_probe` 重跑与夹具相同；没跑全量，没开游戏。

## 交接板

- 下一步：派规则车道量 `act` 门内外各模块在跳过回合的行为（用 `xuan_auto` 的 `skip_*` 写法）；xuan4c P3-1、rules4 P3-1 随下期补测试。
- 用户试玩说明：无。
- 需要用户决定：`hookLines.enabled` 现在是 true，tools57 建议先别开。开着无害，归总装定，不用找 Kyo。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- `state_anims` 判 `sprites.has`、`user_popups` 不判，`_hit_visual` 里的读法不统一。可以让 `_popup` 自己判。归下期规则或界面车道。

## 验证

- 见核查报告「验证」节。

## 本分支提交

- 本提交：审查第 36 期报告和交付单
