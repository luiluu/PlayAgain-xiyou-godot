# 交付：cc/nezha-tools72

- 车道／工作者：工具／BO（cc，哪吒）
- 状态：可合并

## 变更记录草稿

## 2026-11-06 【cc·BO·未经审查】事件状态探针分段并行补跑；空绿清单去掉 m4e46p0（dev.待定）

- **补跑提速**：`event_state_probe.cjs` 加 `XIYOU_PROBE_SHARD=i/n`（按变体序号轮转，序号 % n == i）；`补跑事件状态探针.py` 默认起 4 个 node 进程（`XIYOU_STATE_SHARDS=1` 退回单进程），各占 1 个共用槽（`占槽.py`）、各用自己的存档目录（`.sandbox/run/state-shard-i`，开跑复制 save／macport，跑完删），按序号交错拼回 `event_states.json`。v0.28 上本机实测：单进程 6 分 08 秒 → 分段 3 分 53 秒（机器上另有别的车道在跑），**两份文件逐字节相同**（`cmp`）。数字和派单里的「14 分钟」差别大是因为当时机器更忙；新源上变体多、单进程慢，分段收益更大，没在新源上测。
- 新增 `测试事件探针分段.py` 的 `StateShardMergeTests`（轮转拼回逐字相同、段被截断时报错）。
- **同步没改**：`同步正式西游.py` 里的 `event_state_probe.cjs` 仍是单进程（它在同步里与别的探针并行，不是长杆）；要提速同步可参照 `run_event_sharded` 接同一个 `XIYOU_PROBE_SHARD`。
- **空绿**：`m4e46p0` 从 `事件空绿走不到.json` 删掉。确认：预设 `m4e46p0#s1`（`answers: [20250826]`）已量到，`finished`、`reached [2,2]`；`事件空绿扫描.py --check` 也提示它已不再空绿。基线用 `--update-baseline` 重写（挡住 56→55 例）。
- **未做（派单 2，「能做就带上」）**：`smart_ai_probe` 新局开销缓存。`installUniqueEffectMarkRuntime`／`installAbyssMerchantRuntime` 是正式源插件里的函数（v0.62.12 才有，v0.28 里没有），要在探针侧给它们加记忆化包装，必须在新源上量慢点、再逐字节对比，而 main 还没换源；留给 BM 换源后再做。

## 交接板

- 下一步：smart_ai 新局缓存（等换源后量）。
- 用户试玩说明：无（工具改动）。
- 需要用户决定：无。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：`同步正式西游.py` 的 event_state_probe 也接分段（只在同步成为长杆时做）；smart_ai 缓存见上（换源后，归工具车道）。

## 待交叉核查

- `mv_oracle/event_state_probe.cjs`（分段过滤）、`补跑事件状态探针.py`（并行与拼回）。未改战斗核心文件。

## 验证

- v0.28 分段与单进程 `event_states.json` 逐字节相同；`测试事件探针分段.py` 5 项；`事件空绿扫描.py --check` 通过；工具回归见提交。

## 本分支提交

- 见 git log
