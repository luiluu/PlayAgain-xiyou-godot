# 交付：cc/nezha-preempt1

- 车道／工作者：C 规则／哪吒（cc，Sonnet）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·哪吒·未经审查】先制／偷袭整套（含 passivePREE／passiveASUP 12 个技能）（dev.待定）

背景：重制里先制／偷袭整套没有（`rg preempt|surprise` 无结果），随机遇敌（51 张地图有遇敌表）永远是普通开战；`passivePREE`／`passiveASUP`（技能 1053、1084、1110、1113、1897、2782、5937、7849、8017 等）和护甲上的队伍能力 2「防偷袭」／3「先发制人率上升」都是空的。

**原版**（读冻结源 rpg_managers／rpg_objects／YEP_BattleEngineCore／Olivia_BattleSysOTB／dsPassiveSkill，再用新参照探针 `mv_oracle/preempt_probe.cjs` 量，75 例，夹具 `tests/fixtures/preempt_oracle.json`；公式只量公式，没有随机采样）：
- 只有**随机遇敌**（`Game_Player.executeEncounter`）调 `BattleManager.onEncounter`；事件战斗（指令 301）不掷，两个标志都是 false。XdRs_HangUp 里「挂机关偷袭」那段被注释掉了，没生效；zidongzhandou 没启用。
- 先制率：我方平均敏捷 ≥ 敌方平均敏捷 → 0.05，否则 0.03；队伍能力 3 → ×4；再加出战成员每个 `passivePREE` 的 v×0.01，夹 0～1。**我方敏捷按全名册 `members()` 算**（未进战斗，不是出战栏：后备成员的敏捷也算进去，参照 reserveAgi 例 150→262），敌方按全部成员；倒下的出战成员的被动照样算（deadMember 例先制率 1）。
- 偷袭率：我方 ≥ 敌方 → 0.03，否则 0.05；队伍能力 2 → 0；再对每个 `passiveASUP` 做 rate −= v×0.01×rate，夹 0～1（同一人两个 100% 都是 0）。
- 掷骰：两次随机数**总是各取一次**（先制 r1 < 先制率，严格小于；偷袭 r2 < 偷袭率 且没先制）。
- 开战第一回合行动顺序（OTB `makeActionOrdersOTB`）：偷袭＝第一回合只排敌人（我方整回合不能动）；先制＝只排我方；「下个回合」始终是全员。这一回合结束时（`endTurn`）标志清掉，之后正常。
- 开场文字：先制「<队名>先发制人！」、偷袭「<队名>被偷袭了！」（队名＝出战 1 人时他的名字，否则「…的队伍」）；YEP Show Emerge Text 关，不显示「出现了」；快速战斗（XdRs_HangUp）不显示。
- 先制时逃跑必成功（不掷随机数）；偷袭时逃跑照常按逃跑率。

**重制**：
- 新 `core/preempt.gd`（`XPreempt`：`rates`／`compute`／`roll`／`party_name`／`start_text`）。
- `battle_logic.gd`：加 `preemptive`／`surprise`／`encounter`；`roll_encounter()`（`setup` 之后由随机遇敌调，用战斗随机流 `encounter_preemptive`／`encounter_surprise`，回放照样再掷）；`_make_action_orders` 首回合按标志过滤；`end_turn` 开头清标志；`try_escape` 先制必成功。改动集中在开战段，没碰 `damage.gd`。
- `battle_scene.gd`：`setup` 多一个 `random_encounter` 参数；入场移动后显示开场文字；`escape_text` 改用 `XPreempt.party_name`。`map_scene.gd`：`_encounter` 把随机遇敌标志传给 `start_battle`。`battle_replay.gd` 记录／回放 `encounter`。
- 开场文字原版与入场移动同时进行，这里入场后再显示（小差异，不影响规则）。

**专项**：新 `tests/xiyou_preempt.gd`（211 项）逐例对参照：公式 41 例（敏捷两边用参照值压住两边能力值取整的差异，能力与被动来自真实角色数据；另验默认队伍对 3 号敌群的原生敏捷）、掷骰 24 例（含严格小于临界）、第一回合顺序／消息 8 例、逃跑 6 例、endTurn。反向验证：去掉首回合过滤后 6 项失败、去掉先制必逃 3 项失败、去掉 endTurn 清标志 2 项失败。

## 交接板

- 下一步：无
- 用户试玩说明：随机遇敌时有 5%／3% 的基础概率先制／被偷袭（我方敏捷不低于敌方 5%／3%，低于则 3%／5%）；先制我方先动一回合敌人不动，偷袭反之；防偷袭、先发制人率上升的装备和 12 个带 PREE／ASUP 的技能生效。开场会有一行「先发制人！／被偷袭了！」。事件战斗（Boss、剧情）不受影响。
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 无

## 验证

- 专项 `xiyou_preempt` 211 项通过；`xiyou_battle`、`xiyou_determinism`、`xiyou_flow` 通过；`语法检查.py`、`探针登记检查.py` 通过。
- 云端选测（提交 b6f8cb39，基准 fc7d88f3，245 个场景、7 片）241 个通过，4 个失败（xiyou_barrier、xiyou_dot、xiyou_state_effects、xiyou_state_effects_tp）：不是本分支改动，是车道 generated/oracle 停在旧版（tools64 修的那个毛病，并行测试的落后检查也报了）；合并 main、重新 --补齐刷新 3 份参照后本地重跑这 4 个加 xiyou_preempt 全过。没有再跑云端。
- 参照没登记 PROBES，走冻结夹具（同 steal1）：先制／偷袭公式是 v0.28 冻结源的，不随同步变，这样也不依赖 `generated/oracle`。
- 待交叉核查（核心文件）：`battle_logic.gd`（`roll_encounter`、`_make_action_orders`、`end_turn`、`try_escape`）、`core/preempt.gd`、`battle_scene.gd`（开场文字）。

## 本分支提交

- 见 `git log cc/nezha-preempt1`
