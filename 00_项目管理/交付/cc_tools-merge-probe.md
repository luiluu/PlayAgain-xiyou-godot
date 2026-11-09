# 交付：cc/tools-merge-probe

- 车道／工作者：工具（cc·哪吒，派单第十六批追加十四 GC5）
- 状态：可合并
- 基于：github/main 00fa4857（已含 seg-a3 合并）。

## 做了什么

### ② 主工作区同步为什么没复用车道的事件状态探针结果（seg-a3 合并两次各 90 分钟）

- 原因一：车道的同步指纹 `generated/sync_stamp.json` 还停在 11-08 04:11，车道之后只用 `补跑事件状态探针.py` 更新了 `event_states.json`，没再跑同步。`--from-worktree` 每次都拒成「车道同步后又改了转换工具文件」，退回完整同步（merge8／merge11 日志第 16 行）。
- 原因二：完整同步里事件状态探针的「上次结果」只认 main 自己已发布的 `generated/oracle/event_states.json`，再拿结果文件的 SHA-256 去 main 的摘要账 `.sandbox/event_state_keys.json` 上认领。seg-a3 改了探针，main 那份旧结果的摘要（coreFingerprint 9861…）整份作废，所以 4 段整份重量。把车道的 `.sandbox/event_states*.json` 拷进主工作区也没用：同步不读 `.sandbox/event_states.json`，拷来的账记的是车道那份结果的 SHA，跟 main 的 generated 对不上。
- 修法：`同步正式西游.py` 加 `--state-prev-from <车道工作树>`。完整同步跑事件状态探针前，把车道账上认得的车道结果，跟 main 自己的上次结果按用例号拼成一份「上次结果＋摘要」（车道的优先，main 补车道没有的），交给探针。取不取回仍由探针按摘要逐例判断（摘要含探针代码、来源、预设、读到的地图），再抽 1% 重跑自检，所以对不上的结果带不进来。`合并车道.py` 在 `--from-worktree` 退出码 3、改跑完整同步时自动带上这个参数。
- 回退：`XIYOU_STATE_PREV_FROM=0`，合并工具不传参数，同步也不用车道结果。`--full` 时不用车道结果。

### ① 合并准备阶段查车道删了基线参照用例

- `合并车道.py` 的 `plan` 里加 `deleted_reference_presets`：用三方比对 `event_presets.json`，分叉点和合并前 main 都有、车道上没了的预设行才算车道删的；main 已发布的 `event_states.json` 在时，只留基线里真有的用例（goneIn 跳过的不算）。查到就在合并前停下，列出前 6 个，main 不动。
- 换源合并（`XIYOU_ACCEPT_SOURCE_SWITCH`）不查；`XIYOU_LANE_DELETE_CHECK=0` 关掉这项检查。读不准（解析失败等）就返回空，照旧交给同步把关。
- 只管事件状态预设（这次踩坑的就是它）。别的参照文件被删仍由同步拒收。

### 顺手修

- `同步正式西游.py` 的 `_main` 里 `ap` 没定义（`--accept-withdrawal` 写错、`--full` 加 `--from-worktree` 的报错路径会抛 NameError），改成 `ap = build_parser()`。

## 改动文件

- 改：`03_再刷重制_Godot/03_转换工具/同步正式西游.py`（`lane_state_prev`、`combine_prev`、`run_state_sharded`、`--state-prev-from`、`_main`）
- 改：`03_再刷重制_Godot/07_开发环境/合并车道.py`（`deleted_reference_presets`、`plan`、`prepare` 退回完整同步那段）
- 改：`03_再刷重制_Godot/07_开发环境/测试合并工具.py`、`工具回归.py`
- 没动 `event_state_probe.cjs`、`event_state_shards.py`（后者在 incremental_sync 的 PROBE_INPUTS 里，改了会让同步的探针缓存失效）。注意：`同步正式西游.py` 在转换工具指纹里，合并后各车道已有的同步指纹会失效，`--from-worktree` 退回完整同步。这正是本次修的那条路，事件状态探针会从车道结果里取回。

