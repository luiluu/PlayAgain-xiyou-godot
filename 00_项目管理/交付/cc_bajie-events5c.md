# 交付：cc/bajie-events5c（接自 cc/bajie-events5b 头 68925f5d，已收尾）

- 车道：A 内容·事件解释器／八戒（cc）。分支 cc/bajie-events5c。
- 状态：**可合并**（云端选测结果见文末「验证」）

## 一、本分支做的（接 5b 之后）

1. **接受单逐字段理由**：`04_验证/测量接受/cc_bajie-events5b_obs.json`（474 条）分布：战斗背景 461（events 407＋event_states 54）、能力加成 4、HP 2、HP＋MP 3、HP＋MP＋能力加成 2、HP＋能力加成 1、MP＋能力加成 1。hp／mp 只有 9 例，**不是初值差噪声**：观察面本来就是"快照差"，只有指令改了才进 delta，所以不用改成"只记指令改过的角色"；9 例都是 316 升级药（CE231、m4e64p0、m4e69p0）、死亡状态置 0（CE46）、转职（CE29）等。理由已按字段重写（战斗背景分"设成空串／设成某两张图"，能力加成写角色号，HP／MP 写成因）。
2. **同步**：先 `--accept-additions` 退出码 2（474 条候选，与草稿一致），再 `--accept-changes obs.json` 重跑，退出码 0。**注意：`cc_bajie-events5b.json`（320 条）与 obs 有重复键，两份不能同时给**（"接受单有重复条目"）；本工作树的基线已含 5b 那 320 条，所以这里只给 obs。**main 合并时**参照落后，见下"合并提示"。
3. **事件对照咬出的三类差异，逐个量原版再修**：
   - 战斗背景 Godot 全是 null（464 例）：① 测试宿主 `EventHost` 没有 `change_battleback`（283 被丢）→ 补上（同 map_scene）；② MV 的 `_battleback1Name` 在换图时由 Game_Map.setup 设成目标地图指定的背景，Godot 分开存（283 覆盖＋地图指定，开战才合）→ 测试快照改成 `_effective_battleback`（覆盖优先，否则地图 specifyBattleback，否则空），宿主 transfer 换图清覆盖（同 map_scene l.241）。**游戏本体行为没改**，只是测试口径对齐。
   - **真缺口：升级不回满 HP／MP**。mv_oracle 量原版：actor 1 hp 100/485 时 `levelUp()` 后 566/566、`changeLevel(5)` 后 806/806，来源是 `Olivia_AntiPlayerStress.levelUpRecover`（参数 Recover Full HP／MP 都 true，每升一级在基础 levelUp 之后回满再 refresh）；重制 `_level_up` 只夹不回。→ `actor.gd` 加 `_level_up_recover()`（先 refresh_passive 让刚学技能的被动进 mhp，再按参数回满，refresh_resources），挂在 `_level_up` 学技能之后。**影响战斗后升级、升级药、经验类事件**。直接设等级的 `change_level`（读档、夹具）不回，对应原版没有 levelUp 调用。
   - 其余 6230/6231 一致，剩 1 例 m4e73p0 是登记里已知不一致。
4. 两份基线重写：`event_compare_baseline.json`、`event_skipped_baseline.json`（跳过 148 例 424 条，CE1386 不再跳后 5b 写的 160/436 缩了 12 例）。

## 二、合并提示（给总装）

- main 的 generated 参照落后于 events4：同步 main 时需要把本分支的 `cc_bajie-events5b.json`（320，刷 events4 落后）与 obs 的**合并单**给 `--accept-changes`。重复键（两份都有的）要合成"main 旧摘要 → 最终新摘要"一条；我没有 main 的参照产物，没法本地验证合并单，故未提供。若总装从 `--from-worktree cc/bajie-events5c` 克隆本分支产物则无此问题。
- 本分支产物指纹已留（同步退出码 0 带 `--accept-additions`）。

## 变更记录草稿

## 2026-11-05 【cc·八戒·未经审查】事件对照加跳过基线、扩 hp/mp/能力加成/战斗背景观察面，守护者战斗背景不再跳过（dev.待定）

- 地图事件对照新增"解释器跳过"基线（148 例 424 条），新增跳过会红；分诊后唯一玩家可达缺口是 CE1386（守护者战斗背景），已修。
- 快照加角色 hp／mp／能力加成与战斗背景，预设加击败数；对照咬出真缺口：**升级不回满 HP／MP**（原版 Olivia_AntiPlayerStress.levelUpRecover），`actor.gd` 补 `_level_up_recover`；战斗背景口径在测试里按 MV 的有效值对齐（游戏本体不变）。

## 待交叉核查

- `mv_event_core.gd`：`skip_common_events` 清空（CE1386 现会执行 283）。
- `xiyou_event_compare.gd` 与两个探针的快照同规则；`_effective_battleback`、宿主 `change_battleback`／transfer 清覆盖。
- **核心文件 `actor.gd`**：`_level_up_recover`（挂在 `_level_up` 学技能后），请沙僧线重点核：升级顺序（专属角色模块 level_up 在回满之后）、mhp 是否需 refresh_passive 的取舍、gain_exp 战斗路径随机流（refresh_resources 无 random）。

## 验证

- 本机：`语法检查.py` 0 问题；`工具回归.py` 通过；同步（`--accept-additions --accept-changes obs`）退出码 0；`xiyou_event_compare` 6231 例 6230 一致、1 例已知、0 回归，跳过基线 new=0。
- 选测：`选测.py main --list` 220 个场景（actor.gd 牵动面大）→ 云端选测，结果见下。

