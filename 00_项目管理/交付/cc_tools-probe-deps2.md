# 交付：cc/tools-probe-deps2

- 车道／工作者：C 工具／哪吒（cc，tools-probe-deps 续：troop 探针与事件状态探针不再整份重跑）
- 状态：可合并

## 变更记录草稿

## 2026-11-10 【cc·哪吒·未经审查】troop 探针按用例增量、事件状态探针代码改动影响面声明、每日审计、运行时读文件核对（dev.待定）

- troop 探针（阶段①）：用例清单拆到 `mv_oracle/troop_event_cases.cjs`（只许列用例），探针本体 `troop_event_probe.cjs` 留 `run()` 的逻辑。每例按「描述」（`run()` 全部参数、换队伍／事件随机上下文、`variant` 等标签）算键；缓存键没命中进探针后，公共指纹（缓存键去掉用例清单文件）相同就把「已发布的 troop_events.json＋键表」交进来，只跑新增或描述变了的用例，其余取回；取回的每 100 个抽 1 个重跑比对，不同整份重跑并打 `TROOP_INCREMENTAL_MISMATCH`。键账 `.sandbox/troop_event_keys.json`（`KeyHistory` 版本 1）随 `--补齐` 带进车道，`--from-worktree` 克隆车道产物时把车道的 troop 键账和事件状态摘要账并进 main。回退 `XIYOU_TROOP_INCREMENTAL=0`。实测：整份 2770 秒（46 分钟），加 3 例的增量 38 秒（取回 1414、抽查 15、新跑 3），两种结果与 main 已发布的 `troop_events.json` 逐字节相同。
- 事件状态探针（阶段②）：变体指纹里「本文件那一份」可按 `03_转换工具/probe_change_scope.json` 的影响面声明折算（只影响预设带某些键路径的变体，别的变体取回，不再因探针改一行 90 分钟整份重跑）。本次改动自己的声明已写（`presetKeys` 空：只动指纹计算，不动 applyPreset／runCase）；实测对 main 已发布的结果与键表，有声明时 10 个变体全部取回、去掉声明 0 个。
- 每日审计（阶段③）：两个探针的键账记 `auditedAt`；超过 24 小时（`XIYOU_TROOP_AUDIT_HOURS`／`XIYOU_STATE_AUDIT_HOURS`，0＝不审计）这一轮整份重跑并把「键相同的用例／变体」逐个与上次比对，不同就失败（`TROOP_AUDIT_FAIL`／`STATE_AUDIT_FAIL`，退出码 3＝指纹漏依赖）。事件状态账上旧条目没有 `auditedAt` 的从第一次见到起算，不为推出功能白跑一轮。
- 指纹漏依赖要失败：`probe_dep_recorder.cjs` 多记「03_转换工具里 mv_oracle 之外的读」，`ProbeCache.unregistered_reads` 报出没进键的文件，同步日志打 `PROBE_READ_UNREGISTERED`、报告 `readGaps`；`XIYOU_PROBE_STRICT_READS=1` 直接失败（默认只报不拦，因为没法在不跑全部 96 个探针的情况下保证零误报）。
- 周边：`Boss战清单.py` 改读 `troop_event_cases.cjs`；`选测对照.json` 新文件归 `troop_probe`；`探针登记检查` 登记新环境变量与动态读取；`KeyHistory` 加版本参数；`测试事件探针分段.py` 分段进度心跳断言改成事件驱动（协调员交办，单独提交 be6b05864）。
- 说明：`07_开发环境/长任务与增量同步.md` 加两节。
- 验证：`测试增量同步.py` 93 例、`测试合并工具.py` 338 例、`测试事件探针分段.py`（含 `TroopCaseIncrementalTests`、`StateScopeTests`）、`测试角色同步提速.py` 27 例、`测试选测.py`、`工具回归.py`、`语法检查.py`、`探针登记检查.py` 通过；真跑：troop 整份＋增量（见上）、状态探针对真实键表。没跑真实整轮同步。

## 交接板

- 下一步：合并后第一轮同步看日志「troop 探针：…」「事件状态探针：…」两行；troop 账上没有已发布文件的记录，第一次是整份（约 46 分钟），之后增量。**第一次同步前，troop 键账是空的**：可在合并后用 `--from-worktree` 克隆本车道产物（本车道没有自己的同步产物），或接受一次整份。
- 用户试玩说明：无（工具）。
- 需要用户决定：无。

## 可优化（流程／工具／效率）

- 建议：把每日审计放到夜里单独跑（`XIYOU_TROOP_AUDIT_HOURS=0.001 XIYOU_STATE_AUDIT_HOURS=0.001` 加 `--full-probes` 之外的强制），避免白天某次合并撞上 46～90 分钟的审计；目前默认是谁先赶上谁付。
- 建议：事件状态声明的验证工具（跑新旧两版探针比未声明变体），现在靠抽查加每日审计兜底。

## 待交叉核查

- 甲档：`probe_change_scope.json`（声明内容）；`event_state_probe.cjs` 的 `scopedSelf`／`coreFor`（新键公式对无声明时与旧公式逐字相同，已用 main 键表实测）；`troop_event_probe.cjs` 的规划／取回／审计段。
- 丙档：`troop_event_cases.cjs`（纯搬移，整份结果逐字节相同）、`同步正式西游.py` 的 `run_troop_sharded`／克隆并账、`probe_dep_recorder.cjs`。

## 本分支提交

- 972ffb6c6、be6b05864、58a47ec32 及收尾提交
