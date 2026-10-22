# 交付：claude/bajie-next（一期：地图侧随机流）

- 车道／工作者：C 规则·工具／八戒（Claude，八戒_45）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·八戒·未经Codex检验】地图侧随机流核对：游戏侧已在 dev.102 接好，楼层流程补「不取全局随机」回归

- 做了什么：
  - **核对**：派下来的方案（遇敌、事件脚本随机、真气、挂机改接 world 流；随机走动与打字音用独立 RNG；world 流不随存档固定）已由沙僧 `codex/rng-rework`（95a51c3，dev.102 合并）做完：`map_scene._make_encounter_count／_encounter` 取 world 流，`MVEventCore.random_float／random_int` 无规则流时取所属存档的 world 流，`XZhenqi._random_int`、`XHangUp.next_dirs` 走 world 流，`MVEvent._wander_rng`、`XMessageBox._letter_rng` 各自 `randomize()`；`random_master` 只在运行时生成，`XState.to_dict` 不再写随机流。全仓游戏代码（`core`／`modes`／`scenes`，不含 generated）已没有全局 `randi`／`randf`／`seed` 调用，剩下的都是独立 `RandomNumberGenerator`。`xiyou_random_streams` 的 `_world_visual_boundaries` 已覆盖调用点与「走动／打字音不动全局与规则流」。本期没有改游戏代码。
  - **回归**（`tests/xiyou_floor_run.gd`）：每层开头按层种子取两次全局随机，守层者战胜后再取一次，应正好是同种子下的第二个数（新断言 `f<N>_boss_no_global_random`，每层一项）——地图行走、遇敌、事件、战斗都不取全局随机；每层守层者前把 `battle_serial`、world 流已取次数、遇敌步数写进日志，便于以后比对。去掉了守层者前已无作用的 `seed(seed_value + n)`；按层固定 `battle_serial` 留着（让各层与前面各段无关），注释改写成现状。
  - **确认不再因帧时序偶发**：同一种子下用共用槽位并行连跑 `xiyou_floor_run_c` 三次，各层「战斗 N 场」与守层者前的 world 流取数、遇敌步数三次逐行相同（33 层，world 流 83→257 次）；再临时去掉按层固定 `battle_serial` 并行连跑三次，仍三次逐行相同、全过（说明守层者战拿到的流已只由种子决定，不再看帧数）。实验改动已还原。
- 验证：`并行测试.py` 跑 `xiyou_floor_run`（273）、`_b`（332）、`_c`（558，新增 33 项）、`xiyou_random_streams`（484）全过；合 main（含 dev.123、`codex/state-effects-2`）并 `--补齐` 后 `xiyou_random_streams` 复跑通过。没改切片、转换器、探针，不用重跑同步。
- 提交：见「本分支提交」。
- 未完成：无。

## 交接板

- 下一步：沙僧清单第 8 条「地图侧随机方案仍待做」划掉（dev.102 已接，八戒_45 补楼层流程回归并确认并行下逐次相同）；第 8 条④里「xiyou_floor_run_c 并行偶发」同样销掉。
- 用户试玩说明：无可见变化（只加测试）。
- 需要用户决定：无

## 进度账

- 不加点（测试与核对）。

## 本分支提交

- 99a679c floor_run：查地图与战斗不取全局随机，记各层守层者前 world 流取数
- 220c52d 合并 main
- 二期另见 [claude_bajie-next_慢场景拆分.md](claude_bajie-next_慢场景拆分.md)
