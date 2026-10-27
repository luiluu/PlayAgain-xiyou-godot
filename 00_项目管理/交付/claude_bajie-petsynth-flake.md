# 交付：claude/bajie-petsynth-flake

- 车道／工作者：B 界面·测试／八戒（Claude，八戒_77）
- 状态：进行中
- 基线：按派单从 6a41f47f（claude/bajie-ce-fix2 末尾，未合）开的分支，所以本分支带着 ce-fix2／ce-fix1 的提交与交付单；先合 ce-fix2 再合本分支，或只摘 8f80e4ae 一个提交都行（只改了 `tests/xiyou_pet_synth.gd`）。
- 来源：沙僧 10-27 第二期交回的 P2：`xiyou_pet_synth` 并行首轮 24/26（syn_occludes_status、feed_occludes_status 失败），单跑 26/26，累计第二次偶发。

## 变更记录草稿

## 2026-10-27 【Claude·八戒·未经Codex检验】修 xiyou_pet_synth 遮挡断言的偶发：等窗口开合到终点再等一个 process（dev.待定）

- **根因**：窗口开合在 `XMVWindow._physics_process` 里每 tick ±32，状态窗被挖掉的范围 `status_cover` 在 `XPetScene._process` 里刷新。测试原来固定等 10 个 physics tick 就断言。负载重时一帧要补跑好几个 physics tick，10 个 tick 走完时，开合到终点之后的那次 `_process` 可能还没跑，`status_cover` 还是旧值。
- **修法**：测试加 `settled(窗口, 终点)`：按 process 帧等 `openness` 到终点，再多等一个 process 帧。`process_frame` 信号在节点 `_process` 之前发出，所以要多等这一帧，页面才会刷新。最多等 120 帧，超时就交给原断言判失败。合成窗打开、喂养窗打开、喂养窗关上三处都换成这个写法。原断言、参照、容差都没动，页面代码没改。
- 沙僧的候选 fa2ccd8a 思路相同（只作参考，没有摘）。本分支是自己写的，最多等 120 帧（候选是 90 帧）。

## 交接板

- 下一步：无新增。
- 用户试玩说明：无（只改测试）。
- 需要用户决定：无。

## 进度账

- 无变化。

## 验证

- **RED（负载下复现）**：自写压测脚本，每轮同时起 6 个 `xiyou_pet_synth`（机器上另有车道在跑，loadavg 约 9～18），10 轮 60 次里失败 15 次（25%）：syn_occludes_status 7、status_restored_after_feed 5、feed_occludes_status 4。
- **GREEN**：同样负载 20 轮 × 6 并发，120 次全部 26/26。
- **反向验证**：`git stash push`（带标签）撤掉修复，再跑 10 轮 × 6，失败 2/60（feed_occludes_status、syn_occludes_status 各 1）；`git stash apply` 恢复后删掉该条 stash。两次复现率差别大，是因为当时机器负载不同。
- `并行测试.py --full xiyou_pet_synth xiyou_system_evidence`：（待填）
- 没改界面代码，所以不用跑必跑项 `xiyou_event_compare`；没跑全量。

## 同类写法排查（固定 N 个 physics tick 后断言界面）

用 rg 查了 `tests/` 里所有 `await get_tree().physics_frame`（22 个文件）：

- `xiyou_system_evidence.gd` 230～235：同样是宠物页的 `status_cover`，写法是等 20 个 physics tick 再 `frames(2)`（两个 process 帧）。第二个 process 帧恢复时，`_process` 已经跑过一次，开合也早就走完（8 tick），**没有这个问题**，不改。
- `xiyou_achievement.gd` 246～247：先把弹窗帧号直接设到末尾，再等 2 个 physics tick，然后断言弹窗已移除。移除在弹窗自己的 `_physics_process` 里做，第一次 await 恢复后同一 tick 就会跑到，**不依赖 process**。flaky.jsonl 里它有 2 次偶发（10-21，两个旧工作树），可是失败日志已经没有了；本轮 6 并发 × 10 轮 60 次没有复现，所以没改，列进遗留。
- `xiyou_battle_options.gd` 219／231（逃跑失败消息等 60／30 tick）、`xiyou_drop_dh.gd` 280、`xiyou_mv_animation.gd`／`xiyou_sequence_visual.gd`／`xiyou_battle_events.gd` 开场等 1～2 tick：断言的都是 physics 里推进的状态（消息暂停、按键处理、战斗建立），或者只是让场景建好，和遮挡这类 `_process` 才刷新的量无关，不改。
- 其余是 `frames()`／`physics()`／`until()` 这类辅助函数，或者按条件等待（hangup、options_basic、drop_record、floor_run），不属于这一类。

## 遗留

- `xiyou_achievement` 累计 2 次偶发，原因不明（日志已不在，本轮复现不出来）。下次偶发时先保留 `.log`／`.rerun1.log`，看是哪项失败。

## 可优化（流程／工具／效率）

- 建议：`并行测试.py` 记 flaky.jsonl 时，把首轮失败的 `FAIL` 行（前几行）也写进去。这次 achievement 的两次偶发只有通过／失败，没有失败项，日志又跟着工作树一起清掉了，没法查。改动很小，归工具车道（哪吒／木吒）。
- 已做：压测脚本放在会话临时目录，没入库。要不要做成 `07_开发环境/压测场景.sh <场景> <轮数> <并发>`，留给总装定。偶发要求「负载下 20 轮全过」时，每条车道都得自己写一份。

## 本分支提交

- 8f80e4ae pet_synth 偶发：遮挡断言前等窗口开合真到终点再等一个 process

## 待交叉核查

- 8f80e4ae（执行者: Claude（八戒），核查: 待Codex）。只改 `tests/xiyou_pet_synth.gd`，没碰原沙僧核心文件。
