# 交付：cc/pro-tools-fixes

- 车道／工作者：D 工具·合并与出包小修／cc（Pro，云端）
- 状态：可合并

## 变更记录草稿

## 2026-11-12 【cc·Pro·未经审查】合并与出包工具三处小修：解析检查跳过 .gdignore、交付自检查漏交 .gd.uid、Windows 发 zip（dev.待定）

- 解析检查跳过 `.gdignore` 目录：`合并车道.py` 新增 `project_gd_files()`，跳过 `.godot` 缓存和含 `.gdignore` 的目录整棵（出安卓包生成的 `android/build` 里有模板自带的测试 .gd，load 会报错）。`parse_check` 交给外置 load 脚本的文件清单、`gd_await_ternary_problems` 都改用它；`语法检查.py` 借的是同一个 `parse_check`，跟着生效（测试里真跑了一次 `语法检查.py`）。
- 漏提交 .uid：`合并车道.py` 新增 `missing_gd_uids(root, base, target)`：分支相对 main 新增的工程 .gd（tests、modes 都算）在分支提交里没有同目录同名 `.gd.uid` 的列出来；`.gdignore` 目录下和工程外的脚本不算。`交付自检.py` 把它算问题（退出 1，列出缺的 .uid 文件）；`plan()` 只打一行提示不拦，因为 `--finish` 收尾的 `lane_uids` 仍会自动带入主工作区生成的 .uid。两处共用这一个函数。
- `发行出包.py`：Windows 导出成功后另打 `再刷一把_天启篇_windows.zip`（zipfile 压缩，里面只放 exe 和 pck 两个文件，文件名标 UTF-8 位），写进 `SHA256SUMS.txt` 和 `体积.md`（新行「Windows zip」）；`windows/` 目录照旧留着给冒烟用；发行说明的 Windows 安装句改成「解开 再刷一把_天启篇_windows.zip……双击 exe」。
- 测试：`测试合并工具.py` 加 `test_gdignore_dirs_skipped`、`test_syntax_checker_skips_gdignore`、`test_plan_hints_missing_gd_uid`；`测试交付自检.py` 加 `test_new_gd_without_uid_is_reported`、`test_uid_committed_later_passes`，夹具默认车道脚本带上 .uid；`测试发行出包.py` 加 `test_win_zip_and_manifests`、`test_export_makes_win_zip_and_notes_say_unzip`。都用临时目录夹具，不真导出、不调 godot。
- 玩家可见：Windows 版改成下载一个 zip，解开后双击 exe。

## 交接板

- 下一步：无。
- 用户试玩说明：下次出包 Windows 是 `再刷一把_天启篇_windows.zip`，解开即用。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：云端容器默认没有 zsh，`工具回归.py` 里提交守卫、临时探针两项因此报错（本轮 `apt-get install zsh` 后通过）；可在云端准备脚本里装 zsh，或测试里没有 zsh 时跳过（归工具车道）。

## 验证

- `python3 03_再刷重制_Godot/07_开发环境/工具回归.py`（云端，装了 zsh 后）：18 项过 17 项。失败的「选测替身与 检查.sh 解析」（`测试选测.py CheckerTests`）在未改动的 origin/main 上同样失败，是云端环境问题（没有 Godot／Mac 环境），和本分支无关；本分支没碰选测与 `检查.sh`。
- 单跑：`测试合并工具.py` 343/344，唯一失败 `SlotWeightTests.test_sync_heavy_probe_weight_and_waiting_heartbeat` 在 origin/main 上同样失败（云端核数少，共用槽上限算成 2，断言写死「占 3 槽」），和本分支无关；`测试交付自检.py` 29/29；`测试发行出包.py` 13/13。

## 本分支提交

- 合并工具：解析检查跳过 .gdignore 目录；交付自检查新增 .gd 缺 .gd.uid
- 发行出包：Windows 另打 zip（UTF-8 文件名），写进校验和与体积表，发行说明改「解开 zip」
- 交付单
