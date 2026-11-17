# 交付：luiluu/cc-t132-select-map2

- 车道／工作者：T132 选测对照二（cc，Sonnet＋medium，丙档机械活）
- 状态：可合并

## 变更记录草稿

## 2026-11-17 【cc·未经审查】T132 选测对照：没人读的 modes/xiyou/*.json 不再判成整轮（dev.待定）

- 起因：T131 交付单「可优化」：`mode_data` 组对找不到引用测试的 `modes/xiyou/*.json` 仍 fallback FULL（整轮 658 场景）。
- `选测对照.json` 的 `mode_data` 组 fallback 由 `FULL` 改成数据校验场景 `xiyou_json_cache`、`xiyou_text_batch23`、`xiyou_tianqi_balance`（refs＋loaders 照旧先找引用它的测试，找不到才用这三个）。不另开小组：现有六张表都有测试或加载者可引用，唯一会落到 fallback 的是将来新加没人读的表，改 fallback 即覆盖。
- 实测选中场景数（含事件对照 4 段）：recipes.json 7、zh_collation.json 7、guide_atlas.json 6、rift_alien.json 5；新加未登记的孤表 7；均不整轮。
- 防漏：`测试选测.py` 加两条：孤表／有引用表／新加未登记表都不整轮；真实对照表下 modes/xiyou/*.json 每张都归 mode_data、fallback 不含 FULL 且场景都存在（有人改回 FULL 或场景改名会红）。
- 玩家可见：无。

## 交接板

- 下一步：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 git log

## 合前复查（动态加载 json）

- rg 查 modes/xiyou 下 DirAccess／list_dir／get_files／拼 .json：没有目录扫描 modes/xiyou 手写数据的代码（DirAccess 都是存档与 generated/db 相关）；拼名加载只有 `tianqi_line.gd`（key＋"_line.json"，5 张）和 `text_fix.gd` 常量路径。
- `*_line.json` 五张：测试按文件名引用，实测各选中 phase4／death／famine／plague／war 专项，没问题。
- 漏的一张：`text_fix/overrides.json`（没有测试提它）原会只剩 3 个校验场景、漏 xiyou_text_fix。已新增 `text_fix` 组（xiyou_text_fix＋事件对照）和规则 `modes/xiyou/text_fix/*`，并加测试 `test_real_dynamic_loaded_json_reach_their_scenes`。
