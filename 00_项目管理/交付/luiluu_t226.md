# 交付：luiluu/t226

- 车道／工作者：T226 测试工具看门狗／cc（Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-19 【cc·未经审查】并行测试看门狗：运行期 SCRIPT ERROR 也提前终止（dev.待定）

- 原来只有脚本解析错误（FATAL_LOAD）会提前杀进程；运行期 `SCRIPT ERROR: Invalid call…` 让协程卡住时仍挂到 600 秒超时。新增 `FATAL_ERROR`（FATAL_LOAD＋行首 `SCRIPT ERROR: `），`run_one` 改用它：出现即杀、rc 143、日志留错误行。`result_ok` 本来就把任何 SCRIPT ERROR 行判失败，判定不变，只省等待。
- 重跑豁免、语法检查提示仍用窄的 FATAL_LOAD（运行期错误可能偶发，照旧给一次重跑）。
- 查过：工程内 `SCRIPT ERROR` 字样只出现在 3 个测试的注释里，没有测试故意打印；正文里非行首的字样不误杀。
- 回退：`run_one` 里把 FATAL_ERROR 改回 FATAL_LOAD。
- 测试：测试合并工具.py 新增 test_runtime_script_error_fails_fast。

## 交接板

- 下一步：无
- 用户试玩说明：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：见上（回退见变更记录草稿）。临时探针.py 是 node 原版探针，不是 Godot，未改。

## 本分支提交

- c73de076a 看门狗＋用例＋交付单
