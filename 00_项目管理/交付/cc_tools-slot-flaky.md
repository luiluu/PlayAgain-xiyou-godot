# 交付：cc/tools-slot-flaky

- 车道／工作者：工具（cc，线程「让 main 复用车道同步结果」续）
- 状态：可合并
- 基于：cc/tools-merge-args3 末端（98111154）。那条还没合时，本分支把它一起带进来。

## 做了什么

- 查清：`SlotWeightTests` 的 `test_lane_single_yields_to_live_priority_waiter_even_with_free_slots` 和 `test_lane_heavy_waits_for_priority_waiter_before_gathering` 偶发失败，原因不是机器负载。这两项用 `os.getppid()` 当「活着的总装等候者」的进程号；测试从后台子壳（`( … &)`）启动、子壳先退出时，父进程号变成 1（launchd）。`os.kill(1, 0)` 报 PermissionError，`并行测试.py earlier_waiter` 照设计把它跳过（不当成等候者），车道就直接占了槽。上次「和选测并行跑时挂」，正好是我用后台子壳同时起了两组测试。
- 复现：用后台子壳单跑这两项，2/2 必挂；前台跑全过。
- 修：测试里加 `live_pid()`，自己起一个 sleep 子进程当假等候者（确定活着、归本用户），用完杀掉。三处 `os.getppid()` 都换掉（含 stale 排队文件那项）。
- 产品代码没动：真实等候者的排队文件写的是自己的 pid，不会碰到 PermissionError。
- 回退：revert 本提交。

## 改动文件

- 改：`03_再刷重制_Godot/07_开发环境/测试合并工具.py`

## 验证

- 后台子壳跑 `SlotWeightTests`：修前 11/13（这两项挂），修后 13/13；前台 13/13。
- `测试合并工具.py` 整份 298 项通过；`工具回归.py` 11 项全过（65 秒）。没有 Godot 场景。

## 优化登记草稿

优化登记草稿：无

## 可优化（流程／工具／效率）

- 无

## 变更记录草稿

## 2026-11-07 【cc·工具·未经审查】SlotWeightTests 偶发失败修稳（dev.待定）

- 两项「车道让总装等候者」测试用 `os.getppid()` 冒充活着的等候者；从后台子壳启动时父进程号变 1，`os.kill` 报 PermissionError 被当成不存在，必挂。改用测试自己起的子进程号。产品代码不变。

## 交接板

- 待交叉核查：cc/tools-slot-flaky（丙：工具测试）

## 本分支提交

- 034e8b8f SlotWeightTests 假等候者改用自己起的子进程号
