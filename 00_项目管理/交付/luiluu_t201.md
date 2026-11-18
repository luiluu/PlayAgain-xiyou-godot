# 交付：luiluu/t201

- 车道／工作者：T201 总账改名／cc（Sonnet＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-18 【cc·T201·未经审查】总账静态 reload() 改名 reload_table()（dev.待定）

- `XTianqiLedger` 的静态 `reload()` 改名 `reload_table()`：类外写 `XTianqiLedger.reload()` 实际调到 Godot 内建 `Script.reload()`（整个脚本重载、开关全复原），改名后不再撞名。
- 5 个测试文件 7 处调用同步（`xiyou_tianqi_ledger`、`ledger_p3`、`live_sample`、`phase4_modules`、`nine_off`）。`live_sample` 里原有「先改开关再清缓存，开关不被复原」的检查改调 `reload_table()`，注释同步（验收第 2 条）。
- 测试：ledger 82/82、ledger_p3 40/40、live_sample 17/17、phase4_modules 85/85、nine_off 19/19；天启篇数据校验全部通过；语法检查 1037 个 .gd 0 问题。
- 没做（验收第 3、4 条，协调另开 T202 整类拆除）：
  - 第 3 条：`damage_ledger.json` 本来就没有 `nice_number_exempt` 字段（全文无），无可删。
  - 第 4 条范围（我扫到的）：24 张表 JSON 带 `nice_number_exempt`；约 20 个 GDScript 模块的 `nice_number_violations()` 读它；约 25 处测试断言 violations 为空（另有 `xiyou_tianqi_balance.gd`、`xiyou_tianqi_qiyin_gear.gd` 直接读该字段）；`天启篇期四填表生成.py` 3 处写入；`测试天启篇数据校验.py` 有 `test_own_exempt_respected` 等。D205 已删 Python 侧报 4 检查，GD 侧只剩空转。会碰 T192 在改的表，需协调冲突。
- 玩家可见：无。

## 交接板

- 下一步：T202 整类拆除 nice_number_exempt（范围见上）
- 用户试玩说明：无
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：T202 拆除 nice_number_exempt 整类检查（GD 侧空转，每表多一个字段与一个函数；归一条机械车道）。

## 本分支提交

- 7c03b9921 T201 总账静态 reload() 改名 reload_table()，7 处测试调用同步
