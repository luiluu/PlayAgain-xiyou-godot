# 交付：luiluu/t202

- 车道／工作者：T202（cc 车道，Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·T202·未经审查】D205 拆除 GD 侧整类「避 4」检查，并把类外会撞 Script.reload() 的静态 reload() 改名 reload_table()（dev.待定）

- 删：24 张表（`tianqi_data/*.json` 23 张＋`rift_alien.json`）的 `nice_number_exempt` 键；17 个模块里的 `nice_number_violations()`（含 `XTianqiLine.nice_number_violations(key)`）及只为它服务的 `_scan`／`_scan_nice`（`XTianqiHorsemen._scan`、`XTianqiDrop._scan`、`XTianqiBalance／QiyinDrop／QiyinGear／QiyinDragon._scan_nice`、`XTianqiQiyinGear._num_text`）；27 个专项里的避 4 断言和 3 个 `_nice()` 函数；填表脚本三处写入；Python 测试 `test_own_exempt_respected` 改名 `test_values_with_four_pass_d205`（内容照旧：带 4 的数通过）。
- 改名：23 个模块的静态 `reload()` → `reload_table()`（实测：类外写 `X.reload()` 调到引擎 `Script.reload()`，整脚本重编译、全部静态变量回默认，开关被重置）。XTianqiLedger 留给 T201；XYunshangOrders、XDemonCrown 不在天启篇范围，没动。
- 没动任何数值行。

## 交接板

- 下一步：无
- 用户试玩说明：无（只删检查、改函数名）
- 需要用户决定：无

## 进度账

- 无变化

## 可优化（流程／工具／效率）

- 已做：见上，reload 改名（回退＝改回函数名）。
- 建议：其余仍带「避 4」口径的断言未动（不在本单名单）：`tests/xiyou_tianqi_money.gd:74,80`（标价不含 4）、`xiyou_gojo_trials.gd:94`（data_nice）、`xiyou_tianqi_sect_b.gd:155`（texts_no_four）、`xiyou_tianqi_gear2.gd:96`、`xiyou_rift2_canglong.gd:111`；`tianqi_money.gd` 里「标价避开 4」取整逻辑。T192 改数值后若这些红了，需另判是否一并拆。
- 建议：`XYunshangOrders.reload()`（11 处类外调用）、`XDemonCrown`、`XTianqiLedger`（T201）、`XTianqiMoney`／`XTianqiGojoTrial`（目前无类外调用，潜在同类）建议同样改名；`skill_rework.json` 的 `_note` 和 `天启篇系数取整.py:466` 文字里还写着 `XTianqiSkills.reload()`，改数值行的车道顺手改成 `reload_table()`。

## 验证

- 语法检查：1037 个 .gd 0 问题；`测试天启篇数据校验.py` 62 项 OK；`天启篇数据校验.py` 全部通过。
- Godot：`xiyou_tianqi*`＋`xiyou_rift*` 全部专项（结果见回执）。
