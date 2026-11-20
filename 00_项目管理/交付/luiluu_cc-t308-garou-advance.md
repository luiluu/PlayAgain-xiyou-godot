# 交付：luiluu/cc-t308-garou-advance

- 车道／工作者：T308 advance.gd 饿狼进阶别套天启篇进阶金钱（cc，Sonnet＋medium，职级 P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T308·未经审查】进阶行不再给饿狼套天启篇进阶金钱（dev.待定）

- `XAdvance.row` 给饿狼（173，`XGarou.ACTOR`）也套了天启篇进阶金钱（`XTianqiMoney.advance_gold`），可饿狼进阶走 `XGarou.advance`、不扣表里金钱，旧进阶页的 `missing` 会被金钱误挡。根修：`row` 对 173 跳过天启篇金钱，保留表里原值（与西游存档一致）。其他角色、非天启篇存档的进阶条件逐项不变。
- 新增断言（`xiyou_actor_advanced`）：`garou_row_not_tianqi_gold`（天启篇存档里饿狼 0 阶行的金钱＝表值、不是 10 万）、`other_row_tianqi_gold`（别的角色仍套天启篇金钱）。反向验证：去掉修复后 `garou_row_not_tianqi_gold` 失败（0 vs 100000）。
- 卡 O 的 `lack_of`（`actor_advanced.gd:729`）**没有收掉**：它对饿狼只看 `XGarou.reason`，而 `XAdvance.missing` 对饿狼在 reason 通过后仍会继续查表里的等级、物品；饿狼进阶不扣这些，所以绕法并非多余，注释里「金钱误报」的原因现已根修，剩下的等级／物品不对口仍靠它。注释未改，建议后续卡决定是否把 `missing` 对饿狼也收口。

## 交接板

- 下一步：无
- 用户试玩说明：天启篇存档里饿狼旧进阶页不再被金钱误挡（卡 O 新页本就绕开）
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`XAdvance.missing` 对 `XGarou.own` 角色在 reason 通过后直接返回空，可删 `lack_of` 的饿狼分支（小改，归任一界面车道）。

## 验证

- 语法检查 0 问题；`xiyou_actor_advanced` 35/35、`xiyou_ui_skin_card_o` 124/124（headless，无声音）。
- 未跑选测全表／全量（按车道规矩）；改动只在 `advance.gd` 一个条件。

## 本分支提交

- 见 git log
