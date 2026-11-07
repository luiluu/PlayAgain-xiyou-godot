# 交付：cc/rules-bugfix3

- 车道／工作者：规则（cc，项目线程「完成再刷西游Godot引擎重制」），总装派单：审查第 51 期 P3-1、P3-2
- 状态：可合并
- 基于：main ab80ca89，交付前已 merge main 677bfc08。
- 改了战斗核心：`core/battler.gd` on_restrict 删一行；`core/three_growth.gd` mark_recruit 一个条件。

## 逐条

### 审查 51 P3-1（three_growth.gd mark_recruit）

- 复现测试：`tests/xiyou_three_growth.gd` 的 `mark.on.written`、`mark.on.roundtrip`（O-137 开着：招募后法宝实例没有 `_o137Dup`，存档读档后也没有）；`mark.off.*`（关着：照写，往返后还在）。旧代码上 `mark.on.*` 挂（已核）。
- 修法：`mark_recruit` 只在 `FIX_RECRUIT_DUP` 关着时写记号。开着时本来也不读它，只是白写进存档。

### 审查 51 P3-2（battler.gd on_restrict）

- 复现测试：`tests/xiyou_state_remove.gd` 的 `sc.restrict_no_tag_in_data`（数据里没有「SC行动限制解除」标签）、`sc.restrict_no_change`（临时给凌波舞 525 写上标签，第一次受限时 525 照样去掉、记进解除，不换成别的状态）。旧代码上 `sc.restrict_no_change` 挂（之前那行会把 525 从本次解除里删掉，已核）。
- 修法：删掉 `change_state_if_removed(id, "行动限制解除")`；原版这里被 _Fix_StackOverflow 的全局锁挡住，注释写明了原因。`change_state_if_removed` 还留给受伤解除用。

## 优化登记草稿

优化登记草稿：无

（O-137、O-223 的登记不变。）

## 变更记录草稿

## 2026-11-07 【cc·规则·未经审查】审查 51 期两处小修：百谷生招募记号、受限解除不换状态（dev.待定）

- **P3-1**（`core/three_growth.gd`）：O-137 开着（默认）时招募不再往法宝实例写 `_o137Dup`，存档里不留无用记号。
- **P3-2**（`core/battler.gd`）：第一次受限解除状态时不走「SC行动限制解除」换状态，同原版（被全局锁挡住）。

## 交接板

- 下一步：无新增。
- 用户试玩说明：无可见变化。
- 需要用户决定：无。

## 待交叉核查

- cc/rules-bugfix3：审查 51 P3-1、P3-2（甲档：battler；乙档：three_growth）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 验证

- 语法检查通过。
- 专项（本地）：xiyou_state_remove 389/389、xiyou_three_growth 110/110、xiyou_guyu 78/78。旧代码上新断言挂（已核）。
- 云端选测通过：ea50efde，139 个场景、10 片（https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42338289420）。

## 本分支提交

- 3b0720c4 两处修复与断言
- ea50efde 合并 main
- 交付单 cc_rules-bugfix3（本提交）
