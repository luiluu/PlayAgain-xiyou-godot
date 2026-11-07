# 交付：cc/tools-merge-args6

- 车道／工作者：工具（cc，线程「让 main 复用车道同步结果」续）
- 状态：可合并
- 基于：cc/tools-merge-args5 末端（53183eeb）。args4、args5 没合时，本分支一起带进来。

## 做了什么（审查 63 P2-1）

- 问题：同一个文件里既有开发编号占位、又有「O-待定·名字」时（包括优化登记行里写了开发编号占位），准备阶段的 `replace_versions` 已经把这个文件替换后的摘要记进 `versionEdits.after`。`number_named` 发号时又改了它，`--finish` 的 `validate_version_edits` 就报「编号替换文件还有其它改动」停下，交接板也只改了一半。重跑同一条 `--lane` 时，登记里的首格已经发过号，认不出要做什么，还是停。
- 修法：
  - `number_named` 收进合并状态：先把发号计划（`namedNumbers` 名字→号、`namedRows`、`namedFiles` 要扫的文件、`namedNames`）和交接板要加的行（`optAppended`）存进 `state.json`，再写文件。重跑时照存下的计划再换一遍：换过的不会再变，交接板行也不重复记。
  - 换完的文件如果在 `versionEdits` 里，把它的 `after` 摘要更新成发号之后的；这类文件本来就在收尾允许的范围里，不再经 `--also` 点名，其余改过的文件照旧走 `--also`。
- 回退：revert 本提交（回到 args5）。

## 改动文件

- 改：`03_再刷重制_Godot/07_开发环境/合并车道.py`（`number_named`、`lane_one`）、`测试合并工具.py`

## 验证

- 新测试 `test_named_number_and_dev_placeholder_in_same_file_survive_finish_and_rerun`：
  - 场景：车道的优化登记新行和一份设计文档里，都同时写了开发编号占位和「O-待定·双占位」，文档里还提到一条早先登记的「O-待定·旧」。
  - 先让第一次 `--finish --batch` 停下（模拟中途中断），再重跑 `lane_one`：首格和文档都换成 O-119，开发编号占位也换好；「O-待定·旧」不动；交接板「- O-119 甲项」只有一行；合并状态已清，main 干净。
  - 反向验证：去掉更新 `versionEdits` 那一行，这项测试就挂（finish --batch 没过）。
- `测试合并工具.py` 整份 303 项通过；`工具回归.py` 11 项全过（56 秒）。没有 Godot 场景。

## 优化登记草稿

优化登记草稿：无

## 可优化（流程／工具／效率）

- 无

## 变更记录草稿

## 2026-11-07 【cc·工具·未经审查】合并车道具名发号：同文件有开发编号占位时不再卡收尾，中断后重跑能接着做（dev.待定）

- `合并车道.py --lane`：具名占位的发号计划先存进合并状态再写文件，重跑同一条照计划接着换、不重复记交接板行；同一文件也有开发编号占位时，更新准备阶段记下的 `versionEdits` 摘要，`--finish` 不再报「编号替换文件还有其它改动」。审查 63 P2-1。

## 交接板

- 待交叉核查：cc/tools-merge-args6（甲：合并流程改优化登记与代码）

## 本分支提交

- 13887fae 合并车道 具名发号：发号计划存进合并状态、重跑幂等；同文件有 dev 占位时更新 versionEdits 摘要
