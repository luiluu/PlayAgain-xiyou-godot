# 交付：cc/update-check-test-fix

- 车道／工作者：总装三十八自修（cc）
- 状态：可合并
- 分道：快车道（只改一个测试）

## 变更记录草稿

## 2026-11-12 【cc·总装三十八·未经审查】检查更新专项不再读 build_info 的发行版本名（dev.待定）

- 出 v0.01 整包时 build_info 的 releaseVersion 填了 "0.01"，`xiyou_update_check` 的检查更新页一段按「0.<编号>」核提示文字，页面经 `XUpdateClient.init_versions` 读进发行版本名后显示成 0.01.N，挂一项。
- 测试开头先把 `XUpdateCheck.release_name` 置空、`release_base` 置 1，不让它读 build_info；发行版本名那段原本就自己设、自己还原。只改测试。

## 交接板

- 无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无
