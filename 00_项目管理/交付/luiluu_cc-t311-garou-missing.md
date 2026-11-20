# 交付：luiluu/cc-t311-garou-missing

- 车道／工作者：T311 XAdvance.missing 对饿狼查表条件，先对原版（cc，Sonnet＋medium，职级 P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T311·未经审查】XAdvance.missing 对饿狼的查表条件：核原版，结论「照原版」，只补注释（dev.待定）

- 原版核查（冻结正式源 v0.62.12）：饿狼 `onBottomConfirmOk` 包装（`js/codex/runtime/installNativeGarouRuntime.js:277-286`）里，`G.reason(a)` 不通过才 buzzer 并取消；通过后 `return bottom.apply(this,arguments)`（:285），继续走原 `Scene_ActorAdvanced.prototype.onBottomConfirmOk`（`js/plugins/Star_ActorAdvanced.js:2973-2998`），那里按 `$dataStarAdvancedOpt` 行查等级、金钱、物品，没有行或不够就提示「进阶条件未达成」。所以原版**reason 通过后仍查表**。
- 结论：`XAdvance.missing` 对饿狼「先 reason、再查表」就是照原版，**不改代码**；`advance.gd` 该处补了注释说明，勿收口。
- 副作用说明：T308 已让 `XAdvance.row` 不给饿狼套天启篇进阶金钱，所以 `missing` 对饿狼现在的金钱判断与原版一致。卡 O 的 `lack_of`（`actor_advanced.gd:729`）对饿狼只看 reason，是**比原版更宽松**的刻意偏离（进阶本身不扣表里金钱／物品），本单按验收第 2 条不动它；要不要让新页也照原版挡，是策划口径，列在下面「要 Kyo 定」。
- 未新增断言、未改行为（只加注释），因此无反向验证。

## 交接板

- 下一步：无
- 用户试玩说明：无变化
- 需要用户决定：卡 O 新进阶页对饿狼是否照原版也查表里等级／金钱／物品（现状：只看 XGarou.reason，更宽松；旧页照原版）。倾向不改，旧页本身是兜底。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- `xiyou_actor_advanced` 35/35、`xiyou_ui_skin_card_o` 124/124（headless，--audio-driver Dummy）。

## 本分支提交

- 见 git log
