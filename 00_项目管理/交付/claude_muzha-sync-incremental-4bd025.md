# 交付：claude/muzha-sync-incremental-4bd025

- 车道／工作者：D2 同步与测试提速／木吒（Claude，重制_木吒_1）
- 状态：可合并（截至合并 main b24c9fb7 后的本分支最新提交）

## 接续要点

- 已完成本批规划的三件：JSON 解析缓存、拆 xiyou_variants、headless 不睡（逐个选用，dungeon、event_compare）；revive_fades_in 只在全局不睡时失败，现不全局开，已不受影响。必跑选测 11/11 通过（见「验证」）。
- 没有未完成的坑。合并时注意：xdb.gd 改了所有 JSON 读取路径（全量一次已在缓存开着时跑过，没有缓存引起的失败）；本分支新增场景 `xiyou_json_cache`、`xiyou_variants_b`。
- 不在本批（用户 2026-10-25 定恢复双车道后不再开新期）：slice／smart_ai 探针分片增量；floor 类测试的战斗计时器提速（见「可优化」）。

## 改派说明

总装 2026-10-25 改派：事件探针增量与 map186 拆分归哪吒（`claude/nezha-check-tiers-eac2f9-3`），本车道不碰 `同步正式西游.py`、`event_probe.cjs`、`tests/xiyou_map186*`。本车道改做：①拆其他慢测试；②Godot 测试启动开销（内容数据库重复解析）；③哪吒的事件探针增量合进 main 后，再给 slice／smart_ai 探针做分片增量（等总装通知）。

改派前查到的事件探针根因与实测数据已写进共用笔记（`木吒_事件探针实测.md`），供哪吒参考。

## 验证

- **全量一次（JSON 缓存开、headless 全局不睡，182 场景，并行 2，5368 秒）**：缓存在全量下全程开着、并发首写无问题；失败只有两类——全局不睡引起的 crafting、hud、popup_overlap、opening_branches、battle_ui（超时）与 battle_events 的 revive_fades_in（恢复每帧睡眠后都通过），以及 main 基线当时的 seal1691（唐僧已在 4cd01282 修）。据此改为逐个选用。
- **选用候选**：对比全量不睡与基线耗时，只有 dungeon（195→15）、event_compare（51→18）提速明显且按帧计；opening_branches 不睡会失败，其余提速不到 10 秒，不选。
- **A/B 实测**（同工作树、同占共用槽）：dungeon 204.0→17.6、event_compare 82.0→14.9；floor_goblin024、floor_unknown223、troop_events、variants 不变（它们在等真实秒数的计时器）。
- **JSON 缓存**：`xiyou_json_cache` 100/100；命中／未命中与直接解析 `var_to_bytes` 逐字节相同（db 全部表、manifest、slice、Map004／186、smart_ai、formula_programs、events，另 slice_d2 一次性脚本比对相同）。
- **拆分**：xiyou_variants 135/135、xiyou_variants_b 140/140（合计 275＝拆分前）。
- **合并 main 后选测**（`并行测试.py … xiyou_json_cache xiyou_dungeon xiyou_event_compare xiyou_variants xiyou_variants_b xiyou_battle_events xiyou_crafting xiyou_hud xiyou_popup_overlap xiyou_opening_branches xiyou_battle_ui`）：11/11 通过——json_cache 100、dungeon 6954（12 秒）、event_compare 5（21 秒）、variants 135、variants_b 140、battle_events 108（含 revive_fades_in：只在全局不睡时失败，逐个选用后不受影响）、crafting 49、hud 34、popup_overlap 8、opening_branches 16、battle_ui 70。墙钟 9118 秒是排共用槽（两条车道同步占满 4 槽），各场景实跑见括号。
- 车道不跑全量 `检查.sh`。xdb.gd 落在选测对照的 game 组。

## 变更记录草稿

## 2026-10-25 【Claude·木吒·未经Codex检验】测试提速：JSON 解析缓存、headless 不睡逐个选用、拆 xiyou_variants（dev.待定）

