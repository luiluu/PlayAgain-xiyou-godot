# 交付：cc/update-revoke-fix1

- 车道／工作者：自动更新（工具与平台）／cc（update-revoke-fix1）
- 状态：可合并

## 变更记录草稿

## 2026-11-11 【cc·update-revoke-fix1·未经审查】审查 78 P3-4：静默检查见到撤回时，已登记新补丁只差重启就不退回（dev.待定）

- 问题（审查 78 P3-4）：`XUpdateClient.check()` 在静默检查里发现「现在运行的版本在撤回名单里」就直接 `XUpdateInstall.rollback()`。检查更新页那条路有 `pending_code()` 把关（已下好只差重启时直接显示「已准备好」，不再检查），静默检查没有。于是：玩家装好了修正补丁还没重启，隔天进标题静默检查，会把新登记的修正补丁退掉。
- 修法：`core/update_client.gd` 那一处加 `XUpdateInstall.pending_code() == 0`：登记着的就是正在跑的那一版才退；已经登记了别的补丁、只差重启时不动。
- 测试：`tests/xiyou_update_install` 加 4 项（共 53 项）：撤回名单里有现在运行的版本；已登记新补丁只差重启时静默检查不退回、不留退回提示；登记着的就是正在跑的被撤回版本时照常退回并留「已撤回」提示。
- 验证：`xiyou_update_install` 53/53、`xiyou_update_check` 54/54、`xiyou_boot_patch` 20/20（直接用引擎单跑；`并行测试.py` 因本树 `generated/` 落后主工作区一项参照而拒跑，这三个专项不读转换产物）；`语法检查.py` 通过。
- 合并顺序：排在 `cc/update-input-fix1` 之后（spike0 → check1 → release1 → install1 → cloud1 → android-net1 → input-fix1 → revoke-fix1）。改代码的只有 `core/update_client.gd` 一行，要先拣也可以，但它依赖 install1 里的 `XUpdateInstall`。
- 待交叉核查：乙档，一行加测试。

优化登记草稿：无

## 交接板

- 下一步：无新增。
- 用户试玩说明：无。
- 需要用户决定：无。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- （见 git log cc/update-input-fix1..cc/update-revoke-fix1）
