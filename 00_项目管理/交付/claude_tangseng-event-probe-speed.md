# 交付：claude/tangseng-event-probe-speed

- 车道／工作者：工具·探针提速／唐僧（Claude，项目线程「完成再刷重制」本机总装）
- 状态：可合并（截至本交付单提交；已合 main 9460efc5 之后的 03dd4b4d）

## 接续要点（本机额度用完前 WIP 推送）

用户 2026-10-25 采纳 event_probe 提速三条：
1. **开局快照**（event_probe.cjs `NEW_GAME_SNAPSHOT`）：只第一例真 setupNewGame，存下 $gameSystem…$gamePlayer 与 YEP 独立装备实例（JsonEx），之后每例 createGameObjects 后换回副本、loadIndependentItems。不走 extractSaveContents（插件钩子与开局一样慢）。回退：常量改 false。
   - 首版（未恢复独立装备）全量 4318 例 12.5 分钟（原约 100 分钟，本机负载 16～18），只 m4e73p0 不同（战力短板：装备 0%，因装备实例没恢复）。已补独立装备恢复；**补后的全量对照还没跑完**，接手先跑：
     `XIYOU_GENERATED=<main generated> XIYOU_EVENT_OUT=<沙盒内路径> node event_probe.cjs`，与 generated/oracle/events.json `cmp` 应逐字相同。
2. **空成长记录**（同步正式西游.py `EVENT_LEDGERS`）：event_probe 的存档目录不复制 crown_progress_v1.json／yunshang_orders_v1.json（种子里已累积 48439 个档案、7 MB／4 MB）。117 例实测输出相同。
3. **按地图分段并行**（同步正式西游.py `run_event_sharded`，`EVENT_PROBE_SHARDS` 默认 4，=1 退回）：按用例数把单元切成连续段，各段一个进程占 1 槽、独立存档目录，`XIYOU_EVENT_OUT` 写各自文件，再按原顺序拼回。**小样本自测还在等槽，未验证**；接手要跑一次 `--full` 同步或单独调用核对拼回结果与单进程逐字相同。
- incremental_sync.py 的 event_probe 读取面审核值改为 `reads:b8ffbf2d6b5a3c38`（只多了 XIYOU_EVENT_OUT 写路径），待 Codex 核。
- 还没跑 检查.sh，没写测试（建议给 split_contiguous／拼回补单测）。

### 进展（2026-10-25 傍晚，按用户要求暂停前）

- 开局快照补独立装备后全量 4318 例与 main 的 generated/oracle/events.json **逐字相同**，单进程 11 分钟（本机负载高时）。
- 分段改为按用例数均分（split_balanced，m187 独占一段），拼回按单元原顺序稳定排序；全量四段 **逐字相同**，墙钟 203 秒（m187 一段 198 秒是下限）。
- 新增 07_开发环境/测试事件探针分段.py 并接入检查.sh；测试增量同步、测试角色同步提速通过。
- 未完成：`检查.sh --affected main` 里「测试选测.py」两例失败（test_default_runs_everything、test_unknown_change_is_full，夹具里整轮检查 rc=1），还没查是否本分支引起（可能是新加的检查行在夹具里跑不了）；查清后跑收工检查、写变更记录草稿、标可合并。

## 变更记录草稿

## 2026-10-26 【Claude·唐僧·未经Codex检验】event_probe 提速：开局快照、空成长记录、按地图分段并行（dev.待定）

- **开局快照**（`event_probe.cjs` `NEW_GAME_SNAPSHOT`）：只第一例真跑 setupNewGame，存下开局对象与 YEP 独立装备实例，之后每例换回副本并恢复独立装备；回退 `NEW_GAME_SNAPSHOT=false`。
- **空成长记录**（`同步正式西游.py` `EVENT_LEDGERS`）：事件探针的存档目录不再复制种子里累积的 crown_progress／yunshang_orders（共约 11 MB）。
- **按地图分段并行**（`run_event_sharded`，`EVENT_PROBE_SHARDS` 默认 4，=1 回退）：按用例数均分成连续段，各段一个进程占 1 槽、独立存档目录、各写各的输出，按单元原顺序拼回。`incremental_sync.py` 读取面审核值改为 `reads:b8ffbf2d6b5a3c38`（只多了 XIYOU_EVENT_OUT 写路径）。
- 验证：全量 4318 例与 main 的 `generated/oracle/events.json` 逐字相同；单进程约 11 分钟，四段并行墙钟 203 秒（原整轮约 100 分钟）。新增 `07_开发环境/测试事件探针分段.py` 接进 检查.sh；`检查.sh --affected main` 选测全部通过（10-25 23:20）。
- 只改工具与测试，不改游戏代码。

## 交接板

- 下一步：合并后各车道整轮同步的事件探针约 3～4 分钟；smart_ai_probe 可能有同类每例开局开销，值得剖析（见可优化）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 已做：见上（回退：NEW_GAME_SNAPSHOT=false、EVENT_PROBE_SHARDS=1）
- 建议：smart_ai_probe 可能也有每例新开局的同类开销，值得同样剖析

## 本分支提交

- 见 git log