- **XDB JSON 解析缓存**（`modes/xiyou/core/xdb.gd`）：`XDB.load_json`／新的 `XDB.parse_file` 按「文件内容 SHA-256＋格式号＋引擎构建号＋路径」作键，把 `JSON.parse_string` 结果 `var_to_bytes` 后 zstd 压缩缓存（开发与测试在工程 `.godot/xiyou_json_cache/`，导出版在 `user://`）；命中 `bytes_to_var` 还原，坏缓存、读不出照常解析再重写，先写临时文件再改名。Skills 683→479 毫秒、slice_d2 3884→2049 毫秒。回退 `XIYOU_JSON_CACHE=0`。回归 `tests/xiyou_json_cache`（100 项：刁钻 JSON、坏缓存、换内容、开关、db 全部表与几份地图／参照，命中与未命中都与直接解析逐字节相同）。
- **headless 不睡逐个选用**（`core/game_app.gd`）：Godot 无窗口时每帧固定睡 6.9 毫秒，空场景 600 帧 4.2 秒。新增 `GameApp.fast_headless_frames()`，测试开头调用即本测试不睡；`xiyou_dungeon`（195→15 秒）、`xiyou_event_compare`（51～82→15～18 秒）选用（两者都按帧计、不看真实时间）。全局不睡试过一次全量：crafting、hud、popup_overlap、opening_branches 失败，battle_ui 超时、battle_events 的 revive_fades_in 失败（拿「等 n 帧」当「等动画」），所以不全局开。回退 `XIYOU_HEADLESS_SLEEP_USEC=6900`。
- **拆 xiyou_variants**：单跑约 280 秒，照 xiyou_rules 加 `part`／`parts`，拆成 `xiyou_variants`（135 项）＋`xiyou_variants_b`（140 项，含困难模式）＝275 项，各约 145 秒。除 map186（哪吒拆）外没有别的场景单跑超过 300 秒。
- 说明见 [测试提速](../../03_再刷重制_Godot/07_开发环境/测试提速.md)。

## 交接板

- 下一步：slice_probe／smart_ai_probe 分片增量等哪吒的事件探针增量框架合进 main 后再派（本车道这批不做，用户 2026-10-25 定做完已规划任务后恢复双车道）。
- 下一步（建议）：floor 类测试一半时间在等真实秒数的战斗计时器，可做测试专用战斗节奏倍速或查清 `--fixed-fps` 下 variants 卡死（见可优化）。

## 进度账

- 无（只改工具与测试，不改完成度）

## 可优化（流程／工具／效率）

- 已做：XDB JSON 解析缓存（回退 `XIYOU_JSON_CACHE=0`）；headless 不睡逐个选用（回退 `XIYOU_HEADLESS_SLEEP_USEC=6900`）；拆 xiyou_variants（回退：删 `_b` 场景、主场景去掉 `parts = 2`）。
- 建议：其他测试若也拿固定帧数等动画，可改成按条件等，之后就能选用不睡（归各测试所属车道，顺手做）。
- 建议：floor、variants 一类测试一半时间在等战斗横幅（`XBattleScene._say`）、胜利延时等真实秒数的计时器（goblin024 墙钟 102 秒、CPU 48 秒）。给测试一个只在 headless 测试里生效的战斗节奏倍速，或查清 `--fixed-fps 144` 下 xiyou_variants 卡死的原因后改用固定帧率，floor 类约 30 个场景可再省一半时间（归本车道续做，需动 `并行测试.py` 时交哪吒）。
- 建议：`xiyou_rules*` 24 份每份各解析一次 150 MB 的 slice_d*（约 4～5 秒）并重建全部 572 个敌群；改用 `XDB.parse_file` 可省约 2 秒／份（归哪吒）。

## 本分支提交

- 3c6850bc WIP: 木吒交付单（改派后范围）
- 2ce3a199 WIP: XDB JSON 解析缓存与 xiyou_json_cache 回归
- a6e2b1e1 WIP: headless 不睡（已改为逐个选用，见上）；xiyou_variants 拆两份
- e55b9edb WIP: 测试提速.md 草稿
- 62fe2fcc WIP: headless 不睡改为逐个测试选用；dungeon、event_compare 选用；交付单接续要点
- 419fa2a2、b09f5782 WIP: 交付单（提交号、battle_events 归因）
- b24c9fb7 合并 main
- 22820e85 WIP: 交付单写变更记录草稿、验证、可优化
- 本条：交付单验证结果、标可合并
