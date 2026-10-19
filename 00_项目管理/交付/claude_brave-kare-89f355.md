# 交付：claude/brave-kare-89f355

- 车道／工作者：核查／八戒（Claude，重制_八戒_29），只读，不占车道
- 状态：可合并

## 变更记录草稿

## 2026-10-20 【Claude·八戒_29】核查 95a51c3、b8749f8、c8f2300（含同分支 c4e567e、fa2b279）

- 范围：沙僧三条分支的实现提交。只读核查，没有改 `codex/rng-rework`、`codex/review-backlog-20261019-followup`、`codex/framework-docs`；专项在本工作树临时检出后单跑，跑完已还原。
- **核查 95a51c3**（codex/rng-rework，普通读档重建运行时随机流）：通过，有 3 处低级问题。
  - 普通档不再写 `random` 字段（`XState.to_dict`），`from_dict` 和 `XSave.valid_data` 都不看旧的 dev.099 `random` 字段，所以引擎串不同的旧档能读，不再整档拒读。`random_master` 改为 `XRandomStream.fresh_seed()` 的独立熵，读档后第一次用到时才建。rom 六字段、orb_seed、已有装备实例原样保留。这符合用户「读档重打照原版能刷」的决定（原版 Math.random 不随档，rom 预掷池随档）。
  - debug replay 升到 schema 2：`setup` 在预约随机之后、敌人生成之前记 `initialRuntime` 和 `battleStart`，重播用 `restore_runtime_random` 和 `XBattleRandom.restore(battleStart)` 复原，不走普通读档。终点另比 `finalRuntime`。`valid()` 先整份校验，再改运行时流。
  - 遇敌步数／敌群（`map_scene.gd`）、事件 `random_float`／`random_int`（`mv_event_core.gd`）、真气道法（`zhenqi.gd`）、挂机方向（`hang_up.gd`）都接到 world 流；NPC 走动和打字音各用自己的 RandomNumberGenerator。在该提交下 grep `randi(`／`randf(`／`randi_range(`，`modes/` 和 `core/` 里已经没有命中。实战公式不可用时统一 `push_warning`，并留最多 128 条诊断；预览不记。
  - 单跑：`xiyou_random_streams` 482/482、`xiyou_determinism` 372/372、`xiyou_save_page` 40/40、`xiyou_hangup` 25/25、`xiyou_combat` 34/34、`xiyou_floor_run` 261/261、`xiyou_drop_record` 26/26（分支 tip 9ca266d，已含 main）。
  - 低①：`dungeon.gd:221/278/319/321` 和 `mv_script.gd:41` 调 `MVInterpreter.random_*` 时没传手里的 `s`，靠 `XState.current` 兜底。正常游玩时两者是同一个，结果相同；测试或工具传入的 state 不是 current 时，会消费 current 的 world 流。建议顺手补上 owner 参数。
  - 低②：诊断数组限 128 条，`push_warning` 却每次都打。同一个不可用技能反复使用时会刷屏日志，不影响规则。
  - 低③：`框架维护约定.md` 的 RNG「实施状态」段落按 main 写着「仍序列化 master…」。两条分支谁后合并，谁就要改这一段，不然会过时。
- **核查 b8749f8**（codex/review-backlog-20261019-followup，同步拒收后的独立接受基线）：通过，有 1 处中级流程缺口。
  - `comparison_baseline` 在第一次覆盖产物之前，把 oracle 和 manifest 原子地放到 `04_验证/本地结果/同步基线/<路径摘要>/`：先在临时目录写好再 rename，中断会删掉半份。测量比较、`additionCheck`、`sameExistingSource` 改成对基线比较，旧来源也取自基线。只有 `ok` 时才退役基线。修掉了「拒绝后第二轮把上轮产物当旧值，于是误判无变化」的漏洞（八戒_25 的缓存核查项）。
  - 单跑 `测试增量同步.py` 39/39 通过（临时 worktree 检出分支 tip 4e5fac7）。9 例新增回归用真实 Node 和 ProbeCache，覆盖五轮拒绝加缓存命中／备份淘汰、`--full`、只新增显式接受、撤回、来源保留、来源／导入／缓存／指纹失败、clone、半份快照和基线损坏。
  - 中①：现在除了「撤回」和「同源只新增加 `--accept-additions`」，没有任何办法接受一次合理的既有测量变化（例如参照探针被有意修正）。基线会一直留着，每轮都退出 2，只能手动删 `同步基线/<摘要>/`，而这件事 `长任务与增量同步.md` 和多会话并行合并步骤里都没写。以前这条路靠的是那个漏洞，所以不算回退，但合并后第一次遇到时会卡住。建议补一个显式接受开关（要求写理由并进同步报告），或者至少在文档里写明人工接受的步骤。不阻塞合并。
  - 低：`finish_comparison` 在 `ok` 之后才 rename，rename 失败会抛异常，此时登记已写好、基线还在，下轮会再拒一次。这是保守失败，可以接受。
- **核查 c8f2300**（codex/framework-docs，按 dev.101 修正变身与 Permanent 的验收边界）：通过。文档里的说法都和 main 的代码对得上：`KNOWN_TRANSFORM_GAPS` 已在 dev.101 删掉（变更记录 1033 行），`stale_caps` 见 `battle_logic.gd:644-690`，`recover_all` 保留 Permanent 见 `battler.gd:481-483`，「本版按新上限截、11 处新形态 MHP 不低于旧值」和 `enemy_transform` 的注释一致（11 处那个数是照注释写的，我没有重新扫）。`same()` 比较哪些字段的描述和 `xiyou_battle_events.gd:87-92` 一致。
- **同分支 c4e567e、fa2b279**（框架现状／历史拆分、架构 11～13 接口、战斗事件验收清单）：通过。用脚本把 main→分支删掉的 57 行逐行和新的约定加历史比对，只有 6 行找不到原文，都是标题或状态句改写成现状（如「跨楼层共性系统（副本、限购及普通战斗对话已接…）」「角色模板批量接入（部分实现…）」），没有丢正文。11～13 三项接口（转换器 `parse_mechanics`／`XMechanicsView`、`XSession`、`XModuleRegistry` 挂点表）都标了「尚未实施」，迁移有白名单和单一入口，可以回退。12 项写的「新局／普通读档重建运行时 RNG，debug replay 走显式快照」和 95a51c3 一致。
- 结论：三条分支的上述提交都可保留；只有 b8749f8 的中①需要后续补，已列进交接板。

## 交接板

- 待交叉核查：销掉 95a51c3、b8749f8、c8f2300、c4e567e、fa2b279。
- 下一步（新增，低优先）：同步工具要补「显式接受既有测量变化」的入口或文档（八戒_29 核查 b8749f8 中①）；随机流调用点补 owner 参数（dungeon.gd、mv_script.gd，核查 95a51c3 低①）。
- 合并顺序提醒：codex/rng-rework 与 codex/framework-docs 后合并的那一条，要更新 `框架维护约定.md` RNG「实施状态」段。
- 需要用户决定：无。

## 进度账

- 不变（只读核查）。

## 本分支提交

- 本交付单

可合并。
