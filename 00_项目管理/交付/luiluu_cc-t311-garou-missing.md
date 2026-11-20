# 交付：luiluu/cc-t311-garou-missing

- 车道／工作者：T311 XAdvance.missing 对饿狼查表条件，先对原版（cc，Sonnet＋medium，职级 P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-20 【cc·T311·未经审查】XAdvance.missing 对饿狼的查表条件：核原版，结论「照原版」，只补注释（dev.待定）

- 原版核查（冻结正式源 v0.62.12）：饿狼 `onBottomConfirmOk` 包装（`js/codex/runtime/installNativeGarouRuntime.js:277-286`）里，`G.reason(a)` 不通过才 buzzer 并取消；通过后 `return bottom.apply(this,arguments)`（:285），继续走原 `Scene_ActorAdvanced.prototype.onBottomConfirmOk`（`js/plugins/Star_ActorAdvanced.js:2973-2998`），那里按 `$dataStarAdvancedOpt` 行查等级、金钱、物品，没有行或不够就提示「进阶条件未达成」。所以原版**reason 通过后仍查表**。
- 结论：`XAdvance.missing` 对饿狼「先 reason、再查表」就是照原版，**不改代码**；`advance.gd` 该处补了注释说明，勿收口。
- Kyo 11-20 定（经协调转达）：卡 O 新进阶页对饿狼也照原版查表。T308 已根修金钱误挡，绕法没理由留，于是收掉 `actor_advanced.gd` 的 `lack_of` 饿狼分支，一律 `XAdvance.missing`，新旧两页对饿狼条件一致。
- 新增断言（`xiyou_ui_skin_card_o`）：`garou_table_blocks`（临时把饿狼 0 阶表行改成等级 99、要物品，reason 通过时新页仍禁用按钮并列「还差」）、`garou_table_restored`（还原后可进阶）。反向验证：恢复旧绕法后 `garou_table_blocks` 失败。
- 注意：现行真实数据里饿狼各阶表行等级＝reason 等级、金钱 0、只有 5→6 阶要 1 个神之触媒（与 reason 一致），所以玩家看到的行为不变；收口只是防以后两边漂移。

## 交接板

- 下一步：无
- 用户试玩说明：无变化（真实数据下新旧页判断本来一致）
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- `xiyou_actor_advanced` 35/35、`xiyou_ui_skin_card_o` 126/126（headless，--audio-driver Dummy）。

## 本分支提交

- 见 git log
