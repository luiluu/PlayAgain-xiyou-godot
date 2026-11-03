# 交付：cc/nezha-tools54

- 车道／工作者：D 工具／哪吒（cc）。分支从 `cc/nezha-tools53b` 的 f7da71dc 接着切出，所以带着 tools53b 的提交；合并时 tools53b 先合
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·哪吒·未经审查】选测按钩子行收窄核心文件的影响面（O-153，dev.待定）

- 起因：dev.294～296 一批选了 337／383 个场景，约等于全量。车道常在 `battle_logic.gd`、`actor.gd`、`xstate.gd`、`resource_context.gd` 里只加「调用角色专属模块」的钩子（如 `XXuanBattle.take_logs()`），选测按文件判，碰一行就几乎全选。
- 做法：`选测对照.json` 新增 `hookLines`（默认开）和 `battle_hooks` 组；`选测.py` 新增 `hook_modules`。`hookLines.files` 里的核心文件，每个改动块（`git diff -U0` 的 hunk）至少有一行引用非核心设施的 X 模块（`excludeModules` 排除 XDB、XState、XActor 等），其余行只能是注释、空行或胶水（`return`／`return false`／`else:`／`if not x.is_empty():`），就改归 `battle_hooks`：冒烟场景（determinism、battle 系列、combat、rules 抽样、存档类、事件对照）＋引用了这些模块名的测试。有一块认不出（含真逻辑行、或块里没有模块调用）就退回原组，行为和以前一样。合并工具、`沿用车道.py`、`检查.sh` 都走 `select()`，同一入口，不用另改。
- 回退：`hookLines.enabled` 设 false，或环境变量 `XIYOU_HOOKS=0`；优化登记 O-153（编号是我先占的，总装若另有预分配请改号）。
- 测试：`测试选测.py` 新增 `HookLineTests`（6 例：只加钩子收窄、胶水行、真逻辑混入退回、无钩子块退回、核心设施不算钩子、开关关掉）和 `HookHistoryTests`（真实合并回归，浅克隆自动跳过），共 99 例全过。

## 量化（最近合并的核心文件 diff）

对 `git log --merges` 最近合并逐个看核心文件（battler／damage／state_effects／actor／enemy／battle_logic／xstate／resource_context）的改动行：

| 合并 | 核心文件改动 | 结论 |
|---|---|---|
| b5f3a0ce xuan3 | actor 2 行、battle_logic 7 行、xstate 1 行、resource_context 2 行 | 全是钩子调用＋胶水（`return xuan_cmd`、`return {}`） |
| c7b7f237 growth5 | battle_logic 2 行 | 钩子 |
| effc9fa4 xuan2 | battle_logic 6 行、resource_context 2 行 | 钩子＋`return false` 胶水 |
| 296a571a honghuang2 | state_effects 20 行（`_revive` 整个函数）、battle_logic 3 行、xstate 8 行（`for rec in XDB.table`） | 真改逻辑，仍全选 |
| 2c2f2612、7e7b1c71、28b3b2e9、54ba6b1f、a70c62bc、44371eb1 | 核心文件没改 | 不受影响 |

最近 10 次合并里，4 次碰了核心文件，其中 3 次纯钩子、1 次真改逻辑。

## 预计省多少（选测实际口径，含 rules 抽样；总共 383 个场景）

| 合并 | 旧选法 | 新选法 |
|---|---|---|
| b5f3a0ce xuan3 | 313 | 138 |
| c7b7f237 growth5 | 134 | 47 |
| effc9fa4 xuan2 | 131 | 27 |
| 296a571a honghuang2 | 301 | 301（真改逻辑，不变） |
| 其余 6 次 | 0～46 | 不变 |

按纯钩子合并平均省约 65%（b5f3a0ce 剩下的 138 个主要是同一批里别的文件 xuan3 自己的模块引用面）。每个场景一批约 10 秒量级（一批 313 个约一个多小时），预计每遇到一次纯钩子合并省 30～50 分钟。

## 验证

- 新选法漏选检查：翻变更记录没找到「某次合并收尾真挂过哪个场景」的明确记录，所以用各车道交付单里自己跑的专项当代用：xuan3 的 xuan_battle／xuan_chart／xuan_bind／binding、growth5 的 heartsteel／growth_forge／growth_help、xuan2 的 xuan_battle／xuan_chart，在新选法里全部被选上（`HookHistoryTests` 断言）；新选法比旧选法多出的只有冒烟场景。**这条是代用的，不是真失败记录**，请总装知悉。
- 已知盲区：钩子行只在专属模块起作用，但如果模块 A 的钩子经 B 间接影响了只引用 B 的测试，新选法不会选它（只按直接引用）；有冒烟场景兜底，真碰到再补 `battle_hooks.scenes`。
- `测试选测.py` 99/99；`语法检查.py` 见下；没跑 Godot 测试、没跑全量（只改工具与登记）。

## 交接板

- 下一步：无。
- 用户试玩说明：无（只改工具）。
- 需要用户决定：O-153 登记为「待用户确认」，同其它工具类优化。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 已做：钩子行收窄（见上，回退见上）。
- 建议：合并后几批若发现冒烟场景不够，往 `选测对照.json` 的 `battle_hooks.scenes` 加；`excludeModules` 里漏列的核心设施类名（出现在钩子行里被当成专属模块）也在这里补（归总装／哪吒）。

## 本分支提交

- 见 git log（含 tools53b 的 890ffb7f、8ad17068、f7da71dc）
