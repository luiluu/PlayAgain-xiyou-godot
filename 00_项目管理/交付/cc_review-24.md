# 交付：cc/review-24

- 车道／工作者：审查／cc（审查）
- 状态：可合并
- 基线：从 main `9c85dcba`（dev.272）切出，只加报告和本交付单。

## 变更记录草稿

## 2026-11-02 【cc·审查】核查 屠苏三期与云裳外层包装、谷雨读档同步

- 核查覆盖：cc/bailong-tusu3（edcc1ca4）；收尾 941f053e；cc/bajie-guyu-fix1（96036312）；收尾 9c85dcba
- 结论：P1 无，P2 一条，P3 一条，其余通过。P2-1：屠苏噬主付费分支（battle_logic execute 的 `XTusu.pay`）跳过了 `XSkillMastery.record`，持武者的武装技能和屠苏的支援不记熟练度，原版会记（mv_oracle 实测）；同一分支也跳过了 pay_hp 和异化缄默／饕餮。P3-1：屠苏绑定种类只在开战时登记，开机后没打过仗就读档，`XBinding.clear_all` 清不掉屠苏的形态状态。S2-1-03 的包装次序、子行动成帧、_yunTotal 挪到扣血处，屠苏三期的条件、费用、指令、盾相、清理，谷雨挪到换档之后，千位逗号，O-143 说明，都对。镜流 after_load、绑定 clear_all、屠苏 clear 不读 current，不用挪。详见[报告](核查报告_20261102_审查第24期.md)。
- 验证：对着冻结 v0.28 读 diff（installNativeYunshangRuntime、installNativeTusuRuntime、YEP_SkillMasteryLevels）；重跑 yunshang_wraps、tusu_battle 两个探针，和夹具一致；本地并行测试 14 个场景全过。

## 交接板

- 下一步：P2-1 派白龙（屠苏四期之前，或并进四期）：XTusu.pay 只替换 MP 扣法，熟练度计次、pay_hp、异化支付照常走，xiyou_tusu_battle 补一例（参照的 pay 步加记 `_actionMastery`）；P3-1 顺手在读档清理前登记屠苏种类。
- 用户试玩说明：无（只改文档）。
- 需要用户决定：无。

## 进度账

- 无变化。

## 优化登记草稿

优化登记草稿：无

## 可优化（流程／工具／效率）

- 无新增。

## 本分支提交

- 见 `git log 9c85dcba..cc/review-24`。
