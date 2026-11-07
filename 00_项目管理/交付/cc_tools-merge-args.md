# 交付：cc/tools-merge-args

- 车道／工作者：工具（cc，线程「让 main 复用车道同步结果」续）
- 状态：可合并

## 做了什么

### 1. `--queue` 的 `--who`／`--desc` 按英文逗号拆

- 起因：11-07 总装三十一 `--queue a,b,c,d --who "x,y,z,w" --desc "…,…,…,…"`，一个值被当成「全队同用」，四行待核查都写成同一串。
- 现在：`--queue` 有多条、`--who` 或 `--desc` 只给一个值且里面有英文逗号时，按英文逗号拆成每条一个（打一行「按英文逗号拆成每条一个」）；段数对不上条数或有空段就拒绝，并说清两种写法。全队同用的值里别带英文逗号；`--lane` 和只有一条的 `--queue` 不拆。重复写 `--who`／`--desc` 的老写法不变。
- 帮助文字已改（`--who`、`--desc`、`--queue`）。

### 2. `--queue` 收了 `--also` 不转也不报错

- 起因：`lane_one` 调准备与收尾两步时只带任务名、执行者、分支，`--also`、`--accept-changes`、`--accept-doc-edits`、`--no-parse-check` 给了也丢掉，修好的文件没提交，下一步照样停。
- 现在：
  - `--lane` 把 `--also`、`--accept-changes`、`--no-parse-check` 转给准备那步，把 `--also`、`--accept-doc-edits` 转给 `--finish --batch` 那步。
  - `--queue` 只转 `--no-parse-check`（对每条都适用）；`--also`、`--accept-changes`、`--accept-doc-edits` 只对一条，给了就拒绝并指路：停在哪条，就用 `--lane <那条>` 带上它们修好合完，再重跑同一条 `--queue`（已攒进本批的会跳过）。
  - `--who`、`--desc` 不配 `--lane`／`--queue` 时拒绝（原来静默忽略）。
- 回退：`git revert` 本提交即可（只改参数处理，不碰合并流程本身）。

## 改动文件

- 改：`03_再刷重制_Godot/07_开发环境/合并车道.py`（`lane_one`、`queue_items`、`main` 参数处理与帮助文字）、`测试合并工具.py`

## 验证

- `测试合并工具.py` 新增 2 项：`test_queue_who_desc_split_on_ascii_comma`（拆分、全队同用、单条不拆、段数不对与空段拒绝）、`test_queue_rejects_per_lane_flags_and_lane_passes_them_on`（`--queue` 拒三种单条参数；`--who` 不配 `--lane` 拒；`--lane` 把参数转到两步）。整份 296 项通过。
- `工具回归.py` 11 项全过（55 秒）。
- `选测.py main`：Godot 场景 0 个（只动开发工具），所以没跑云端。

## 优化登记草稿

优化登记草稿：无

（合并工具参数处理，不是原版优化项。）

## 可优化（流程／工具／效率）

- 已做：上面两项（回退：revert 本提交）。
- 无别的新发现。

## 变更记录草稿

## 2026-11-07 【cc·工具·未经审查】合并车道：--queue 的 --who／--desc 按英文逗号拆，单条参数不再被 --queue 静默丢掉（dev.待定）

- `合并车道.py --queue`：`--who`／`--desc` 只给一个带英文逗号的值时按逗号拆成每条一个，段数对不上就拒绝（三十一 11-07 四行待核查被拼成同一串）。
- `--lane` 把 `--also`、`--accept-changes`、`--no-parse-check`、`--accept-doc-edits` 转给准备与收尾两步；`--queue` 拿到 `--also` 等只对一条的参数时拒绝并指路（原来不报错也不转）；`--who`／`--desc` 不配 `--lane`／`--queue` 时拒绝。

## 交接板

- 待交叉核查：cc/tools-merge-args（丙：工具）

## 本分支提交

- 8daa465d 合并车道：--queue 的 --who／--desc 按英文逗号拆；--queue 拒收 --also 等单条参数，--lane 转给准备与收尾
