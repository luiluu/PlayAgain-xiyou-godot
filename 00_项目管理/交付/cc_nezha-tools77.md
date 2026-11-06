# 交付：cc/nezha-tools77

- 车道／工作者：工具（CI）／哪吒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-06 【cc·哪吒·未经审查】合并推送后自动立云端锚点（dev.待定）

- `合并车道.py`：`push_github` 推送成功后调新加的 `anchor_after_push`：main 顶上的收尾提交带「验证: 选测／全量」尾注时，跑 `云端选测.py trust <收尾提交> --reason 合并推送后自动`（脚本路径照 `adopt` 认 `XIYOU_CLOUD_SCRIPT`），选测基准跟着 main 走，不再一直停在很早的云端通过点、每次退成整轮。
- 不立的情况（`anchor_target` 判，打一行「未立云端锚点：原因」）：没有「验证:」尾注（`--batch` 攒的、`--close-batch` 收口的）；收尾提交带「手补:」却没有「手补已验:」（tools60 规矩）。没推出去（无 github 远端、GitHub 有本地没有的提交、推送失败）也不立。
- 立失败（trust 退出非零、超时 180 秒、脚本起不来）只打「警告：给收尾提交 … 立云端锚点失败」，推送和合并结果不受影响。
- 回退：删掉 `push_github` 末尾的 `anchor_after_push(root)` 一行即回到原行为。

## 交接板

- 下一步：无新增（tools76「可优化」④已做）。
- 用户试玩说明：无（工具改动）。
- 需要用户决定：无。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议（工具车道，小）：`--close-batch` 收口跑的是本批统一检查，通过的是 HEAD，但 HEAD 没有「验证:」尾注，本轮按派单口径不立锚点。若要它也立，可在收口通过后另记一条「验证: 全量／选测」的空提交或直接按检查结果 trust（批里各条收尾提交的手补没记「手补:」，要先补这条记录才安全）。
- 优化登记草稿：无

## 待交叉核查

- `03_再刷重制_Godot/07_开发环境/合并车道.py`：新增 `ANCHOR_REASON`、`anchor_target`、`anchor_after_push`；`push_github` 失败分支加 `return`、成功后调 `anchor_after_push`；模块说明加一段。未改战斗核心文件。
- `03_再刷重制_Godot/07_开发环境/测试合并工具.py`：`github()` 夹具默认装云端脚本替身（`cloud_stub`），不碰真 `云端选测.py`。

## 验证

- `测试合并工具.py` 269 项全过；新增 4 项：`test_finish_push_anchors_verified_closing_commit`、`test_hand_patched_closing_commit_without_tested_mark_is_not_anchored`、`test_anchor_failure_only_warns`、`test_no_anchor_without_successful_push`（无远端、GitHub 领先两种）；改 2 项：`test_finish_cloud_adopts_snapshot_result_and_marks_hand_patch`（手补已验→adopt 后接 trust）、`test_close_batch_checks_once_cleans_and_pushes`（收口不立）。这 6 项在改动前的 `合并车道.py` 上全部挂（5 失败 1 报错）。
- `测试选测.py` 133 项全过；`工具回归.py` 全过（68 秒）。
- 没在真仓库跑过 trust（会往 GitHub 写 refs/ci/results），首次真合并时看输出那一行。没跑 `语法检查.py`：没改 .gd。

## 本分支提交

- 见 git log
