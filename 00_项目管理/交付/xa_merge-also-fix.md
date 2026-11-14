# 交付：xa/merge-also-fix

- 车道／工作者：ag（默认模型，工具小修）
- 状态：可合并

## 变更记录草稿

## 2026-11-14 【ag·未经审查】合并车道.py：编号替换文件允许 --also 手补并记入尾注

- `03_再刷重制_Godot/07_开发环境/合并车道.py`：
  - `validate_version_edits(root, state, state_file=None)` 在检测到 `versionEdits` 文件与替换后哈希不一致时，若该文件显式列在 `state['also']`（即 `--finish`／`--lane` 传入 `--also`）中，则放行手补、将 `hashes['after']` 更新为当前文件摘要并记入 `state['versionHandEdits']`（同步保存 `state_file`）；未列在 `--also` 中的文件照旧抛错拦下。
  - `finish()` 收尾提交尾注整合 `state.get('versionHandEdits', [])`：无论常规 `--finish` 还是 `--finish --batch`（`--lane`），经 `--also` 手补过的编号替换文件都会记入 `手补: <文件>` 尾注（去重）。
- `03_再刷重制_Godot/07_开发环境/测试合并工具.py`：新增 `MergeTests.test_also_allows_hand_edit_on_version_replaced_file` 与 `MergeTests.test_also_allows_hand_edit_on_version_replaced_file_in_batch`，覆盖不带 `--also` 被拦、`--also` 点名别的文件或漏点被手补文件时照旧拦、显式带 `--also <文件>` 放行并更新哈希且尾注记录 `手补: <文件>`。
- 验证：
  - `python3 03_再刷重制_Godot/07_开发环境/测试合并工具.py MergeTests.test_also_allows_hand_edit_on_version_replaced_file MergeTests.test_also_allows_hand_edit_on_version_replaced_file_in_batch MergeTests.test_also_allows_extra_change_at_finish MergeTests.test_also_with_git_rm_sheet_at_finish MergeTests.test_finish_stops_on_opt_audit MergeTests.test_named_number_and_dev_placeholder_in_same_file_survive_finish_and_rerun MergeTests.test_hand_patched_closing_commit_without_tested_mark_is_not_anchored MergeTests.test_finish_without_affected_runs_full_check MergeTests.test_close_batch_checks_once_cleans_and_pushes`：9/9 通过（19.356s）。
  - `python3 03_再刷重制_Godot/07_开发环境/测试交付自检.py`：30/30 通过（50.963s）。
  - `python3 03_再刷重制_Godot/07_开发环境/测试记录工具.py`：17/17 通过（18.245s）。
  - `python3 03_再刷重制_Godot/07_开发环境/测试工具回归.py`：6/6 通过（0.027s）。
  - 完整 `测试合并工具.py` 与 `工具回归.py` 留由总装合并时跑。
- 提交：0b8e283f2（及本交付单提交）

## 交接板

- 下一步：无
- 需要用户决定：无

## 进度账

- 工具脚本小修，不涉及功能完成度变更。

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 0b8e283f2 合并车道.py：编号替换文件允许 --also 手补并记入尾注