## 验证

- 真实历史：拿 seg-a3 的提交跑 `deleted_reference_presets`，删 w8_* 那次（b445a3fe→3ef8425f）查出 70 例（ce1442#w8_762…），revert 后（9618d8e0）是 0。
- 真探针实测（单段、经 `占槽.py` 占 1 槽）：本树合了 main（探针同 seg-a3），把本树自己的摘要账换成空账，只靠 `--state-prev-from` 指向 seg-a3 车道树。结果车道 24058 例、取回 24058 例，自检抽 241 例全对，用时 206 秒（原来主工作区 4 段整份 90 分钟）。产物跟车道结果、跟 main 当时整份重跑的结果都逐字节相同（cmp）。
- 新单测：`StatePrevFromLaneTests` 5 项（车道优先、main 补缺、开局设定不同不拼、fileSha 认领、车道账没有就不用、本树账指到别处时车道账照样找得到、回退开关、合并工具传参）；`MergeTests` 3 项（删基线行准备阶段停且 main 不动、只加行照常合并、三方比对＋基线过滤＋回退开关＋换源不查）。工具回归加了一项，跑这 8 例。
- `测试合并工具.py` 整份 310 项通过（最后一处小修之前跑的，修后相关 8 例重跑通过）；`测试增量同步.py` 74 项通过；`工具回归.py` 15 项全过（62 秒）；语法检查 659 个 .gd 0 问题。没有 Godot 场景改动。
- 占槽：第一次实测脚本有 bug（把本树账指到别处时，车道账也跟着找不到了），于是 2 段整份重量了约 50 分钟。那次经同步的 run_node 走了共用槽，但外面没包 `占槽.py`，总装看到差点超 4 槽，叫停了。以后手动起探针一律外包 `占槽.py`。

## 优化登记草稿

优化登记草稿：无

## 可优化（流程／工具／效率）

- 车道只改了 `event_presets.json`／探针、用 `补跑事件状态探针.py` 补量后，同步指纹就过期了，`--from-worktree` 整份克隆永远走不通（本次原因一）。可以让补跑工具在「除事件状态产物外，其余产物与指纹一致」时刷新指纹（指纹里加一个不含 event_states.json 的产物摘要），这样合并直接克隆，连探针都不用跑。本单没做，因为现有指纹没有分项摘要，只能对以后的同步生效。

## 变更记录草稿

## 2026-11-09 【cc·工具·未经审查】合并：车道删基线参照用例在准备阶段就停；完整同步复用车道已跑完的事件状态探针结果（dev.待定）

- `合并车道.py`：合并前用三方比对 `event_presets.json`，车道删了 main 基线里还有的预设行就停下列出（同步不收删除，原来要白跑一轮整份探针才拒）；`XIYOU_LANE_DELETE_CHECK=0` 关掉，换源合并不查。
- `同步正式西游.py --state-prev-from <车道树>`：完整同步时把车道账上认得的事件状态结果并进上次结果，探针按摘要逐例取回、抽 1% 自检；合并工具在 `--from-worktree` 退回完整同步时自动带上。实测 seg-a3 那份 24058 例全部取回，单段 206 秒，跟整份重跑的结果逐字节相同（原来 4 段 90 分钟）。`XIYOU_STATE_PREV_FROM=0` 回退。

## 交接板

- 待交叉核查：cc/tools-merge-probe（甲：合并流程与同步的探针取回）

## 本分支提交

- ad48c843 完整同步把车道事件状态结果并进上次结果（--state-prev-from）
- 8bdbaf33 合并准备阶段查车道删基线预设行；工具回归加例
- 2f3b9d41 车道摘要账按固定 .sandbox 位置找
- 交付单提交（本条）
