# 交付：cc/nezha-tools47

- 车道／工作者：D 工具／哪吒（cc）
- 状态：可合并
- 基于 `cc/nezha-tools46`（已在 main）

## 变更记录草稿

## 2026-11-03 【cc·哪吒·未经审查】事件普查认「再次释放」原生模式、slice_probe 可只量指定角色（dev.待定）

- 事件普查（`tests/xiyou_script_census.gd`、`fixtures/script_census_known.json`）：E 类 62 种里，凡写法含 `new Game_Action(actor, true)` 与 `BattleManager.forceAction(actor)` 的「再次释放」脚本，普查在地图解释器认不出之后再交给战斗事件解释器 `XBattleEventRunner`（`_recast_script`，参照 `xiyou_battle_common_events` 的 `recast_*` 与 `battle_common_event_oracle.json`）跑一遍，认得就算原生处理、不进 unknown，也从已知清单里删掉。清单 182→143（删 39）。比总装估的 36 多 3 种：CE1327／881／884 的 `by_var`／`_targetActorId` 变体，同走 `_recast_script`、同有 `recast_target_*` 测试。核实：`CENSUS_BATTLE` 逐条 62 种里 59 种战斗解释器认得，其中 39 种是再次释放；剩下的 CodexFreezeFollowup 变体（`CodexFreezeFollowup.takeCaster()` 战斗里认不出）**不是**原生模式，留在清单。其余 20 种战斗里认得的（加状态 10、变量操作 9、敌人暴闪 1）本期不动，仍在清单（它们有各自的原生函数，但不在本任务范围）。新加断言 `native_recast_seen`（≥30），防普查口径悄悄失效；若 `_recast_script` 对不上某变体，它会重新出现在 unknown 里被 `no_new_unknown` 抓到。`xiyou_script_census` 4/4 过。
- `slice_probe.cjs`：认 `XIYOU_PROBE_ACTORS=角色号,…`（只量这些角色；切片外的号直接报错）。因为产物是残缺的，没给 `XIYOU_SLICE_OUT` 时改写 `.sandbox/slice_actors/`，不覆盖同步用的整份。顺手把「六个难度全算完才写文件」改成每个难度量完就写（默认输出内容不变）。六难度可各开一个进程并行。实测 `XIYOU_PROBE_ACTORS=1 node slice_probe.cjs 3`（配 `XIYOU_PROBE_UNITS='[]'` 跳过敌群）约 6 秒出文件。`车道须知.md`「扩角色车道」那句与 `03_转换工具/README.md` 改写了用法。
- 第 3 项（选测窄口径，八戒 growth1 提的）只写方案，没实现：
  - 现状：`选测对照.json` 把 `core/actor.gd`、`battle/battle_logic.gd` 都归 `battle` 组（整轮 235 个场景左右）。
  - 方案（待总装／审查定）：在 `选测.py` 加一类「窄改动」判定——对 `battle_logic.gd`／`actor.gd`／`enemy.gd` 取 `git diff -U0`，若**所有**新增行都是形如 `XFoo.hook(...)` 的单行调用（`XFoo` 是本次同时新增、且没被别的文件引用的新文件里的类），并且删除行为 0，则把它们降到一个窄组：只选新模块自己的测试＋`xiyou_determinism`＋`xiyou_rules` 抽样；任何别的形状（有删除、有分支、有赋值、新模块已被旧文件引用）一律退回整轮。保守原则：判不准就整轮，宁可漏省不能漏测。风险：挂钩函数里的副作用能改战斗结果，所以窄组必须带 `xiyou_determinism`，且新模块的测试由其作者提供，不能为空。要实现的话需要在 `测试选测.py` 加正反例（含「新增行里夹一个 if」「同时删了一行」「新模块已被引用」）。建议先观察一两期再做。
- 回退：revert 本分支；`slice_probe` 不设环境变量时行为同前。

优化登记草稿：无

## 交接板

- 下一步：第 3 项方案等总装定要不要做。
- 用户试玩说明：无。
- 需要用户决定：无。

## 进度账

- 无变化（工具、测试）。

## 验证

- `xiyou_script_census` 4/4（`--jobs 2`）；`slice_probe` 单角色单难度实跑与错误角色号报错；`语法检查.py`。
- 没改游戏逻辑与切片，没跑全量。

## 本分支提交

见 `git log cc/nezha-tools46..cc/nezha-tools47`。
