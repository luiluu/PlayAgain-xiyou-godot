# 交付：cc/nezha-tools78

- 车道／工作者：工具（CI）／哪吒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-06 【cc·哪吒·未经审查】收口也立云端锚点；合并小工具进库（--lane／--queue）（dev.待定）

- ① `合并车道.py` `close_batch`：收口检查通过后记下 HEAD，推送成功后给它立云端锚点（`云端选测.py trust <提交> --reason 收口推送后自动`）。tools77 收口不立是因为批里的收尾提交没有「验证:」尾注；但收口前要求工作区干净（含未跟踪文件），手补都已提交，检查测的就是这个提交本身，tools60 防的「手补没提交、云端只测了合并提交」在这里不会发生，所以不看尾注、不排除手补。检查后 main 又动了就不立；没推出去不立；立失败只警告。`anchor_after_push`／`push_github` 加参数 `verified`。
- ② 新 `--lane <任务> --who <执行者> --desc <内容> [--branch <分支>]`：照总装 `lane.sh`＋`addrow.py` 一步做完：准备（已准备好就跳过）→ 查工程与 `00_设计` 里相对合并前 main 新冒出来的 `O-待定`（`new_placeholders`，含未跟踪文件；原脚本写死排除 heartsteel／tusu，现在按与 base 比，旧有的自动不算）→ `board_add`：移走「正在进行」表里提到本分支或工作树的行（`--finish` 要求的）、新优化号的「需要用户决定」行插到最后一条 `- O-NNN ` 行后、待核查表首行插 `| 分支 | 执行者 | 内容 | 待审查 |`（已有不重插）→ `--finish --batch`。`--who`／`--desc` 不许带 `|`、换行。
- ② 新 `--queue a,b=分支,c`：按序逐条 `--lane`，全过后自动 `--close-batch`（`--affected`、`--cloud` 传给收口）；`--who`／`--desc` 给一个全队同用，或按顺序每条一个；分支写「任务=分支」，不用 `--branch`。哪条停下就停在那条，修好后重跑同一条命令：已攒进本批（`batch.json`）的那几条跳过，接着合剩下的再收口。
- 回退：①把 `close_batch` 末尾的 `push_github(root, verified=checked)` 改回 `push_github(root)`；②不用这两个参数即可，原命令行为不变。

## 交接板

- 下一步：总装可以改用 `合并车道.sh --queue …` 代替 scratchpad 里的 lane.sh／chain*.sh。
- 用户试玩说明：无（工具改动）。
- 需要用户决定：无。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：`--queue` 重跑时跳过本批已有的任务（回退：删 `main` 里 `done` 的那段跳过判断）。
- 建议（工具车道，小）：`--lane`／`--queue` 现在要总装手写 `--desc`；交付单里没有现成的「一句话内容」字段，可以在交付单模板加一行「待核查摘要：」，没给 `--desc` 时就用它。
- 优化登记草稿：无

## 待交叉核查

- `03_再刷重制_Godot/07_开发环境/合并车道.py`：`CLOSE_ANCHOR_REASON`、`anchor_after_push(root, verified)`、`push_github(..., verified)`、`close_batch` 记 `checked`；新增 `REVIEW_HEAD`、`OPT_ROW_RE`、`new_placeholders`、`board_add`、`lane_one`、`queue_items`，`main` 加 `--lane`／`--queue`／`--who`／`--desc`；模块说明加两段。未改战斗核心文件。
- `03_再刷重制_Godot/07_开发环境/测试合并工具.py`：新增 `lane_board`、`tool` 夹具与 8 项用例，改 1 项。

## 验证

- `测试合并工具.py` 277 项全过。新增 8 项：`test_close_batch_without_push_does_not_anchor`、`test_lane_one_step_prepares_fills_board_and_batches`、`test_lane_rerun_after_prepare_does_not_duplicate_rows`、`test_new_placeholders_counts_only_lines_new_since_base`、`test_lane_stops_on_new_placeholder_and_keeps_board`、`test_lane_and_queue_argument_errors`、`test_queue_merges_in_order_then_closes_and_anchors`、`test_queue_rerun_skips_lanes_already_in_batch`。改 1 项：`test_close_batch_checks_once_cleans_and_pushes`（tools77 时断言收口不立，现在断言立在收口检查过的 main 头上）。
- 换回改动前的 `合并车道.py` 字节跑（`--queue` 跳过那项是后加的，没在旧代码上跑）：7 项挂（5 失败、2 报错）。`test_close_batch_without_push_does_not_anchor` 在旧代码上也过：它守的是「没推出去不立」，旧代码本来就不立。
- `测试选测.py` 133 项全过；`工具回归.py` 全过（51 秒）。
- 没在真仓库跑过 `--lane`、`--queue` 和收口立锚点；总装第一次用 `--queue` 时请看一眼交接板改动，以及「立云端锚点（收口推送后自动）」那行输出。没跑 `语法检查.py`：没改 .gd。

## 本分支提交

- 见 git log
