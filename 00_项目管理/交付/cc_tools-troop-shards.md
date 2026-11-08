# 交付：cc/tools-troop-shards

- 车道／工作者：哪吒工具／cc（哪吒）
- 状态：可合并

## 变更记录草稿

troop_event_probe 分段并行（XIYOU_PROBE_SHARD=i/n，同步默认 4 段，`TROOP_PROBE_SHARDS=1` 退回单进程）、`XIYOU_PROBE_FROM` 只跑尾部新例；ui6 摇杆翻页专项补断言翻页结果。

## 验证
- 已 merge main（d7f2953a，无冲突）。首次整份：2 段 1047 秒、单进程 893 秒；两份 troop_events.json 与 main 现有基线 SHA-256 三者完全相同（6484007…4abfb）。processVictory 补丁不调 endBattle 的残留（审查 69 P3③）在这份结果里没造成分段差异；残留本身没处理，留作乙档观察。
- 语法检查 0 问题，工具回归 59 秒全过。

## 接续要点（11-08 收工，额度到线）

- 已做：`troop_event_probe.cjs` 加 `XIYOU_PROBE_SHARD=i/n`（全局用例序号 % n，占位 `{__skip:true}` 最后滤掉）、`XIYOU_TROOP_OUT`、`XIYOU_PROBE_FROM=k`（开发用，只跑序号 ≥k 的尾部新例，必须同时给 `XIYOU_TROOP_OUT`）；`同步正式西游.py` 加 `TROOP_MERGE_JS`、`run_troop_sharded`（默认 4 段，`TROOP_PROBE_SHARDS=1` 退回单进程，`XIYOU_COVER=1` 自动单进程）并把它排进 `slow` 前面；`测试事件探针分段.py` 加 `TroopShardMergeTests`（3 例，过）。
- 已 `git merge cc/rules-gaps6`，冲突解完（GB 的用例尾巴、`switches` 参数、`processVictory`／`SceneManager._nextScene` 补丁都在；`node --check` 过）。
- 审查 66 P3-4 已做：`tests/xiyou_platform.gd` 的 Recorder 记 `ui_page_down／ui_page_up`，新增 `stick_page_reaches_pages` 等端到端断言；反向验证会挂，专项通过。
- （已完成，见上「验证」）原：没做完首次整份验证。第一次（合并前）被总装叫停；第二次（合并后，2 段再单进程对比）开跑约几分钟，收工时停掉，无结果、无产物。所以**分段拼回与单进程逐字相同这一点还没在真探针上验证**，只有拼回脚本的单元测试。不能合并，状态保持「进行中」。
- 接续：新会话在此分支 `新建工作树.sh --补齐`（或沿用工作树 tools-troop-shards），约总装槽后跑 `/private/tmp/claude-501/gc_shardrun2.py`（若 /private/tmp 已清，写法：对同一 box 先后用 `TROOP_PROBE_SHARDS=2` 与 `1` 调 `同步正式西游.run_troop_sharded`，各自把 `.sandbox/troop_events.json` 另存后比 SHA）。两份相同才可标可合并；不同则查哪个用例受全局状态影响。首跑想少占槽用 2 段；单进程那份约 45 分钟占 1 槽。通过后再写变更记录草稿、跑工具回归，标可合并。

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
- 579e682f3 合并 cc/rules-gaps6、加 XIYOU_PROBE_FROM；之后的 WIP 提交为守卫测试与本交付单
