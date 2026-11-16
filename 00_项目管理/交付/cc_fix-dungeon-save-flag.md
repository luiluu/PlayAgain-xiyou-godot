# 交付：cc/fix-dungeon-save-flag

- 车道／工作者：T055 副本内外回城判断反了（玩家报），cc（Opus＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·未经审查】T055 副本外回城／存档被拦「当前正在挑战副本」：变量 21 停在 −1（dev.待定）

- 玩家 11-16 私聊截图：野外（不在副本）用回城物品弹「当前正在挑战副本，不可使用该物品！」，副本里反而能存档、回城。
- 判断口径（原版数据，未改）：变量 21（System 名「存档」）是「在副本内」计数，副本门进门 +1，逃离／通关／重置 −1。45 个回城公共事件（CE10 回到大厅、CE12…CE1214）条件都是 `111 [1, 21, 0, 0, 0]`＝变量 21 等于 0 才传送，否则出这句；CE1 存档同样要变量 21＝0。**解释器条件分支没判反**；是变量 21 在副本外成了 −1：副本外 −1≠0 被拦，进副本 +1 变 0 反而放行，正好是「反过来」。
- 根因①（重制独有，主因）：抽奖强制存档 CE1431／1432／1433（两处）／1434 写成「变量 21 −1 → 调 CE1 存档 → 变量 21 +1」（让副本里也能存这一档，防 SL 赌博）。Map141「深渊:未知存在」事件 1 一进就调 CE1434。原版存档连地图解释器一起存，读档后从存档那条接着跑，把 −1 补回来；重制不存解释器，副本里存的档读回来变量 21＝0，之后逃离再 −1＝−1，从此副本外不能回城、不能存档。修：`XDungeon.save_resume_fix`——解释器在 117 调 CE1 时认出前后正好是「变量 21 减 n／加 n」（`XDungeon.save_bias`），子游标里的存档按加回后的值写进文件，写完当场还原（`mv_script.gd` 存档分支），等于原版读档后的结果。
- 根因②（原版数据 bug）：猿神空间两扇门 Map128／Map154 事件 3「重置副本」把变量 21 连减两次（第 33、34 条／第 46、47 条），重置完是 −1，原版也会这样。修：`XDungeon.inside_repair`——顶层事件结束时变量 21 小于 0 就归零；`XDungeon.inside()` 只认大于 0（−1 不再当成在副本内，O-038／O-040 的离开收尾照常走）。不手改 generated。
- 旧档兼容（不改存档结构）：读档后 `XDungeon.repair_after_load`（`xsave.gd` `_load_data`）：有副本上下文（进门时记、随存档）且变量 5≥1 才算人在副本里，变量 21≤0 改 1；不在副本里而变量 21<0 改 0，残留的副本上下文清掉（按 O-040 恢复挂机开关，难度不动——离开后玩家可能自己改过）。已经中招的存档读一次档就好。
- 改：`modes/xiyou/core/dungeon.gd`（两个开关、`save_bias`、`repair_after_load`、`inside`、`event_finished`）、`core/mv_event_core.gd`（117 给子游标带 `save_bias`）、`map/mv_script.gd`（存档分支按偏移写）、`core/xsave.gd`（读档修正一行）。测试：`tests/xiyou_dungeon.gd` 第一轮（原版对照）关 `inside_repair`（参照 ab* 瞬移进深渊再出口原版就是 −1）、第二轮开；`tests/xiyou_event_compare.gd` 对照原版关 `inside_repair`、`_finish` 还原。
- 玩家可见：野外用回城物品、存档不再被「当前正在挑战副本」拦；副本里照旧拦。已经被拦的存档读一次档自动修好。
- 验证：新增专项 `tests/xiyou_dungeon_inside_flag` 52/52，西游档（`XState.new_game`）与天启篇档（`XTianqi.start_new_game` 炼狱）各一遍，用真实数据：Map003 EV7 二层副本门、Map123 EV6 逃离、CE10 回到大厅、CE1434 第 70～72 条、Map128 EV3。断言：副本外可用（`outside_ok`）、副本内禁用（`inside_block`）、逃离后可用（`after_escape_ok`）；副本里抽奖存档文件里变量 21＝1、读档仍禁用、逃离后可用（`lottery.*`）；两个开关全关复现玩家的 bug（`off.inside_ok_bug`、`off.outside_block_bug`）；旧坏档副本外读档归零可用、副本内 0 读回 1（`legacy.*`）；猿神空间重置修正后 0 可回城、原版 −1 被拦（`yuanshen.*`）。`反向验证`（手工）：去掉存档偏移和读档修正，`lottery.file_has_1`、`lottery.load`、`legacy.*` 等 8 项以上失败，还原后全过。本机专项 `xiyou_dungeon`、`xiyou_event_compare`、`xiyou_save_*`、`xiyou_floor_reach075`、`xiyou_seal_doors`、`xiyou_tianqi_save`、`xiyou_pause_save`、`xiyou_autosave`、`xiyou_determinism` 共 16 场全过；`检查.sh --affected main --cloud` 通过（云端 252 场＋沿用本机 16 场，运行 43877070166）。`语法检查.py` 通过。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/dungeon.gd` `XDungeon.inside_repair`、`XDungeon.save_resume_fix`；`core/mv_event_core.gd`、`map/mv_script.gd`、`core/xsave.gd`；`tests/xiyou_dungeon_inside_flag.gd`、`tests/xiyou_dungeon.gd`、`tests/xiyou_event_compare.gd` | 猿神空间门（Map128／154 EV3）重置连减两次变量 21 成 −1；抽奖强制存档在副本里存下少 1 的变量 21（原版靠读档续跑补回，重制没有续跑） | 变量 21 顶层事件结束不留负数、只认 >0 为副本内、读档按副本上下文修正；抽奖包着的存档按加回后的值写 | 玩家 11-16 报副本外回城被拦（T055） | `XDungeon.inside_repair = false`、`XDungeon.save_resume_fix = false` | cc | 保留 |

## 交接板

- 下一步：无（玩家那份存档读一次档即可；如能拿到存档可再核一次是哪条路径）
- 用户试玩说明：野外用回城物品不再提示「当前正在挑战副本」；副本里照旧不能用。
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 见 `git log main..cc/fix-dungeon-save-flag`
