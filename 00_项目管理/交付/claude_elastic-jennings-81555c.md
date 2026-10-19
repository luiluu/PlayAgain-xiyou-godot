# 交付：claude/elastic-jennings-81555c

- 车道／工作者：C 测试，重制_八戒_26（Claude）
- 状态：**可合并**（并行 `检查.sh --oracle` 连跑两次全过）
- 基准：main d405f0a。只改 tests/，不递增开发编号，不改游戏代码；预分配的 O-066 未用（没有新的原版优化）。

## 做了什么

沙僧清单第 8 条④。dev.099 起每场战斗用本场规则流，主种子由新开局的 orb_seed 派生（`XState._fresh_seed()` 用独立生成器、每次不同），全局 `seed()` 管不到战斗，所以原来「seed(N) 后新开局再打」的测试其实每次打的是不同的随机数。

**逐个看了 15 个仍用 `seed()` 的文件：**

| 文件 | 处理 |
| --- | --- |
| xiyou_battle、xiyou_combat、xiyou_flow、xiyou_floor16_dungeon、xiyou_floor30_seeker、xiyou_hangup、xiyou_drop_record（地图上那两场）、xiyou_opening_branches | 都会真打战斗、看胜负或奖励：新开局后设 `random_master = XRandomStream.hex64(原种子)`，照 xiyou_troop_events／floor_run 已有写法；`seed()` 保留，地图侧遇敌、事件脚本随机仍走全局 |
| xiyou_smart_ai | 原有「预览不动全局随机」检查保留，另加 `preview_preserves_rule_*`：智能 AI 预览前后本场规则流快照不变（实战现在抽的是这条流） |
| xiyou_battle_events、xiyou_battle_options、xiyou_battle_ui、xiyou_sequence_visual（主场景） | 已设 random_master，不动 |
| xiyou_sequence_visual 的 MIRROR／双持两段 | 只看行动序列里有没有攻击动画指令、镜像方向，不依赖胜负，不动 |
| xiyou_random_streams | 是在测全局 seed 与规则流互不影响，不动 |
| xiyou_floor_run | 见下 |

**楼层流程 c 偶发败的来源**：每场战斗的规则流按 `battle_serial`（第几场战斗）派生。守层者战之前打了几场遇敌，取决于遇敌步数（`map_scene._make_encounter_count`，全局 `randi_range`）；而全局随机还被地图事件随机走动（`mv_event.update_character`，每个物理帧可能取数）和打字音音高（`message_box`）按帧消耗。测试按 process 帧轮询，负载下每个 process 帧跑的物理帧数不同，于是遇敌场数、守层者战的序号和规则流都跟着变。八戒_25 那次二十八层镇元子（敌群 464，有 3% 即死的圣裁之雷）拿到了一条打输的流。

**只改测试的修法**：`_floor` 在挑战守层者前按层固定 `s.battle_serial = 1000 + 层号` 并 `seed(seed_value + 层号)`，守层者战每次用同一条规则流，不再随前面遇敌场数变。遇敌战本身仍随帧时序变（队伍攻击 3e15 起，遇敌都一回合打完，不影响通过）。

## 留给沙僧的方案（游戏代码，不在本车道改）

地图侧玩法随机仍走全局 `randi`／`randf`，与纯表现的随机共用一个序列，所以玩法结果受帧时序影响，回放和测试都难复现。建议：

1. **玩法随机接 world 流**（`XState.world_random()`，或另派生 `map` 域）：遇敌步数与敌群（`map_scene.gd:483`、`:494`）、地图事件脚本 `MVEventCore.random_float／random_int`（mv_script 的随机池、`dungeon.gd:221` 掉书、`:278`）、真气 `zhenqi._random_int`、挂机 `hang_up.gd:176`。这些都只在玩家动作（走一步、触发事件）时取数，接上后结果只看动作序列。
2. **纯表现随机改各自的 RandomNumberGenerator**：事件随机走动（`mv_event.gd:95-96`，MV 里也是 Math.random，但它按帧取数，留在玩法流里会把帧时序带进遇敌）、打字音音高（`message_box.gd:379`）。照 battler_sprite／drop_popup 已有的 `visual_rng` 写法。
3. world 流随不随存档，与第 8 条③（读档重打能刷出不同结果）一起定。改后 floor_run 的「按层固定 battle_serial」可以去掉。

## 验证

- 改过的 9 个测试并行（4 路）全过：battle 8、combat 34、drop_record 26、floor16_dungeon 25、floor30_seeker 27、flow 48、hangup 25、opening_branches 16、smart_ai 45059。
- 楼层流程 a／b／c 三个并行连跑两次都全过（c：524/524，到三十三层）。
- 并行 `检查.sh --oracle`（worktree 2 路）连跑两次都全部通过，80 个场景，楼层流程 c 两次都 524/524。

## 交接板（由唐僧并入）

- 车道表八戒_26 一行收尾。
- 「沙僧协作清单」第 8 条④改为：测试侧已做（八戒_26，本分支）；剩地图随机接 world 流、表现随机分开的方案，见本交付单「留给沙僧的方案」。
- 待交叉核查加一行：本分支，执行者 Claude（八戒_26），核查 Codex。

## 变更记录草稿

## 2026-10-19 【Claude·八戒_26·未经Codex检验】测试改用固定本场规则流；楼层流程守层者战固定规则流序号

- dev.099 起战斗不认全局 `seed()`：battle、combat、flow、floor16_dungeon、floor30_seeker、hangup、drop_record、opening_branches 新开局后固定 `random_master`；smart_ai 加预览不动本场规则流的检查；其余用 `seed()` 的文件逐个看过，不依赖战斗随机或已固定，不动。
- xiyou_floor_run_c 并行下偶发败的来源：守层者战的规则流按第几场战斗派生，前面遇敌场数受地图随机走动、打字音按帧消耗全局随机影响。测试在挑战守层者前按层固定 `battle_serial` 与全局种子。地图玩法随机接 world 流的方案交沙僧。
- 不递增开发编号，不改游戏代码。

## 进度账

只改测试，不增加游戏完成度。

## 本分支提交

- 5a3eb2e 测试：战斗用的存档固定本场规则流主种子；楼层流程守层者战按层固定序号
- dc703f3 交付单草稿

可合并。
