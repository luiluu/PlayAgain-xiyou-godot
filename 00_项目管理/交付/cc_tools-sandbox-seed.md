# 交付：cc/tools-sandbox-seed

- 车道／工作者：哪吒工具／cc（哪吒）
- 状态：可合并

## 变更记录草稿

## 2026-11-08 【cc·哪吒·未经审查】新树补跑事件状态探针不再退成整份重量（dev.待定）

- 起因：floor9 新树第一轮补跑因没带上次的结果与摘要，退成整份重量约 40 分钟；interp5／interp6／seg-a3 又三次因车道改了探针，`--补齐` 收尾自动补跑整份。
- ① `新建工作树.sh` 在补跑前把主工作区 `.sandbox/event_states.json`、`event_states.keys.json` APFS 克隆进新树（已有的不覆盖；账认得才用，旧结果不会冒充新的）。没放进 `incremental_sync.carry_cache`：该文件在 TOOLING 里，改它会让所有分片探针（slice／smart_ai／event）下次同步整体重跑。
- ② `补跑事件状态探针.py`：`event_state_probe.cjs` 或 `event_state_shards.py` 相对 main 有差异时，只打印「整份重量约数小时、先约总装」并跳过（退出 0，不算失败）；带 `--confirm-full`（或 `XIYOU_CONFIRM_FULL=1`）才跑。`XIYOU_PROBE_CHANGE_GUARD=0` 回到旧行为。`--补齐` 与 `检查.sh` 的自动调用因此不再误触整份重量。
- 测试：`测试事件探针分段.py` 加脚本顺序用例（carry→克隆→补跑，不覆盖已有）；`测试事件探针分段.py` 加守卫用例（5 种组合）；工具回归全过，语法检查过。

## 交接板

- 下一步：第二期（troop_event_probe 按敌群分片）等总装对计划拍板，见下「第二期计划」。
- 用户试玩说明：无（工具）。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 已做：见上 ①②，回退开关 `XIYOU_PROBE_CHANGE_GUARD=0`；多克隆的两个文件走 APFS 克隆，不占空间；删掉 `新建工作树.sh` 里那个 for 循环即回退。
- 建议：第二期，见下。

## 第二期计划（先报，未动手）

- 现状：`troop_event_probe.cjs` 的用例由文件里写死的 TROOPS 等常量生成（约 900 例，一次进程里顺序跑），不在 `SHARDS` 里，同步时每次整份跑约 45 分钟；`SHARDS` 的 `troops` 种类以切片的 `troops` 为单元，对不上这里的用例清单。
- 做法：① `SHARDS` 加 `'troop_event_probe.cjs': {'kind': 'troopcases'}`，单元＝用例的敌群号（同一敌群的 variant／已交礼／血线例同一单元）；② 探针加 `XIYOU_PROBE_UNITS`（同 smart_ai_probe）只跑指定敌群的用例，结果由 `oracle_shard_merge.cjs` 按原用例顺序拼回；③ 按敌群号轮转分 N 段并行（同事件状态探针的 `XIYOU_STATE_SHARDS`），单进程退回开关；④ 用例顺序与单进程逐字相同由测试保证。
- 难点：用例里 `Math.random` 序列、变量／开关是否每例重置要核（每例从新局起跑则可拆；`rules-gaps5` 提过默认堆 OOM，分段反而缓解）；`XIYOU_COVER=1` 的 coverByCase 下标要跟着重排。
- 代价：改探针本身，首次同步整份跑一次（约 45 分钟，请总装安排在夜里）；`反向验证` 与 `读取面审计` 需要重算。
- 收益：同步长杆从约 45 分钟降到约 12～15 分钟（4 段）或改动敌群时几分钟（增量）。

## 本分支提交

- 5546a2939 WIP（含已撤回的 carry_cache 改动）；本次提交把 ① 改放到 新建工作树.sh
