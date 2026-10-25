# 交付：claude/muzha-sync-incremental-4bd025

- 车道／工作者：D2 同步与测试提速／木吒（Claude，重制_木吒_1）
- 状态：进行中

## 改派说明

总装 2026-10-25 改派：事件探针增量与 map186 拆分归哪吒（`claude/nezha-check-tiers-eac2f9-3`），本车道不碰 `同步正式西游.py`、`event_probe.cjs`、`tests/xiyou_map186*`。本车道改做：①拆其他慢测试；②Godot 测试启动开销（内容数据库重复解析）；③哪吒的事件探针增量合进 main 后，再给 slice／smart_ai 探针做分片增量（等总装通知）。

改派前查到的事件探针根因与实测数据已写进共用笔记（`木吒_事件探针实测.md`），供哪吒参考。

## 进度与接续要点（2026-10-25 07:30）

已提交：
- `2ce3a199` XDB JSON 解析缓存（`modes/xiyou/core/xdb.gd`）＋回归 `tests/xiyou_json_cache`（100 项，单跑通过）。
- `a6e2b1e1` xiyou_variants 拆两份（135＋140＝275，与拆分前相同；各约 145 秒，单跑通过）；当时 game_app 是「headless 全局不睡」。
- `e55b9edb` 测试提速.md 草稿（会话中断时唐僧代存）。

`62fe2fcc` 已提交（当时 Bash 安全检查无响应，后由总装叫停时补交；dungeon、event_compare 选用后**尚未单跑验证**）：
- `core/game_app.gd`：从「headless 全局不睡」改成**逐个测试选用** `GameApp.fast_headless_frames()`；`XIYOU_HEADLESS_SLEEP_USEC` 设了就全局用它（=6900 即回退）。
- `tests/xiyou_dungeon.gd`、`tests/xiyou_event_compare.gd` 开头调用 `GameApp.fast_headless_frames()`（两者都按帧计、不看真实时间）。
- `07_开发环境/测试提速.md` 改写「headless 每帧不睡」一节为逐个选用。

全量实测（全局不睡，182 个场景，并行 2，5368 秒）：crafting、hud、popup_overlap、opening_branches 失败，battle_ui 超时；只恢复每帧睡眠（`XIYOU_HEADLESS_SLEEP_USEC=6900`）后这 5 个都通过 → 全局不睡不可行，改逐个选用。另 battle_events 的 `seal1691.*` 三项与 `scene.revive_fades_in` 在恢复睡眠后仍失败，待查是否为本分支基线（d50c5147）已有、或 JSON 缓存引起（已排队 `XIYOU_JSON_CACHE=0 XIYOU_HEADLESS_SLEEP_USEC=6900` 单跑，日志在草稿目录 be_nc.log）。

接续：
1. 单跑 xiyou_dungeon、xiyou_event_compare（各应约 18、15 秒、断言数 6954／5 不变）。
2. battle_events：已关缓存＋恢复睡眠单跑（`XIYOU_JSON_CACHE=0 XIYOU_HEADLESS_SLEEP_USEC=6900`），`seal1691.*` 三项照样失败（105／108），**与本分支的缓存、不睡无关**；`scene.revive_fades_in` 这次通过（全局不睡时才失败）。还要在 main 上单跑对照，确认是基线已有的问题，报给总装。
3. 用全量轮 `test_timings.json`（不睡）对比基线耗时，找更多「不睡大幅提速、且只按帧或条件等」的测试逐个选用、逐个单跑验证。
4. `xiyou_rules*` 改用 `XDB.parse_file` 读 slice_d*（每份约省 2 秒）——哪吒的文件，写提案给总装。
5. 收尾：`git merge main`、填下面各节、状态改可合并。

## 变更记录草稿

（待写）

## 交接板

- 下一步：（待写）

## 进度账

- 无（只改工具与测试，不改完成度）

## 可优化（流程／工具／效率）

- 建议：floor、variants 一类测试一半时间在等战斗横幅（`XBattleScene._say`）、胜利延时等真实秒数的计时器（goblin024 墙钟 102 秒、CPU 48 秒）。给测试一个只在 headless 测试里生效的战斗节奏倍速，或查清 `--fixed-fps 144` 下 xiyou_variants 卡死的原因后改用固定帧率，floor 类约 30 个场景可再省一半时间（归本车道续做，需动 `并行测试.py` 时交哪吒）。
- 建议：`xiyou_rules*` 24 份每份各解析一次 150 MB 的 slice_d*（约 4～5 秒）并重建全部 572 个敌群；改用 `XDB.parse_file` 可省约 2 秒／份（归哪吒）。

## 本分支提交

- 3c6850bc WIP: 木吒交付单（改派后范围）
- 2ce3a199 WIP: XDB JSON 解析缓存与 xiyou_json_cache 回归
- a6e2b1e1 WIP: headless 不睡（已改为逐个选用，见上）；xiyou_variants 拆两份
- e55b9edb WIP: 测试提速.md 草稿
- 62fe2fcc WIP: headless 不睡改为逐个测试选用；dungeon、event_compare 选用；交付单接续要点
