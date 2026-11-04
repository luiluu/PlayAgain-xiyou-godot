# 交付：cc/bajie-rules9

- 车道／工作者：C 规则／八戒（cc，Sonnet）
- 状态：可合并

（本单只含任务一：审查 39 的三条小修。任务二插件备注真缺另写在 `cc_bajie-rules9_接续.md`，那张标可合并才并。）

## 变更记录草稿

## 2026-11-04 【cc·八戒·未经审查】审查第 39 期三条小修：开战清队列位置、琼霄防连锁范围、反击计数（dev.待定）

- **P3-5 开战清队列位置**（`battle_logic.gd` start_battle）：`clear_queues()` 从 `_start_battle_effects` 提到「开战移除 removeAtBattleEnd 状态」循环之前（仍受 `FIX_QUEUE_CLEAR` 控制）。之前清队列在循环之后，状态 1307 崩坏能 remove 阶段排的 CE1505 预约会被清掉；现在先清上一场遗留，再移除状态，1307 的预约进入预约流。**注意**：公共事件预约是单槽，随后开战预约的 1320 照原版盖掉 1505（`battle_common_event.gd` 开头已写明单槽、后一个盖前一个），所以玩家层面看不到变化，改的是预约流的次序与原版一致。
- **P3-6 琼霄防连锁收窄**（`battle_logic.gd` `_forced_run`）：`chain_depth` 只在被执行的强制行动本身是 5576／5577（`CHAIN_SKILLS`）时才加 1。之前任何强制行动执行期间都算，别的技能的强制行动命中琼霄时 5577 反击也被吞。现在只有 5576／5577 自己打出的一击触发的追加／反击才被拦。回退开关仍是 `FIX_CHAIN_GUARD`（关掉后 `queue_force_quiet` 不拦）。
- **P3-7 反击计数：核对后不改**。`battle_turn` 在 `start_turn` 最前面设为 `turn + 1`，回合结束阶段触发的反击记在本回合号上、属于本回合；下一回合 `start_turn` 先把号改成新值，计数自然重置，不存在吞掉下一回合第一次反击。回合外（开战预处理）`battle_turn = 0`，第一回合是 1，也不冲突。没有实际影响。

**这期没改任何游戏数值，没有新优化，不占优化号。**

## 验证

- `语法检查.py` 通过。
- `xiyou_state_effects`（25090 项）：新增 `rules9.queue_clear.keeps_remove_reserve`（开战带 1307，预约流里有 1505、没有上一场残留的 2）、`rules9.chain_depth.only_chain_skills`（强制行动 7303 时深度 0，5577 时深度 1，执行后归 0）；老用例 `fix2.chain_guard.*`、`fix.queue_clear.*` 不变。用最新主工作区的 `generated/oracle/state_effects.json` 全部通过。
- 本地 `xiyou_state_effects_tp`、`xiyou_qiongxiao_balance`、`xiyou_determinism` 通过。
- 云端选测（`选测.py main` 140 个场景，4 片，提交 a189615c02）：139 个通过；唯一失败是 `xiyou_state_effects` 的三条 `*.oracle_present`（`effect2`／`poison`／`rest2`），原因是我工作树的 `generated/oracle` 是 rules8 合并前的旧参照（缺 rules8 新增的三个用例），不是这期改动；换主工作区的新参照后本地重跑通过。
- 没做反向验证（改动只有两处小改，新断言直接对着两处行为）。

## 交接板

- 下一步：任务二（Max State Floor 6 个状态、Multi-Element Rule 16 个技能、Element Reflect 1 件防具）在同分支继续。
- 用户试玩说明：无变化。
- 需要用户决定：无。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 建议：`新建工作树.sh --补齐` 在总装合并 rules8 的间隙复制了旧 `generated/oracle`，之后不会自己刷新（日志只提示「等合并收尾后再 --补齐」），但合并收尾后再跑 `--补齐` 也没刷新这份旧参照（我跑了一次，`state_effects.json` 仍是 09:05 的旧文件）。可让 `--补齐` 比较主工作区与本工作树 `oracle` 目录的修改时间，不一致就重拷（归工具车道／哪吒）。

## 本分支提交

- ca2ff27ca1 WIP: rules9 任务一 P3-5/P3-6 修复与测试
