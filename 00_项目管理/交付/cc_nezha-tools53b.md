# 交付：cc/nezha-tools53b

- 车道／工作者：D 工具／哪吒（cc，接替 tools53 原会话：原账号额度用完停，由新会话接着做；分支从 `cc/nezha-tools53` 的 8ad17068 切出）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·哪吒·未经审查】探针超强者参照公用开关、选测分叉点提示、flags 整数查找扫描（dev.待定）

- **探针超强者参照公用开关**（890ffb7f）：`03_转换工具/mv_oracle/shared/host.cjs` 加 `superReference(w)`：去掉 `route-suppress`、`zones-correction` 两个伤害钩子，关路线压制三处（`otherScale`、`isSuper`、`support` 恒为不压制），返回 `enableSuperSwitch()`（开 2494；`newGame` 会重置开关，每次新局后自己调）。`tusu_battle`、`binding`、`heartsteel` 三个探针改用它，各少约 10 行手写。`xuan_*` 探针悟空 xuan 期在改，本期没动，留给下期迁。
- **选测分叉点提示**（890ffb7f）：`选测.py` 新增 `stale_notice`：工作树分叉点比基准旧、且分叉之后基准改过 `.gd` 时，报告开头打一行「先 git merge main 再选测」，`select()` 返回里多一个 `notice` 字段；只改文档或基准是祖先时不提示。`测试选测.py` 加 `test_stale_lane_gets_merge_main_notice_only_when_main_moved_gd`。
- **flags 整数查找扫描**（8ad17068 起头，本期做完）：`07_开发环境/扫描_flags整数查找.py`，只读静态粗筛 `modes/` 下的 .gd：从 `s.flags`（存档走 JSON 读回，数组里整数变浮点、字典整数键变字符串）取出的数组／字典，被整数当参数 `find`／`has`／`count`／`erase`／`in` 的可疑处。本期改动：①来源函数按不动点算（`return` 含 flags、含来源变量、或调用来源函数，`chart(s)` 套 `chart(s)` 也算）；②接收者表达式往回取整段（`(c.roster as Array).slice(0, n)`、`.has(` 前是括号的写法）；③「已归一」不再把 `int(...)` 算进去（数组里存的是浮点，`has(int(x))` 照样找不到，这正是审查 34 P2-2 的写法），只认字符串字面量、`str(`／`float(`、`%`、`.hash()`。新增 `测试扫描_flags整数查找.py`（3 例）。不改游戏代码。
- **O-150 作者改正**（审查 34 P3-3）：`00_设计/优化登记.md` O-150 执行者由「cc（悟空）」改「cc（八戒）」（37395338 八戒加的）。O-149 仍是悟空。

## 扫描结果（对当前 main 工程，14 处，逐条人工核过）

反例验证：审查 34 P2-2（`core/xuan_battle.gd:151` `_is_roster`）被抓到，修之前如果跑扫描就能提前发现。

**真问题 1 处**
- `core/xuan_battle.gd:151` `_is_roster`：`(c.roster as Array).slice(0, stage).has(int(t.actor_id))`，读档后名册是 `[8.0]`，找不到。= 审查 34 P2-2，已派 xuan4（悟空）修，不重复派。

**已核、安全（扫描粗筛会报，列在这里省得下次再核）**
- `core/xuan_chart.gd:120` `toggle_roster`：上一行已 `roster.map(int)` 归整，安全（xuan-fix1 修的）。
- `core/item_marks.gd:23、27、40、44`：`_ids()` 读出来就 `map(int)`，安全。
- `core/xglobal_vars.gd:68、77`：`switch_ids()`／`variable_ids()` 来自数据库插件参数并 `map(int)`，不是存档 flags，安全。
- `core/tusu.gd:441、1022、1046`、`ui/tusu_forge.gd:48`：开刃名册 `kairen` 里是武器名字符串，JSON 往返不变，安全。
- `core/demon_crown.gd:266`：`_known` 里是 uid 字符串，安全。
- `core/yunshang_orders.gd:419`：`s.flags.erase(ORIGIN_FLAG)`，键是字符串常量，安全。

结论：没有要新派的修复；扫描能抓 P2-2，以后加进选测前可以跑一遍（约 1 秒）。

## 交接板

- 下一步：无（P2-2 在 xuan4 里）。
- 用户试玩说明：无（只改工具）。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 建议：把 `扫描_flags整数查找.py` 的「真问题」当作回归——总装合并涉及 `flags` 读取的车道时跑一次，新增命中先核再放行（几秒；归总装）。扫描存量里 13 处误报，需要时可加豁免清单，本期没做。
- 建议：`测试扫描_flags整数查找.py` 未登记进 `检查.sh`，登记时一并加（归总装，改 `检查.sh` 是共用文件）。
- 留给下期：`xuan_*` 探针迁到 `superReference`。

## 验证

- `语法检查.py`：511 个 .gd，0 问题。`探针登记检查.py` 通过。
- `测试选测.py`：92/92（含新加的分叉点提示用例）。`测试探针登记检查.py` 7 例通过。`测试扫描_flags整数查找.py` 3 例通过。
- 三个探针重跑比对：先在 890ffb7f 版本跑，再把四个文件（三个探针＋`shared/host.cjs`）临时换回 b5f3a0ce 的旧版跑，产物 `tusu_battle.json`（13 例）、`binding.json`（8 例）、`heartsteel.json`（49 例）三份新旧逐字相同，且与 `tests/fixtures/*_oracle.json` 夹具逐字相同（旧版文件已还原）。
- 没跑 Godot 测试（main 的 dev.296 收尾还没出现时按派单不跑；本期只改工具和一行文档，也不碰游戏代码），没跑全量。

## 本分支提交

- 890ffb7f 探针超强者参照公用开关、选测分叉点提示（原会话）
- 8ad17068 WIP：flags 整数查找扫描（总装十八代存）
- 本期：扫描做完＋测试＋O-150 改正＋本交付单
