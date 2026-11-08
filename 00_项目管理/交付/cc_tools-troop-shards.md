# 交付：cc/tools-troop-shards

- 车道／工作者：哪吒工具／cc（哪吒）
- 状态：进行中

## 变更记录草稿

（待 GB 合进 main、merge 后做完首次整份验证再写）

## 接续要点（总装 16:07 定：GB 先合，GC 后接）

- 已做（代码，未验证整份）：`troop_event_probe.cjs` 加 `XIYOU_PROBE_SHARD=i/n`（全局用例序号 % n，占位 `{__skip:true}` 最后滤掉）、`XIYOU_TROOP_OUT`；`同步正式西游.py` 加 `TROOP_MERGE_JS`、`run_troop_sharded`（默认 4 段，`TROOP_PROBE_SHARDS=1` 退回单进程，`XIYOU_COVER=1` 自动单进程），`slow` 里把它排在前面；`测试事件探针分段.py` 加 `TroopShardMergeTests`（拼回逐字、段数对不上拒收、探针守卫字样）。
- 审查 66 P3-4 已做：`tests/xiyou_platform.gd` 的 Recorder 记 `ui_page_down／ui_page_up` 事件，三处翻页断言加端到端（新增 `stick_page_reaches_pages`；浅推、设置关掉时页面也收不到）。反向验证过：把期望改成 +3 会挂。
- 整份跑过一次，被总装叫停（GB 同改探针文件，现在的结果合并后作废），未得结果；没有产物留下。
- 接续：等总装通知 GB 已合 main → `git merge main`，解 `troop_event_probe.cjs` 冲突（GB 的用例尾巴、`run()` 的 switches 参数、`processVictory`／`SceneManager._nextScene` 两处补丁都保留；我的改动只有 SHARD 常量块、`run()` 开头一行、`result` 后的 filter 一行、输出路径一行）。注意 switches 参数让 `run()` 签名变长，我的跳过判断在函数最前，不受影响。
- 然后约总装跑首次整份：`TROOP_PROBE_SHARDS=2` 占 2 槽，产物与主工作区单进程产物逐字节比对（`cmp`）；比对用的单进程产物要和合并后的探针同版本（合 GB 后需要先有一份新单进程产物或用 `TROOP_PROBE_SHARDS=1` 跑一次）。验证脚本在 scratchpad：`/private/tmp/claude-501/gc_shardrun.py`（调 `run_troop_sharded`）。

## 交接板

- 下一步：见接续要点。
- 用户试玩说明：无（工具）。
- 需要用户决定：无。

## 进度账

- 无。

## 可优化（流程／工具／效率）

- 已做：见上（`TROOP_PROBE_SHARDS=1` 回退；平台专项断言）。
- 建议：分段拼回目前靠「两个进程各自按序号跑」；若以后用例间出现共享状态（例如 run() 不再每例 setupNewGame），分段结果会与单进程不同——首次整份比对通过是前提，别删。

## 本分支提交

- c972c1b0a WIP: troop_event_probe 分段并行、ui6 翻页端到端断言
